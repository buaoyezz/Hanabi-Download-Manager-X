import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:flutter/material.dart' show Material;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/update_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/fluent_icons.dart';

class UpdatePage extends StatefulWidget {
  const UpdatePage({super.key});

  @override
  State<UpdatePage> createState() => _UpdatePageState();
}

class _UpdatePageState extends State<UpdatePage> {
  @override
  void initState() {
    super.initState();
    // 页面加载时自动检查更新
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final updateService = context.read<UpdateService>();
      updateService.checkForUpdates();
    });
  }

  @override
  Widget build(BuildContext context) {
    // 返回Column而不是ScaffoldPage，因为这个页面会被嵌入到settings_page的ScaffoldPage.scrollable中
    return Consumer<UpdateService>(
      builder: (context, updateService, child) {
        // 判断是否有更新
        final hasUpdate = updateService.hasUpdate();
        
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildUpdateCheckSection(context),
            const SizedBox(height: 24),
            // 只有在没有更新时才显示当前版本信息
            if (!hasUpdate) ...[
              _buildCurrentVersionSection(context),
              const SizedBox(height: 24),
            ],
            _buildUpdateSettingsSection(context),
          ],
        );
      },
    );
  }

  Widget _buildCurrentVersionSection(BuildContext context) {
    return Consumer<UpdateService>(
      builder: (context, updateService, child) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: FluentTheme.of(context).resources.cardBackgroundFillColorDefault,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(
              color: FluentTheme.of(context).resources.cardStrokeColorDefault,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    FluentIcons.info,
                    size: 20,
                    color: AppTheme.accentLight,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '当前版本',
                    style: FluentTheme.of(context).typography.subtitle?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.accentPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(
                    color: AppTheme.accentPrimary.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      FluentIcons.completed_solid,
                      color: AppTheme.accentLight,
                      size: 32,
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'v${updateService.currentVersion}',
                          style: FluentTheme.of(context).typography.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.accentLight,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Hanabi Download ManagerX',
                          style: FluentTheme.of(context).typography.body?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '更新日志',
                style: FluentTheme.of(context).typography.bodyStrong?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 200),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.bgLayer1,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                child: SingleChildScrollView(
                  child: _buildMarkdownContent(context, updateService.getCurrentChangelog()),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUpdateCheckSection(BuildContext context) {
    return Consumer<UpdateService>(
      builder: (context, updateService, child) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: FluentTheme.of(context).resources.cardBackgroundFillColorDefault,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(
              color: FluentTheme.of(context).resources.cardStrokeColorDefault,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        FluentIcons.update_restore,
                        size: 20,
                        color: AppTheme.accentLight,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '检查更新',
                        style: FluentTheme.of(context).typography.subtitle?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      // 如果有更新，显示"开始更新"按钮
                      if (!updateService.isChecking && updateService.hasUpdate()) ...[
                        FilledButton(
                          onPressed: () async {
                            // 先弹出确认对话框
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (context) => ContentDialog(
                                title: const Text('确认更新'),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '新版本已经准备好啦，为保障安装过程可以正常进行，本应用将会关闭！',
                                      style: FluentTheme.of(context).typography.body,
                                    ),
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AppTheme.accentPrimary.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                                        border: Border.all(
                                          color: AppTheme.accentPrimary.withValues(alpha: 0.3),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            FluentIcons.info,
                                            size: 16,
                                            color: AppTheme.accentPrimary,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                                '新版本：${updateService.availableUpdate?.version ?? updateService.latestRelease?.version ?? "未知"}\n旧版本：${updateService.currentVersion}\n变化：${updateService.currentVersion} → ${updateService.availableUpdate?.version ?? updateService.latestRelease?.version ?? "未知"}\n通道：${updateService.currentChannel.name} → ${updateService.availableUpdate?.versionInfo.channel?.name ?? updateService.latestRelease?.versionInfo.channel?.name ?? "未知"}\n全新的版本已经准备好啦，准备好更新了吗？',
                                              style: FluentTheme.of(context).typography.caption?.copyWith(
                                                color: AppTheme.textSecondary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                actions: [
                                  Button(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: const Text('取消'),
                                  ),
                                  FilledButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    child: const Text('确认更新'),
                                  ),
                                ],
                              ),
                            );

                            if (confirmed != true) return;

                            // 用户确认后开始更新
                            final hasDotNet8 = updateService.isDotNet8Installed ?? false;
                            if (hasDotNet8) {
                              final success = await updateService.launchUpdateExe();
                              if (!success && context.mounted) {
                                await showDialog(
                                  context: context,
                                  builder: (context) => ContentDialog(
                                    title: const Text('启动更新器失败'),
                                    content: const Text('无法启动 Update.exe\n问题自查\n ·请检查 Update.exe 是否被删除或移动了\n ·.NET 8 是否安装正常\n ·本软件安装包是否完整\n若均无效可以选择手动下载并安装'),
                                    actions: [
                                      Button(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('关闭'),
                                      ),
                                      FilledButton(
                                        onPressed: () async {
                                          Navigator.pop(context);
                                          final release = updateService.availableUpdate ?? updateService.latestRelease!;
                                          if (release.downloadUrl.isNotEmpty) {
                                            final uri = Uri.parse(release.downloadUrl);
                                            if (await canLaunchUrl(uri)) {
                                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                                            }
                                          }
                                        },
                                        child: const Text('手动下载'),
                                      ),
                                    ],
                                  ),
                                );
                              }
                            } else {
                              // 没有 .NET 8，直接打开下载页面
                              final release = updateService.availableUpdate ?? updateService.latestRelease!;
                              if (release.downloadUrl.isNotEmpty) {
                                final uri = Uri.parse(release.downloadUrl);
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                                }
                              }
                            }
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(FluentIcons.download, size: 14),
                              const SizedBox(width: 6),
                              const Text('开始更新'),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      // 检查中显示进度环，否则显示重新检查按钮
                      if (updateService.isChecking)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: ProgressRing(strokeWidth: 2),
                        )
                      else
                        Button(
                          onPressed: () async {
                            await updateService.checkForUpdates();
                          },
                          child: const Text('重新检查'),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (updateService.isChecking)
                _buildCheckingState(context)
              else if (updateService.error != null)
                _buildErrorState(context, updateService.error!)
              else if (updateService.isVersionNewer)
                _buildVersionNewerState(context, updateService)
              else if (updateService.hasUpdate())
                _buildUpdateAvailable(context, updateService)
              else if (updateService.lastCheckTime != null)
                _buildNoUpdate(context)
              else
                _buildInitialState(context),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCheckingState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.statusInfo.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: AppTheme.statusInfo.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 24,
            height: 24,
            child: ProgressRing(strokeWidth: 2),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              '正在检查更新...',
              style: FluentTheme.of(context).typography.body,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String error) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.statusError.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: AppTheme.statusError.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            FluentIcons.error,
            color: AppTheme.statusError,
            size: 24,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '检查更新失败',
                  style: FluentTheme.of(context).typography.bodyStrong?.copyWith(
                    color: AppTheme.statusError,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  error,
                  style: FluentTheme.of(context).typography.caption?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoUpdate(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.statusSuccess.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: AppTheme.statusSuccess.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            FluentIcons.check_mark,
            color: AppTheme.statusSuccess,
            size: 24,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '已是最新版本',
                  style: FluentTheme.of(context).typography.bodyStrong?.copyWith(
                    color: AppTheme.statusSuccess,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '您正在使用最新版本',
                  style: FluentTheme.of(context).typography.caption?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgLayer2,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Row(
        children: [
          Icon(
            FluentIcons.info,
            color: AppTheme.textSecondary,
            size: 24,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              '点击"重新检查"按钮检查最新版本',
              style: FluentTheme.of(context).typography.body?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarkdownContent(BuildContext context, String content) {
    return Material(
      color: Colors.transparent,
      child: MarkdownBody(
        data: content,
        selectable: true,
        styleSheet: MarkdownStyleSheet(
          p: FluentTheme.of(context).typography.body?.copyWith(
            height: 1.6,
            color: AppTheme.textPrimary,
          ),
          h1: FluentTheme.of(context).typography.title?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
          h2: FluentTheme.of(context).typography.subtitle?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
          h3: FluentTheme.of(context).typography.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
          listBullet: FluentTheme.of(context).typography.body?.copyWith(
            color: AppTheme.textPrimary,
          ),
          code: FluentTheme.of(context).typography.body?.copyWith(
            fontFamily: 'Consolas',
            backgroundColor: AppTheme.bgLayer2,
            color: AppTheme.accentLight,
          ),
          codeblockDecoration: BoxDecoration(
            color: AppTheme.bgLayer2,
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          ),
          blockquoteDecoration: BoxDecoration(
            color: AppTheme.bgLayer2,
            border: Border(
              left: BorderSide(
                color: AppTheme.accentPrimary,
                width: 3,
              ),
            ),
          ),
          a: FluentTheme.of(context).typography.body?.copyWith(
            color: AppTheme.accentLight,
            decoration: TextDecoration.underline,
          ),
        ),
        onTapLink: (text, href, title) async {
          if (href != null) {
            final uri = Uri.parse(href);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          }
        },
      ),
    );
  }

  Widget _buildVersionNewerState(BuildContext context, UpdateService updateService) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.accentPrimary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: AppTheme.accentPrimary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            FluentIcons.product_release,
            color: AppTheme.accentLight,
            size: 24,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '未发布的版本',
                  style: FluentTheme.of(context).typography.bodyStrong?.copyWith(
                    color: AppTheme.accentLight,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '当前版本 v${updateService.currentVersion} | 当前版本号不存在,或许为特殊版本或开发版',
                  style: FluentTheme.of(context).typography.caption?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpdateSettingsSection(BuildContext context) {
    return Consumer<UpdateService>(
      builder: (context, updateService, child) {
        final hasDotNet8 = updateService.isDotNet8Installed;
        
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: FluentTheme.of(context).resources.cardBackgroundFillColorDefault,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(
              color: FluentTheme.of(context).resources.cardStrokeColorDefault,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    FluentIcons.settings,
                    size: 20,
                    color: AppTheme.accentLight,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '更新设置',
                    style: FluentTheme.of(context).typography.subtitle?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // .NET 8 未安装时显示醒目横幅
              if (hasDotNet8 == false) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.statusWarning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(
                      color: AppTheme.statusWarning.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        FluentIcons.warning,
                        color: AppTheme.statusWarning,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '.NET 8 Desktop Runtime',
                              style: FluentTheme.of(context).typography.bodyStrong,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '未安装 - 推荐安装以使用自动更新器',
                              style: FluentTheme.of(context).typography.caption?.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Button(
                        onPressed: () async {
                          final uri = Uri.parse(updateService.getDotNet8DownloadUrl());
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        },
                        child: const Text('下载'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              // .NET 8 已安装时显示简洁行
              if (hasDotNet8 == true)
                _buildSettingRow(
                  context,
                  title: '.NET 8 Desktop Runtime',
                  subtitle: '已安装 - 可使用更新器',
                  trailing: Button(
                    onPressed: () => updateService.checkDotNet8Installation(),
                    child: const Text('重新检测'),
                  ),
                ),
              if (hasDotNet8 == true) const SizedBox(height: 12),
              // 当前通道显示
              _buildSettingRow(
                context,
                title: '当前通道',
                subtitle: updateService.getChannelDisplayName(updateService.currentChannel),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getChannelColor(updateService.currentChannel).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    updateService.currentChannel.name.toUpperCase(),
                    style: FluentTheme.of(context).typography.caption?.copyWith(
                      color: _getChannelColor(updateService.currentChannel),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // 自动检查间隔
              _buildSettingRow(
                context,
                title: '自动检查更新',
                subtitle: '设置自动检查更新的频率',
                trailing: ComboBox<UpdateCheckInterval>(
                  value: updateService.checkInterval,
                  items: UpdateCheckInterval.values.map((interval) {
                    return ComboBoxItem(
                      value: interval,
                      child: Text(interval.displayName),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      updateService.setCheckInterval(value);
                    }
                  },
                ),
              ),
              const SizedBox(height: 12),
              // 允许 Beta 更新
              _buildSettingRow(
                context,
                title: '接收 Beta 更新',
                subtitle: '允许接收较稳定的测试版更新',
                trailing: ToggleSwitch(
                  checked: updateService.allowBeta,
                  onChanged: (value) => updateService.setAllowBeta(value),
                ),
              ),
              const SizedBox(height: 12),
              // 允许 Alpha 更新
              _buildSettingRow(
                context,
                title: '接收 Alpha 更新',
                subtitle: '允许接收最新的测试版更新（可能不稳定）',
                trailing: ToggleSwitch(
                  checked: updateService.allowAlpha,
                  onChanged: (value) => updateService.setAllowAlpha(value),
                ),
              ),
              if (updateService.lastCheckTime != null) ...[
                const SizedBox(height: 16),
                Text(
                  '上次检查: ${_formatDateTime(updateService.lastCheckTime!)}',
                  style: FluentTheme.of(context).typography.caption?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildSettingRow(
    BuildContext context, {
    required String title,
    required String subtitle,
    required Widget trailing,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: FluentTheme.of(context).typography.body?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: FluentTheme.of(context).typography.caption?.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
        trailing,
      ],
    );
  }

  Color _getChannelColor(VersionChannel channel) {
    switch (channel) {
      case VersionChannel.alpha:
        return AppTheme.statusError;
      case VersionChannel.beta:
        return AppTheme.statusWarning;
      case VersionChannel.release:
        return AppTheme.statusSuccess;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    
    if (diff.inMinutes < 1) {
      return '刚刚';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes} 分钟前';
    } else if (diff.inDays < 1) {
      return '${diff.inHours} 小时前';
    } else {
      return '${dateTime.month}/${dateTime.day} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }

  Widget _buildUpdateAvailable(BuildContext context, UpdateService updateService) {
    final release = updateService.availableUpdate ?? updateService.latestRelease!;
    final hasDotNet8 = updateService.isDotNet8Installed ?? false;
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.statusWarning.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(
              color: AppTheme.statusWarning.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                FluentIcons.download,
                color: AppTheme.statusWarning,
                size: 24,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '发现新版本',
                      style: FluentTheme.of(context).typography.bodyStrong?.copyWith(
                        color: AppTheme.statusWarning,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'v${updateService.currentVersion} → v${release.version}',
                      style: FluentTheme.of(context).typography.caption?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '更新内容',
          style: FluentTheme.of(context).typography.bodyStrong?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.bgLayer1,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: AppTheme.borderSubtle),
          ),
          child: _buildMarkdownContent(context, updateService.getLatestChangelog()),
        ),
        const SizedBox(height: 16),
        // .NET 8 提示信息
        if (!hasDotNet8) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.statusInfo.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(
                color: AppTheme.statusInfo.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  FluentIcons.info,
                  color: AppTheme.statusInfo,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '推荐安装 .NET 8',
                        style: FluentTheme.of(context).typography.bodyStrong?.copyWith(
                          color: AppTheme.statusInfo,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '安装 .NET 8 Desktop Runtime 后可使用更新器自动更新',
                        style: FluentTheme.of(context).typography.caption?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Button(
                  onPressed: () async {
                    final uri = Uri.parse(updateService.getDotNet8DownloadUrl());
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                  child: const Text('下载 .NET 8'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}
