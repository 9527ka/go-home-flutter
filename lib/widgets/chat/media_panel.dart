import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../config/theme.dart';

/// Media action panel shown below the input bar (camera, album, video, red packet).
class MediaPanel extends StatelessWidget {
  final VoidCallback onPickImage;
  final VoidCallback onTakePhoto;
  final VoidCallback onPickVideo;
  final VoidCallback? onSendRedPacket;
  final VoidCallback? onVoiceCall;
  final String pickImageLabel;
  final String takePhotoLabel;
  final String pickVideoLabel;
  final String? redPacketLabel;
  final String? voiceCallLabel;

  const MediaPanel({
    super.key,
    required this.onPickImage,
    required this.onTakePhoto,
    required this.onPickVideo,
    this.onSendRedPacket,
    this.onVoiceCall,
    required this.pickImageLabel,
    required this.takePhotoLabel,
    required this.pickVideoLabel,
    this.redPacketLabel,
    this.voiceCallLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        border: Border(
          top: BorderSide(color: AppTheme.dividerColor, width: 0.5),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _mediaItem(Icons.image_outlined, pickImageLabel, onPickImage),
          _mediaItem(Icons.camera_alt_outlined, takePhotoLabel, onTakePhoto),
          _mediaItem(Icons.videocam_outlined, pickVideoLabel, onPickVideo),
          if (onSendRedPacket != null && redPacketLabel != null)
            _mediaImageItem('assets/icon/red.svg', redPacketLabel!, onSendRedPacket!),
          if (onVoiceCall != null && voiceCallLabel != null)
            _mediaItem(Icons.call_outlined, voiceCallLabel!, onVoiceCall!),
        ],
      ),
    );
  }

  Widget _mediaImageItem(String assetPath, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppTheme.scaffoldBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: SvgPicture.asset(
                assetPath,
                width: 26,
                height: 26,
                colorFilter: const ColorFilter.mode(
                  Color(0xFFD4534B), // 红包主题红
                  BlendMode.srcIn,
                ),
                placeholderBuilder: (_) => Icon(Icons.redeem, color: AppTheme.textSecondary, size: 26),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppTheme.textHint),
          ),
        ],
      ),
    );
  }

  Widget _mediaItem(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppTheme.scaffoldBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppTheme.textSecondary, size: 26),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppTheme.textHint),
          ),
        ],
      ),
    );
  }
}
