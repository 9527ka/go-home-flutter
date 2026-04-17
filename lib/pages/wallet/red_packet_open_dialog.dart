import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../config/currency.dart';
import '../../l10n/app_localizations.dart';
import '../../services/wallet_service.dart';
import '../../utils/url_helper.dart';

/// 微信风格红包开启弹窗
/// 返回值: {'claimed': true, 'amount': double} 或 {'claimed': false} 或 null
class RedPacketOpenDialog extends StatefulWidget {
  final int redPacketId;
  final String senderName;
  final String senderAvatar;
  final String greeting;

  /// 是否已领取（已领取时直接显示金额，不再显示"開"按钮）
  final bool alreadyClaimed;

  /// 已领取金额（alreadyClaimed=true 时使用）
  final double claimedAmount;

  const RedPacketOpenDialog({
    super.key,
    required this.redPacketId,
    this.senderName = '',
    this.senderAvatar = '',
    this.greeting = '',
    this.alreadyClaimed = false,
    this.claimedAmount = 0,
  });

  @override
  State<RedPacketOpenDialog> createState() => _RedPacketOpenDialogState();
}

class _RedPacketOpenDialogState extends State<RedPacketOpenDialog>
    with SingleTickerProviderStateMixin {
  bool _isOpening = false;
  bool _opened = false;
  double _claimedAmount = 0;
  late AnimationController _rotateController;

  // 微信红包红色
  static const _rpRed = Color(0xFFD4534B);
  static const _rpRedDark = Color(0xFFBE4740);
  static const _goldText = Color(0xFFECC88A);

  @override
  void initState() {
    super.initState();
    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    // 如果已领取，直接进入已拆开状态
    if (widget.alreadyClaimed) {
      _opened = true;
      _claimedAmount = widget.claimedAmount;
    }
  }

  @override
  void dispose() {
    _rotateController.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    if (_isOpening) return;
    setState(() => _isOpening = true);
    _rotateController.repeat();

    try {
      final res = await WalletService().claimRedPacket(widget.redPacketId);
      if (mounted) {
        _rotateController.stop();
        if (res['code'] == 0) {
          final amount = _parseDouble(res['data']?['amount']);
          setState(() {
            _opened = true;
            _claimedAmount = amount;
          });
        } else {
          // 已领取/已过期/已领完 — 直接关闭跳详情
          Navigator.pop(context, {'claimed': false});
        }
      }
    } catch (e) {
      if (mounted) {
        _rotateController.stop();
        Navigator.pop(context, {'claimed': false});
      }
    }
  }

  double _parseDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  void _viewDetail() {
    Navigator.pop(
        context, {'claimed': _opened && !widget.alreadyClaimed, 'amount': _claimedAmount});
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: _opened ? _buildOpenedLayout() : _buildUnopenedLayout(),
      ),
    );
  }

  /// 未拆开布局：半透明背景 + 居中红包卡片 + 底部关闭
  Widget _buildUnopenedLayout() {
    final screenSize = MediaQuery.of(context).size;

    return Stack(
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(color: Colors.black54),
        ),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildUnopenedBody(screenSize),
              const SizedBox(height: 24),
              _buildCloseButton(() => Navigator.pop(context)),
            ],
          ),
        ),
      ],
    );
  }

  /// 已拆开布局
  Widget _buildOpenedLayout() {
    final screenSize = MediaQuery.of(context).size;

    return Stack(
      children: [
        // 半透明背景
        GestureDetector(
          onTap: _viewDetail,
          child: Container(color: Colors.black54),
        ),
        // 居中内容
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 红色卡片
              Container(
                width: screenSize.width * 0.8,
                height: screenSize.height * 0.56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [_rpRed, _rpRedDark],
                  ),
                ),
                child: Column(
                  children: [
                    const Spacer(flex: 3),
                    _buildOpenedContent(),
                    const Spacer(flex: 3),
                    // 弧形分隔
                    ClipPath(
                      clipper: _ArcClipper(),
                      child: Container(
                        height: 24,
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                    // 查看领取详情
                    _buildViewDetailButton(),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _buildCloseButton(_viewDetail),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCloseButton(VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.6),
            width: 1.5,
          ),
        ),
        child: Icon(
          Icons.close,
          color: Colors.white.withValues(alpha: 0.6),
          size: 22,
        ),
      ),
    );
  }

  /// 未拆开状态 —— 显示发送者 + 祝福语 + "開"按钮
  Widget _buildUnopenedBody(Size screenSize) {
    final l = AppLocalizations.of(context)!;
    final greeting = widget.greeting.isNotEmpty
        ? widget.greeting
        : l.get('rp_default_greeting');

    return Container(
      width: screenSize.width * 0.8,
      height: screenSize.height * 0.56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_rpRed, _rpRedDark],
        ),
      ),
      child: Column(
        children: [
          const Spacer(flex: 2),

          // 发送者头像
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: widget.senderAvatar.isNotEmpty
                ? Image.network(
                    UrlHelper.ensureAbsolute(widget.senderAvatar),
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        _buildAvatarPlaceholder(),
                  )
                : _buildAvatarPlaceholder(),
          ),
          const SizedBox(height: 14),

          // 发送者名字
          Text(
            '${widget.senderName}${l.get("s_red_packet")}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: _goldText,
            ),
          ),
          const SizedBox(height: 14),

          // 祝福语
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              greeting,
              style: TextStyle(
                fontSize: 15,
                color: Colors.white.withValues(alpha: 0.85),
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          const Spacer(flex: 2),

          // 分隔弧线
          ClipPath(
            clipper: _ArcClipper(),
            child: Container(
              height: 24,
              color: Colors.white.withValues(alpha: 0.06),
            ),
          ),

          // "開" 按钮区域
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 12, bottom: 24),
            child: Center(
              child: GestureDetector(
                onTap: _open,
                child: _isOpening
                    ? AnimatedBuilder(
                        animation: _rotateController,
                        builder: (context, child) {
                          return Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, 0.002)
                              ..rotateY(
                                  _rotateController.value * 2 * math.pi),
                            child: child,
                          );
                        },
                        child: _buildOpenButton(),
                      )
                    : _buildOpenButton(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 已拆开内容 —— 发送者 + 金额
  Widget _buildOpenedContent() {
    final l = AppLocalizations.of(context)!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 发送者头像 + 名字
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: widget.senderAvatar.isNotEmpty
                  ? Image.network(
                      UrlHelper.ensureAbsolute(widget.senderAvatar),
                      width: 36,
                      height: 36,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _buildAvatarPlaceholder(size: 36),
                    )
                  : _buildAvatarPlaceholder(size: 36),
            ),
            const SizedBox(width: 10),
            Text(
              '${widget.senderName}${l.get("s_red_packet")}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: _goldText,
              ),
            ),
          ],
        ),

        const SizedBox(height: 32),

        // 金额（居中）
        Text(
          CurrencyConfig.formatNumber(_claimedAmount),
          style: const TextStyle(
            fontSize: 60,
            fontWeight: FontWeight.w300,
            color: _goldText,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 6),
        // 爱心值
        Text(
          CurrencyConfig.coinUnit,
          style: TextStyle(
            fontSize: 15,
            color: _goldText.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  /// 查看领取详情按钮
  Widget _buildViewDetailButton() {
    final l = AppLocalizations.of(context)!;
    return GestureDetector(
      onTap: _viewDetail,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              l.get('view_claim_detail'),
              style: TextStyle(
                fontSize: 15,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOpenButton() {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _goldText,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Center(
        child: Text(
          '開',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            color: _rpRed,
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarPlaceholder({double size = 48}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(size * 0.16),
      ),
      alignment: Alignment.center,
      child: Text(
        widget.senderName.isNotEmpty ? widget.senderName[0] : '?',
        style: TextStyle(
            fontSize: size * 0.45, color: Colors.white),
      ),
    );
  }
}

/// 弧形裁剪器 —— 底部向上凸起的弧线
class _ArcClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, size.height);
    path.quadraticBezierTo(
        size.width / 2, 0, size.width, size.height);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
