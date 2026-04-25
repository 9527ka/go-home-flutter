import 'package:flutter/material.dart';
import '../../config/currency.dart';
import '../../l10n/app_localizations.dart';
import '../../models/red_packet.dart';
import '../../services/wallet_service.dart';
import '../../utils/url_helper.dart';
import '../../widgets/red_packet_effect.dart';
import '../../widgets/vip_decoration.dart';

class RedPacketDetailPage extends StatefulWidget {
  final int redPacketId;

  const RedPacketDetailPage({super.key, required this.redPacketId});

  @override
  State<RedPacketDetailPage> createState() => _RedPacketDetailPageState();
}

class _RedPacketDetailPageState extends State<RedPacketDetailPage> {
  final _walletService = WalletService();
  RedPacketModel? _packet;
  bool _isLoading = true;

  // 微信红包配色（与 open_dialog 统一）
  static const _rpRed = Color(0xFFD4534B);
  static const _goldText = Color(0xFFECC88A);
  static const _orangeText = Color(0xFFE8A03A);

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() => _isLoading = true);
    try {
      _packet = await _walletService.getRedPacketDetail(widget.redPacketId);
    } catch (e) {
      debugPrint('[RedPacketDetailPage] load detail error: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: _rpRed,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white))
          : _packet != null
              ? _buildContent(l)
              : _buildEmpty(l),
    );
  }

  /// 有数据时的完整页面
  Widget _buildContent(AppLocalizations l) {
    final packet = _packet!;
    final sender = packet.user;
    final topPadding = MediaQuery.of(context).padding.top;

    return Column(
      children: [
        // ======= 红色顶部区域（按发送者 VIP 皮肤叠加动效） =======
        RedPacketEffectOverlay(
          effectKey: packet.senderEffectKey,
          borderRadius: BorderRadius.zero,
          child: Container(
          width: double.infinity,
          padding: EdgeInsets.only(top: topPadding),
          color: _rpRed,
          child: Column(
            children: [
              // 返回按钮
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_ios_new,
                      size: 18, color: Colors.white),
                ),
              ),

              const SizedBox(height: 24),

              // 发送者头像 + 名字（带 VIP 皮肤装饰）
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  VipAvatarFrame(
                    vip: sender?.vip,
                    borderWidth: 1.5,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: sender?.avatar != null && sender!.avatar.isNotEmpty
                          ? Image.network(
                              UrlHelper.ensureAbsolute(sender.avatar),
                              width: 36,
                              height: 36,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _avatarPlaceholder(sender.nickname, 36),
                            )
                          : _avatarPlaceholder(sender?.nickname, 36),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${sender?.nickname ?? ""}${l.get("s_red_packet")}',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                      color: _goldText,
                    ),
                  ),
                  if (packet.senderVipLevel != 'normal') ...[
                    const SizedBox(width: 6),
                    VipLevelBadge(vip: sender?.vip, fontSize: 10),
                  ],
                ],
              ),

              const SizedBox(height: 12),

              // 祝福语
              Text(
                packet.greeting.isNotEmpty
                    ? packet.greeting
                    : l.get('rp_default_greeting'),
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),

              const SizedBox(height: 24),

              // 金额或状态
              if (packet.hasClaimed) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      CurrencyConfig.formatNumber(packet.myClaim!.amount),
                      style: const TextStyle(
                        fontSize: 56,
                        fontWeight: FontWeight.w300,
                        color: _goldText,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      CurrencyConfig.coinUnit,
                      style: const TextStyle(fontSize: 18, color: _goldText),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  l.get('rp_saved_to_wallet'),
                  style: const TextStyle(fontSize: 14, color: _goldText),
                ),
              ] else ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    packet.isExpired
                        ? l.get('red_packet_expired')
                        : l.get('red_packet_not_claimed'),
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),
            ],
          ),
          ),
        ),

        // ======= 白色底部区域（弧形衔接） =======
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: _buildClaimList(packet, l),
          ),
        ),
      ],
    );
  }

  /// 领取列表
  Widget _buildClaimList(RedPacketModel packet, AppLocalizations l) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Text(
            '${packet.claimedCount}${l.get("packets")}${l.get("wechat_red_packet")}，${l.get("claimed")} ${packet.claimedCount}/${packet.totalCount}${l.get("packets")}',
            style: const TextStyle(fontSize: 13, color: Color(0xFF999999)),
          ),
        ),

        // 分隔线
        Container(
          height: 0.5,
          margin: const EdgeInsets.symmetric(horizontal: 20),
          color: const Color(0xFFF0F0F0),
        ),

        // 列表
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: packet.claims.length,
            itemBuilder: (context, index) {
              final claim = packet.claims[index];
              // 仅当所有红包都被领完时，才在金额最高的领取记录下显示"手气最佳"
              bool isBest = false;
              if (packet.isFinished && packet.claims.length > 1) {
                final maxAmount = packet.claims
                    .map((c) => c.amount)
                    .reduce((a, b) => a > b ? a : b);
                isBest = claim.amount == maxAmount;
              }
              return _buildClaimItem(claim, isBest, l);
            },
          ),
        ),
      ],
    );
  }

  /// 领取记录项
  Widget _buildClaimItem(
      RedPacketClaimModel claim, bool isBest, AppLocalizations l) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          // 头像
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: claim.user?.avatar != null && claim.user!.avatar.isNotEmpty
                ? Image.network(
                    UrlHelper.ensureAbsolute(claim.user!.avatar),
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        _avatarPlaceholder(claim.user?.nickname, 44),
                  )
                : _avatarPlaceholder(claim.user?.nickname, 44),
          ),
          const SizedBox(width: 12),

          // 昵称 + 时间
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  claim.user?.nickname ?? '',
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF333333),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  claim.createdAt,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFBBBBBB),
                  ),
                ),
              ],
            ),
          ),

          // 金额 + 手气最佳
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                CurrencyConfig.format(claim.amount),
                style: const TextStyle(
                  fontSize: 15,
                  color: Color(0xFF333333),
                ),
              ),
              if (isBest) ...[
                const SizedBox(height: 3),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('👑', style: TextStyle(fontSize: 11)),
                    const SizedBox(width: 2),
                    Text(
                      l.get('best_luck'),
                      style: const TextStyle(
                        fontSize: 12,
                        color: _orangeText,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// 空状态页面
  Widget _buildEmpty(AppLocalizations l) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Column(
      children: [
        SizedBox(height: topPadding),
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new,
                size: 18, color: Colors.white),
          ),
        ),
        const SizedBox(height: 80),
        Icon(Icons.card_giftcard,
            size: 48, color: Colors.white.withValues(alpha: 0.4)),
        const SizedBox(height: 12),
        Text(
          l.get('red_packet_not_found'),
          style: TextStyle(
              fontSize: 16, color: Colors.white.withValues(alpha: 0.7)),
        ),
      ],
    );
  }

  Widget _avatarPlaceholder(String? nickname, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(size * 0.14),
      ),
      alignment: Alignment.center,
      child: Text(
        nickname?.isNotEmpty == true ? nickname![0] : '?',
        style: TextStyle(fontSize: size * 0.4, color: Colors.white),
      ),
    );
  }
}
