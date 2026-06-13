import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:rhttp/rhttp.dart' as rhttp;
import 'package:win32/win32.dart';

import '../../kernel_interface.dart' as kernel;
import '../config/download_config.dart';

class NsfxResolvedProxy {
  final String type;
  final String host;
  final int port;
  final String? username;
  final String? password;
  final bool requiresAuth;
  final bool usesSystemSettings;
  final String? proxyChainDirective;

  const NsfxResolvedProxy._({
    required this.type,
    required this.host,
    required this.port,
    this.username,
    this.password,
    this.requiresAuth = false,
    this.usesSystemSettings = false,
    this.proxyChainDirective,
  });

  const NsfxResolvedProxy.direct()
      : this._(
          type: 'direct',
          host: '',
          port: 0,
        );

  const NsfxResolvedProxy.system()
      : this._(
          type: 'system',
          host: '',
          port: 0,
          usesSystemSettings: true,
        );

  const NsfxResolvedProxy.manual({
    required String type,
    required String host,
    required int port,
    String? username,
    String? password,
    bool requiresAuth = false,
    String? proxyChainDirective,
  }) : this._(
          type: type,
          host: host,
          port: port,
          username: username,
          password: password,
          requiresAuth: requiresAuth,
          proxyChainDirective: proxyChainDirective,
        );

  bool get isDirect => type == 'direct';
  bool get hasProxy => !isDirect;
  bool get isManual => hasProxy && !usesSystemSettings;

  bool get supportsHttpBasicAuth =>
      !isDirect &&
      !usesSystemSettings &&
      type != 'socks5' &&
      requiresAuth &&
      username != null &&
      username!.isNotEmpty &&
      password != null &&
      password!.isNotEmpty;

  String get identity {
    if (isDirect) {
      return 'direct';
    }
    if (usesSystemSettings) {
      return 'system';
    }
    final authKey = supportsHttpBasicAuth ? '${username!}:${password!}' : '';
    return '$type://$host:$port|$authKey';
  }

  String? get proxyDirective {
    if (isDirect || usesSystemSettings) {
      return null;
    }
    if (type == 'socks5') {
      return 'SOCKS5 $host:$port';
    }
    return 'PROXY $host:$port';
  }

  String? get displayLabel {
    if (isDirect) {
      return null;
    }
    if (usesSystemSettings) {
      return 'system';
    }
    return '$type $host:$port';
  }
}

class NsfxProxyRuntime {
  static final Map<String, _BadProxyEntry> _badProxyCache = {};
  static const Duration defaultBadProxyTtl = Duration(minutes: 5);
  static const List<Duration> _badProxyBackoffSteps = [
    defaultBadProxyTtl,
    Duration(minutes: 15),
    Duration(minutes: 30),
    Duration(hours: 1),
  ];
  static const Duration _windowsSystemProxyConfigTtl = Duration(minutes: 1);
  static const Duration _windowsSystemProxyResolutionTtl =
      Duration(seconds: 30);
  static const String _windowsInternetSettingsSubKey =
      r'Software\Microsoft\Windows\CurrentVersion\Internet Settings';
  static const int _windowsSystemProxyObserverWaitTimeoutMs = 1000;
  static const String _observerMessageReady = 'ready';
  static const String _observerMessageChanged = 'changed';
  static const String _observerMessageStopped = 'stopped';
  static const String _observerMessageError = 'error';
  static const String _observerCommandStop = 'stop';

  static _TimedCache<_WindowsSystemProxyConfig?>? _windowsSystemConfigCache;
  static final Map<String, _TimedCache<_WindowsResolvedProxyList>>
      _windowsSystemProxyCache = {};
  static Isolate? _windowsSystemProxyObserverIsolate;
  static ReceivePort? _windowsSystemProxyObserverEvents;
  static ReceivePort? _windowsSystemProxyObserverErrors;
  static ReceivePort? _windowsSystemProxyObserverExit;
  static StreamSubscription<dynamic>? _windowsSystemProxyObserverEventsSub;
  static StreamSubscription<dynamic>? _windowsSystemProxyObserverErrorsSub;
  static StreamSubscription<dynamic>? _windowsSystemProxyObserverExitSub;
  static SendPort? _windowsSystemProxyObserverControlPort;
  static Future<void>? _windowsSystemProxyObserverStartFuture;
  static Completer<void>? _windowsSystemProxyObserverStopCompleter;

  static void clearBadProxies() {
    _badProxyCache.clear();
    _clearWindowsSystemCaches();
  }

  static bool forceReloadSystemProxyConfig() {
    if (!Platform.isWindows) {
      return false;
    }
    return _refreshWindowsSystemProxyConfig(forceRefresh: true).$2;
  }

