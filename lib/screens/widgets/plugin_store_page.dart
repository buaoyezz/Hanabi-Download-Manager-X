import 'dart:io';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:path/path.dart' as path;
import 'package:provider/provider.dart';

import '../../models/plugin_manifest.dart';
import '../../models/plugin_store_models.dart';
import '../../services/plugin_diagnostic_logger.dart';
import '../../services/plugin_lifecycle_service.dart';
import '../../services/plugin_store_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/fluent_icons.dart' as custom_icons;
import '../../widgets/animated_notifications.dart';
import '../../widgets/folder_picker_dialog.dart';
import '../../widgets/settings_components.dart';
import '../../widgets/smooth_scroll_wrapper.dart';
import 'plugin_settings_dialog.dart';

class PluginStorePage extends StatefulWidget {
  const PluginStorePage({super.key});

  @override
  State<PluginStorePage> createState() => _PluginStorePageState();
}

class _PluginStorePageState extends State<PluginStorePage> {
  final TextEditingController _searchController = TextEditingController();
  final PluginDiagnosticLogger _diag = PluginDiagnosticLogger();
  bool _busy = false;
  String _installedCategory = 'all';
  String _storeCategory = 'all';

  bool get _isChinese =>
      Localizations.localeOf(context).languageCode.toLowerCase().startsWith(
            'zh',
          );

  String get _title => _isChinese ? '插件' : 'Plugins';
  String get _installedTitle => _isChinese ? '本地插件' : 'Installed plugins';
  String get _storeTitle => _isChinese ? '插件商店' : 'Plugin store';

