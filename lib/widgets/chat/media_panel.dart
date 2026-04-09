import 'package:flutter/material.dart';
import '../../config/theme.dart';

/// Media action panel shown below the input bar (camera, album, video, red packet).
class MediaPanel extends StatelessWidget {
  final VoidCallback onPickImage;
  final VoidCallback onTakePhoto;
  final VoidCallback onPickVideo;
  final VoidCallback? onSendRedPacket;
  final String pickImageLabel;
  final String takePhotoLabel;
  final String pickVideoLabel;
  final String? redPacketLabel;

  const MediaPanel({
    super.key,
    required this.onPickImage,
    required this.onTakePhoto,
    required this.onPickVideo,
    this.onSendRedPacket,
    required this.pickImageLabel,
    required this.takePhotoLabel,
    required this.pickVideoLabel,
    this.redPacketLabel,
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
            _mediaItem(Icons.redeem, redPacketLabel!, onSendRedPacket!),
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