  static Future<void> ensureSystemProxyObserverStarted() {
    if (!Platform.isWindows) {
      return Future<void>.value();
    }

    forceReloadSystemProxyConfig();
    if (_windowsSystemProxyObserverIsolate != null) {
      return Future<void>.value();
    }

    final pending = _windowsSystemProxyObserverStartFuture;
    if (pending != null) {
      return pending;
    }

    final startFuture = _startWindowsSystemProxyObserver();
    _windowsSystemProxyObserverStartFuture = startFuture;
    return startFuture.whenComplete(() {
      if (identical(_windowsSystemProxyObserverStartFuture, startFuture)) {
        _windowsSystemProxyObserverStartFuture = null;
      }
    });
  }

  static Future<void> stopSystemProxyObserver() async {
    final isolate = _windowsSystemProxyObserverIsolate;
    if (isolate == null) {
      _cleanupWindowsSystemObserverState();
      return;
    }

    final pendingStart = _windowsSystemProxyObserverStartFuture;
    if (pendingStart != null) {
      await pendingStart;
    }

    final completer =
        _windowsSystemProxyObserverStopCompleter ?? Completer<void>();
    _windowsSystemProxyObserverStopCompleter = completer;
    _windowsSystemProxyObserverControlPort?.send(_observerCommandStop);

    Future<void>.delayed(const Duration(milliseconds: 1500), () {
      if (completer.isCompleted ||
          !identical(_windowsSystemProxyObserverIsolate, isolate)) {
        return;
      }
      isolate.kill(priority: Isolate.immediate);
      _cleanupWindowsSystemObserverState();
      completer.complete();
    });

    await completer.future;
  }

  static void _clearWindowsSystemCaches() {
    _windowsSystemConfigCache = null;
    _windowsSystemProxyCache.clear();
  }

  static void markProxyFailure(
    NsfxResolvedProxy proxy, {
    Duration? ttl,
  }) {
    if (!proxy.hasProxy) {
      return;
    }
    _purgeExpiredBadProxies();
    final previousFailures = _badProxyCache[proxy.identity]?.failures ?? 0;
    final failures = previousFailures + 1;
    final effectiveTtl = ttl ?? _ttlForBadProxyFailure(failures);
    _badProxyCache[proxy.identity] = _BadProxyEntry(
      failures: failures,
      expiresAt: DateTime.now().add(effectiveTtl),
    );
  }

  static bool isBadProxy(NsfxResolvedProxy proxy) {
    if (!proxy.hasProxy) {
      return false;
    }
    _purgeExpiredBadProxies();
    final entry = _badProxyCache[proxy.identity];
    return entry != null && entry.expiresAt.isAfter(DateTime.now());
  }

  static NsfxResolvedProxy resolveFromNextConfig(
    NsfxProxyConfig config,
    Uri uri,
  ) =>
      _resolveNextConfig(config, uri: uri);

  static NsfxResolvedProxy configuredFromNextConfig(NsfxProxyConfig config) =>
      _resolveNextConfig(config);

  static NsfxResolvedProxy resolveFromKernelConfig(
    kernel.ProxyConfig? config,
    Uri uri,
  ) =>
      _resolveKernelConfig(config, uri: uri);

  static NsfxResolvedProxy configuredFromKernelConfig(
    kernel.ProxyConfig? config,
  ) =>
      _resolveKernelConfig(config);

  static void applyToHttpClient(HttpClient client, NsfxResolvedProxy proxy) {
    if (!proxy.hasProxy) {
      client.findProxy = (_) => 'DIRECT';
      return;
    }

    if (proxy.usesSystemSettings) {
      client.findProxy = (uri) {
        if (_shouldBypassProxy(uri)) {
          return 'DIRECT';
        }
        if (Platform.isWindows) {
          final resolved = _resolveWindowsSystemProxy(uri);
          return resolved.proxyChainDirective ??
              resolved.proxyDirective ??
              'DIRECT';
        }
        return HttpClient.findProxyFromEnvironment(uri);
      };
      return;
    }

    client.findProxy = (uri) {
      if (_shouldBypassProxy(uri)) {
        return 'DIRECT';
      }
      return proxy.proxyChainDirective ?? proxy.proxyDirective!;
    };

    if (proxy.supportsHttpBasicAuth) {
      client.addProxyCredentials(
        proxy.host,
        proxy.port,
        'Basic',
        HttpClientBasicCredentials(
          proxy.username!,
          proxy.password!,
        ),
      );
    }
  }

  static rhttp.ProxySettings? toRhttpProxySettings(NsfxResolvedProxy proxy) {
    if (!proxy.hasProxy) {
      return const rhttp.ProxySettings.noProxy();
    }
    if (proxy.usesSystemSettings) {
      return null;
    }

    final scheme = proxy.type == 'socks5' ? 'socks5' : 'http';
    String auth = '';
    if (proxy.supportsHttpBasicAuth) {
      final user = Uri.encodeComponent(proxy.username!);
      final pass = Uri.encodeComponent(proxy.password!);
      auth = '$user:$pass@';
    }

    return rhttp.ProxySettings.proxy(
      '$scheme://$auth${proxy.host}:${proxy.port}',
    );
  }

