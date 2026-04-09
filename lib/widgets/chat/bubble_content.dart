import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/theme.dart';
import '../../models/chat_message.dart';
import '../../utils/url_helper.dart';
import '../../widgets/red_packet_card.dart';

/// Builds the appropriate bubble content widget based on message type.
class BubbleContent extends StatelessWidget {
  final ChatMessageModel msg;
  final bool isMe;
  final VoidCallback? onImageTap;
  final VoidCallback? onVideoTap;
  final VoidCallback? onVoiceTap;
  final VoidCallback? onRedPacketTap;
  final bool isVoicePlaying;
  /// Optional mini-wave widget shown when voice is playing (only used by public chat)
  final Widget? voicePlayingWave;
  /// Whether the red packet has been claimed
  final bool hasClaimed;

  const BubbleContent({
    super.key,
    required this.msg,
    required this.isMe,
    this.onImageTap,
    this.onVideoTap,
    this.onVoiceTap,
    this.onRedPacketTap,
    this.isVoicePlaying = false,
    this.voicePlayingWave,
    this.hasClaimed = false,
  });

  @override
  Widget build(BuildContext context) {
    switch (msg.msgType) {
      case ChatMsgType.image:
        return _buildImageBubble();
      case ChatMsgType.video:
        return _buildVideoBubble();
      case ChatMsgType.voice:
        return _buildVoiceBubble();
      case ChatMsgType.redPacket:
        return _buildRedPacketBubble();
      case ChatMsgType.text:
      default:
        return _buildTextBubble();
    }
  }

  Widget _buildTextBubble() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isMe ? AppTheme.primaryColor : AppTheme.cardBg,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(isMe ? 14 : 4),
          topRight: Radius.circular(isMe ? 4 : 14),
          bottomLeft: const Radius.circular(14),
          bottomRight: const Radius.circular(14),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        msg.content,
        style: TextStyle(
          fontSize: 14,
          color: isMe ? Colors.white : AppTheme.textPrimary,
        ),
      ),
    );
  }

  Widget _buildImageBubble() {
    final url = UrlHelper.ensureAbsolute(
        msg.thumbUrl.isNotEmpty ? msg.thumbUrl : msg.mediaUrl);
    return GestureDetector(
      onTap: onImageTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 200, maxHeight: 200),
          child: CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(
              width: 120,
              height: 120,
              color: AppTheme.scaffoldBg,
              child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            errorWidget: (_, __, ___) => Container(
              width: 120,
              height: 120,
              color: AppTheme.scaffoldBg,
              child:
                  const Icon(Icons.broken_image, color: AppTheme.textHint),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoBubble() {
    final thumbUrl = UrlHelper.ensureAbsolute(
        msg.thumbUrl.isNotEmpty ? msg.thumbUrl : '');
    final duration = msg.mediaInfo?['duration'] ?? 0;
    return GestureDetector(
      onTap: onVideoTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (thumbUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl: thumbUrl,
                width: 180,
                height: 120,
                fit: BoxFit.cover,
              )
            else
              Container(width: 180, height: 120, color: Colors.black87),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(Icons.play_arrow,
                  color: Colors.white, size: 28),
            ),
            if (duration > 0)
              Positioned(
                right: 6,
                bottom: 6,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _formatDuration(duration),
                    style:
                        const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceBubble() {
    // Use voiceDuration from the model if available, otherwise from mediaInfo
    final duration = msg.voiceDuration > 0
        ? msg.voiceDuration
        : (msg.mediaInfo?['duration'] ?? 0);
    final width = math.min(50.0 + duration * 4.0, 200.0);

    return GestureDetector(
      onTap: onVoiceTap,
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? AppTheme.primaryColor : AppTheme.cardBg,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(isMe ? 14 : 4),
            topRight: Radius.circular(isMe ? 4 : 14),
            bottomLeft: const Radius.circular(14),
            bottomRight: const Radius.circular(14),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isVoicePlaying ? Icons.pause : Icons.play_arrow,
              size: 20,
              color: isMe ? Colors.white : AppTheme.primaryColor,
            ),
            const SizedBox(width: 4),
            if (isVoicePlaying && voicePlayingWave != null) ...[
              voicePlayingWave!,
              const SizedBox(width: 4),
            ],
            Text(
              '${duration}s',
              style: TextStyle(
                fontSize: 13,
                color: isMe ? Colors.white : AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRedPacketBubble() {
    int redPacketId = 0;
    String greeting = '';
    try {
      if (msg.content.startsWith('{')) {
        final data = jsonDecode(msg.content) as Map<String, dynamic>;
        redPacketId = data['red_packet_id'] ?? 0;
        greeting = data['greeting'] ?? '';
      }
    } catch (_) {}

    return RedPacketCard(
      redPacketId: redPacketId,
      senderName: msg.nickname,
      greeting: greeting,
      isMine: isMe,
      hasClaimed: hasClaimed,
      onTap: onRedPacketTap ?? () {},
    );
  }

  static String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(1, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

/// Voice uploading placeholder bubble shown at the end of the message list.
class UploadingVoiceBubble extends StatelessWidget {
  final int duration;

  const UploadingVoiceBubble({super.key, required this.duration});

  @override
  Widget build(BuildContext context) {
    final width = (80 + (duration * 3.0)).clamp(80.0, 200.0);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
            child: Container(
              width: width,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.6),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  topRight: Radius.circular(4),
                  bottomLeft: Radius.circular(14),
                  bottomRight: Radius.circular(14),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$duration"',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Placeholder avatar area (alignment with normal messages)
          const SizedBox(width: 36),
        ],
      ),
    );
  }
}
