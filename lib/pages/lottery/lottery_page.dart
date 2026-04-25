import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/currency.dart';
import '../../models/lottery.dart';
import '../../services/lottery_service.dart';
import '../../widgets/lottery_wheel.dart';
import '../../widgets/lottery_result_burst.dart';

/// 抽奖主页：转盘 UI + 旋转动画，结果弹窗按 rarity/是否头奖分级特效
class LotteryPage extends StatefulWidget {
  const LotteryPage({super.key});

  @override
  State<LotteryPage> createState() => _LotteryPageState();
}

class _LotteryPageState extends State<LotteryPage>
    with TickerProviderStateMixin {
  final _service = LotteryService();
  LotteryInfoModel? _info;
  bool _loading = true;
  bool _drawing = false;
  LotteryResultModel? _lastResult;

  // 转盘旋转：由 spin controller 驱动
  double _wheelRotation = 0;
  double _rotationStart = 0;
  double _rotationEnd = 0;
  late final AnimationController _spinCtrl;
  // 每经过一个扇形就触发一次 selectionClick，模拟转盘"咔咔"刮板音
  int _lastTickSegment = 0;
  int _prizeCountForTick = 0;

  @override
  void initState() {
    super.initState();
    _spinCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    )..addListener(_onSpinTick);
    _loadInfo();
  }

  @override
  void dispose() {
    _spinCtrl.dispose();
    super.dispose();
  }

  void _onSpinTick() {
    final t = const _SpinCurve().transform(_spinCtrl.value);
    final next = _rotationStart + (_rotationEnd - _rotationStart) * t;
    // 按扇形刻度发出触觉脉冲：起步慢 → 匀速密 → 末段稀疏，形成加速-匀速-减速"咔咔"感
    if (_prizeCountForTick > 0) {
      final seg = 2 * math.pi / _prizeCountForTick;
      final segIdx = (next / seg).floor();
      if (segIdx != _lastTickSegment) {
        _lastTickSegment = segIdx;
        HapticFeedback.selectionClick();
      }
    }
    setState(() {
      _wheelRotation = next;
    });
  }

  Future<void> _loadInfo() async {
    setState(() => _loading = true);
    final info = await _service.getInfo();
    if (!mounted) return;
    setState(() {
      _info = info;
      _loading = false;
    });
  }

  Future<void> _draw() async {
    if (_drawing) return;
    if (_info == null) return;
    if (_info!.todayRemaining <= 0) {
      _toast('今日抽奖次数已达上限');
      return;
    }

    setState(() => _drawing = true);
    HapticFeedback.mediumImpact();
    SystemSound.play(SystemSoundType.click);
    final res = await _service.draw();
    if (!mounted) return;

    if (res['code'] != 0 || res['data'] == null) {
      setState(() => _drawing = false);
      _toast(res['msg'] ?? '抽奖失败');
      return;
    }

    final result = LotteryResultModel.fromJson(res['data']);
    final prizes = _info!.prizes;
    final idx = prizes.indexWhere((p) => p.id == result.prizeId);
    final prizeIdx = idx >= 0 ? idx : 0;

    // 计算目标角度并启动转盘旋转
    _rotationStart = _wheelRotation;
    _rotationEnd = LotteryWheel.computeTargetRotation(
      currentRotation: _wheelRotation,
      prizeIndex: prizeIdx,
      prizeCount: prizes.length,
    );
    _prizeCountForTick = prizes.length;
    _lastTickSegment = (_rotationStart / (2 * math.pi / prizes.length)).floor();
    _spinCtrl.reset();
    await _spinCtrl.forward().orCancel;
    if (!mounted) return;

    setState(() {
      _drawing = false;
      _lastResult = result;
    });
    _playResultHaptic(result);
    _showResultDialog(result);
    _loadInfo();
  }

  void _playResultHaptic(LotteryResultModel r) {
    final isJackpot = r.isBigPrize || r.rarity >= 3;
    if (!r.isWin) {
      HapticFeedback.lightImpact();
      return;
    }
    if (isJackpot) {
      HapticFeedback.heavyImpact();
      Future.delayed(const Duration(milliseconds: 150),
          () => HapticFeedback.heavyImpact());
      Future.delayed(const Duration(milliseconds: 320),
          () => HapticFeedback.heavyImpact());
    } else if (r.rarity >= 2) {
      HapticFeedback.heavyImpact();
      Future.delayed(const Duration(milliseconds: 140),
          () => HapticFeedback.mediumImpact());
    } else {
      HapticFeedback.mediumImpact();
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  void _showResultDialog(LotteryResultModel r) {
    final isJackpot = r.isBigPrize || r.rarity >= 3;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: Stack(
            alignment: Alignment.center,
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(color: Colors.black54),
              ),
              // 结果卡片
              _buildResultCard(r, isJackpot),
              // 按 rarity/isBigPrize 分级的爆发特效（铺满屏幕）
              Positioned.fill(
                child: IgnorePointer(
                  child: LotteryResultBurst(
                    rarity: r.rarity,
                    isJackpot: isJackpot,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 结果卡片：彩带 banner + 金色奖章 + 奖品名 + 奖励 + 金属渐变按钮
  Widget _buildResultCard(LotteryResultModel r, bool isJackpot) {
    final isWin = r.isWin;
    // 卡底渐变：按稀有度分档
    final List<Color> bgColors = !isWin
        ? const [Color(0xFF546E7A), Color(0xFF263238)]
        : isJackpot
            ? const [Color(0xFF6A1B9A), Color(0xFFC2185B)]
            : r.rarity >= 2
                ? const [Color(0xFFFF8F00), Color(0xFFE65100)]
                : const [Color(0xFF0288D1), Color(0xFF0D47A1)];
    final String bannerText = !isWin
        ? '谢谢参与'
        : isJackpot
            ? '头奖降临'
            : r.rarity >= 2
                ? '恭喜中奖'
                : '恭喜获得';
    final List<Color> bannerColors = !isWin
        ? const [Color(0xFF90A4AE), Color(0xFF546E7A)]
        : isJackpot
            ? const [Color(0xFFFF4081), Color(0xFFAA00FF)]
            : const [Color(0xFFFFD54F), Color(0xFFFF8F00)];
    final IconData medalIcon = isWin
        ? (isJackpot
            ? Icons.diamond
            : r.rarity >= 2
                ? Icons.stars
                : Icons.card_giftcard)
        : Icons.sentiment_satisfied;
    final bool showGoldCta = isWin;

    return Container(
      width: 320,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: bgColors.first.withValues(alpha: 0.55),
            blurRadius: 30,
            spreadRadius: 2,
          ),
          if (r.rarity >= 2)
            BoxShadow(
              color: const Color(0xFFFFD54F)
                  .withValues(alpha: isJackpot ? 0.8 : 0.55),
              blurRadius: isJackpot ? 42 : 28,
              spreadRadius: isJackpot ? 4 : 2,
            ),
          if (isJackpot)
            const BoxShadow(
              color: Color(0xFFFFF59D),
              blurRadius: 72,
              spreadRadius: 2,
            ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          // 主体卡片
          Container(
            margin: const EdgeInsets.only(top: 22),
            padding: const EdgeInsets.fromLTRB(22, 58, 22, 22),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: bgColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              border: r.rarity >= 2
                  ? Border.all(
                      color: const Color(0xFFFFD54F),
                      width: isJackpot ? 2.5 : 1.6,
                    )
                  : Border.all(
                      color: Colors.white.withValues(alpha: 0.25),
                      width: 1,
                    ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 奖章（金色外环 + 渐变内盘 + 图标 + 光晕）
                _buildMedallion(medalIcon, bgColors, isJackpot),
                const SizedBox(height: 14),
                // 奖品名
                Text(
                  r.prizeName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.6,
                    shadows: [
                      Shadow(
                          color: Colors.black45,
                          blurRadius: 4,
                          offset: Offset(0, 2)),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                // 金色装饰分隔线
                _buildGoldDivider(),
                const SizedBox(height: 12),
                // 奖励或鼓励语
                if (isWin)
                  _buildRewardRow(r.rewardAmount)
                else
                  const Text(
                    '下次一定能中～',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                const SizedBox(height: 22),
                // 按钮
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: _buildCtaButton(
                    label: isWin ? '领取奖励' : '再来一次',
                    gold: showGoldCta,
                  ),
                ),
              ],
            ),
          ),
          // 顶部缎带 banner（压在卡片顶边）
          _buildRibbon(bannerText, bannerColors),
        ],
      ),
    );
  }

  Widget _buildMedallion(
      IconData icon, List<Color> bg, bool isJackpot) {
    return Container(
      width: 92,
      height: 92,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: [Color(0xFFFFF8E1), Color(0xFFFFB300), Color(0xFFE65100)],
          stops: [0.0, 0.6, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD54F).withValues(alpha: 0.7),
            blurRadius: 18,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: bg,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.7),
            width: 2,
          ),
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: isJackpot ? 42 : 38,
          color: Colors.white,
          shadows: const [
            Shadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 2)),
          ],
        ),
      ),
    );
  }

  Widget _buildGoldDivider() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: Container(
            height: 1,
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [
                Color(0x00FFD54F),
                Color(0xFFFFD54F),
              ]),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Icon(Icons.star, size: 10, color: Color(0xFFFFE082)),
        ),
        Expanded(
          child: Container(
            height: 1,
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [
                Color(0xFFFFD54F),
                Color(0x00FFD54F),
              ]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRewardRow(double amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Icon(Icons.auto_awesome, size: 18, color: Color(0xFFFFD54F)),
        const SizedBox(width: 8),
        ShaderMask(
          shaderCallback: (rect) => const LinearGradient(
            colors: [
              Color(0xFFFFF59D),
              Color(0xFFFFD54F),
              Color(0xFFFFB300),
            ],
          ).createShader(rect),
          child: Text(
            '+${CurrencyConfig.format(amount)}',
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 0.5,
              shadows: [
                Shadow(
                    color: Colors.black54,
                    blurRadius: 6,
                    offset: Offset(0, 2)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 4),
        const Text(
          CurrencyConfig.coinUnit,
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFFFFE082),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 8),
        const Icon(Icons.auto_awesome, size: 18, color: Color(0xFFFFD54F)),
      ],
    );
  }

  Widget _buildCtaButton({required String label, required bool gold}) {
    final colors = gold
        ? const [Color(0xFFFFF176), Color(0xFFFFC107), Color(0xFFFF8F00)]
        : const [Color(0xFFECEFF1), Color(0xFFB0BEC5)];
    final textColor = gold ? const Color(0xFF5D2E00) : const Color(0xFF263238);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: (gold
                    ? const Color(0xFFFF6F00)
                    : const Color(0xFF37474F))
                .withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.8),
          width: 1.2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.pop(context),
          borderRadius: BorderRadius.circular(24),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: textColor,
                letterSpacing: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRibbon(String text, List<Color> colors) {
    return Positioned(
      top: 0,
      child: ClipPath(
        clipper: _RibbonClipper(),
        child: Container(
          width: 180,
          height: 44,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: colors.first.withValues(alpha: 0.6),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 2,
                shadows: [
                  Shadow(
                      color: Colors.black54,
                      blurRadius: 4,
                      offset: Offset(0, 2)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('心愿转盘'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFE91E63), Color(0xFF9C27B0)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF3F1F5E), // 深紫
              Color(0xFF6A1B9A),
              Color(0xFFAD1457), // 深粉
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
            : _info == null
                ? _buildErrorState()
                : _buildContent(),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 56, color: Colors.white70),
          const SizedBox(height: 12),
          const Text('加载失败',
              style: TextStyle(color: Colors.white, fontSize: 15)),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _loadInfo,
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final info = _info!;
    final topPad = MediaQuery.of(context).padding.top + kToolbarHeight + 8;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, topPad, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(info),
          const SizedBox(height: 28),
          _buildWheelSection(info),
          const SizedBox(height: 20),
          _buildStatusBar(info),
          const SizedBox(height: 10),
          _buildHintLine(info),
          const SizedBox(height: 16),
          if (_lastResult != null) _buildLastResult(_lastResult!),
        ],
      ),
    );
  }

  Widget _buildHeader(LotteryInfoModel info) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.25), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFFFFD54F), Color(0xFFFF8F00)],
              ),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.auto_awesome,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(info.pool.name,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.3)),
                const SizedBox(height: 2),
                Text(
                  '单次 ${CurrencyConfig.format(info.pool.costPerDraw)} · 每日最多 ${info.pool.dailyDrawLimit} 次',
                  style: const TextStyle(
                      fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWheelSection(LotteryInfoModel info) {
    final screenWidth = MediaQuery.of(context).size.width;
    final wheelSize = math.min(screenWidth - 32, 360.0);
    return Center(
      child: LotteryWheel(
        prizes: info.prizes,
        rotation: _wheelRotation,
        size: wheelSize,
        spinning: _drawing,
        centerChild: _buildCenterButton(info),
      ),
    );
  }

  Widget _buildCenterButton(LotteryInfoModel info) {
    final disabled =
        _drawing || info.todayRemaining <= 0 || !info.pool.isEnabled;
    return GestureDetector(
      onTap: disabled ? null : _draw,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 92,
        height: 92,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: disabled
                ? const [Color(0xFFEEEEEE), Color(0xFF9E9E9E)]
                : const [Color(0xFFFFF59D), Color(0xFFFFB300), Color(0xFFE65100)],
            stops: const [0.2, 0.7, 1.0],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
            if (!disabled)
              BoxShadow(
                color: const Color(0xFFFFD54F).withValues(alpha: 0.6),
                blurRadius: 18,
                spreadRadius: 1,
              ),
          ],
          border: Border.all(color: Colors.white, width: 4),
        ),
        alignment: Alignment.center,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              _drawing ? '抽奖中' : 'GO',
              style: TextStyle(
                fontSize: _drawing ? 15 : 26,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: _drawing ? 1 : 3,
                shadows: const [
                  Shadow(
                      color: Colors.black54,
                      blurRadius: 4,
                      offset: Offset(0, 2)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBar(LotteryInfoModel info) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _statusChip(
          icon: Icons.monetization_on,
          label: '单次',
          value:
              '${CurrencyConfig.format(info.pool.costPerDraw)} ${CurrencyConfig.coinUnit}',
        ),
        const SizedBox(width: 10),
        _statusChip(
          icon: Icons.confirmation_number,
          label: '剩余',
          value: '${info.todayRemaining} / ${info.pool.dailyDrawLimit}',
          highlight: info.todayRemaining > 0,
        ),
      ],
    );
  }

  Widget _statusChip({
    required IconData icon,
    required String label,
    required String value,
    bool highlight = true,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: (highlight
                  ? const Color(0xFFFFD54F)
                  : Colors.white)
              .withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 16,
              color: highlight
                  ? const Color(0xFFFFD54F)
                  : Colors.white70),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(fontSize: 12, color: Colors.white70)),
          const SizedBox(width: 4),
          Text(value,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.white,
                fontWeight: FontWeight.w700,
              )),
        ],
      ),
    );
  }

  Widget _buildHintLine(LotteryInfoModel info) {
    final String text;
    if (!info.pool.isEnabled) {
      text = '当前奖池已关闭';
    } else if (info.todayRemaining <= 0) {
      text = '今日次数已用完，明天再来';
    } else if (_drawing) {
      text = '转盘转动中…';
    } else {
      text = '点击中间金色 GO 按钮开始抽奖';
    }
    return Text(
      text,
      style: const TextStyle(fontSize: 12, color: Colors.white60),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildLastResult(LotteryResultModel r) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.25), width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.history, size: 18, color: Colors.white70),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '最近：${r.prizeName}${r.isWin ? "  +${CurrencyConfig.format(r.rewardAmount)}" : ""}',
              style: const TextStyle(
                  fontSize: 13, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

/// 转盘旋转曲线：梯形速度分布（加速 → 匀速 → 减速）
///
/// 位移 p(t) 为速度 v(t) 的积分：
/// - t ∈ [0, 0.25]  线性加速：v = vmax * t / 0.25
/// - t ∈ [0.25, 0.65]  匀速：v = vmax
/// - t ∈ [0.65, 1.0]  线性减速：v = vmax * (1 - t) / 0.35
///
/// 将三段梯形面积归一化到 1 得 vmax = 1/0.7 ≈ 1.4286。
class _SpinCurve extends Curve {
  const _SpinCurve();

  static const double _accEnd = 0.25;
  static const double _decStart = 0.65;
  static const double _vmax = 1.0 / 0.7;

  @override
  double transformInternal(double t) {
    if (t <= _accEnd) {
      // 抛物线加速：∫(vmax * s / accEnd) ds = vmax * t² / (2 * accEnd)
      return _vmax * t * t / (2 * _accEnd);
    }
    // 到 accEnd 时累计位移
    const p1 = _vmax * _accEnd / 2;
    if (t <= _decStart) {
      // 匀速段线性叠加
      return p1 + _vmax * (t - _accEnd);
    }
    // 到 decStart 时累计位移
    const p2 = p1 + _vmax * (_decStart - _accEnd);
    final dt = t - _decStart;
    const remain = 1.0 - _decStart;
    // 抛物线减速：∫vmax * (1 - s/remain) ds = vmax * (dt - dt² / (2*remain))
    return p2 + _vmax * (dt - dt * dt / (2 * remain));
  }
}

/// 缎带 banner 形状：两端各有一个 V 形缺口
class _RibbonClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    const notchW = 12.0;
    const notchH = 10.0;
    return Path()
      ..moveTo(0, 0)
      ..lineTo(w, 0)
      ..lineTo(w - notchW, h / 2)
      ..lineTo(w, h)
      ..lineTo(w - notchW - 2, h)
      ..lineTo(w / 2, h - notchH)
      ..lineTo(notchW + 2, h)
      ..lineTo(0, h)
      ..lineTo(notchW, h / 2)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> old) => false;
}
