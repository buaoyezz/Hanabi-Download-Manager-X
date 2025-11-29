import 'dart:io';
import 'package:fluent_ui/fluent_ui.dart';
import '../../utils/constants.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  Future<void> _launchUrl(BuildContext context, String url) async {
    try {
      // 使用 Windows cmd 打开链接
      await Process.start('cmd', ['/c', 'start', '', url], runInShell: true);
    } catch (e) {
      if (context.mounted) {
        displayInfoBar(
          context,
          builder: (context, close) => InfoBar(
            title: const Text('错误'),
            content: Text('打开链接失败: $e'),
            severity: InfoBarSeverity.error,
          ),
        );
      }
    }
  }

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
                FluentIcons.info,
                size: 16,
                color: FluentTheme.of(context).accentColor,
              ),
            ),
            const SizedBox(width: 12),
            const Text('关于'),
          ],
        ),
      ),
      children: [
        const SizedBox(height: 8),
        
        // Logo and App Info Section
        _buildSection(
          context,
          title: '应用信息',
          icon: FluentIcons.app_icon_default,
          children: [
            Center(
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset(
                      'assets/logo/logo.png',
                      width: 96,
                      height: 96,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            color: FluentTheme.of(context).accentColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            FluentIcons.download,
                            size: 48,
                            color: FluentTheme.of(context).accentColor,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    AppConstants.appName,
                    style: FluentTheme.of(context).typography.subtitle?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: FluentTheme.of(context).accentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'v${AppConstants.version}',
                      style: FluentTheme.of(context).typography.caption?.copyWith(
                        color: FluentTheme.of(context).accentColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 24),
        
        // Details Section
        _buildSection(
          context,
          title: '详细信息',
          icon: FluentIcons.info,
          children: [
            _buildInfoItem(context, '开发者', AppConstants.developer),
            const SizedBox(height: 12),
            _buildInfoItem(context, '下载核心', AppConstants.kernelName),
            const SizedBox(height: 12),
            _buildInfoItem(context, 'UI 框架', 'Fluent UI for Flutter'),
            const SizedBox(height: 12),
            _buildInfoItem(context, '字体', 'Noto Sans'),
          ],
        ),
        
        const SizedBox(height: 24),
        
        // Links Section
        _buildSection(
          context,
          title: '链接',
          icon: FluentIcons.link,
          children: [
            _buildLinkButton(
              context,
              icon: FluentIcons.globe,
              title: '官方网站',
              subtitle: '访问项目主页',
              onPressed: () => _launchUrl(context, AppConstants.officialUrl),
            ),
            const SizedBox(height: 12),
            _buildLinkButton(
              context,
              icon: FluentIcons.open_source,
              title: 'GitHub',
              subtitle: '查看源代码和贡献',
              onPressed: () => _launchUrl(context, AppConstants.githubUrl),
            ),
            const SizedBox(height: 12),
            _buildLinkButton(
              context,
              icon: FluentIcons.mail,
              title: '联系我们',
              subtitle: AppConstants.contactEmail,
              onPressed: () => _launchUrl(context, 'mailto:${AppConstants.contactEmail}'),
            ),
          ],
        ),
        
        const SizedBox(height: 24),
        
        // Copyright Section
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: FluentTheme.of(context).resources.cardBackgroundFillColorDefault,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: FluentTheme.of(context).resources.cardStrokeColorDefault,
            ),
          ),
          child: Center(
            child: Text(
              '© ${DateTime.now().year} ${AppConstants.developer}. All rights reserved.',
              style: FluentTheme.of(context).typography.caption?.copyWith(
                color: Colors.white.withValues(alpha: 0.5),
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        
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
        Expanded(
          child: Text(
            value,
            style: FluentTheme.of(context).typography.body?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLinkButton(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onPressed,
  }) {
    return Button(
      onPressed: onPressed,
      style: ButtonStyle(
        padding: WidgetStateProperty.all(
          const EdgeInsets.all(12),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: FluentTheme.of(context).accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 20,
              color: FluentTheme.of(context).accentColor,
            ),
          ),
          const SizedBox(width: 12),
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
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            FluentIcons.chevron_right,
            size: 16,
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ],
      ),
    );
  }
}
