import '../config/download_config.dart';
import '../models/task.dart';

const Set<String> _hopByHopHeaders = {
  'connection',
  'keep-alive',
  'proxy-connection',
  'proxy-authorization',
  'transfer-encoding',
  'upgrade',
};

const Set<String> _browserManagedHeaders = {
  'accept',
  'accept-encoding',
  'accept-language',
  'alt-used',
  'cache-control',
  'content-length',
  'cookie',
  'dnt',
  'host',
  'origin',
  'pragma',
  'priority',
  'purpose',
  'range',
  'referer',
  'te',
  'upgrade-insecure-requests',
  'user-agent',
  'via',
  'x-client-data',
  'x-forwarded-for',
  'x-forwarded-host',
  'x-forwarded-proto',
};

Map<String, String> buildDownloadHeaders(Task task, NsfxConfig config) {
  final headers = <String, String>{
    'User-Agent': _normalizedOrNull(task.userAgent) ??
        _taskHeaderValue(task.headers, 'user-agent') ??
        config.defaultUserAgent,
    'Accept': '*/*',
    // Byte ranges are defined over the selected representation.  Asking for
    // identity prevents transparent gzip/br compression from changing byte
    // offsets and corrupting segmented/resumed downloads.
    'Accept-Encoding': 'identity',
    'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
  };

  final referer = _normalizedOrNull(task.referer) ??
      _taskHeaderValue(task.headers, 'referer');
  if (referer != null) {
    headers['Referer'] = referer;
  } else {
    final fallbackReferer = _deriveReferer(task.url);
    if (fallbackReferer != null) {
      headers['Referer'] = fallbackReferer;
    }
  }

  final cookie = _normalizedOrNull(task.cookies) ??
      _taskHeaderValue(task.headers, 'cookie');
  if (cookie != null) {
    headers['Cookie'] = cookie;
  }

  if (task.headers != null) {
    headers.addAll(sanitizeDownloadHeaders(task.headers!));
  }

  return headers;
}

Map<String, String> sanitizeDownloadHeaders(Map<String, String> rawHeaders) {
  final sanitized = <String, String>{};

  rawHeaders.forEach((key, value) {
    final normalizedKey = key.trim();
    final normalizedValue = value.trim();
    if (normalizedKey.isEmpty || normalizedValue.isEmpty) {
      return;
    }

    final lowerKey = normalizedKey.toLowerCase();
    if (_hopByHopHeaders.contains(lowerKey) ||
        _browserManagedHeaders.contains(lowerKey) ||
        lowerKey.startsWith('proxy-') ||
        lowerKey.startsWith('sec-') ||
        lowerKey.startsWith(':')) {
      return;
    }

    sanitized[normalizedKey] = normalizedValue;
  });

  return sanitized;
}

String? lookupHeaderValue(
  Map<String, dynamic>? rawHeaders,
  String targetHeader,
) {
  if (rawHeaders == null || rawHeaders.isEmpty) {
    return null;
  }

  final target = targetHeader.toLowerCase();
  for (final entry in rawHeaders.entries) {
    if (entry.key.toLowerCase() != target) {
      continue;
    }

    final value = entry.value?.toString().trim();
    if (value != null && value.isNotEmpty) {
      return value;
    }
  }

  return null;
}

String? _taskHeaderValue(Map<String, String>? rawHeaders, String targetHeader) {
  if (rawHeaders == null || rawHeaders.isEmpty) {
    return null;
  }

  final target = targetHeader.toLowerCase();
  for (final entry in rawHeaders.entries) {
    if (entry.key.toLowerCase() != target) {
      continue;
    }

    final value = _normalizedOrNull(entry.value);
    if (value != null) {
      return value;
    }
  }

  return null;
}

String? _normalizedOrNull(String? value) {
  final normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }
  return normalized;
}

String? _deriveReferer(String url) {
  try {
    final uri = Uri.parse(url);
    return '${uri.scheme}://${uri.host}/';
  } catch (_) {
    return null;
  }
}