  static NsfxResolvedProxy resolveProxyListString(
    String? rawProxyList,
    Uri uri, {
    String? bypassList,
  }) {
    if (_shouldBypassProxy(uri) || _shouldBypassRawList(uri, bypassList)) {
      return const NsfxResolvedProxy.direct();
    }

    final candidates = _parseProxyCandidates(
      rawProxyList,
      uri,
    );
    if (candidates.isEmpty) {
      return const NsfxResolvedProxy.direct();
    }

    final proxyChainDirective = buildHttpClientProxyDirective(
      rawProxyList,
      uri,
      bypassList: bypassList,
    );
    for (final candidate in candidates) {
      if (candidate.isDirect) {
        return const NsfxResolvedProxy.direct();
      }
      if (!isBadProxy(candidate)) {
        return _withProxyChainDirective(candidate, proxyChainDirective);
      }
    }

    return const NsfxResolvedProxy.direct();
  }

  static String buildHttpClientProxyDirective(
    String? rawProxyList,
    Uri uri, {
    String? bypassList,
  }) {
    if (_shouldBypassProxy(uri) || _shouldBypassRawList(uri, bypassList)) {
      return 'DIRECT';
    }

    final candidates = _parseProxyCandidates(rawProxyList, uri);
    if (candidates.isEmpty) {
      return 'DIRECT';
    }

    final directives = <String>[];
    for (final candidate in candidates) {
      if (candidate.isDirect) {
        directives.add('DIRECT');
        continue;
      }
      if (isBadProxy(candidate)) {
        continue;
      }
      final directive = candidate.proxyDirective;
      if (directive != null && directive.isNotEmpty) {
        directives.add(directive);
      }
    }

    return directives.isEmpty ? 'DIRECT' : directives.join('; ');
  }

  static NsfxResolvedProxy _resolveNextConfig(
    NsfxProxyConfig config, {
    Uri? uri,
  }) {
    if (!config.enabled) {
      return const NsfxResolvedProxy.direct();
    }
    if (uri != null && _shouldBypassProxy(uri)) {
      return const NsfxResolvedProxy.direct();
    }

    final resolved = _configuredProxy(
      type: config.type,
      host: config.host,
      port: config.port,
      username: config.username,
      password: config.password,
      requiresAuth: config.requiresAuth,
      uri: uri,
    );

    return isBadProxy(resolved) ? const NsfxResolvedProxy.direct() : resolved;
  }

  static NsfxResolvedProxy _resolveKernelConfig(
    kernel.ProxyConfig? config, {
    Uri? uri,
  }) {
    if (config == null || !config.enabled) {
      return const NsfxResolvedProxy.direct();
    }
    if (uri != null && _shouldBypassProxy(uri)) {
      return const NsfxResolvedProxy.direct();
    }

    final resolved = _configuredProxy(
      type: config.type,
      host: config.host,
      port: config.port,
      username: config.username,
      password: config.password,
      requiresAuth: config.requiresAuth,
      uri: uri,
    );

    return isBadProxy(resolved) ? const NsfxResolvedProxy.direct() : resolved;
  }

  static NsfxResolvedProxy _configuredProxy({
    required String type,
    required String host,
    required int port,
    required String? username,
    required String? password,
    required bool requiresAuth,
    Uri? uri,
  }) {
    final normalizedType = type.trim().toLowerCase();
    if (normalizedType.isEmpty || normalizedType == 'system') {
      return _resolveSystemProxy(uri);
    }

    return NsfxResolvedProxy.manual(
      type: normalizedType == 'socks' ? 'socks5' : normalizedType,
      host: host.trim().isEmpty ? '127.0.0.1' : host.trim(),
      port: port,
      username: username,
      password: password,
      requiresAuth: requiresAuth,
    );
  }

  static NsfxResolvedProxy _resolveSystemProxy(Uri? uri) {
    if (uri == null) {
      return const NsfxResolvedProxy.system();
    }
    if (Platform.isWindows) {
      return _resolveWindowsSystemProxy(uri);
    }
    return const NsfxResolvedProxy.system();
  }

