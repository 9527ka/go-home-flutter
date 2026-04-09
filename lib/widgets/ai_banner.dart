import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

enum AiBannerStyle { prominent, compact }

/// AI 宣传横幅 — 用于首页、详情页、线索提交页
class AiBanner extends StatelessWidget {
  final AiBannerStyle style;
  final String title;
  final String subtitle;
  final bool dismissible;
  final VoidCallback? onDismiss;
  final IconData? icon;

  const AiBanner({
    super.key,
    required this.style,
    required this.title,
    required this.subtitle,
    this.dismissible = false,
    this.onDismiss,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return style == AiBannerStyle.prominent
        ? _buildProminent(context)
        : _buildCompact(context);
  }

  /// 首页大卡片 — 蓝紫渐变科技感
  Widget _buildProminent(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4A90D9), Color(0xFF7C3AED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4A90D9).withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // 装饰性背景圆
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.08),
              ),
            ),
          ),
          Positioned(
            right: 30,
            bottom: -30,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          // 内容
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon ?? Icons.auto_awesome,
                    size: 24,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.9),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                if (dismissible) ...[
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: onDismiss,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.close,
                        size: 14,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 详情页/线索页小提示条
  Widget _buildCompact(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEDE9FE), Color(0xFFE8F0FE)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF7C3AED).withOpacity(0.15),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFF7C3AED).withOpacity(0.12),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(
              icon ?? Icons.auto_awesome,
              size: 16,
              color: const Color(0xFF7C3AED),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title.isNotEmpty)
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF4C1D95),
                    ),
                  ),
                if (title.isNotEmpty && subtitle.isNotEmpty)
                  const SizedBox(height: 2),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B21A8),
                      height: 1.3,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// AI 智能分析面板 — 详情页可展开/收起
class AiAnalysisPanel extends StatefulWidget {
  final int imageCount;
  final int appearanceLength;

  const AiAnalysisPanel({
    super.key,
    required this.imageCount,
    required this.appearanceLength,
  });

  @override
  State<AiAnalysisPanel> createState() => _AiAnalysisPanelState();
}

class _AiAnalysisPanelState extends State<AiAnalysisPanel> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEDE9FE), Color(0xFFE8F0FE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFF7C3AED).withOpacity(0.15),
          width: 0.5,
        ),
      ),
      child: Column(
        children: [
          // 标题行（点击展开/收起）
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: const Icon(Icons.auto_awesome, size: 16, color: Color(0xFF7C3AED)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l.get('ai_analysis_title'),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF4C1D95),
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.keyboard_arrow_down, size: 20, color: Color(0xFF7C3AED)),
                  ),
                ],
              ),
            ),
          ),

          // 展开内容
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1, color: Color(0xFFD8B4FE)),
                  const SizedBox(height: 10),
                  // 照片分析
                  _analysisItem(
                    widget.imageCount > 0 ? Icons.check_circle : Icons.info_outline,
                    widget.imageCount > 0
                        ? l.get('ai_analysis_photos').replaceAll('{n}', '${widget.imageCount}')
                        : l.get('ai_photo_hint'),
                    widget.imageCount > 0,
                  ),
                  const SizedBox(height: 6),
                  // 描述分析
                  _analysisItem(
                    widget.appearanceLength >= 30 ? Icons.check_circle : Icons.warning_amber_rounded,
                    widget.appearanceLength >= 30
                        ? l.get('ai_analysis_desc_good')
                        : l.get('ai_analysis_desc_low'),
                    widget.appearanceLength >= 30,
                  ),
                  const SizedBox(height: 6),
                  // 匹配状态
                  _analysisItem(
                    Icons.sync,
                    l.get('ai_analysis_matching'),
                    true,
                  ),
                  const SizedBox(height: 10),
                  // 行动号召
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      l.get('ai_analysis_cta'),
                      style: const TextStyle(fontSize: 12, color: Color(0xFF6B21A8), fontWeight: FontWeight.w500),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _analysisItem(IconData icon, String text, bool positive) {
    return Row(
      children: [
        Icon(
          icon,
          size: 14,
          color: positive ? const Color(0xFF059669) : const Color(0xFFD97706),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: positive ? const Color(0xFF065F46) : const Color(0xFF92400E),
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}
