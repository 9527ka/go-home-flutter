import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/theme.dart';

/// Reusable image picker section supporting both new XFile images
/// and existing network image URLs (for edit mode).
class ImagePickerSection extends StatelessWidget {
  final List<XFile> newImages;
  final List<String> existingImageUrls;
  final int maxImages;
  final VoidCallback onPickImages;
  final VoidCallback onTakePhoto;
  final ValueChanged<int> onRemoveNewImage;
  final ValueChanged<int>? onRemoveExistingImage;

  const ImagePickerSection({
    super.key,
    required this.newImages,
    this.existingImageUrls = const [],
    this.maxImages = 9,
    required this.onPickImages,
    required this.onTakePhoto,
    required this.onRemoveNewImage,
    this.onRemoveExistingImage,
  });

  int get _totalCount => existingImageUrls.length + newImages.length;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        // Existing server images
        ...existingImageUrls.asMap().entries.map((entry) {
          return Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  entry.value,
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
        // New local images
        ...newImages.asMap().entries.map((entry) {
          return Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _buildImagePreview(entry.value),
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
        if (_totalCount < maxImages)
          GestureDetector(
            onTap: () => _showImageSourceDialog(context),
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

  void _showImageSourceDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('拍照'),
              onTap: () {
                Navigator.pop(ctx);
                onTakePhoto();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('从相册选择'),
              onTap: () {
                Navigator.pop(ctx);
                onPickImages();
              },
            ),
          ],
        ),
      ),
    );
  }
}