  static NsfxResolvedProxy _resolveWindowsSystemProxy(Uri uri) {
    if (_shouldBypassProxy(uri)) {
      return const NsfxResolvedProxy.direct();
    }

    final config = _getWindowsSystemProxyConfig();
    if (config == null) {
      return const NsfxResolvedProxy.system();
    }

    final cacheKey = '${config.cacheKey}|${uri.toString()}';
    final now = DateTime.now();
    final cachedResolution = _windowsSystemProxyCache[cacheKey];
    if (cachedResolution != null && !cachedResolution.isExpired(now)) {
      return _resolveWindowsProxyList(
        cachedResolution.value,
        uri,
      );
    }

    if (config.shouldBypass(uri)) {
      return const NsfxResolvedProxy.direct();
    }

    if (config.hasAutoProxy) {
      final autoProxy = _resolveWindowsAutoProxy(uri, config);
      if (autoProxy != null) {
        _windowsSystemProxyCache[cacheKey] = _TimedCache(
          value: autoProxy,
          expiresAt: now.add(_windowsSystemProxyResolutionTtl),
        );
        return _resolveWindowsProxyList(autoProxy, uri);
      }
    }

    if (config.hasManualProxy) {
      return _resolveWindowsProxyList(
        _WindowsResolvedProxyList(
          proxyList: config.manualProxyList,
          proxyBypass: config.proxyBypass,
        ),
        uri,
      );
    }

    return const NsfxResolvedProxy.direct();
  }

  static _WindowsSystemProxyConfig? _getWindowsSystemProxyConfig({
    bool forceRefresh = false,
  }) =>
      _refreshWindowsSystemProxyConfig(forceRefresh: forceRefresh).$1;

  static (_WindowsSystemProxyConfig?, bool) _refreshWindowsSystemProxyConfig({
    bool forceRefresh = false,
  }) {
    if (!Platform.isWindows) {
      return (null, false);
    }

    final now = DateTime.now();
    final cached = _windowsSystemConfigCache;
    if (!forceRefresh && cached != null && !cached.isExpired(now)) {
      return (cached.value, false);
    }

    final previousKey = cached?.value?.cacheKey;
    final config = _readWindowsSystemProxyConfig();
    final changed = previousKey != config?.cacheKey;
    if (changed) {
      _badProxyCache.clear();
      _windowsSystemProxyCache.clear();
    }
    _windowsSystemConfigCache = _TimedCache(
      value: config,
      expiresAt: now.add(_windowsSystemProxyConfigTtl),
    );
    return (config, changed);
  }

  static Future<void> _startWindowsSystemProxyObserver() async {
    final events = ReceivePort();
    final errors = ReceivePort();
    final exit = ReceivePort();

    _windowsSystemProxyObserverEvents = events;
    _windowsSystemProxyObserverErrors = errors;
    _windowsSystemProxyObserverExit = exit;

    _windowsSystemProxyObserverEventsSub = events.listen(
      _handleWindowsSystemProxyObserverMessage,
    );
    _windowsSystemProxyObserverErrorsSub = errors.listen((_) {
      _handleWindowsSystemProxyObserverMessage(
        const <Object?>[_observerMessageError],
      );
    });
    _windowsSystemProxyObserverExitSub = exit.listen((_) {
      _handleWindowsSystemProxyObserverMessage(
        const <Object?>[_observerMessageStopped],
      );
    });

    _windowsSystemProxyObserverIsolate = await Isolate.spawn(
      _windowsSystemProxyRegistryObserverMain,
      events.sendPort,
      errorsAreFatal: false,
      onError: errors.sendPort,
      onExit: exit.sendPort,
    );
  }

  static void _handleWindowsSystemProxyObserverMessage(dynamic message) {
    if (message is! List<Object?> || message.isEmpty) {
      return;
    }

    final type = message.first;
    if (type == _observerMessageReady) {
      final sendPort = message.length > 1 ? message[1] : null;
      if (sendPort is SendPort) {
        _windowsSystemProxyObserverControlPort = sendPort;
      }
      return;
    }

    if (type == _observerMessageChanged) {
      forceReloadSystemProxyConfig();
      return;
    }

    if (type == _observerMessageError || type == _observerMessageStopped) {
      final completer = _windowsSystemProxyObserverStopCompleter;
      _cleanupWindowsSystemObserverState();
      if (completer != null && !completer.isCompleted) {
        completer.complete();
      }
    }
  }

  static void _cleanupWindowsSystemObserverState() {
    _windowsSystemProxyObserverControlPort = null;
    _windowsSystemProxyObserverIsolate = null;
    _windowsSystemProxyObserverStopCompleter = null;
    _windowsSystemProxyObserverEventsSub?.cancel();
    _windowsSystemProxyObserverErrorsSub?.cancel();
    _windowsSystemProxyObserverExitSub?.cancel();
    _windowsSystemProxyObserverEvents?.close();
    _windowsSystemProxyObserverErrors?.close();
    _windowsSystemProxyObserverExit?.close();
    _windowsSystemProxyObserverEventsSub = null;
    _windowsSystemProxyObserverErrorsSub = null;
    _windowsSystemProxyObserverExitSub = null;
    _windowsSystemProxyObserverEvents = null;
    _windowsSystemProxyObserverErrors = null;
    _windowsSystemProxyObserverExit = null;
  }

