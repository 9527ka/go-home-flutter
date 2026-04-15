import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/post.dart';
import '../../services/post_service.dart';
import '../../services/upload_service.dart';
import '../../widgets/post/image_picker_section.dart';
import '../../widgets/post/post_form_fields.dart';
import '../../widgets/post/visibility_selector.dart';
import 'location_picker_page.dart';

class PostEditPage extends StatefulWidget {
  final PostModel post;
  const PostEditPage({super.key, required this.post});

  @override
  State<PostEditPage> createState() => _PostEditPageState();
}

class _PostEditPageState extends State<PostEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _postService = PostService();
  final _uploadService = UploadService();
  final _imagePicker = ImagePicker();

  late int _category;
  final _nameCtrl = TextEditingController();
  final _appearanceCtrl = TextEditingController();
  final _lostCityCtrl = TextEditingController();

  late DateTime _lostAt;
  List<MediaItem> _newMedia = [];
  List<String> _existingImageUrls = [];
  bool _imagesChanged = false;
  bool _isSubmitting = false;
  bool _privacyAgreed = false;
  bool _isPublic = true;
  double? _lostLatitude;
  double? _lostLongitude;

  @override
  void initState() {
    super.initState();
    _prefillForm();
  }

  void _prefillForm() {
    final p = widget.post;
    _category = p.category;
    _nameCtrl.text = p.name;
    _appearanceCtrl.text = p.description.isNotEmpty
        ? '${p.appearance}\n${p.description}'
        : p.appearance;
    _lostCityCtrl.text = p.locationText;
    _lostAt = DateTime.tryParse(p.lostAt) ?? DateTime.now();
    _existingImageUrls = p.images.map((img) => img.imageUrl).toList();
    _isPublic = p.visibility != 2;
    _lostLatitude = p.lostLatitude;
    _lostLongitude = p.lostLongitude;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _appearanceCtrl.dispose();
    _lostCityCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    try {
      final images = await _imagePicker.pickMultiImage(
        maxWidth: 1920, maxHeight: 1920, imageQuality: 80,
      );
      if (images.isNotEmpty) {
        setState(() {
          final total = _existingImageUrls.length + _newMedia.length;
          final remaining = 9 - total;
          _newMedia.addAll(
            images.take(remaining).map((f) => MediaItem(file: f, isVideo: false)),
          );
          _imagesChanged = true;
        });
      }
    } catch (e) {
      if (mounted) _showError(AppLocalizations.of(context)!.get('cannot_open_album'));
    }
  }

  Future<void> _takePhoto() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920, maxHeight: 1920, imageQuality: 80,
      );
      final total = _existingImageUrls.length + _newMedia.length;
      if (image != null && total < 9) {
        setState(() {
          _newMedia.add(MediaItem(file: image, isVideo: false));
          _imagesChanged = true;
        });
      }
    } catch (e) {
      if (mounted) _showError(AppLocalizations.of(context)!.get('cannot_open_camera'));
    }
  }

  Future<void> _pickVideo() async {
    try {
      final video = await _imagePicker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 5),
      );
      final total = _existingImageUrls.length + _newMedia.length;
      if (video != null && total < 9) {
        setState(() {
          _newMedia.add(MediaItem(file: video, isVideo: true));
          _imagesChanged = true;
        });
      }
    } catch (e) {
      if (mounted) _showError(AppLocalizations.of(context)!.get('cannot_open_album'));
    }
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _lostAt,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_lostAt),
      );
      setState(() {
        _lostAt = DateTime(
          date.year, date.month, date.day,
          time?.hour ?? 0, time?.minute ?? 0,
        );
      });
    }
  }

  Future<void> _pickLocation() async {
    final result = await Navigator.push<LocationPickerResult>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerPage(
          initialLatitude: _lostLatitude,
          initialLongitude: _lostLongitude,
        ),
      ),
    );
    if (result != null) {
      setState(() {
        _lostLatitude = result.latitude;
        _lostLongitude = result.longitude;
        if (_lostCityCtrl.text.trim().isEmpty && result.address.isNotEmpty) {
          _lostCityCtrl.text = result.address;
        }
      });
    }
  }

  Future<void> _submit() async {
    final l = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;

    if (!_privacyAgreed) {
      _showError(l.get('privacy_consent_required'));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      List<String>? finalImages;
      if (_imagesChanged) {
        List<String> uploadedUrls = [];
        if (_newMedia.isNotEmpty) {
          final imageFiles = _newMedia.where((m) => !m.isVideo).map((m) => m.file).toList();
          final videoFiles = _newMedia.where((m) => m.isVideo).map((m) => m.file).toList();
          if (imageFiles.isNotEmpty) {
            uploadedUrls.addAll(await _uploadService.uploadXFiles(imageFiles));
          }
          for (final vf in videoFiles) {
            final url = await _uploadService.uploadVideo(vf);
            if (url != null) uploadedUrls.add(url);
          }
        }
        finalImages = [..._existingImageUrls, ...uploadedUrls];
      }

      final res = await _postService.update(
        id: widget.post.id,
        name: _nameCtrl.text.trim(),
        appearance: _appearanceCtrl.text.trim(),
        description: '',
        lostAt: _lostAt.toIso8601String(),
        lostCity: _lostCityCtrl.text.trim(),
        lostDistrict: '',
        lostAddress: '',
        lostLongitude: _lostLongitude,
        lostLatitude: _lostLatitude,
        images: finalImages,
        visibility: _isPublic ? 1 : 2,
      );

      if (!mounted) return;

      if (res['code'] == 0) {
        _showSuccess(l.get('edit_success'));
        Navigator.pop(context, true);
      } else {
        _showError(res['msg'] ?? l.get('edit_failed'));
      }
    } catch (e) {
      _showError(l.get('network_error'));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppTheme.dangerColor),
    );
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppTheme.successColor),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l.get('edit_notice'))),
      body: Column(
        children: [
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  // 驳回原因提示
                  if (widget.post.status == 4) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3CD),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFFE69C)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Color(0xFF856404), size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              l.get('review_rejected_hint'),
                              style: const TextStyle(color: Color(0xFF856404), fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 举报屏蔽提示
                  if (widget.post.status == 5) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDEDED),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFF5C6CB)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.flag_outlined, color: Color(0xFF721C24), size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  l.get('report_blocked_hint'),
                                  style: const TextStyle(color: Color(0xFF721C24), fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                          if (widget.post.auditRemark != null && widget.post.auditRemark!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              '${l.get("reason_prefix")}：${widget.post.auditRemark}',
                              style: const TextStyle(color: Color(0xFF721C24), fontSize: 13),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 类别（编辑时不允许修改）
                  Text(l.get('find_category'), style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      widget.post.categoryText,
                      style: const TextStyle(fontSize: 16, color: AppTheme.textSecondary),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ========== 可见性选项 ==========
                  VisibilitySelector(
                    isPublic: _isPublic,
                    onChanged: (v) => setState(() => _isPublic = v),
                  ),

                  const SizedBox(height: 20),

                  // ========== 表单字段 ==========
                  PostFormFields(
                    category: _category,
                    nameCtrl: _nameCtrl,
                    appearanceCtrl: _appearanceCtrl,
                    lostCityCtrl: _lostCityCtrl,
                    lostAt: _lostAt,
                    onSelectDate: _selectDate,
                    onPickLocation: _pickLocation,
                    selectedLatitude: _lostLatitude,
                    selectedLongitude: _lostLongitude,
                  ),

                  const SizedBox(height: 20),

                  // 图片
                  Text(l.get('photos_max'), style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ImagePickerSection(
                    newMedia: _newMedia,
                    existingImageUrls: _existingImageUrls,
                    onPickImages: _pickImages,
                    onTakePhoto: _takePhoto,
                    onPickVideo: _pickVideo,
                    onRemoveNewImage: (index) {
                      setState(() {
                        _newMedia.removeAt(index);
                        _imagesChanged = true;
                      });
                    },
                    onRemoveExistingImage: (index) {
                      setState(() {
                        _existingImageUrls.removeAt(index);
                        _imagesChanged = true;
                      });
                    },
                  ),

                  const SizedBox(height: 20),

                  // ========== 隐私声明同意 ==========
                  _buildPrivacyConsent(l),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // 底部悬浮提交区域
          Container(
            padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 24, height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(l.get('submit_edit'), style: const TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l.get('edit_resubmit_notice'),
                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyConsent(AppLocalizations l) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield_outlined, size: 16, color: AppTheme.primaryColor),
              const SizedBox(width: 6),
              Text(
                l.get('privacy_consent_title'),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l.get('privacy_consent_text'),
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: _privacyAgreed,
                  onChanged: (v) => setState(() => _privacyAgreed = v ?? false),
                  activeColor: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _privacyAgreed = !_privacyAgreed),
                  child: Text(
                    l.get('privacy_consent_checkbox'),
                    style: TextStyle(
                      fontSize: 13,
                      color: _privacyAgreed ? AppTheme.textPrimary : AppTheme.textSecondary,
                      fontWeight: _privacyAgreed ? FontWeight.w500 : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
