import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vibration/vibration.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../services/call_signaling_service.dart';
import '../../widgets/avatar_widget.dart';
import 'in_call_page.dart';

/// 私聊来电全屏页
///
/// 显示主叫昵称/头像，提供接听/拒绝两个按钮。
/// 接听后被替换为 [InCallPage]；拒绝/对方取消后自动 pop。
class IncomingCallPage extends StatefulWidget {
  const IncomingCallPage({super.key});

  @override
  State<IncomingCallPage> createState() => _IncomingCallPageState();
}

class _IncomingCallPageState extends State<IncomingCallPage> {
  @override
  void initState() {
    super.initState();
    _startVibrate();
  }

  @override
  void dispose() {
    Vibration.cancel();
    super.dispose();
  }

  Future<void> _startVibrate() async {
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(pattern: [500, 1000, 500, 1000], repeat: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Vibration.cancel();
        context.read<CallSignalingService>().decline();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF1A1A2E),
        body: SafeArea(
          child: Consumer<CallSignalingService>(
            builder: (_, call, __) {
            // 来电结束（对方取消/超时）自动关闭
            if (call.state == CallState.idle) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && Navigator.canPop(context)) Navigator.pop(context);
              });
            }
            // 接听后切到 InCallPage
            if (call.state == CallState.connecting || call.state == CallState.connected) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const InCallPage()),
                );
              });
            }
            return Column(
              children: [
                const SizedBox(height: 80),
                AvatarWidget(
                  avatarPath: call.peerAvatar,
                  name: call.peerNickname,
                  size: 96,
                ),
                const SizedBox(height: 24),
                Text(
                  call.peerNickname,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  l.get('voice_call_incoming'),
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 60),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _circleButton(
                        icon: Icons.call_end,
                        color: AppTheme.dangerColor,
                        label: l.get('voice_call_decline'),
                        onTap: () {
                          Vibration.cancel();
                          call.decline();
                        },
                      ),
                      _circleButton(
                        icon: Icons.call,
                        color: AppTheme.successColor,
                        label: l.get('voice_call_answer'),
                        onTap: () async {
                          Vibration.cancel();
                          await call.accept();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
      ),
    );
  }

  Widget _circleButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 32),
          ),
        ),
        const SizedBox(height: 10),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
      ],
    );
  }
}
