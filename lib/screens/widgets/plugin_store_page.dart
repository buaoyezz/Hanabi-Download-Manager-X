import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:provider/provider.dart';

import '../../models/plugin_manifest.dart';
import '../../models/plugin_store_models.dart';
import '../../services/plugin_lifecycle_service.dart';
import '../../services/plugin_store_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/fluent_icons.dart' as custom_icons;
import '../../widgets/animated_notifications.dart';
import '../../widgets/settings_components.dart';
import '../../widgets/smooth_scroll_wrapper.dart';

class PluginStorePage extends StatefulWidget {
  const PluginStorePage({super.key});

  @override
  State<PluginStorePage> createState() => _PluginStorePageState();
}

class _PluginStorePageState extends State<PluginStorePage> {
  final TextEditingController _searchController = TextEditingController();
  bool _busy = false;

  bool get _isChinese =>
      Localizations.localeOf(context).languageCode.toLowerCase().startsWith(
            'zh',
          );

  String get _title => _isChinese ? '插件' : 'Plugins';
  String get _installedTitle => _isChinese ? '本地插件' : 'Installed plugins';
  String get _storeTitle => _isChinese ? '插件商店' : 'Plugin store';

  @override
  void dispose() {
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
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSummary(pluginService, storeService),
            const SizedBox(height: 16),
            _buildInstalledSection(pluginService),
            const SizedBox(height: 16),
            _buildStoreSection(pluginService, storeService),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary(
    PluginLifecycleService pluginService,
    PluginStoreService storeService,
  ) {
    final enabled = pluginService.plugins.where((p) => p.enabled).length;
    final disabled = pluginService.plugins.length - enabled;
    final updates = storeService.availableUpdates();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgLayer1.withValues(alpha: 0.56),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border:
            Border.all(color: AppTheme.borderSubtle.withValues(alpha: 0.55)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          final stats = [
            _statChip(_isChinese ? '已启用' : 'Enabled', enabled),
            _statChip(_isChinese ? '已禁用' : 'Disabled', disabled),
            _statChip(_isChinese ? '商店条目' : 'Store entries',
                storeService.index.entries.length),
            _statChip(_isChinese ? '可更新' : 'Updates', updates.length),
          ];
          final actions = Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _actionButton(
                icon: custom_icons.FluentIcons.folder_open,
                label: _isChinese ? '安装目录' : 'Install folder',
                onPressed: _busy ? null : () => _installFromDirectory(context),
              ),
              _actionButton(
                icon: custom_icons.FluentIcons.document,
                label: _isChinese ? '安装包' : 'Install package',
                onPressed: _busy ? null : () => _installFromPackage(context),
              ),
              _actionButton(
                icon: custom_icons.FluentIcons.refresh,
                label: _isChinese ? '刷新' : 'Refresh',
                onPressed: _busy
                    ? null
                    : () => context
                        .read<PluginLifecycleService>()
                        .scanInstalledPlugins(),
              ),
              _actionButton(
                icon: custom_icons.FluentIcons.update_restore,
                label: _isChinese ? '全部更新' : 'Update all',
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
                Wrap(spacing: 8, runSpacing: 8, children: stats),
                const SizedBox(height: 12),
                actions,
              ],
            );
          }

          return Row(
            children: [
              Expanded(
                child: Wrap(spacing: 8, runSpacing: 8, children: stats),
              ),
              actions,
            ],
          );
        },
      ),
    );
  }

  Widget _statChip(String label, int value) {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppTheme.bgLayer2.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(AppTheme.radiusRound),
        border: Border.all(color: AppTheme.borderSubtle.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: FluentTheme.of(context).typography.caption?.copyWith(
                  color: AppTheme.textTertiary,
                  fontSize: 12,
                ),
          ),
          const SizedBox(width: 8),
          Text(
            value.toString(),
            style: FluentTheme.of(context).typography.body?.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstalledSection(PluginLifecycleService service) {
    final plugins = service.plugins;
    return SettingsSection(
      title: _installedTitle,
      icon: custom_icons.FluentIcons.app_icon_default,
      children: [
        if (plugins.isEmpty)
          _emptyState(
            _isChinese ? '还没有安装本地插件' : 'No local plugins installed',
            _isChinese
                ? '可以从本地目录或 .hanabi-plugin.zip 包安装。'
                : 'Install from a local folder or a .hanabi-plugin.zip package.',
          )
        else
          ...plugins.map((plugin) => _installedPluginTile(service, plugin)),
      ],
    );
  }

  Widget _installedPluginTile(
    PluginLifecycleService service,
    InstalledPlugin plugin,
  ) {
    final stateColor = _stateColor(plugin);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.bgLayer2.withValues(alpha: 0.54),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border:
            Border.all(color: AppTheme.borderSubtle.withValues(alpha: 0.48)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: stateColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Icon(
                  custom_icons.FluentIcons.app_icon_default,
                  size: 18,
                  color: stateColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plugin.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: FluentTheme.of(context).typography.body?.copyWith(
                            color: AppTheme.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${plugin.id} · v${plugin.version} · ${plugin.manifest.author}',
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
              const SizedBox(width: 12),
              ToggleSwitch(
                checked: plugin.enabled,
                onChanged: plugin.state == PluginInstallState.invalid ||
                        plugin.state == PluginInstallState.incompatible
                    ? null
                    : (value) => _setPluginEnabled(service, plugin, value),
              ),
            ],
          ),
          if (plugin.manifest.description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              plugin.manifest.description,
              maxLines: 2,
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
              _statusPill(_stateLabel(plugin), stateColor),
              ...plugin.manifest.capabilities.map(
                (capability) => _plainPill(capability),
              ),
            ],
          ),
          if (plugin.lastError != null && plugin.lastError!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              plugin.lastError!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: FluentTheme.of(context).typography.caption?.copyWith(
                    color: AppTheme.statusError,
                    fontSize: 12,
                  ),
            ),
          ],
          const SizedBox(height: 10),
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
              _actionButton(
                icon: custom_icons.FluentIcons.delete,
                label: _isChinese ? '卸载' : 'Uninstall',
                onPressed:
                    _busy ? null : () => _uninstallPlugin(service, plugin),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStoreSection(
    PluginLifecycleService pluginService,
    PluginStoreService storeService,
  ) {
    final query = _searchController.text.trim().toLowerCase();
    final entries = storeService.index.entries.where((entry) {
      if (query.isEmpty) {
        return true;
      }
      return entry.name.toLowerCase().contains(query) ||
          entry.id.toLowerCase().contains(query) ||
          entry.description.toLowerCase().contains(query);
    }).toList(growable: false);

    return SettingsSection(
      title: _storeTitle,
      icon: custom_icons.FluentIcons.app_icon_default,
      children: [
        _buildStoreSourcePanel(storeService),
        const SizedBox(height: 10),
        TextBox(
          controller: _searchController,
          placeholder: _isChinese ? '搜索插件' : 'Search plugins',
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        if (storeService.lastError != null)
          _errorText(storeService.lastError!)
        else if (entries.isEmpty)
          _emptyState(
            _isChinese ? '商店索引为空' : 'Store index is empty',
            _isChinese
                ? '加载一个索引 JSON 后，会在这里显示可安装插件。'
                : 'Load an index JSON to show installable plugins here.',
          )
        else
          ...entries.map((entry) => _storeEntryTile(pluginService, entry)),
      ],
    );
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.bgLayer2.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.borderSubtle.withValues(alpha: 0.5)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 620;
          final titleBlock = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _isChinese ? '官方插件源' : 'Official plugin source',
                    style: FluentTheme.of(context).typography.body?.copyWith(
                          color: AppTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(width: 8),
                  _statusPill(
                    _isChinese ? '当前：$activeLabel' : 'Current: $activeLabel',
                    activeIsCache
                        ? AppTheme.statusWarning
                        : AppTheme.accentPrimary,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Tooltip(
                message: activeUrl,
                child: Text(
                  activeUrl,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: FluentTheme.of(context).typography.caption?.copyWith(
                        color: AppTheme.textTertiary,
                        fontSize: 12,
                      ),
                ),
              ),
            ],
          );
          final actions = Wrap(
            alignment: compact ? WrapAlignment.start : WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: disabled
                    ? null
                    : (activeIsCache
                        ? () => storeService.loadLocalIndex()
                        : () => _refreshStoreIndex(storeService)),
                child: Text(_isChinese ? '刷新当前源' : 'Refresh source'),
              ),
              Button(
                onPressed:
                    disabled ? null : () => storeService.loadLocalIndex(),
                child: Text(_isChinese ? '加载缓存' : 'Load cache'),
              ),
            ],
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (compact) ...[
                titleBlock,
                const SizedBox(height: 12),
                actions,
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: titleBlock),
                    const SizedBox(width: 16),
                    actions,
                  ],
                ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _sourceSwitchButton(
                    label: _isChinese ? '自动' : 'Auto',
                    selected: selectedAuto,
                    onPressed: disabled
                        ? null
                        : () => storeService.refreshOfficialIndex(),
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
          );
        },
      ),
    );
  }

  Widget _storeEntryTile(
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

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.bgLayer2.withValues(alpha: 0.54),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border:
            Border.all(color: AppTheme.borderSubtle.withValues(alpha: 0.48)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${entry.name} · v${entry.version}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: FluentTheme.of(context).typography.body?.copyWith(
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  entry.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: FluentTheme.of(context).typography.caption?.copyWith(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                ),
                const SizedBox(height: 8),
                if (entry.changelog.isNotEmpty) ...[
                  Text(
                    entry.changelog,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: FluentTheme.of(context).typography.caption?.copyWith(
                          color: AppTheme.textTertiary,
                          fontSize: 12,
                        ),
                  ),
                  const SizedBox(height: 8),
                ],
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
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
                    _plainPill(entry.author),
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
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: _busy || !entry.isInstallable
                ? null
                : () => _installStoreEntry(context, entry),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }

  Widget _sourceSwitchButton({
    required String label,
    required bool selected,
    required VoidCallback? onPressed,
  }) {
    final child = Text(label);
    if (selected) {
      return FilledButton(onPressed: onPressed, child: child);
    }
    return Button(onPressed: onPressed, child: child);
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    return Button(
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
    );
  }

  Widget _plainPill(String label) {
    return _pill(
      label,
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
        style: FluentTheme.of(context).typography.caption?.copyWith(
              color: textColor,
              fontSize: 11,
            ),
      ),
    );
  }

  Widget _emptyState(String title, String subtitle) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.bgLayer2.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.borderSubtle.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: FluentTheme.of(context).typography.body?.copyWith(
                  color: AppTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
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
    );
  }

  Widget _errorText(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.statusError.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.statusError.withValues(alpha: 0.25)),
      ),
      child: Text(
        text,
        softWrap: true,
        style: FluentTheme.of(context).typography.caption?.copyWith(
              color: AppTheme.statusError,
              fontSize: 12,
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
        return _isChinese ? '已禁用' : 'Disabled';
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
      default:
        return value;
    }
  }

  Future<void> _installFromDirectory(BuildContext context) async {
    final selected = await FilePicker.platform.getDirectoryPath(
      dialogTitle: _isChinese ? '选择插件目录' : 'Select plugin folder',
    );
    if (selected == null || selected.trim().isEmpty) {
      return;
    }
    await _runAction(
      () =>
          context.read<PluginLifecycleService>().installFromDirectory(selected),
      successTitle: _isChinese ? '插件已安装' : 'Plugin installed',
    );
  }

  Future<void> _installFromPackage(BuildContext context) async {
    final picked = await FilePicker.platform.pickFiles(
      dialogTitle: _isChinese ? '选择插件包' : 'Select plugin package',
      type: FileType.custom,
      allowedExtensions: ['zip', 'hanabi-plugin'],
    );
    final packagePath = picked?.files.single.path;
    if (packagePath == null || packagePath.trim().isEmpty) {
      return;
    }
    await _runAction(
      () => context
          .read<PluginLifecycleService>()
          .installFromPackage(packagePath),
      successTitle: _isChinese ? '插件包已安装' : 'Plugin package installed',
    );
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
    );
  }

  Future<void> _updateAllPlugins(BuildContext context) async {
    await _runAction(
      () => context.read<PluginStoreService>().updateAllAvailable(),
      successTitle: _isChinese ? '插件已更新' : 'Plugins updated',
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
          : (_isChinese ? '插件已禁用' : 'Plugin disabled'),
    );
  }

  Future<void> _uninstallPlugin(
    PluginLifecycleService service,
    InstalledPlugin plugin,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ContentDialog(
        title: Text(_isChinese ? '卸载插件' : 'Uninstall plugin'),
        content: Text(plugin.name),
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
    if (confirmed != true) {
      return;
    }

    await _runAction(
      () => service.uninstallPlugin(plugin.id),
      successTitle: _isChinese ? '插件已卸载' : 'Plugin uninstalled',
    );
  }

  Future<void> _runAction(
    Future<Object?> Function() action, {
    required String successTitle,
  }) async {
    if (_busy) {
      return;
    }

    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      NotificationManager.of(context)?.showSuccess(successTitle);
    } catch (e) {
      if (!mounted) return;
      NotificationManager.of(context)?.showError(
        _isChinese ? '操作失败' : 'Action failed',
        message: e.toString(),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _openDirectory(String directoryPath) async {
    final directory = Directory(directoryPath);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    await Process.start(
      'explorer',
      [directory.path],
      mode: ProcessStartMode.detached,
    );
  }
}