  static _WindowsSystemProxyConfig? _readWindowsSystemProxyConfig() {
    final configPtr = calloc<WinHttpCurrentUserIeProxyConfig>();
    try {
      if (_winHttpGetIEProxyConfigForCurrentUser(configPtr) == FALSE) {
        return null;
      }

      return _WindowsSystemProxyConfig(
        autoDetect: configPtr.ref.fAutoDetect != FALSE,
        autoConfigUrl: _readWideString(configPtr.ref.lpszAutoConfigUrl),
        manualProxyList: _readWideString(configPtr.ref.lpszProxy),
        proxyBypass: _readWideString(configPtr.ref.lpszProxyBypass),
      );
    } finally {
      _freeGlobalWideString(configPtr.ref.lpszAutoConfigUrl);
      _freeGlobalWideString(configPtr.ref.lpszProxy);
      _freeGlobalWideString(configPtr.ref.lpszProxyBypass);
      calloc.free(configPtr);
    }
  }

  static _WindowsResolvedProxyList? _resolveWindowsAutoProxy(
    Uri uri,
    _WindowsSystemProxyConfig config,
  ) {
    final userAgentPtr = NsfxConfig.defaultUserAgentFallback.toNativeUtf16();
    final session = _winHttpOpen(
      userAgentPtr,
      _winHttpAccessTypeNoProxy,
      nullptr.cast<Utf16>(),
      nullptr.cast<Utf16>(),
      0,
    );
    calloc.free(userAgentPtr);

    if (session == 0) {
      return null;
    }

    final urlPtr = uri.toString().toNativeUtf16();
    final options = calloc<WinHttpAutoproxyOptions>();
    final proxyInfo = calloc<WinHttpProxyInfo>();
    Pointer<Utf16> autoConfigUrlPtr = nullptr;

    try {
      if (config.autoDetect) {
        options.ref.dwFlags |= _winHttpAutoProxyAutoDetect;
        options.ref.dwAutoDetectFlags =
            _winHttpAutoDetectTypeDhcp | _winHttpAutoDetectTypeDnsA;
      }

      final autoConfigUrl = config.autoConfigUrl?.trim() ?? '';
      if (autoConfigUrl.isNotEmpty) {
        autoConfigUrlPtr = autoConfigUrl.toNativeUtf16();
        options.ref.dwFlags |= _winHttpAutoProxyConfigUrl;
        options.ref.lpszAutoConfigUrl = autoConfigUrlPtr;
      }

      options.ref.fAutoLogonIfChallenged = TRUE;
      if (options.ref.dwFlags == 0) {
        return null;
      }

      if (_winHttpGetProxyForUrl(session, urlPtr, options, proxyInfo) ==
          FALSE) {
        return null;
      }

      final accessType = proxyInfo.ref.dwAccessType;
      final proxyList = accessType == _winHttpAccessTypeNamedProxy
          ? _readWideString(proxyInfo.ref.lpszProxy)
          : null;

      return _WindowsResolvedProxyList(
        proxyList: proxyList,
        proxyBypass: _readWideString(proxyInfo.ref.lpszProxyBypass),
      );
    } finally {
      if (autoConfigUrlPtr.address != 0) {
        calloc.free(autoConfigUrlPtr);
      }
      _freeGlobalWideString(proxyInfo.ref.lpszProxy);
      _freeGlobalWideString(proxyInfo.ref.lpszProxyBypass);
      calloc.free(proxyInfo);
      calloc.free(options);
      if (session != 0) {
        _winHttpCloseHandle(session);
      }
      calloc.free(urlPtr);
    }
  }

  static List<NsfxResolvedProxy> _parseProxyCandidates(
    String? rawProxyList,
    Uri uri,
  ) {
    final proxyList = _selectProxyListForUri(
      rawProxyList,
      uri,
    );
    if (proxyList == null || proxyList.trim().isEmpty) {
      return const [];
    }

    final candidates = <NsfxResolvedProxy>[];
    for (final rawCandidate in proxyList.split(RegExp(r'[;,]'))) {
      final candidate = _parseProxyCandidate(rawCandidate.trim());
      if (candidate != null) {
        candidates.add(candidate);
      }
    }
    return candidates;
  }