  @override
  void dispose() {
    _diag.mark('storePage.dispose');
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pluginService = context.watch<PluginLifecycleService>();
    final storeService = context.watch<PluginStoreService>();

    return ScaffoldPage(
      header: SettingsPageHeader(
        title: _title,
        icon: custom_icons.FluentIcons.app_icon_default,
      ),
      content: SmoothSingleChildScrollView(
        config: SmoothScrollConfig.fast,
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1280),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildOverview(pluginService, storeService),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 980;
                    if (compact) {
                      return Column(
                        children: [
                          _buildInstalledPanel(pluginService),
                          const SizedBox(height: 16),
                          _buildStorePanel(pluginService, storeService),
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 9,
                          child: _buildInstalledPanel(pluginService),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 11,
                          child: _buildStorePanel(pluginService, storeService),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverview(
    PluginLifecycleService pluginService,
    PluginStoreService storeService,
  ) {
    final enabled = pluginService.plugins.where((p) => p.enabled).length;
    final invalid = pluginService.plugins
        .where(
          (p) =>
              p.state == PluginInstallState.invalid ||
              p.state == PluginInstallState.incompatible,
        )
        .length;
    final updates = storeService.availableUpdates();

    return _surface(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 820;
          final stats = [
            _metricTile(
              icon: custom_icons.FluentIcons.app_icon_default,
              label: _isChinese ? '已安装' : 'Installed',
              value: pluginService.plugins.length.toString(),
              color: AppTheme.accentPrimary,
            ),
            _metricTile(
              icon: custom_icons.FluentIcons.checkmark_circle_24,
              label: _isChinese ? '已启用' : 'Enabled',
              value: enabled.toString(),
              color: AppTheme.statusSuccess,
            ),
            _metricTile(
              icon: custom_icons.FluentIcons.update_restore,
              label: _isChinese ? '可更新' : 'Updates',
              value: updates.length.toString(),
              color: AppTheme.statusWarning,
            ),
            _metricTile(
              icon: custom_icons.FluentIcons.warning,
              label: _isChinese ? '需处理' : 'Needs review',
              value: invalid.toString(),
              color:
                  invalid == 0 ? AppTheme.textTertiary : AppTheme.statusError,
            ),
          ];
          final commands = Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: compact ? WrapAlignment.start : WrapAlignment.end,
            children: [
              _actionButton(
                icon: custom_icons.FluentIcons.folder_open,
                label: _isChinese ? '安装目录' : 'Install folder',
                onPressed: _busy ? null : () => _installFromDirectory(context),
              ),
              _actionButton(
                icon: custom_icons.FluentIcons.document,
                label: _isChinese ? '安装包' : 'Install package',
                onPressed: _busy ? null : _installFromPackage,
              ),
              _actionButton(
                icon: custom_icons.FluentIcons.refresh,
                label: _isChinese ? '扫描本地' : 'Scan local',
                onPressed: _busy
                    ? null
                    : () => context
                        .read<PluginLifecycleService>()
                        .scanInstalledPlugins(),
              ),
              _actionButton(
                icon: custom_icons.FluentIcons.update_restore,
                label: _isChinese ? '全部更新' : 'Update all',
                filled: updates.isNotEmpty,
                onPressed: _busy || updates.isEmpty
                    ? null
                    : () => _updateAllPlugins(context),
              ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(spacing: 10, runSpacing: 10, children: stats),
                const SizedBox(height: 14),
                commands,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Wrap(spacing: 10, runSpacing: 10, children: stats),
              ),
              const SizedBox(width: 18),
              commands,
            ],
          );
        },
      ),
    );
  }

  Widget _metricTile({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      width: 136,
      constraints: const BoxConstraints(minHeight: 58),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.bgLayer2.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.borderSubtle.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: FluentTheme.of(context).typography.body?.copyWith(
                        color: AppTheme.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 1),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: FluentTheme.of(context).typography.caption?.copyWith(
                        color: AppTheme.textTertiary,
                        fontSize: 11,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstalledPanel(PluginLifecycleService service) {
    final plugins = service.plugins.where((plugin) {
      if (_installedCategory == 'all') {
        return true;
      }
      return plugin.manifest.category.toLowerCase() == _installedCategory;
    }).toList()
      ..sort((a, b) {
        final category = a.manifest.category.compareTo(b.manifest.category);
        if (category != 0) {
          return category;
        }
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

    final enabled = plugins.where((plugin) => plugin.enabled).length;

    return _panel(
      title: _installedTitle,
      subtitle: _isChinese
          ? '$enabled 个启用，${plugins.length} 个当前筛选结果'
          : '$enabled enabled, ${plugins.length} in this view',
      icon: custom_icons.FluentIcons.app_icon_default,
      trailing: SizedBox(
        width: 160,
        child: ComboBox<String>(
          value: _installedCategory,
          items: _buildCategoryItems(),
          onChanged: (value) {
            if (value != null) {
              setState(() => _installedCategory = value);
            }
          },
        ),
      ),
      child: plugins.isEmpty
          ? _emptyState(
              icon: custom_icons.FluentIcons.folder_open,
              title: _isChinese ? '还没有本地插件' : 'No local plugins',
              subtitle: _isChinese
                  ? '可以从插件目录或 .hanabi-plugin.zip 安装。'
                  : 'Install from a plugin folder or a .hanabi-plugin.zip package.',
            )
          : Column(
              children: _groupedInstalledPlugins(service, plugins),
            ),
    );
  }

  List<Widget> _groupedInstalledPlugins(
    PluginLifecycleService service,
    List<InstalledPlugin> plugins,
  ) {
    final grouped = <String, List<InstalledPlugin>>{};
    for (final plugin in plugins) {
      final category = plugin.manifest.category.trim().isEmpty
          ? 'other'
          : plugin.manifest.category.trim();
      grouped.putIfAbsent(category, () => []).add(plugin);
    }

    final widgets = <Widget>[];
    final categories = grouped.keys.toList()..sort();
    for (final category in categories) {
      if (widgets.isNotEmpty) {
        widgets.add(const SizedBox(height: 14));
      }
      widgets.add(_groupLabel(_getCategoryName(category)));
      widgets.add(const SizedBox(height: 8));
      for (final plugin in grouped[category]!) {
        widgets.add(_installedPluginCard(service, plugin));
      }
    }
    return widgets;
  }

  Widget _installedPluginCard(
    PluginLifecycleService service,
    InstalledPlugin plugin,
  ) {
    final stateColor = _stateColor(plugin);
    final hasSettings =
        plugin.manifest.uiExtensions?['settings']?.isNotEmpty == true;
    final permissionLabels = plugin.manifest.permissions.toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: _itemDecoration(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 520;
          final titleBlock = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _pluginIcon(
                icon: custom_icons.FluentIcons.app_icon_default,
                color: stateColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            plugin.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: FluentTheme.of(context)
                                .typography
                                .body
                                ?.copyWith(
                                  color: AppTheme.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                        if (!compact) ...[
                          const SizedBox(width: 10),
                          _statusPill(_stateLabel(plugin), stateColor),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${plugin.id} - v${plugin.version} - ${plugin.manifest.author}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          FluentTheme.of(context).typography.caption?.copyWith(
                                color: AppTheme.textTertiary,
                                fontSize: 12,
                              ),
                    ),
                  ],
                ),
              ),
            ],
          );

          final toggle = ToggleSwitch(
            checked: plugin.enabled,
            onChanged: plugin.state == PluginInstallState.invalid ||
                    plugin.state == PluginInstallState.incompatible
                ? null
                : (value) => _setPluginEnabled(service, plugin, value),
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (compact) ...[
                titleBlock,
                const SizedBox(height: 10),
                Row(
                  children: [
                    _statusPill(_stateLabel(plugin), stateColor),
                    const Spacer(),
                    toggle,
                  ],
                ),
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: titleBlock),
                    const SizedBox(width: 14),
                    toggle,
                  ],
                ),
              if (plugin.manifest.description.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  plugin.manifest.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: FluentTheme.of(context).typography.caption?.copyWith(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                ),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _plainPill(_getCategoryName(plugin.manifest.category)),
                  ...plugin.manifest.capabilities.map(_plainPill),
                  ...permissionLabels.map(_permissionPill),
                ],
              ),
              if (plugin.lastError != null && plugin.lastError!.isNotEmpty) ...[
                const SizedBox(height: 10),
                _messageStrip(
                  icon: custom_icons.FluentIcons.warning,
                  text: plugin.lastError!,
                  color: AppTheme.statusError,
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _actionButton(
                    icon: custom_icons.FluentIcons.folder_open,
                    label: _isChinese ? '日志' : 'Logs',
                    onPressed: () =>
                        _openDirectory(service.pluginLogDir(plugin.id)),
                  ),
                  if (hasSettings)
                    _actionButton(
                      icon: custom_icons.FluentIcons.settings,
                      label: _isChinese ? '设置' : 'Settings',
                      onPressed: () => _openPluginSettings(context, plugin),
                    ),
                  _actionButton(
                    icon: custom_icons.FluentIcons.delete,
                    label: _isChinese ? '卸载' : 'Uninstall',
                    danger: true,
                    onPressed:
                        _busy ? null : () => _uninstallPlugin(service, plugin),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStorePanel(
    PluginLifecycleService pluginService,
    PluginStoreService storeService,
  ) {
    final query = _searchController.text.trim().toLowerCase();
    final entries = storeService.index.entries.where((entry) {
      if (_storeCategory != 'all' &&
          entry.category.toLowerCase() != _storeCategory) {
        return false;
      }
      if (query.isEmpty) {
        return true;
      }
      return entry.name.toLowerCase().contains(query) ||
          entry.id.toLowerCase().contains(query) ||
          entry.description.toLowerCase().contains(query) ||
          entry.author.toLowerCase().contains(query);
    }).toList()
      ..sort((a, b) {
        final category = a.category.compareTo(b.category);
        if (category != 0) {
          return category;
        }
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

    return _panel(
      title: _storeTitle,
      subtitle: _isChinese
          ? '${entries.length} 个当前筛选结果，${storeService.index.entries.length} 个商店条目'
          : '${entries.length} in this view, ${storeService.index.entries.length} store entries',
      icon: custom_icons.FluentIcons.globe,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStoreSourcePanel(storeService),
          const SizedBox(height: 12),
          _buildStoreFilters(),
          const SizedBox(height: 12),
          if (storeService.lastError != null)
            _messageStrip(
              icon: custom_icons.FluentIcons.warning,
              text: storeService.lastError!,
              color: AppTheme.statusError,
            )
          else if (entries.isEmpty)
            _emptyState(
              icon: custom_icons.FluentIcons.searchIcon,
              title: _isChinese ? '没有匹配的插件' : 'No matching plugins',
              subtitle: _isChinese
                  ? '刷新插件源，或调整搜索关键词和分类。'
                  : 'Refresh the source, or adjust the search and category filters.',
            )
          else
            Column(children: _groupedStoreEntries(pluginService, entries)),
        ],
      ),
    );
  }

  Widget _buildStoreFilters() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 520;
        final search = TextBox(
          controller: _searchController,
          placeholder: _isChinese
              ? '搜索插件、作者或说明'
              : 'Search plugins, authors, or descriptions',
          onChanged: (_) => setState(() {}),
        );
        final category = SizedBox(
          width: compact ? double.infinity : 160,
          child: ComboBox<String>(
            value: _storeCategory,
            items: _buildCategoryItems(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _storeCategory = value);
              }
            },
          ),
        );

        if (compact) {
          return Column(
            children: [
              search,
              const SizedBox(height: 8),
              category,
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: search),
            const SizedBox(width: 8),
            category,
          ],
        );
      },
    );
  }

  List<Widget> _groupedStoreEntries(
    PluginLifecycleService pluginService,
    List<PluginStoreEntry> entries,
  ) {
    final grouped = <String, List<PluginStoreEntry>>{};
    for (final entry in entries) {
      final category =
          entry.category.trim().isEmpty ? 'other' : entry.category.trim();
      grouped.putIfAbsent(category, () => []).add(entry);
    }

    final widgets = <Widget>[];
    final categories = grouped.keys.toList()..sort();
    for (final category in categories) {
      if (widgets.isNotEmpty) {
        widgets.add(const SizedBox(height: 14));
      }
      widgets.add(_groupLabel(_getCategoryName(category)));
      widgets.add(const SizedBox(height: 8));
      for (final entry in grouped[category]!) {
        widgets.add(_storeEntryCard(pluginService, entry));
      }
    }
    return widgets;
  }

  Widget _buildStoreSourcePanel(PluginStoreService storeService) {
    final disabled = _busy || storeService.loading;
    final activeLabel = _displaySourceLabel(storeService.activeSourceLabel);
    final activeUrl =
        storeService.activeSourceUrl ?? storeService.defaultIndexUrl;
    final activeIsCache = storeService.activeSourceLabel == 'Local cache';
    final selectedAuto =
        storeService.selectedSourceId == null && !activeIsCache;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.bgLayer2.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border:
            Border.all(color: AppTheme.borderSubtle.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 560;
              final title = Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _pluginIcon(
                    icon: activeIsCache
                        ? custom_icons.FluentIcons.hard_drive
                        : custom_icons.FluentIcons.globe,
                    color: activeIsCache
                        ? AppTheme.statusWarning
                        : AppTheme.accentPrimary,
                    size: 32,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                _isChinese ? '插件源' : 'Plugin source',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: FluentTheme.of(context)
                                    .typography
                                    .body
                                    ?.copyWith(
                                      color: AppTheme.textPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _statusPill(
                              activeLabel,
                              activeIsCache
                                  ? AppTheme.statusWarning
                                  : AppTheme.accentPrimary,
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Tooltip(
                          message: activeUrl,
                          child: Text(
                            activeUrl,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: FluentTheme.of(context)
                                .typography
                                .caption
                                ?.copyWith(
                                  color: AppTheme.textTertiary,
                                  fontSize: 12,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );

              final commands = Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: compact ? WrapAlignment.start : WrapAlignment.end,
                children: [
                  _actionButton(
                    icon: custom_icons.FluentIcons.refresh,
                    label: _isChinese ? '刷新源' : 'Refresh source',
                    filled: true,
                    onPressed: disabled
                        ? null
                        : (activeIsCache
                            ? () => storeService.loadLocalIndex()
                            : () => _refreshStoreIndex(storeService)),
                  ),
                  _actionButton(
                    icon: custom_icons.FluentIcons.hard_drive,
                    label: _isChinese ? '加载缓存' : 'Load cache',
                    onPressed:
                        disabled ? null : () => storeService.loadLocalIndex(),
                  ),
                ],
              );

              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    title,
                    const SizedBox(height: 12),
                    commands,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: title),
                  const SizedBox(width: 14),
                  commands,
                ],
              );
            },
          ),
          if (storeService.loading) ...[
            const SizedBox(height: 10),
            _messageStrip(
              icon: custom_icons.FluentIcons.refresh,
              text: _isChinese ? '正在刷新插件源...' : 'Refreshing plugin source...',
              color: AppTheme.accentPrimary,
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _sourceSwitchButton(
                label: _isChinese ? '自动' : 'Auto',
                selected: selectedAuto,
                onPressed:
                    disabled ? null : () => storeService.refreshOfficialIndex(),
              ),
              ...storeService.officialMirrors.map(
                (source) => _sourceSwitchButton(
                  label: source.label,
                  selected: storeService.selectedSourceId == source.id,
                  onPressed: disabled
                      ? null
                      : () => _refreshStoreMirror(storeService, source),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _storeEntryCard(
    PluginLifecycleService pluginService,
    PluginStoreEntry entry,
  ) {
    final installed = pluginService.getPlugin(entry.id);
    final installedVersion = installed?.version;
    final actionLabel = installed == null
        ? (_isChinese ? '安装' : 'Install')
        : (installedVersion == entry.version
            ? (_isChinese ? '重装' : 'Reinstall')
            : (_isChinese ? '更新' : 'Update'));
    final actionIcon = installed == null
        ? custom_icons.FluentIcons.download
        : custom_icons.FluentIcons.update_restore;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: _itemDecoration(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 540;
          final details = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _pluginIcon(
                    icon: custom_icons.FluentIcons.app_icon_default,
                    color: entry.isInstallable
                        ? AppTheme.accentPrimary
                        : AppTheme.textTertiary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${entry.name} - v${entry.version}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              FluentTheme.of(context).typography.body?.copyWith(
                                    color: AppTheme.textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          entry.author.isEmpty
                              ? entry.id
                              : '${entry.author} - ${entry.id}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: FluentTheme.of(context)
                              .typography
                              .caption
                              ?.copyWith(
                                color: AppTheme.textTertiary,
                                fontSize: 12,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (entry.description.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  entry.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: FluentTheme.of(context).typography.caption?.copyWith(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                ),
              ],
              if (entry.changelog.isNotEmpty) ...[
                const SizedBox(height: 10),
                _messageStrip(
                  icon: custom_icons.FluentIcons.info,
                  text: entry.changelog,
                  color: AppTheme.statusInfo,
                  maxLines: 2,
                ),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _plainPill(_getCategoryName(entry.category)),
                  _plainPill(entry.channel),
                  _statusPill(
                    _reviewStatusLabel(entry.reviewStatus),
                    entry.isPublished
                        ? AppTheme.statusSuccess
                        : AppTheme.statusError,
                  ),
                  if (entry.hasSignature)
                    _statusPill(
                      _isChinese ? '已签名' : 'Signed',
                      AppTheme.statusSuccess,
                    ),
                  if (installedVersion != null)
                    _statusPill(
                      _isChinese
                          ? '已安装 $installedVersion'
                          : 'Installed $installedVersion',
                      AppTheme.statusSuccess,
                    ),
                  ...entry.capabilities.map(_plainPill),
                ],
              ),
            ],
          );

          final action = _actionButton(
            icon: actionIcon,
            label: actionLabel,
            filled: true,
            onPressed: _busy || !entry.isInstallable
                ? null
                : () => _installStoreEntry(context, entry),
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                details,
                const SizedBox(height: 12),
                action,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: details),
              const SizedBox(width: 14),
              action,
            ],
          );
        },
      ),
    );
  }

  Widget _panel({
    required String title,
    required IconData icon,
    required Widget child,
    String? subtitle,
    Widget? trailing,
  }) {
    return _surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 520;
              final titleBlock = Row(
                children: [
                  _pluginIcon(icon: icon, color: AppTheme.accentPrimary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              FluentTheme.of(context).typography.body?.copyWith(
                                    color: AppTheme.textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                        if (subtitle != null && subtitle.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: FluentTheme.of(context)
                                .typography
                                .caption
                                ?.copyWith(
                                  color: AppTheme.textTertiary,
                                  fontSize: 12,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              );

              if (trailing == null) {
                return titleBlock;
              }

              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    titleBlock,
                    const SizedBox(height: 12),
                    trailing,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: titleBlock),
                  const SizedBox(width: 12),
                  trailing,
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _surface({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
  }) {
    final isDark = AppTheme.isDarkContext(context);
    return Container(
      width: double.infinity,
      padding: padding,
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

  BoxDecoration _itemDecoration() {
    return BoxDecoration(
      color: AppTheme.bgLayer2.withValues(alpha: 0.48),
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      border: Border.all(color: AppTheme.borderSubtle.withValues(alpha: 0.46)),
    );
  }

  Widget _pluginIcon({
    required IconData icon,
    required Color color,
    double size = 36,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Icon(icon, size: size * 0.48, color: color),
    );
  }

  Widget _groupLabel(String label) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: AppTheme.accentPrimary.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(AppTheme.radiusRound),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: FluentTheme.of(context).typography.caption?.copyWith(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }

  Widget _messageStrip({
    required IconData icon,
    required String text,
    required Color color,
    int maxLines = 3,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
              style: FluentTheme.of(context).typography.caption?.copyWith(
                    color: color,
                    fontSize: 12,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgLayer2.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border:
            Border.all(color: AppTheme.borderSubtle.withValues(alpha: 0.38)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _pluginIcon(icon: icon, color: AppTheme.textTertiary, size: 34),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: FluentTheme.of(context).typography.body?.copyWith(
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
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
    );
  }

  String _getCategoryName(String category) {
    final normalized = category.trim().toLowerCase();
    if (normalized == 'all') {
      return _isChinese ? '全部类型' : 'All';
    }

    if (_isChinese) {
      switch (normalized) {
        case 'feature':
          return '功能类';
        case 'visual':
          return '视觉类';
        case 'protocol':
          return '协议类';
        case 'tool':
          return '工具类';
        case 'other':
        case '':
          return '其他';
        default:
          return category;
      }
    }

    if (normalized.isEmpty) {
      return 'Other';
    }
    return normalized[0].toUpperCase() + normalized.substring(1);
  }

  List<ComboBoxItem<String>> _buildCategoryItems() {
    return [
      'all',
      'feature',
      'visual',
      'protocol',
      'tool',
      'other',
    ]
        .map(
          (category) => ComboBoxItem(
            value: category,
            child: Text(_getCategoryName(category)),
          ),
        )
        .toList();
  }

  Widget _sourceSwitchButton({
    required String label,
    required bool selected,
    required VoidCallback? onPressed,
  }) {
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (selected) ...[
          Icon(custom_icons.FluentIcons.checkmark, size: 13),
          const SizedBox(width: 5),
        ],
        Text(label),
      ],
    );
    if (selected) {
      return FilledButton(onPressed: onPressed, child: child);
    }
    return Button(onPressed: onPressed, child: child);
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    bool filled = false,
    bool danger = false,
  }) {
    final color = danger ? AppTheme.statusError : null;
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: color == null ? null : TextStyle(color: color),
        ),
      ],
    );

    if (filled) {
      return FilledButton(onPressed: onPressed, child: child);
    }
    return Button(onPressed: onPressed, child: child);
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

  Widget _permissionPill(String label) {
    return _pill(
      label,
      AppTheme.statusWarning.withValues(alpha: 0.10),
      AppTheme.statusWarning,
      AppTheme.statusWarning.withValues(alpha: 0.28),
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

  Color _stateColor(InstalledPlugin plugin) {
    switch (plugin.state) {
      case PluginInstallState.enabled:
        return AppTheme.statusSuccess;
      case PluginInstallState.disabled:
        return AppTheme.textTertiary;
      case PluginInstallState.incompatible:
      case PluginInstallState.invalid:
        return AppTheme.statusError;
      case PluginInstallState.available:
        return AppTheme.accentPrimary;
    }
  }

  String _stateLabel(InstalledPlugin plugin) {
    switch (plugin.state) {
      case PluginInstallState.enabled:
        return _isChinese ? '已启用' : 'Enabled';
      case PluginInstallState.disabled:
        return _isChinese ? '已停用' : 'Disabled';
      case PluginInstallState.incompatible:
        return _isChinese ? '不兼容' : 'Incompatible';
      case PluginInstallState.invalid:
        return _isChinese ? '无效' : 'Invalid';
      case PluginInstallState.available:
        return _isChinese ? '可用' : 'Available';
    }
  }

  String _reviewStatusLabel(String status) {
    switch (status) {
      case 'published':
        return _isChinese ? '已发布' : 'Published';
      case 'draft':
        return _isChinese ? '草稿' : 'Draft';
      case 'removed':
        return _isChinese ? '已下架' : 'Removed';
      default:
        return status;
    }
  }

  String _displaySourceLabel(String? label) {
    final value = label?.trim();
    if (value == null || value.isEmpty) {
      return _isChinese ? '未加载' : 'Not loaded';
    }
    if (!_isChinese) {
      return value;
    }
    switch (value) {
      case 'Local cache':
        return '本地缓存';
      case 'Custom':
        return '自定义';
      case 'Remote':
        return '远程源';
      default:
        return value;
    }
  }

  Future<List<String>?> _showPathInputDialog({
    required String title,
    required String placeholder,
    String? description,
    bool isDirectory = false,
    bool allowMultiple = false,
    List<String> allowedFileExtensions = const <String>[],
  }) async {
    assert(!allowMultiple || !isDirectory);
    final controller = TextEditingController();
    try {
      return await showDialog<List<String>>(
        context: context,
        builder: (dialogContext) => ContentDialog(
          title: Text(title),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (description != null && description.isNotEmpty) ...[
                  Text(
                    description,
                    style: FluentTheme.of(context).typography.caption?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                  ),
                  const SizedBox(height: 10),
                ],
                Row(
                  children: [
                    Expanded(
                      child: TextFormBox(
                        controller: controller,
                        autofocus: true,
                        placeholder: placeholder,
                        onFieldSubmitted: (value) {
                          final normalized = _normalizeInputPath(value);
                          if (_isAcceptedInputPath(
                            normalized,
                            allowedFileExtensions,
                          )) {
                            Navigator.pop(
                              dialogContext,
                              <String>[normalized],
                            );
                          }
                        },
                      ),
                    ),
                    if (isDirectory || allowedFileExtensions.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      _actionButton(
                        icon: isDirectory
                            ? custom_icons.FluentIcons.folder_open
                            : custom_icons.FluentIcons.document,
                        label: _isChinese ? '浏览' : 'Browse',
                        onPressed: () async {
                          final picker = FolderPickerDialog(
                            initialPath: controller.text,
                            mode: isDirectory
                                ? FileSystemPickerMode.directory
                                : FileSystemPickerMode.file,
                            allowMultiple: allowMultiple,
                            allowedExtensions: allowedFileExtensions,
                            title: isDirectory
                                ? null
                                : (_isChinese
                                    ? '选择插件安装包'
                                    : (allowMultiple
                                        ? 'Select plugin packages'
                                        : 'Select plugin package')),
                            selectButtonLabel: isDirectory
                                ? null
                                : (allowMultiple
                                    ? (_isChinese
                                        ? '安装所选包'
                                        : 'Install selected')
                                    : (_isChinese ? '使用此文件' : 'Use this file')),
                            emptyMessage: isDirectory
                                ? null
                                : (_isChinese
                                    ? '此位置没有可安装的插件包'
                                    : 'No installable plugin packages here'),
                          );
                          if (allowMultiple) {
                            final selectedPaths =
                                await showDialog<List<String>>(
                              context: dialogContext,
                              builder: (context) => picker,
                            );
                            if (selectedPaths != null &&
                                selectedPaths.isNotEmpty &&
                                dialogContext.mounted) {
                              Navigator.pop(dialogContext, selectedPaths);
                            }
                            return;
                          }
                          final selectedPath = await showDialog<String>(
                            context: dialogContext,
                            builder: (context) => picker,
                          );
                          if (selectedPath != null && selectedPath.isNotEmpty) {
                            controller.text = selectedPath;
                            controller.selection = TextSelection.collapsed(
                              offset: selectedPath.length,
                            );
                          }
                        },
                      ),
                    ],
                  ],
                ),
                if (allowedFileExtensions.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${_isChinese ? '支持格式' : 'Supported'}: '
                    '${allowedFileExtensions.map((value) => '.$value').join(', ')}',
                    style: FluentTheme.of(context).typography.caption?.copyWith(
                          color: AppTheme.textTertiary,
                          fontSize: 11,
                        ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            Button(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(_isChinese ? '取消' : 'Cancel'),
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, child) {
                final normalized = _normalizeInputPath(value.text);
                final canSubmit = _isAcceptedInputPath(
                  normalized,
                  allowedFileExtensions,
                );
                return FilledButton(
                  onPressed: !canSubmit
                      ? null
                      : () => Navigator.pop(
                            dialogContext,
                            <String>[normalized],
                          ),
                  child: Text(_isChinese ? '安装' : 'Install'),
                );
              },
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  String _normalizeInputPath(String value) {
    var normalized = value.trim();
    if (normalized.length >= 2 &&
        normalized.startsWith('"') &&
        normalized.endsWith('"')) {
      normalized = normalized.substring(1, normalized.length - 1).trim();
    }
    return normalized;
  }

  bool _isAcceptedInputPath(
    String value,
    List<String> allowedFileExtensions,
  ) {
    if (value.isEmpty) return false;
    if (allowedFileExtensions.isEmpty) return true;
    final lower = value.toLowerCase();
    return allowedFileExtensions.any((extension) {
      final normalized = extension.trim().toLowerCase().replaceFirst('.', '');
      return normalized.isNotEmpty && lower.endsWith('.$normalized');
    });
  }

  Future<void> _installFromDirectory(BuildContext context) async {
    _diag.mark('storePage.installDirectory.pathDialog.open');
    final selectedPaths = await _showPathInputDialog(
      title: _isChinese ? '安装本地插件目录' : 'Install local plugin folder',
      placeholder: r'E:\path\to\plugin',
      description: _isChinese
          ? '输入或粘贴包含 plugin.json 的插件目录路径。'
          : 'Enter or paste the plugin folder path that contains plugin.json.',
      isDirectory: true,
    );
    _diag.mark(
      'storePage.installDirectory.pathDialog.result',
      data: <String, Object?>{
        'selectedPaths': selectedPaths,
        'mounted': mounted,
      },
    );
    if (selectedPaths == null || selectedPaths.isEmpty) {
      _diag.mark('storePage.installDirectory.cancelled');
      return;
    }
    final selected = selectedPaths.first;
    await _runAction(
      () =>
          context.read<PluginLifecycleService>().installFromDirectory(selected),
      successTitle: _isChinese ? '插件已安装' : 'Plugin installed',
      diagnosticName: 'storePage.installDirectory',
      diagnosticData: <String, Object?>{'selected': selected},
    );
  }

  Future<void> _installFromPackage() async {
    _diag.mark('storePage.installPackage.pathDialog.open');
    final selectedPaths = await _showPathInputDialog(
      title: _isChinese ? '安装插件包' : 'Install plugin package',
      placeholder: r'E:\path\to\plugin.hanabi-plugin.zip',
      description: _isChinese
          ? '可浏览多选 .zip、.hanabi-plugin 插件包，或粘贴单个包路径。'
          : 'Browse for multiple .zip or .hanabi-plugin packages, or paste one package path.',
      allowMultiple: true,
      allowedFileExtensions: const <String>['zip', 'hanabi-plugin'],
    );
    _diag.mark(
      'storePage.installPackage.pathDialog.result',
      data: <String, Object?>{
        'selectedPaths': selectedPaths,
        'packageCount': selectedPaths?.length ?? 0,
        'mounted': mounted,
      },
    );
    if (selectedPaths == null || selectedPaths.isEmpty) {
      _diag.mark('storePage.installPackage.cancelled');
      return;
    }
    final packagePaths = selectedPaths
        .map(_normalizeInputPath)
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);
    await _installPackages(packagePaths);
  }

  Future<void> _installPackages(List<String> packagePaths) async {
    if (packagePaths.isEmpty || _busy) return;
    final service = context.read<PluginLifecycleService>();
    final installedPaths = <String>[];
    final failures = <({String packagePath, Object error})>[];
    final diagnosticData = <String, Object?>{
      'packageCount': packagePaths.length,
      'packagePaths': packagePaths,
    };

    _diag.mark('storePage.installPackage.start', data: diagnosticData);
    setState(() => _busy = true);
    try {
      for (var index = 0; index < packagePaths.length; index++) {
        final packagePath = packagePaths[index];
        _diag.mark(
          'storePage.installPackage.item.start',
          data: <String, Object?>{
            'index': index,
            'packageCount': packagePaths.length,
            'packagePath': packagePath,
          },
        );
        try {
          final installed = await service.installFromPackage(packagePath);
          installedPaths.add(packagePath);
          _diag.mark(
            'storePage.installPackage.item.success',
            pluginId: installed.id,
            data: <String, Object?>{
              'index': index,
              'packagePath': packagePath,
            },
          );
        } catch (error, stackTrace) {
          failures.add((packagePath: packagePath, error: error));
          _diag.error(
            'storePage.installPackage.item.error',
            error,
            stackTrace: stackTrace,
            data: <String, Object?>{
              'index': index,
              'packagePath': packagePath,
            },
          );
        }
      }

      _diag.mark(
        'storePage.installPackage.complete',
        data: <String, Object?>{
          ...diagnosticData,
          'successCount': installedPaths.length,
          'failureCount': failures.length,
          'failedPaths':
              failures.map((failure) => failure.packagePath).toList(),
        },
      );
      if (!mounted) return;
      if (failures.isEmpty) {
        NotificationManager.of(context)?.showSuccess(
          packagePaths.length == 1
              ? (_isChinese ? '插件包已安装' : 'Plugin package installed')
              : (_isChinese
                  ? '已安装 ${installedPaths.length} 个插件包'
                  : '${installedPaths.length} plugin packages installed'),
        );
        return;
      }

      final visibleFailures = failures.take(5).map(
            (failure) =>
                '${path.basename(failure.packagePath)}: ${failure.error}',
          );
      final hiddenFailureCount = failures.length - visibleFailures.length;
      final failureDetails = <String>[
        ...visibleFailures,
        if (hiddenFailureCount > 0)
          _isChinese
              ? '还有 $hiddenFailureCount 个失败项，请查看诊断日志。'
              : '$hiddenFailureCount more failures; see diagnostic logs.',
      ].join('\n');
      NotificationManager.of(context)?.showError(
        packagePaths.length == 1
            ? (_isChinese ? '插件包安装失败' : 'Plugin package install failed')
            : (_isChinese
                ? '批量安装完成：成功 ${installedPaths.length}，失败 ${failures.length}'
                : 'Batch install complete: ${installedPaths.length} succeeded, ${failures.length} failed'),
        message: failureDetails,
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
      _diag.mark(
        'storePage.installPackage.done',
        data: <String, Object?>{
          ...diagnosticData,
          'successCount': installedPaths.length,
          'failureCount': failures.length,
          'mounted': mounted,
        },
      );
    }
  }

  Future<void> _refreshStoreIndex(PluginStoreService storeService) async {
    await storeService.refreshSelectedSource();
  }

  Future<void> _refreshStoreMirror(
    PluginStoreService storeService,
    PluginStoreMirrorSource source,
  ) async {
    await storeService.refreshOfficialMirror(source);
  }

  Future<void> _installStoreEntry(
    BuildContext context,
    PluginStoreEntry entry,
  ) async {
    await _runAction(
      () => context.read<PluginStoreService>().installEntry(entry),
      successTitle: _isChinese ? '插件已安装' : 'Plugin installed',
      diagnosticName: 'storePage.installStoreEntry',
      diagnosticData: <String, Object?>{
        'id': entry.id,
        'name': entry.name,
        'version': entry.version,
      },
    );
  }

  Future<void> _updateAllPlugins(BuildContext context) async {
    await _runAction(
      () => context.read<PluginStoreService>().updateAllAvailable(),
      successTitle: _isChinese ? '插件已更新' : 'Plugins updated',
      diagnosticName: 'storePage.updateAllPlugins',
    );
  }

  Future<void> _setPluginEnabled(
    PluginLifecycleService service,
    InstalledPlugin plugin,
    bool enabled,
  ) async {
    await _runAction(
      () => service.setPluginEnabled(plugin.id, enabled),
      successTitle: enabled
          ? (_isChinese ? '插件已启用' : 'Plugin enabled')
          : (_isChinese ? '插件已停用' : 'Plugin disabled'),
      diagnosticName: 'storePage.setPluginEnabled',
      diagnosticPluginId: plugin.id,
      diagnosticData: <String, Object?>{'enabled': enabled},
    );
  }

  Future<void> _uninstallPlugin(
    PluginLifecycleService service,
    InstalledPlugin plugin,
  ) async {
    _diag.mark(
      'storePage.uninstall.dialog.open',
      pluginId: plugin.id,
      data: <String, Object?>{
        'name': plugin.name,
        'directory': plugin.directory,
      },
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ContentDialog(
        title: Text(_isChinese ? '卸载插件' : 'Uninstall plugin'),
        content: Text(
          _isChinese ? '确定要卸载 ${plugin.name} 吗？' : 'Uninstall ${plugin.name}?',
        ),
        actions: [
          Button(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_isChinese ? '取消' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(_isChinese ? '卸载' : 'Uninstall'),
          ),
        ],
      ),
    );
    _diag.mark(
      'storePage.uninstall.dialog.result',
      pluginId: plugin.id,
      data: <String, Object?>{
        'confirmed': confirmed,
        'mounted': mounted,
      },
    );
    if (confirmed != true) {
      return;
    }

    await _runAction(
      () => service.uninstallPlugin(plugin.id),
      successTitle: _isChinese ? '插件已卸载' : 'Plugin uninstalled',
      diagnosticName: 'storePage.uninstall',
      diagnosticPluginId: plugin.id,
      diagnosticData: <String, Object?>{
        'name': plugin.name,
        'directory': plugin.directory,
      },
    );
  }

  Future<void> _runAction(
    Future<Object?> Function() action, {
    required String successTitle,
    String? diagnosticName,
    String? diagnosticPluginId,
    Map<String, Object?> diagnosticData = const <String, Object?>{},
  }) async {
    if (_busy) {
      _diag.mark(
        '${diagnosticName ?? 'storePage.action'}.ignoredBusy',
        pluginId: diagnosticPluginId,
        data: diagnosticData,
      );
      return;
    }

    _diag.mark(
      '${diagnosticName ?? 'storePage.action'}.start',
      pluginId: diagnosticPluginId,
      data: diagnosticData,
    );
    setState(() => _busy = true);
    try {
      await action();
      _diag.mark(
        '${diagnosticName ?? 'storePage.action'}.success',
        pluginId: diagnosticPluginId,
        data: <String, Object?>{
          ...diagnosticData,
          'successTitle': successTitle,
        },
      );
      if (!mounted) return;
      NotificationManager.of(context)?.showSuccess(successTitle);
    } catch (e) {
      _diag.error(
        '${diagnosticName ?? 'storePage.action'}.error',
        e,
        pluginId: diagnosticPluginId,
        data: diagnosticData,
      );
      if (!mounted) return;
      NotificationManager.of(context)?.showError(
        _isChinese ? '操作失败' : 'Action failed',
        message: e.toString(),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
      _diag.mark(
        '${diagnosticName ?? 'storePage.action'}.done',
        pluginId: diagnosticPluginId,
        data: <String, Object?>{
          ...diagnosticData,
          'mounted': mounted,
        },
      );
    }
  }

  Future<void> _openPluginSettings(
    BuildContext context,
    InstalledPlugin plugin,
  ) async {
    _diag.mark(
      'storePage.settings.open',
      pluginId: plugin.id,
      data: <String, Object?>{
        'name': plugin.name,
        'directory': plugin.directory,
      },
    );
    await showDialog(
      context: context,
      builder: (context) => PluginSettingsDialog(
        plugin: plugin,
        isChinese: _isChinese,
      ),
    );
    _diag.mark('storePage.settings.closed', pluginId: plugin.id);
  }

  Future<void> _openDirectory(String directoryPath) async {
    _diag.mark(
      'storePage.openDirectory.start',
      data: <String, Object?>{
        'directoryPath': directoryPath,
      },
    );
    final directory = Directory(directoryPath);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    await Process.start(
      'explorer',
      [directory.path],
      mode: ProcessStartMode.detached,
    );
    _diag.mark(
      'storePage.openDirectory.done',
      data: <String, Object?>{
        'directoryPath': directory.path,
      },
    );
  }
}
