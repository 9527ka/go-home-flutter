import 'package:flutter/material.dart';
import '../../config/currency.dart';
import '../../config/theme.dart';
import '../../models/vip.dart';
import '../../providers/wallet_provider.dart';
import '../../services/vip_service.dart';
import '../../widgets/vip_decoration.dart';
import 'package:provider/provider.dart';

/// VIP 中心：我的状态 + 等级列表 + 购买/续费
class VipCenterPage extends StatefulWidget {
  const VipCenterPage({super.key});

  @override
  State<VipCenterPage> createState() => _VipCenterPageState();
}

class _VipCenterPageState extends State<VipCenterPage> {
  final _svc = VipService();
  bool _loading = true;
  bool _purchasing = false;
  MyVipModel? _my;
  List<VipLevelModel> _levels = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      _svc.getMy(),
      _svc.getLevels(),
    ]);
    if (!mounted) return;
    setState(() {
      _my = results[0] as MyVipModel?;
      _levels = (results[1] as List<VipLevelModel>)
          .where((l) => !l.isNormal)
          .toList()
        ..sort((a, b) => a.levelOrder.compareTo(b.levelOrder));
      _loading = false;
    });
  }

  Future<void> _purchase(VipLevelModel lv) async {
    if (_purchasing) return;
    final confirmed = await _confirmPurchase(lv);
    if (!confirmed) return;

    setState(() => _purchasing = true);
    final res = await _svc.purchase(lv.levelKey);
    if (!mounted) return;
    setState(() => _purchasing = false);

    if (res['code'] == 0) {
      final msg = res['msg']?.toString() ?? '购买成功';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: AppTheme.successColor,
      ));
      // 刷新 VIP 状态 + 钱包余额
      await _load();
      if (mounted) context.read<WalletProvider>().loadWalletInfo();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(res['msg']?.toString() ?? '购买失败'),
        backgroundColor: AppTheme.dangerColor,
      ));
    }
  }

  Future<bool> _confirmPurchase(VipLevelModel lv) async {
    final isRenew = _my?.isActive == true && _my?.level.levelKey == lv.levelKey;
    final verb = isRenew ? '续费' : '开通';
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('$verb ${lv.levelName} VIP'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('价格：${CurrencyConfig.formatWithUnit(lv.price)}'),
            const SizedBox(height: 6),
            Text('时长：${lv.durationDays} 天'),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(_, false),
              child: const Text('取消')),
          ElevatedButton(
              onPressed: () => Navigator.pop(_, true),
              child: Text('确认$verb')),
        ],
      ),
    );
    return result == true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: const Text('VIP 中心'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildMyStatusCard(),
                    const SizedBox(height: 20),
                    const Text(
                      '选择等级',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_levels.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppTheme.cardBg,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: AppTheme.cardShadow,
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.info_outline,
                                size: 42, color: AppTheme.textHint),
                            const SizedBox(height: 12),
                            const Text(
                              '暂无可开通的等级',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              '若管理员刚完成 VIP 功能部署，请确认后端已执行 migrations/029_add_vip_system.sql',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppTheme.textHint,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextButton(
                                onPressed: _load,
                                child: const Text('重试')),
                          ],
                        ),
                      )
                    else
                      ..._levels.map(_buildLevelCard),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildMyStatusCard() {
    final isActive = _my?.isActive == true && _my!.level.levelKey != 'normal';
    final colors = isActive
        ? _gradientForLevel(_my!.level.levelKey)
        : const [Color(0xFFBDBDBD), Color(0xFF9E9E9E)];
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colors.first.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            isActive ? Icons.workspace_premium : Icons.lock_outline,
            color: Colors.white,
            size: 36,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isActive
                      ? '${_my!.level.levelName} VIP'
                      : '暂未开通 VIP',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isActive
                      ? '有效期至 ${_formatDate(_my!.expiredAt)}'
                      : '开通后享专属皮肤/签到暴击加成/低费率提现',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelCard(VipLevelModel lv) {
    final colors = _gradientForLevel(lv.levelKey);
    final isCurrent = _my?.isActive == true && _my?.level.levelKey == lv.levelKey;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 顶部渐变条：等级名 + 特效示例
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: colors,
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.7),
                        width: 0.8),
                  ),
                  child: Text(
                    lv.levelName,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // 名字特效预览（用 VipNickname + 该等级 nameEffectKey）
                Expanded(
                  child: VipNickname(
                    vip: VipBadgeModel(
                      levelKey: lv.levelKey,
                      levelName: lv.levelName,
                      levelOrder: lv.levelOrder,
                      badgeEffectKey: lv.badgeEffectKey,
                      nameEffectKey: lv.nameEffectKey,
                    ),
                    text: '昵称预览',
                    baseStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                if (isCurrent)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '当前等级',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: colors.first,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // 权益列表
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _benefitRow(Icons.local_fire_department,
                    '签到基础加成 +${(lv.signBonusRate * 100).toStringAsFixed(0)}%'),
                _benefitRow(Icons.casino,
                    '暴击概率 +${(lv.critProbBonus * 100).toStringAsFixed(1)}% / 上限 ×${lv.critMaxMultiple}'),
                _benefitRow(Icons.arrow_circle_up,
                    '提现费率 ${(lv.withdrawFeeRate * 100).toStringAsFixed(1)}% / 每日额度 ${CurrencyConfig.format(lv.withdrawDailyLimit)}'),
                _benefitRow(Icons.auto_awesome,
                    '专属头像边框 / 昵称 / 红包皮肤动效'),
              ],
            ),
          ),
          // 底部：价格 + 购买按钮
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        CurrencyConfig.formatNumber(lv.price),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: colors.first,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        ' ${CurrencyConfig.coinUnit} / ${lv.durationDays}天',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: _purchasing ? null : () => _purchase(lv),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.first,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppTheme.textHint,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                  ),
                  child: Text(
                    isCurrent ? '续费' : '立即开通',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _benefitRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textPrimary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Color> _gradientForLevel(String levelKey) {
    switch (levelKey) {
      case 'silver':
        return const [Color(0xFFBDBDBD), Color(0xFF757575)];
      case 'gold':
        return const [Color(0xFFFFD54F), Color(0xFFFF8F00)];
      case 'platinum':
        return const [Color(0xFFB39DDB), Color(0xFF80DEEA)];
      case 'diamond':
        return const [Color(0xFF40C4FF), Color(0xFF00B0FF)];
      case 'supreme':
        return const [
          Color(0xFFFF4081),
          Color(0xFFAA00FF),
          Color(0xFF40C4FF)
        ];
      default:
        return const [Color(0xFFBDBDBD), Color(0xFF9E9E9E)];
    }
  }

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '-';
    // iso 形如 "2026-05-17 12:00:00"
    if (iso.length >= 10) return iso.substring(0, 10);
    return iso;
  }
}
