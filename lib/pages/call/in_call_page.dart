import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../services/call_signaling_service.dart';
import '../../widgets/avatar_widget.dart';

/// 私聊通话中页（主叫响铃 / 双方通话中 / 连接中 都走这个页面）
class InCallPage extends StatefulWidget {
  const InCallPage({super.key});

  @override
  State<InCallPage> createState() => _InCallPageState();
}

class _InCallPageState extends State<InCallPage> {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final call = context.read<CallSignalingService>();
        call.hangup(); // outgoing→cancel, connected→hangup
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF1A1A2E),
        body: SafeArea(
          child: Consumer<CallSignalingService>(
            builder: (_, call, __) {
            // 通话结束：自动 pop
            if (call.state == CallState.idle) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && Navigator.canPop(context)) Navigator.pop(context);
              });
            }

            return Column(
              children: [
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
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
                          _statusLabel(l, call),
                          style: const TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        // 临时调试信息
                        Text(
                          call.debugInfo,
                          style: const TextStyle(color: Colors.white38, fontSize: 11),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                if (call.state == CallState.connected)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _toggleButton(
                          icon: call.micMuted ? Icons.mic_off : Icons.mic,
                          active: call.micMuted,
                          label: l.get('voice_call_mute'),
                          onTap: () => call.setMute(!call.micMuted),
                        ),
                        _toggleButton(
                          icon: call.speakerOn ? Icons.volume_up : Icons.volume_down,
                          active: call.speakerOn,
                          label: l.get('voice_call_speaker'),
                          onTap: () => call.setSpeaker(!call.speakerOn),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 40),
                Padding(
                  padding: const EdgeInsets.only(bottom: 60),
                  child: GestureDetector(
                    onTap: () => call.hangup(),
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: const BoxDecoration(
                        color: AppTheme.dangerColor,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.call_end, color: Colors.white, size: 32),
                    ),
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

  String _statusLabel(AppLocalizations l, CallSignalingService call) {
    switch (call.state) {
      case CallState.outgoing:
        return l.get('voice_call_calling');
      case CallState.incoming:
        return l.get('voice_call_ringing');
      case CallState.connecting:
        return l.get('voice_call_connecting');
      case CallState.connected:
        return _formatDuration(call.durationSec);
      case CallState.idle:
        return l.get('voice_call_ended');
    }
  }

  String _formatDuration(int sec) {
    final m = (sec ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Widget _toggleButton({
    required IconData icon,
    required bool active,
    required String label,
    required VoidCallback onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: active ? Colors.white24 : Colors.white10,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white30, width: 1),
            ),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}
