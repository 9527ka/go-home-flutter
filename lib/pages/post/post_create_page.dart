import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/app_config_provider.dart';
import '../../services/post_service.dart';
import '../../services/upload_service.dart';
import '../../widgets/ai_banner.dart';
import '../../widgets/post/image_picker_section.dart';
import '../../widgets/post/post_form_fields.dart';
import '../../widgets/post/visibility_selector.dart';

class PostCreatePage extends StatefulWidget {
  const PostCreatePage({super.key});

  @override
  State<PostCreatePage> createState() => _PostCreatePageState();
}

class _PostCreatePageState extends State<PostCreatePage> {
  final _formKey = GlobalKey<FormState>();
  final _postService = PostService();
  final _uploadService = UploadService();
  final _imagePicker = ImagePicker();

  // 表单控制器
  int _category = 1; // 默认宠物，由 didChangeDependencies 根据服务端配置更新
  bool _categoryInitialized = false;
  final _nameCtrl = TextEditingController();
  final _speciesCtrl = TextEditingController();
  final _appearanceCtrl = TextEditingController();
  final _lostCityCtrl = TextEditingController();

  DateTime _lostAt = DateTime.now();
  List<XFile> _selectedImages = [];
  bool _isSubmitting = false;
  bool _privacyAgreed = false;
  bool _isPublic = true; // 可见性：true=公开, false=仅自己可见

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_categoryInitialized) {
      _categoryInitialized = true;
      final config = Provider.of<AppConfigProvider>(context, listen: false);
      if (config.visibleCategories.isNotEmpty) {
        _category = config.visibleCategories.first.id;
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _speciesCtrl.dispose();
    _appearanceCtrl.dispose();
    _lostCityCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    try {
      final images = await _imagePicker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 80,
      );

      if (images.isNotEmpty) {
        setState(() {
          final remaining = 9 - _selectedImages.length;
          _selectedImages.addAll(images.take(remaining));
        });
      }
    } catch (e) {
      if (mounted) _showError('无法打开相册');
    }
  }

  Future<void> _takePhoto() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 80,
      );

      if (image != null && _selectedImages.length < 9) {
        setState(() => _selectedImages.add(image));
      }
    } catch (e) {
      if (mounted) _showError('无法打开相机');
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_privacyAgreed) {
      _showError(AppLocalizations.of(context)!.get('privacy_consent_required'));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // 1. 上传图片
      List<String> imageUrls = [];
      if (_selectedImages.isNotEmpty) {
        imageUrls = await _uploadService.uploadXFiles(_selectedImages);
      }

      // 2. 提交启事
      final res = await _postService.create(
        category: _category,
        name: _nameCtrl.text.trim(),
        species: _speciesCtrl.text.trim(),
        appearance: _appearanceCtrl.text.trim(),
        description: '',
        lostAt: _lostAt.toIso8601String(),
        lostCity: _lostCityCtrl.text.trim(),
        images: imageUrls,
        visibility: _isPublic ? 1 : 2,
      );

      if (!mounted) return;

      if (res['code'] == 0) {
        _showSuccess(AppLocalizations.of(context)!.get('create_success'));
        Navigator.pop(context, true);
      } else {
        _showError(res['msg'] ?? '发布失败');
      }
    } catch (e) {
      _showError('网络异常，请重试');
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
    return Scaffold(
      appBar: AppBar(title: const Text('发布启事')),
      body: Column(
        children: [
          // 可滚动表单区域
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  // ========== 类别选择 ==========
                  const Text('寻找类别', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _buildCategorySelector(),

                  const SizedBox(height: 12),

                  AiBanner(
                    style: AiBannerStyle.compact,
                    title: '',
                    subtitle: AppLocalizations.of(context)!.get('ai_create_hint'),
                  ),
                  const SizedBox(height: 20),

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
                    speciesCtrl: _speciesCtrl,
                    appearanceCtrl: _appearanceCtrl,
                    lostCityCtrl: _lostCityCtrl,
                    lostAt: _lostAt,
                    onSelectDate: _selectDate,
                  ),

                  const SizedBox(height: 20),

                  // ========== 图片 ==========
                  const Text('上传照片 (最多9张)', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.auto_awesome, size: 12, color: const Color(0xFF7C3AED).withOpacity(0.7)),
                      const SizedBox(width: 4),
                      Text(
                        AppLocalizations.of(context)!.get('ai_photo_hint'),
                        style: TextStyle(fontSize: 11, color: const Color(0xFF7C3AED).withOpacity(0.7)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ImagePickerSection(
                    newImages: _selectedImages,
                    onPickImages: _pickImages,
                    onTakePhoto: _takePhoto,
                    onRemoveNewImage: (index) {
                      setState(() => _selectedImages.removeAt(index));
                    },
                  ),

                  const SizedBox(height: 20),

                  // ========== 隐私声明同意 ==========
                  _buildPrivacyConsent(),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // ========== 底部悬浮提交区域 ==========
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
                        : const Text('提交发布', style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '提交即表示您确认信息真实有效。发布虚假信息将被封禁。所有启事需经人工审核后展示。',
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyConsent() {
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
                AppLocalizations.of(context)!.get('privacy_consent_title'),
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
            AppLocalizations.of(context)!.get('privacy_consent_text'),
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
                    AppLocalizations.of(context)!.get('privacy_consent_checkbox'),
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

  Widget _buildCategorySelector() {
    final config = context.watch<AppConfigProvider>();
    final categories = config.visibleCategories;

    // fallback: 未加载时显示全部
    if (categories.isEmpty) {
      return Row(
        children: [
          _categoryButton(1, '宠物', Icons.pets, AppTheme.petColor),
          const SizedBox(width: 8),
          _categoryButton(4, '物品', Icons.inventory_2_outlined, AppTheme.otherColor),
        ],
      );
    }

    final widgets = <Widget>[];
    for (var i = 0; i < categories.length; i++) {
      if (i > 0) widgets.add(const SizedBox(width: 8));
      final cat = categories[i];
      widgets.add(_categoryButton(
        cat.id,
        cat.name,
        AppTheme.getCategoryIcon(cat.id),
        AppTheme.getCategoryColor(cat.id),
      ));
    }
    return Row(children: widgets);
  }

  Widget _categoryButton(int value, String label, IconData icon, Color color) {
    final selected = _category == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _category = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.1) : Colors.grey[100],
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? color : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: selected ? color : AppTheme.textHint, size: 22),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: selected ? color : AppTheme.textSecondary,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
