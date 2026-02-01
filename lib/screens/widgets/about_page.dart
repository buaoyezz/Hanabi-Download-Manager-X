import 'dart:io';
import 'dart:ui';
import 'package:fluent_ui/fluent_ui.dart';
import '../../utils/constants.dart';
import '../../theme/app_theme.dart';
import '../../services/performance_monitor_service.dart';

import '../../widgets/animated_notifications.dart';
class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> with SingleTickerProviderStateMixin {
  int _logoTapCount = 0;
  bool _easterEggActivated = false;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 10).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _onLogoTap() {
    setState(() {
      _logoTapCount++;
      
      if (_logoTapCount >= 10 && !_easterEggActivated) {
        _easterEggActivated = true;
        _showEasterEgg();
      } else if (_logoTapCount < 10) {
        // 摇晃动画
        _shakeController.forward(from: 0);
      }
    });
  }

  void _showEasterEgg() {
    showDialog(
      context: context,
      builder: (ctx) => ContentDialog(
        title: const Row(
          children: [
            Icon(FluentIcons.emoji2, size: 24, color: Color(0xFFFFB900)),
            SizedBox(width: 12),
            Text('Hey！'),
          ],
        ),
        content: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 动画 Logo
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 800),
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: Transform.rotate(
                      angle: value * 6.28, // 360度旋转
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.accentPrimary.withValues(alpha: 0.5),
                              blurRadius: 30,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.asset(
                            'assets/logo/logo.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              const Text(
                '恭喜你发现了这个彩蛋！',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.accentPrimary.withValues(alpha: 0.2),
                      AppTheme.accentPrimary.withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(
                    color: AppTheme.accentPrimary.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  children: [
                    const Text(
                      '这个彩蛋没什么用',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.accentLight,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '但是感谢你使用 ${AppConstants.appName}！\n'
                      '感谢你的支持\n'
                      '希望你可以给他一个Star',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.statusSuccess.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(AppTheme.radiusRound),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(FluentIcons.heart_fill, size: 14, color: Color(0xFFFF6B6B)),
                          const SizedBox(width: 6),
                          Text(
                            'Made by ${AppConstants.developer}',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // 统计信息
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                // children: [
                //   _buildStatItem('版本', AppConstants.version, FluentIcons.code),
                //   _buildStatItem('点击', '$_logoTapCount', FluentIcons.touch),
                //   _buildStatItem('内核', 'NSFX', FluentIcons.processing),
                // ],
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _logoTapCount = 0;
                _easterEggActivated = false;
              });
            },
            child: const Text('假装不知道'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.bgLayer2.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: AppTheme.borderSubtle.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 16, color: AppTheme.accentLight),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.accentLight,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: AppTheme.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchUrl(BuildContext context, String url) async {
    try {
      await Process.start('cmd', ['/c', 'start', '', url], runInShell: true);
    } catch (e) {
      if (context.mounted) {
        NotificationManager.of(context)?.showError('错误', message: '打开链接失败: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 追踪重建
    PerformanceMonitorService().trackRebuild('AboutPage');

    return ScaffoldPage.scrollable(
      header: _buildHeader(context),
      children: [
        const SizedBox(height: 8),
        _buildAppInfoSection(context),
        const SizedBox(height: 20),
        _buildDetailsSection(context),
        const SizedBox(height: 20),
        _buildLinksSection(context),
        const SizedBox(height: 20),
        _buildCopyrightSection(context),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return PageHeader(
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.accentPrimary.withValues(alpha: 0.2),
                  AppTheme.accentPrimary.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              border: Border.all(
                color: AppTheme.accentPrimary.withValues(alpha: 0.3),
              ),
            ),
            child: Icon(
              FluentIcons.info,
              size: 18,
              color: AppTheme.accentLight,
            ),
          ),
          const SizedBox(width: 14),
          const Text('关于'),
        ],
      ),
    );
  }

  Widget _buildAppInfoSection(BuildContext context) {
    return _SectionCard(
      title: '应用信息',
      icon: FluentIcons.app_icon_default,
      child: Center(
        child: Column(
          children: [
            // Logo with glow effect and tap detection
            AnimatedBuilder(
              animation: _shakeAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(_shakeAnimation.value * (_logoTapCount % 2 == 0 ? 1 : -1), 0),
                  child: child,
                );
              },
              child: GestureDetector(
                onTap: _onLogoTap,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      // Pigment mix gradient glow
                      Positioned(
                        top: 4,
                        left: 4,
                        right: 4,
                        bottom: 4,
                        child: Transform.scale(
                          scale: 1.6,
                          child: ImageFiltered(
                            imageFilter: ImageFilter.blur(
                              sigmaX: _logoTapCount > 5 ? 90 : 60,
                              sigmaY: _logoTapCount > 5 ? 90 : 60,
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(30),
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF42A5F5), // Blue
                                    Color(0xFFAB47BC), // Purple
                                    Color(0xFFEC407A), // Pink
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Logo
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.asset(
                            'assets/logo/logo.png',
                            width: 88,
                            height: 88,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 88,
                                height: 88,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      AppTheme.accentPrimary.withValues(alpha: 0.3),
                                      AppTheme.accentPrimary.withValues(alpha: 0.1),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Icon(
                                  FluentIcons.download,
                                  size: 40,
                                  color: AppTheme.accentLight,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // 点击提示（5次后显示）
            if (_logoTapCount >= 5 && _logoTapCount < 10)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 300),
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.statusWarning.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(AppTheme.radiusRound),
                          border: Border.all(
                            color: AppTheme.statusWarning.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          '再点 ${10 - _logoTapCount} 次...',
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppTheme.statusWarning,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 20),
            Text(
              AppConstants.appName,
              style: FluentTheme.of(context).typography.subtitle?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 22,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.accentPrimary.withValues(alpha: 0.2),
                    AppTheme.accentPrimary.withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusRound),
                border: Border.all(
                  color: AppTheme.accentPrimary.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                'v${AppConstants.version}',
                style: FluentTheme.of(context).typography.body?.copyWith(
                  color: AppTheme.accentLight,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsSection(BuildContext context) {
    return _SectionCard(
      title: '详细信息',
      icon: FluentIcons.info,
      child: Column(
        children: [
          _InfoRow(label: '开发者', value: AppConstants.developer),
          const SizedBox(height: 10),
          _InfoRow(label: '下载核心', value: AppConstants.kernelName),
          const SizedBox(height: 10),
          _InfoRow(label: 'UI 框架', value: 'Fluent UI for Flutter'),
        ],
      ),
    );
  }

  Widget _buildLinksSection(BuildContext context) {
    return _SectionCard(
      title: '链接',
      icon: FluentIcons.link,
      child: Column(
        children: [
          _LinkButton(
            icon: FluentIcons.globe,
            title: '官方网站',
            subtitle: '访问项目主页',
            onPressed: () => _launchUrl(context, AppConstants.officialUrl),
          ),
          const SizedBox(height: 10),
          _LinkButton(
            icon: FluentIcons.open_source,
            title: 'GitHub',
            subtitle: '查看源代码和贡献',
            onPressed: () => _launchUrl(context, AppConstants.githubUrl),
          ),
          const SizedBox(height: 10),
          _LinkButton(
            icon: FluentIcons.mail,
            title: '联系我们',
            subtitle: AppConstants.contactEmail,
            onPressed: () => _launchUrl(context, 'mailto:${AppConstants.contactEmail}'),
          ),
        ],
      ),
    );
  }

  Widget _buildCopyrightSection(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.borderSubtle.withValues(alpha: 0.3)),
      ),
      child: Center(
        child: Text(
          '© ${DateTime.now().year} ${AppConstants.developer}. All rights reserved.',
          style: FluentTheme.of(context).typography.caption?.copyWith(
            color: AppTheme.textTertiary,
            fontSize: 11,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

/// 区块卡片组件 - Fluent Design 风格
class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.borderSubtle.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppTheme.textSecondary),
              const SizedBox(width: 10),
              Text(
                title,
                style: FluentTheme.of(context).typography.body?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// 信息行组件 - Fluent Design 风格
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.bgLayer2.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: FluentTheme.of(context).typography.caption?.copyWith(
                color: AppTheme.textTertiary,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: FluentTheme.of(context).typography.body?.copyWith(
                fontWeight: FontWeight.w400,
                color: AppTheme.textPrimary,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 链接按钮组件
class _LinkButton extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onPressed;

  const _LinkButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onPressed,
  });

  @override
  State<_LinkButton> createState() => _LinkButtonState();
}

class _LinkButtonState extends State<_LinkButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _isHovered ? AppTheme.bgLayer2 : AppTheme.bgLayer1,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(
              color: _isHovered 
                  ? AppTheme.accentPrimary.withValues(alpha: 0.3)
                  : AppTheme.borderSubtle,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.accentPrimary.withValues(alpha: _isHovered ? 0.25 : 0.15),
                      AppTheme.accentPrimary.withValues(alpha: _isHovered ? 0.15 : 0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                ),
                child: Icon(
                  widget.icon,
                  size: 18,
                  color: AppTheme.accentLight,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: FluentTheme.of(context).typography.body?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: _isHovered ? AppTheme.accentLight : AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle,
                      style: FluentTheme.of(context).typography.caption?.copyWith(
                        color: AppTheme.textTertiary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                FluentIcons.chevron_right,
                size: 14,
                color: _isHovered ? AppTheme.accentLight : AppTheme.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
