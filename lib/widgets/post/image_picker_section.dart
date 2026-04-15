import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';

/// 判断文件是否为视频
bool isVideoFile(String path) {
  final ext = path.split('.').last.toLowerCase();
  return ext == 'mp4' || ext == 'mov' || ext == 'avi' || ext == 'mkv' || ext == 'webm';
}

/// 本地选择的媒体项（图片或视频）
class MediaItem {
  final XFile file;
  final bool isVideo;

  const MediaItem({required this.file, required this.isVideo});
}

/// Reusable media picker section supporting images and videos,
/// both new local files and existing network URLs (for edit mode).
class ImagePickerSection extends StatelessWidget {
  final List<MediaItem> newMedia;
  final List<String> existingImageUrls;
  final int maxItems;
  final VoidCallback onPickImages;
  final VoidCallback onTakePhoto;
  final VoidCallback? onPickVideo;
  final ValueChanged<int> onRemoveNewImage;
  final ValueChanged<int>? onRemoveExistingImage;

  const ImagePickerSection({
    super.key,
    required this.newMedia,
    this.existingImageUrls = const [],
    this.maxItems = 9,
    required this.onPickImages,
    required this.onTakePhoto,
    this.onPickVideo,
    required this.onRemoveNewImage,
    this.onRemoveExistingImage,
  });

  int get _totalCount => existingImageUrls.length + newMedia.length;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        // Existing server images/videos
        ...existingImageUrls.asMap().entries.map((entry) {
          final url = entry.value;
          final isVideo = isVideoFile(url);
          return Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: isVideo
                    ? Container(
                        width: 80, height: 80,
                        color: Colors.black87,
                        child: const Center(
                          child: Icon(Icons.play_circle_outline, color: Colors.white, size: 36),
                        ),
                      )
                    : Image.network(
                        url,
                        width: 80, height: 80, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 80, height: 80,
                          color: Colors.grey[200],
                          child: const Icon(Icons.broken_image, size: 24),
                        ),
                      ),
              ),
              Positioned(
                top: 0, right: 0,
                child: GestureDetector(
                  onTap: () => onRemoveExistingImage?.call(entry.key),
                  child: Container(
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    child: const Icon(Icons.close, size: 16, color: Colors.white),
                  ),
                ),
              ),
            ],
          );
        }),
        // New local media
        ...newMedia.asMap().entries.map((entry) {
          final item = entry.value;
          return Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: item.isVideo
                    ? Container(
                        width: 80, height: 80,
                        color: Colors.black87,
                        child: const Center(
                          child: Icon(Icons.play_circle_outline, color: Colors.white, size: 36),
                        ),
                      )
                    : _buildImagePreview(item.file),
              ),
              if (item.isVideo)
                Positioned(
                  bottom: 4, left: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'VIDEO',
                      style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              Positioned(
                top: 0, right: 0,
                child: GestureDetector(
                  onTap: () => onRemoveNewImage(entry.key),
                  child: Container(
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    child: const Icon(Icons.close, size: 16, color: Colors.white),
                  ),
                ),
              ),
            ],
          );
        }),
        if (_totalCount < maxItems)
          GestureDetector(
            onTap: () => _showMediaSourceDialog(context),
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.add_photo_alternate, color: AppTheme.textHint),
            ),
          ),
      ],
    );
  }

  Widget _buildImagePreview(XFile xFile) {
    return FutureBuilder<Uint8List>(
      future: xFile.readAsBytes(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return Image.memory(snapshot.data!, width: 80, height: 80, fit: BoxFit.cover);
        }
        return const SizedBox(width: 80, height: 80, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
      },
    );
  }

  void _showMediaSourceDialog(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: Text(l.get('take_photo')),
              onTap: () {
                Navigator.pop(ctx);
                onTakePhoto();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(l.get('choose_from_album')),
              onTap: () {
                Navigator.pop(ctx);
                onPickImages();
              },
            ),
            if (onPickVideo != null)
              ListTile(
                leading: const Icon(Icons.videocam),
                title: Text(l.get('pick_video')),
                onTap: () {
                  Navigator.pop(ctx);
                  onPickVideo!();
                },
              ),
          ],
        ),
      ),
    );
  }
}
