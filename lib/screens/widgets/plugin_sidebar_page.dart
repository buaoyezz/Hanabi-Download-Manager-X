import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:fluent_ui/fluent_ui.dart';
import 'package:provider/provider.dart';
import '../../models/plugin_manifest.dart';
import '../../services/plugin_diagnostic_logger.dart';
import '../../services/plugin_lifecycle_service.dart';
import '../../services/plugin_process_runner.dart';
import '../../widgets/plugin_ui_renderer.dart';
import '../../widgets/settings_components.dart';
import '../../widgets/smooth_scroll_wrapper.dart';
import '../../utils/fluent_icons.dart' as custom_icons;

class PluginSidebarPage extends StatefulWidget {
  final InstalledPlugin plugin;
  final bool isChinese;

  const PluginSidebarPage({
    super.key,
    required this.plugin,
    required this.isChinese,
  });

  @override
  State<PluginSidebarPage> createState() => _PluginSidebarPageState();
}

class _PluginSidebarPageState extends State<PluginSidebarPage> {
  late Map<String, dynamic> _state;
  bool _didLoadSaved = false;
  final PluginDiagnosticLogger _diag = PluginDiagnosticLogger();
  String? _lastBuildSignature;

  @override
  void initState() {
    super.initState();
    _state = {};
    _diag.mark(
      'sidebar.initState',
      pluginId: widget.plugin.id,
      data: <String, Object?>{
        'directory': widget.plugin.directory,
        'state': widget.plugin.state.name,
        'enabled': widget.plugin.enabled,
      },
    );
    // Load default values
    final sidebar = widget.plugin.manifest.uiExtensions?['sidebar'];
    if (sidebar != null) {
      for (final el in sidebar) {
        if (el.defaultValue != null) {
          _state[el.id] = el.defaultValue;
        }
      }
    }
    _diag.mark(
      'sidebar.initState.defaultsLoaded',
      pluginId: widget.plugin.id,
      data: <String, Object?>{
        'keys': _state.keys.toList(),
        'state': _state,
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didLoadSaved) {
      _didLoadSaved = true;
      final pluginService = context.read<PluginLifecycleService>();
      final savedSettings =
          pluginService.getPluginSettings('${widget.plugin.id}_sidebar');
      if (savedSettings != null) {
        _state.addAll(savedSettings);
      }
      _diag.mark(
        'sidebar.dependencies.loadedSaved',
        pluginId: widget.plugin.id,
        data: <String, Object?>{
          'hasSavedSettings': savedSettings != null,
          'keys': _state.keys.toList(),
          'state': _state,
        },
      );
    }
  }

  void _handleStateChanged(Map<String, dynamic> newState) {
    _diag.mark(
      'sidebar.stateChanged.start',
      pluginId: widget.plugin.id,
      data: <String, Object?>{
        'oldState': _state,
        'newState': newState,
      },
    );
    setState(() {
      _state = newState;
    });
    final pluginService = context.read<PluginLifecycleService>();
    unawaited(
      pluginService
          .savePluginSettings('${widget.plugin.id}_sidebar', newState)
          .catchError((e) {
        _diag.error('sidebar.saveState.error', e, pluginId: widget.plugin.id);
        debugPrint('Failed to save plugin sidebar state: $e');
      }),
    );

    // Notify plugin
    final runner = context.read<PluginProcessRunner>();
    _diag.mark(
      'sidebar.invoke.onSidebarStateChanged.start',
      pluginId: widget.plugin.id,
      data: newState,
    );
    runner
        .invoke(
      widget.plugin,
      method: 'onSidebarStateChanged',
      params: newState,
    )
        .catchError((e) {
      _diag.error(
        'sidebar.invoke.onSidebarStateChanged.error',
        e,
        pluginId: widget.plugin.id,
      );
      debugPrint('Failed to notify plugin of sidebar state change: $e');
      return const PluginInvocationResult(success: false);
    });
  }

  void _handleAction(String action) {
    final runner = context.read<PluginProcessRunner>();
    _diag.mark(
      'sidebar.action.start',
      pluginId: widget.plugin.id,
      data: <String, Object?>{'action': action, 'state': _state},
    );
    runner
        .invoke(
      widget.plugin,
      method: action,
      params: _state,
    )
        .then((result) {
      _diag.mark(
        'sidebar.action.done',
        pluginId: widget.plugin.id,
        data: <String, Object?>{
          'action': action,
          'success': result.success,
          'exitCode': result.exitCode,
          'error': result.error,
        },
      );
      debugPrint('Plugin action $action result: ${result.result}');
    }).catchError((e) {
      _diag.error(
        'sidebar.action.error',
        e,
        pluginId: widget.plugin.id,
        data: <String, Object?>{'action': action},
      );
      debugPrint('Failed to invoke plugin action $action: $e');
    });
  }

  @override
  void dispose() {
    _diag.mark(
      'sidebar.dispose',
      pluginId: widget.plugin.id,
      data: <String, Object?>{
        'mounted': mounted,
        'stateKeys': _state.keys.toList(),
      },
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sidebar = widget.plugin.manifest.uiExtensions?['sidebar'] ?? [];
    final buildSignature =
        '${widget.plugin.id}|${widget.plugin.directory}|${sidebar.length}';
    if (_lastBuildSignature != buildSignature) {
      _lastBuildSignature = buildSignature;
      _diag.mark(
        'sidebar.build',
        pluginId: widget.plugin.id,
        data: <String, Object?>{
          'directory': widget.plugin.directory,
          'sidebarCount': sidebar.length,
          'sidebarIds': sidebar.map((element) => element.id).toList(),
          'stateKeys': _state.keys.toList(),
        },
      );
    }

    IconData? iconData;
    Widget Function(BuildContext, Color)? iconBuilder;

    final iconRaw = widget.plugin.manifest.icon;
    if (iconRaw != null && iconRaw.isNotEmpty) {
      if (iconRaw.startsWith('fluent:')) {
        final iconName = iconRaw.substring(7);
        iconData = custom_icons.FluentIcons.getIcon(iconName);
      } else {
        iconBuilder = (context, color) {
          final iconFile = File(path.join(widget.plugin.directory, iconRaw));
          if (!iconFile.existsSync()) {
            _diag.mark(
              'sidebar.icon.missing',
              pluginId: widget.plugin.id,
              data: <String, Object?>{'path': iconFile.path},
            );
            return Icon(custom_icons.FluentIcons.app_icon_default,
                size: 16, color: color);
          }
          return Image.file(
            iconFile,
            width: 16,
            height: 16,
            color: color,
            errorBuilder: (context, error, stackTrace) {
              _diag.error(
                'sidebar.icon.error',
                error,
                pluginId: widget.plugin.id,
                stackTrace: stackTrace,
                data: <String, Object?>{'path': iconFile.path},
              );
              return Icon(custom_icons.FluentIcons.app_icon_default,
                  size: 16, color: color);
            },
          );
        };
      }
    } else {
      iconData = custom_icons.FluentIcons.app_icon_default;
    }

    return ScaffoldPage(
      header: SettingsPageHeader(
        title: widget.plugin.name,
        icon: iconData,
        iconBuilder: iconBuilder,
      ),
      content: SmoothSingleChildScrollView(
        config: SmoothScrollConfig.fast,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SettingsSection(
              title: widget.isChinese ? '插件面板' : 'Plugin Panel',
              icon: iconData,
              iconBuilder: iconBuilder,
              children: sidebar.map((element) {
                return PluginUIRenderer.renderElement(
                  element: element,
                  state: _state,
                  onStateChanged: _handleStateChanged,
                  onAction: _handleAction,
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