  static String? _selectProxyListForUri(
    String? rawProxyList,
    Uri uri,
  ) {
    final normalized = rawProxyList?.trim() ?? '';
    if (normalized.isEmpty) {
      return null;
    }

    final segments = normalized
        .split(';')
        .map((segment) => segment.trim())
        .where((segment) => segment.isNotEmpty)
        .toList();
    if (segments.isEmpty) {
      return null;
    }

    final hasAssignments = segments.any((segment) => segment.contains('='));
    if (!hasAssignments) {
      return normalized;
    }

    String? generic;
    final perScheme = <String, String>{};
    for (final segment in segments) {
      final separator = segment.indexOf('=');
      if (separator <= 0) {
        generic ??= segment;
        continue;
      }

      final scheme = segment.substring(0, separator).trim().toLowerCase();
      final value = segment.substring(separator + 1).trim();
      if (value.isEmpty) {
        continue;
      }
      perScheme[scheme] = value;
    }

    final requestScheme = uri.scheme.toLowerCase();
    if (requestScheme == 'https') {
      return perScheme['https'] ??
          perScheme['http'] ??
          perScheme['socks'] ??
          perScheme['socks5'] ??
          generic;
    }

    if (requestScheme == 'http') {
      return perScheme['http'] ??
          perScheme['https'] ??
          perScheme['socks'] ??
          perScheme['socks5'] ??
          generic;
    }

    return perScheme[requestScheme] ??
        perScheme['http'] ??
        perScheme['https'] ??
        perScheme['socks'] ??
        perScheme['socks5'] ??
        generic;
  }

  static NsfxResolvedProxy? _parseProxyCandidate(String rawCandidate) {
    final normalized = rawCandidate.trim();
    if (normalized.isEmpty) {
      return null;
    }

    if (normalized.toUpperCase() == 'DIRECT') {
      return const NsfxResolvedProxy.direct();
    }

    var proxyType = 'http';
    var endpoint = normalized;
    final assignmentSeparator = normalized.indexOf('=');
    if (assignmentSeparator > 0) {
      final assignedType =
          normalized.substring(0, assignmentSeparator).trim().toLowerCase();
      endpoint = normalized.substring(assignmentSeparator + 1).trim();
      if (assignedType.startsWith('socks')) {
        proxyType = 'socks5';
      }
    }

    final lowerEndpoint = endpoint.toLowerCase();
    if (lowerEndpoint.startsWith('socks://') ||
        lowerEndpoint.startsWith('socks5://')) {
      proxyType = 'socks5';
    }

    final hostPort = _parseHostPort(
      endpoint,
      defaultPort: proxyType == 'socks5' ? 1080 : 80,
    );
    if (hostPort == null) {
      return null;
    }

    return NsfxResolvedProxy.manual(
      type: proxyType,
      host: hostPort.$1,
      port: hostPort.$2,
    );
  }

  static (String, int)? _parseHostPort(
    String rawEndpoint, {
    required int defaultPort,
  }) {
    final normalized = rawEndpoint.trim();
    if (normalized.isEmpty) {
      return null;
    }

    final prefixed =
        normalized.contains('://') ? normalized : 'http://$normalized';
    final uri = Uri.tryParse(prefixed);
    if (uri == null || uri.host.trim().isEmpty) {
      return null;
    }

    return (uri.host.trim(), uri.hasPort ? uri.port : defaultPort);
  }

  static bool _shouldBypassProxy(Uri uri) {
    if (_isLocalHost(uri.host)) {
      return true;
    }

    final noProxy = Platform.environment['NO_PROXY'] ??
        Platform.environment['no_proxy'] ??
        '';
    return _shouldBypassRawList(uri, noProxy);
  }

  static bool _shouldBypassRawList(Uri uri, String? rawBypassList) {
    for (final entry in _splitBypassEntries(rawBypassList)) {
      if (_matchesNoProxyEntry(uri, entry)) {
        return true;
      }
    }
    return false;
  }

  static Iterable<String> _splitBypassEntries(String? rawBypassList) sync* {
    final normalized = rawBypassList?.trim() ?? '';
    if (normalized.isEmpty) {
      return;
    }

    for (final rawEntry in normalized.split(RegExp(r'[;,]'))) {
      final entry = rawEntry.trim();
      if (entry.isNotEmpty) {
        yield entry;
      }
    }
  }

  static bool _matchesNoProxyEntry(Uri uri, String entry) {
    final host = uri.host.toLowerCase();
    final normalized = entry.trim().toLowerCase();
    if (normalized.isEmpty) {
      return false;
    }

    if (normalized == '*' || normalized == '<-loopback>') {
      return true;
    }
    if (normalized == '<local>') {
      return !host.contains('.');
    }
    if (normalized.startsWith('.')) {
      final suffix = normalized.substring(1);
      return host == suffix || host.endsWith('.$suffix');
    }

    final candidate = normalized.contains(':')
        ? '${uri.host}:${uri.port}'.toLowerCase()
        : host;

    if (normalized.contains('*') || normalized.contains('?')) {
      final pattern =
          '^${RegExp.escape(normalized).replaceAll(r'\*', '.*').replaceAll(r'\?', '.')}\$';
      return RegExp(pattern).hasMatch(candidate);
    }

    return candidate == normalized || host.endsWith('.$normalized');
  }

  static bool _isLocalHost(String host) {
    final normalized = host.trim().toLowerCase();
    return normalized == 'localhost' ||
        normalized == '127.0.0.1' ||
        normalized == '::1';
  }

