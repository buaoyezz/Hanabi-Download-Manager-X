import 'dart:async';
import 'dart:io';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:path/path.dart' as path;
import 'package:provider/provider.dart';

import '../../models/plugin_manifest.dart';
import '../../services/plugin_diagnostic_logger.dart';
import '../../services/plugin_lifecycle_service.dart';
import '../../services/plugin_process_runner.dart';
import '../../theme/app_theme.dart';
import '../../utils/fluent_icons.dart' as custom_icons;
import '../../widgets/plugin_ui_renderer.dart';
import '../../widgets/settings_components.dart';
import '../../widgets/smooth_scroll_wrapper.dart';

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

    final sidebar = widget.plugin.manifest.uiExtensions?['sidebar'];
    if (sidebar != null) {
      for (final element in sidebar) {
        if (element.defaultValue != null) {
          _state[element.id] = element.defaultValue;
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

    final iconParts = _resolvePluginIcon();

    return ScaffoldPage(
      header: SettingsPageHeader(
        title: widget.plugin.name,
        icon: iconParts.icon,
        iconBuilder: iconParts.builder,
      ),
      content: SmoothSingleChildScrollView(
        config: SmoothScrollConfig.fast,
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPluginSummary(iconParts),
                const SizedBox(height: 16),
                _buildPanel(
                  title: widget.isChinese ? '插件面板' : 'Plugin panel',
                  iconParts: iconParts,
                  child: sidebar.isEmpty
                      ? _emptyState(
                          widget.isChinese
                              ? '这个插件没有声明侧边栏控件。'
                              : 'This plugin did not declare sidebar controls.',
                        )
                      : Column(
                          children: sidebar.map((element) {
                            return PluginUIRenderer.renderElement(
                              element: element,
                              state: _state,
                              onStateChanged: _handleStateChanged,
                              onAction: _handleAction,
                            );
                          }).toList(),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  _PluginIconParts _resolvePluginIcon() {
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
            return Icon(
              custom_icons.FluentIcons.app_icon_default,
              size: 16,
              color: color,
            );
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
              return Icon(
                custom_icons.FluentIcons.app_icon_default,
                size: 16,
                color: color,
              );
            },
          );
        };
      }
    } else {
      iconData = custom_icons.FluentIcons.app_icon_default;
    }

    return _PluginIconParts(
      icon: iconData ?? custom_icons.FluentIcons.app_icon_default,
      builder: iconBuilder,
    );
  }

  Widget _buildPluginSummary(_PluginIconParts iconParts) {
    return _surface(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 620;
          final titleBlock = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _iconBox(iconParts: iconParts, size: 42),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.plugin.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: FluentTheme.of(context).typography.body?.copyWith(
                            color: AppTheme.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.plugin.id} - v${widget.plugin.version} - ${widget.plugin.manifest.author}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          FluentTheme.of(context).typography.caption?.copyWith(
                                color: AppTheme.textTertiary,
                                fontSize: 12,
                              ),
                    ),
                    if (widget.plugin.manifest.description.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        widget.plugin.manifest.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: FluentTheme.of(context)
                            .typography
                            .caption
                            ?.copyWith(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );

          final badges = Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: compact ? WrapAlignment.start : WrapAlignment.end,
            children: [
              _statusPill(
                widget.plugin.enabled
                    ? (widget.isChinese ? '已启用' : 'Enabled')
                    : (widget.isChinese ? '已停用' : 'Disabled'),
                widget.plugin.enabled
                    ? AppTheme.statusSuccess
                    : AppTheme.textTertiary,
              ),
              _plainPill(widget.plugin.manifest.category),
              ...widget.plugin.manifest.capabilities.map(_plainPill),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                titleBlock,
                const SizedBox(height: 12),
                badges,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: titleBlock),
              const SizedBox(width: 16),
              badges,
            ],
          );
        },
      ),
    );
  }

  Widget _buildPanel({
    required String title,
    required Widget child,
    required _PluginIconParts iconParts,
  }) {
    return _surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconBox(iconParts: iconParts, size: 34),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: FluentTheme.of(context).typography.body?.copyWith(
                        color: AppTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _surface({required Widget child}) {
    final isDark = AppTheme.isDarkContext(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground(darkAlpha: 0.74, lightAlpha: 0.88),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: isDark
              ? AppTheme.borderSubtle.withValues(alpha: 0.60)
              : AppTheme.borderSubtle.withValues(alpha: 0.32),
        ),
        boxShadow: isDark ? null : AppTheme.shadowSm,
      ),
      child: child,
    );
  }

  Widget _iconBox({
    required _PluginIconParts iconParts,
    double size = 36,
  }) {
    final color = AppTheme.accentPrimary;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Center(
        child: iconParts.builder != null
            ? iconParts.builder!(context, color)
            : Icon(
                iconParts.icon,
                size: size * 0.48,
                color: color,
              ),
      ),
    );
  }

  Widget _emptyState(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.bgLayer2.withValues(alpha: 0.44),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.borderSubtle.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        style: FluentTheme.of(context).typography.caption?.copyWith(
              color: AppTheme.textTertiary,
              fontSize: 12,
            ),
      ),
    );
  }

  Widget _plainPill(String label) {
    final value = label.trim();
    if (value.isEmpty) {
      return const SizedBox.shrink();
    }
    return _pill(
      value,
      AppTheme.bgLayer3.withValues(alpha: 0.58),
      AppTheme.textSecondary,
      AppTheme.borderSubtle.withValues(alpha: 0.5),
    );
  }

  Widget _statusPill(String label, Color color) {
    return _pill(
      label,
      color.withValues(alpha: 0.12),
      color,
      color.withValues(alpha: 0.35),
    );
  }

  Widget _pill(String label, Color background, Color textColor, Color border) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppTheme.radiusRound),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: FluentTheme.of(context).typography.caption?.copyWith(
              color: textColor,
              fontSize: 11,
            ),
      ),
    );
  }
}

class _PluginIconParts {
  const _PluginIconParts({
    required this.icon,
    this.builder,
  });

  final IconData icon;
  final Widget Function(BuildContext, Color)? builder;
}
