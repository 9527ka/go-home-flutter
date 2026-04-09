import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/api.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../services/http_client.dart';
import '../../services/upload_service.dart';
import '../../utils/validators.dart';
import '../../widgets/ai_banner.dart';

class ClueSubmitPage extends StatefulWidget {
  final int postId;
  final String postName;

  const ClueSubmitPage({
    super.key,
    required this.postId,
    required this.postName,
  });

  @override
  State<ClueSubmitPage> createState() => _ClueSubmitPageState();
}

class _ClueSubmitPageState extends State<ClueSubmitPage> {
  final _formKey = GlobalKey<FormState>();
  final _contentCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _uploadService = UploadService();
  final _imagePicker = ImagePicker();

  List<XFile> _images = [];
  bool _isSubmitting = false;

  @override
  void dispose() {
    _contentCtrl.dispose();
    _contactCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      // 上传图片
      List<String> imageUrls = [];
      if (_images.isNotEmpty) {
        imageUrls = await _uploadService.uploadXFiles(_images);
      }

      // ⚠️ 修复：images 以数组形式发送（后端 Clue 模型 setImagesAttr 接收数组）
      final res = await HttpClient().post(ApiConfig.clueCreate, data: {
        'post_id': widget.postId,
        'content': _contentCtrl.text.trim(),
        'images': imageUrls,
        'contact': _contactCtrl.text.trim(),
      });

      if (!mounted) return;

      if (res['code'] == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.get('clue_submit_success')),
            backgroundColor: AppTheme.successColor,
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['msg'] ?? '提交失败'),
            backgroundColor: AppTheme.dangerColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('网络异常'), backgroundColor: AppTheme.dangerColor),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('提供线索')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 关联启事
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '为「${widget.postName}」提供线索',
                style: TextStyle(color: AppTheme.primaryColor),
              ),
            ),

            const SizedBox(height: 12),

            AiBanner(
              style: AiBannerStyle.compact,
              title: '',
              subtitle: AppLocalizations.of(context)!.get('ai_clue_hint'),
              icon: Icons.tips_and_updates,
            ),

            const SizedBox(height: 20),

            TextFormField(
              controller: _contentCtrl,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: '线索内容 *',
                hintText: '请描述您所看到/了解的情况（至少5个字）',
                alignLabelWithHint: true,
              ),
              validator: (v) => Validators.minLength(v, 5, '线索内容'),
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _contactCtrl,
              decoration: const InputDecoration(
                labelText: '您的联系方式（可选）',
                hintText: '方便发布者与您联系',
              ),
            ),

            const SizedBox(height: 16),

            // 图片
            const Text('附加照片（可选，最多3张）'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ..._images.asMap().entries.map((e) => Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: _buildImagePreview(e.value),
                        ),
                        Positioned(
                          top: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: () => setState(() => _images.removeAt(e.key)),
                            child: Container(
                              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                              child: const Icon(Icons.close, size: 16, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    )),
                if (_images.length < 3)
                  GestureDetector(
                    onTap: () async {
                      final img = await _imagePicker.pickImage(source: ImageSource.gallery);
                      if (img != null) setState(() => _images.add(img));
                    },
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
            ),

            const SizedBox(height: 32),

            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('提交线索'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