  static String? _readWideString(Pointer<Utf16> pointer) {
    if (pointer.address == 0) {
      return null;
    }
    final value = pointer.toDartString().trim();
    return value.isEmpty ? null : value;
  }

  static void _freeGlobalWideString(Pointer<Utf16> pointer) {
    if (pointer.address != 0) {
      GlobalFree(HGLOBAL(pointer.cast()));
    }
  }

  static void _purgeExpiredBadProxies() {
    final now = DateTime.now();
    _badProxyCache.removeWhere((_, entry) => !entry.expiresAt.isAfter(now));
  }

  static Duration _ttlForBadProxyFailure(int failures) {
    final index = failures <= 1
        ? 0
        : (failures - 1).clamp(0, _badProxyBackoffSteps.length - 1);
    return _badProxyBackoffSteps[index];
  }

  static NsfxResolvedProxy _resolveWindowsProxyList(
    _WindowsResolvedProxyList resolvedList,
    Uri uri,
  ) {
    return resolveProxyListString(
      resolvedList.proxyList,
      uri,
      bypassList: resolvedList.proxyBypass,
    );
  }

  static NsfxResolvedProxy _withProxyChainDirective(
    NsfxResolvedProxy proxy,
    String proxyChainDirective,
  ) {
    if (proxy.isDirect || proxyChainDirective == 'DIRECT') {
      return proxy;
    }

    return NsfxResolvedProxy.manual(
      type: proxy.type,
      host: proxy.host,
      port: proxy.port,
      username: proxy.username,
      password: proxy.password,
      requiresAuth: proxy.requiresAuth,
      proxyChainDirective: proxyChainDirective,
    );
  }
}

class _WindowsSystemProxyConfig {
  final bool autoDetect;
  final String? autoConfigUrl;
  final String? manualProxyList;
  final String? proxyBypass;

  const _WindowsSystemProxyConfig({
    required this.autoDetect,
    required this.autoConfigUrl,
    required this.manualProxyList,
    required this.proxyBypass,
  });

  bool get hasAutoProxy =>
      autoDetect || (autoConfigUrl != null && autoConfigUrl!.isNotEmpty);

  bool get hasManualProxy =>
      manualProxyList != null && manualProxyList!.trim().isNotEmpty;

  String get cacheKey =>
      '${autoDetect ? 1 : 0}|${autoConfigUrl ?? ''}|${manualProxyList ?? ''}|${proxyBypass ?? ''}';

  bool shouldBypass(Uri uri) =>
      NsfxProxyRuntime._shouldBypassRawList(uri, proxyBypass);
}

class _WindowsResolvedProxyList {
  final String? proxyList;
  final String? proxyBypass;

  const _WindowsResolvedProxyList({
    required this.proxyList,
    required this.proxyBypass,
  });
}

class _TimedCache<T> {
  final T value;
  final DateTime expiresAt;

  const _TimedCache({
    required this.value,
    required this.expiresAt,
  });

  bool isExpired(DateTime now) => !expiresAt.isAfter(now);
}

class _BadProxyEntry {
  final int failures;
  final DateTime expiresAt;

  const _BadProxyEntry({
    required this.failures,
    required this.expiresAt,
  });
}

