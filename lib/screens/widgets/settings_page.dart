import 'package:fluent_ui/fluent_ui.dart';
import '../../utils/constants.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  int _maxConnections = 16;
  bool _autoStart = true;
  bool _notifyOnComplete = true;
  final String _downloadPath = 'C:\\Downloads';

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage.scrollable(
      header: PageHeader(
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: FluentTheme.of(context).accentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                FluentIcons.settings,
                size: 16,
                color: FluentTheme.of(context).accentColor,
              ),
            ),
            const SizedBox(width: 12),
            const Text('设置'),
          ],
        ),
      ),
      children: [
        const SizedBox(height: 8),
        _buildSection(
          context,
          title: '下载设置',
          icon: FluentIcons.download,
          children: [
            _buildSettingItem(
              context,
              title: '下载路径',
              subtitle: _downloadPath,
              trailing: Button(
                onPressed: () {},
                child: const Text('更改'),
              ),
            ),
            const SizedBox(height: 12),
            _buildSettingItem(
              context,
              title: '最大连接数',
              subtitle: '每个任务的最大线程数',
              trailing: SizedBox(
                width: 200,
                child: Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: _maxConnections.toDouble(),
                        min: 1,
                        max: 32,
                        divisions: 31,
                        label: _maxConnections.toString(),
                        onChanged: (value) {
                          setState(() => _maxConnections = value.toInt());
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 30,
                      child: Text(
                        '$_maxConnections',
                        style: FluentTheme.of(context).typography.bodyStrong,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _buildSection(
          context,
          title: '行为设置',
          icon: FluentIcons.processing,
          children: [
            _buildSettingItem(
              context,
              title: '自动开始下载',
              subtitle: '添加任务后立即开始下载',
              trailing: ToggleSwitch(
                checked: _autoStart,
                onChanged: (value) => setState(() => _autoStart = value),
              ),
            ),
            const SizedBox(height: 12),
            _buildSettingItem(
              context,
              title: '完成通知',
              subtitle: '下载完成后显示系统通知',
              trailing: ToggleSwitch(
                checked: _notifyOnComplete,
                onChanged: (value) => setState(() => _notifyOnComplete = value),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _buildSection(
          context,
          title: '关于',
          icon: FluentIcons.info,
          children: [
            _buildInfoItem(context, '软件名称', AppConstants.appName),
            const SizedBox(height: 12),
            _buildInfoItem(context, '版本', AppConstants.version),
            const SizedBox(height: 12),
            _buildInfoItem(context, '开发者', AppConstants.developer),
            const SizedBox(height: 12),
            _buildInfoItem(context, '下载核心', AppConstants.kernelName),
          ],
        ),
        const SizedBox(height: 24),
        _buildDangerZone(context),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: FluentTheme.of(context).resources.cardBackgroundFillColorDefault,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: FluentTheme.of(context).resources.cardStrokeColorDefault,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16),
              const SizedBox(width: 8),
              Text(
                title,
                style: FluentTheme.of(context).typography.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSettingItem(
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
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: FluentTheme.of(context).typography.caption?.copyWith(
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
        trailing,
      ],
    );
  }

  Widget _buildInfoItem(BuildContext context, String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: FluentTheme.of(context).typography.body?.copyWith(
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
        ),
        Text(
          value,
          style: FluentTheme.of(context).typography.body?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildDangerZone(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.red.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(FluentIcons.warning, size: 16, color: Colors.red),
              const SizedBox(width: 8),
              Text(
                '危险区域',
                style: FluentTheme.of(context).typography.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '清除所有数据',
                      style: FluentTheme.of(context).typography.body?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '删除所有下载任务和历史记录',
                      style: FluentTheme.of(context).typography.caption?.copyWith(
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              Button(
                onPressed: _confirmClearData,
                child: Text('清除数据'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmClearData() {
    showDialog(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('确认清除'),
        content: const Text('确定要清除所有下载任务和历史记录吗？此操作不可恢复。'),
        actions: [
          Button(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              displayInfoBar(
                context,
                builder: (context, close) => InfoBar(
                  title: const Text('已清除'),
                  content: const Text('所有数据已清除'),
                  severity: InfoBarSeverity.success,
                ),
              );
            },
            child: const Text('确认清除'),
          ),
        ],
      ),
    );
  }
}
