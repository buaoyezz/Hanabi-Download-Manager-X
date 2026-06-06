import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:provider/provider.dart';

import '../../models/plugin_manifest.dart';
import '../../services/plugin_diagnostic_logger.dart';
import '../../services/plugin_lifecycle_service.dart';
import '../../services/plugin_process_runner.dart';
import '../../theme/app_theme.dart';
import '../../utils/fluent_icons.dart' as custom_icons;
import '../../widgets/plugin_ui_renderer.dart';

class PluginSettingsDialog extends StatefulWidget {
  final InstalledPlugin plugin;
  final bool isChinese;

  const PluginSettingsDialog({
    super.key,
    required this.plugin,
    required this.isChinese,
  });

  @override
  State<PluginSettingsDialog> createState() => _PluginSettingsDialogState();
}

class _PluginSettingsDialogState extends State<PluginSettingsDialog> {
  late Map<String, dynamic> _state;
  bool _didLoadSaved = false;
  final PluginDiagnosticLogger _diag = PluginDiagnosticLogger();
  String? _lastBuildSignature;

  @override
  void initState() {
    super.initState();
    _state = {};
    _diag.mark(
      'settingsDialog.initState',
      pluginId: widget.plugin.id,
      data: <String, Object?>{
        'directory': widget.plugin.directory,
        'state': widget.plugin.state.name,
        'enabled': widget.plugin.enabled,
      },
    );

    final settings = widget.plugin.manifest.uiExtensions?['settings'];
    if (settings != null) {
      for (final element in settings) {
        if (element.defaultValue != null) {
          _state[element.id] = element.defaultValue;
        }
      }
    }
    _diag.mark(
      'settingsDialog.initState.defaultsLoaded',
      pluginId: widget.plugin.id,
      data: <String, Object?>{'keys': _state.keys.toList(), 'state': _state},
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didLoadSaved) {
      _didLoadSaved = true;
      final pluginService = context.read<PluginLifecycleService>();
      final savedSettings = pluginService.getPluginSettings(widget.plugin.id);
      if (savedSettings != null) {
        _state.addAll(savedSettings);
      }
      _diag.mark(
        'settingsDialog.dependencies.loadedSaved',
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
      'settingsDialog.stateChanged.start',
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
      pluginService.savePluginSettings(widget.plugin.id, newState).catchError(
        (e) {
          _diag.error(
            'settingsDialog.saveState.error',
            e,
            pluginId: widget.plugin.id,
          );
          debugPrint('Failed to save plugin settings: $e');
        },
      ),
    );

    final runner = context.read<PluginProcessRunner>();
    _diag.mark(
      'settingsDialog.invoke.onSettingsChanged.start',
      pluginId: widget.plugin.id,
      data: newState,
    );
    runner
        .invoke(
      widget.plugin,
      method: 'onSettingsChanged',
      params: newState,
    )
        .catchError((e) {
      _diag.error(
        'settingsDialog.invoke.onSettingsChanged.error',
        e,
        pluginId: widget.plugin.id,
      );
      debugPrint('Failed to notify plugin of settings change: $e');
      return const PluginInvocationResult(success: false);
    });
  }

  void _handleAction(String action) {
    final runner = context.read<PluginProcessRunner>();
    _diag.mark(
      'settingsDialog.action.start',
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
        'settingsDialog.action.done',
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
        'settingsDialog.action.error',
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
      'settingsDialog.dispose',
      pluginId: widget.plugin.id,
      data: <String, Object?>{'stateKeys': _state.keys.toList()},
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.plugin.manifest.uiExtensions?['settings'] ?? [];
    final buildSignature =
        '${widget.plugin.id}|${widget.plugin.directory}|${settings.length}';
    if (_lastBuildSignature != buildSignature) {
      _lastBuildSignature = buildSignature;
      _diag.mark(
        'settingsDialog.build',
        pluginId: widget.plugin.id,
        data: <String, Object?>{
          'directory': widget.plugin.directory,
          'settingsCount': settings.length,
          'settingIds': settings.map((element) => element.id).toList(),
          'stateKeys': _state.keys.toList(),
        },
      );
    }

    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 680, maxHeight: 720),
      title: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppTheme.accentPrimary.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              border: Border.all(
                color: AppTheme.accentPrimary.withValues(alpha: 0.18),
              ),
            ),
            child: Icon(
              custom_icons.FluentIcons.settings,
              size: 17,
              color: AppTheme.accentPrimary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isChinese
                      ? '${widget.plugin.name} 设置'
                      : '${widget.plugin.name} Settings',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${widget.plugin.id} - v${widget.plugin.version}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: FluentTheme.of(context).typography.caption?.copyWith(
                        color: AppTheme.textTertiary,
                        fontSize: 12,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 620,
        height: 500,
        child: settings.isEmpty
            ? _emptyState()
            : ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: settings.length,
                itemBuilder: (context, index) {
                  return PluginUIRenderer.renderElement(
                    element: settings[index],
                    state: _state,
                    onStateChanged: _handleStateChanged,
                    onAction: _handleAction,
                  );
                },
              ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: Text(widget.isChinese ? '关闭' : 'Close'),
        ),
      ],
    );
  }

  Widget _emptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgLayer2.withValues(alpha: 0.44),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.borderSubtle.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            custom_icons.FluentIcons.info,
            size: 18,
            color: AppTheme.textTertiary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.isChinese
                  ? '这个插件没有声明可配置项。'
                  : 'This plugin did not declare configurable settings.',
              style: FluentTheme.of(context).typography.caption?.copyWith(
                    color: AppTheme.textTertiary,
                    fontSize: 12,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