void _windowsSystemProxyRegistryObserverMain(SendPort eventsPort) {
  if (!Platform.isWindows) {
    eventsPort.send(const <Object?>[NsfxProxyRuntime._observerMessageStopped]);
    return;
  }

  final controlPort = ReceivePort();
  eventsPort.send(<Object?>[
    NsfxProxyRuntime._observerMessageReady,
    controlPort.sendPort,
  ]);

  var shouldStop = false;
  final controlSub = controlPort.listen((message) {
    if (message == NsfxProxyRuntime._observerCommandStop) {
      shouldStop = true;
    }
  });

  final subKeyPtr =
      NsfxProxyRuntime._windowsInternetSettingsSubKey.toNativeUtf16();
  final keyPtr = calloc<IntPtr>();
  HKEY registryKey = HKEY(Pointer.fromAddress(0));
  HANDLE eventHandle = HANDLE(Pointer.fromAddress(0));

  try {
    final openResult = RegOpenKeyEx(
      HKEY_CURRENT_USER,
      PCWSTR(subKeyPtr),
      0,
      KEY_NOTIFY,
      keyPtr.cast(),
    );
    if (openResult != ERROR_SUCCESS) {
      eventsPort.send(<Object?>[
        NsfxProxyRuntime._observerMessageError,
        openResult,
      ]);
      return;
    }

    registryKey = HKEY(Pointer.fromAddress(keyPtr.value));
    eventHandle = CreateEvent(
      Pointer.fromAddress(0),
      false,
      false,
      PCWSTR(Pointer.fromAddress(0)),
    ).value;
    if (eventHandle.address == 0) {
      eventsPort.send(const <Object?>[NsfxProxyRuntime._observerMessageError]);
      return;
    }

    while (!shouldStop) {
      final notifyResult = RegNotifyChangeKeyValue(
        registryKey,
        false,
        REG_NOTIFY_CHANGE_LAST_SET,
        eventHandle,
        true,
      );
      if (notifyResult != ERROR_SUCCESS) {
        eventsPort.send(<Object?>[
          NsfxProxyRuntime._observerMessageError,
          notifyResult,
        ]);
        break;
      }

      final waitResult = WaitForSingleObject(
        eventHandle,
        NsfxProxyRuntime._windowsSystemProxyObserverWaitTimeoutMs,
      );
      if (waitResult.value == WAIT_OBJECT_0) {
        eventsPort.send(
          const <Object?>[NsfxProxyRuntime._observerMessageChanged],
        );
      } else if (waitResult.value != WAIT_TIMEOUT) {
        eventsPort.send(<Object?>[
          NsfxProxyRuntime._observerMessageError,
          waitResult.value,
        ]);
        break;
      }
    }
  } finally {
    controlSub.cancel();
    controlPort.close();
    if (eventHandle.address != 0) {
      CloseHandle(eventHandle);
    }
    if (registryKey.address != 0) {
      RegCloseKey(registryKey);
    }
    calloc.free(keyPtr);
    calloc.free(subKeyPtr);
    eventsPort.send(const <Object?>[NsfxProxyRuntime._observerMessageStopped]);
  }
}

final DynamicLibrary _winHttp = DynamicLibrary.open('winhttp.dll');

const int _winHttpAccessTypeNoProxy = 1;
const int _winHttpAccessTypeNamedProxy = 3;
const int _winHttpAutoProxyAutoDetect = 0x00000001;
const int _winHttpAutoProxyConfigUrl = 0x00000002;
const int _winHttpAutoDetectTypeDhcp = 0x00000001;
const int _winHttpAutoDetectTypeDnsA = 0x00000002;

final int Function(
  Pointer<Utf16> userAgent,
  int accessType,
  Pointer<Utf16> proxyName,
  Pointer<Utf16> proxyBypass,
  int flags,
) _winHttpOpen = _winHttp.lookupFunction<
    IntPtr Function(
      Pointer<Utf16>,
      Uint32,
      Pointer<Utf16>,
      Pointer<Utf16>,
      Uint32,
    ),
    int Function(
      Pointer<Utf16>,
      int,
      Pointer<Utf16>,
      Pointer<Utf16>,
      int,
    )>('WinHttpOpen');

final int Function(Pointer<WinHttpCurrentUserIeProxyConfig>)
    _winHttpGetIEProxyConfigForCurrentUser = _winHttp.lookupFunction<
            Int32 Function(Pointer<WinHttpCurrentUserIeProxyConfig>),
            int Function(Pointer<WinHttpCurrentUserIeProxyConfig>)>(
        'WinHttpGetIEProxyConfigForCurrentUser');

final int Function(
  int sessionHandle,
  Pointer<Utf16> url,
  Pointer<WinHttpAutoproxyOptions> options,
  Pointer<WinHttpProxyInfo> proxyInfo,
) _winHttpGetProxyForUrl = _winHttp.lookupFunction<
    Int32 Function(
      IntPtr,
      Pointer<Utf16>,
      Pointer<WinHttpAutoproxyOptions>,
      Pointer<WinHttpProxyInfo>,
    ),
    int Function(
      int,
      Pointer<Utf16>,
      Pointer<WinHttpAutoproxyOptions>,
      Pointer<WinHttpProxyInfo>,
    )>('WinHttpGetProxyForUrl');

final int Function(int handle) _winHttpCloseHandle =
    _winHttp.lookupFunction<Int32 Function(IntPtr), int Function(int)>(
        'WinHttpCloseHandle');

final class WinHttpCurrentUserIeProxyConfig extends Struct {
  @Int32()
  external int fAutoDetect;

  external Pointer<Utf16> lpszAutoConfigUrl;

  external Pointer<Utf16> lpszProxy;

  external Pointer<Utf16> lpszProxyBypass;
}

final class WinHttpAutoproxyOptions extends Struct {
  @Uint32()
  external int dwFlags;

  @Uint32()
  external int dwAutoDetectFlags;

  external Pointer<Utf16> lpszAutoConfigUrl;

  external Pointer<Void> lpvReserved;

  @Uint32()
  external int dwReserved;

  @Int32()
  external int fAutoLogonIfChallenged;
}

final class WinHttpProxyInfo extends Struct {
  @Uint32()
  external int dwAccessType;

  external Pointer<Utf16> lpszProxy;

  external Pointer<Utf16> lpszProxyBypass;
}
