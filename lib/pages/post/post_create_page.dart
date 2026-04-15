import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../config/currency.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/app_config_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../services/post_service.dart';
import '../../services/upload_service.dart';
import '../../utils/validators.dart';
import '../../widgets/coin_icon.dart';
import '../../widgets/post/image_picker_section.dart';
import 'location_picker_page.dart';

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
  int _category = 1;
  bool _categoryInitialized = false;
  final _nameCtrl = TextEditingController();
  final _appearanceCtrl = TextEditingController();
  final _lostCityCtrl = TextEditingController();

  final _rewardCtrl = TextEditingController();
  DateTime _lostAt = DateTime.now();
  List<MediaItem> _selectedMedia = [];
  bool _isSubmitting = false;
  bool _privacyAgreed = false;
  bool _isPublic = true;
  bool _enableReward = false;
  double? _lostLatitude;
  double? _lostLongitude;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_categoryInitialized) {
      _categoryInitialized = true;
      final config = Provider.of<AppConfigProvider>(context, listen: false);
      if (config.visibleCategories.isNotEmpty) {
        _category = config.visibleCategories.first.id;
      }
      if (config.walletEnabled) {
        Provider.of<WalletProvider>(context, listen: false).loadWalletInfo();
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _appearanceCtrl.dispose();
    _lostCityCtrl.dispose();
    _rewardCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    try {
      final images = await _imagePicker.pickMultiImage(
        maxWidth: 1920, maxHeight: 1920, imageQuality: 80,
      );
      if (images.isNotEmpty) {
        setState(() {
          final remaining = 9 - _selectedMedia.length;
          _selectedMedia.addAll(
            images.take(remaining).map((f) => MediaItem(file: f, isVideo: false)),
          );
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
      if (image != null && _selectedMedia.length < 9) {
        setState(() => _selectedMedia.add(MediaItem(file: image, isVideo: false)));
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
      if (video != null && _selectedMedia.length < 9) {
        setState(() => _selectedMedia.add(MediaItem(file: video, isVideo: true)));
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
      List<String> imageUrls = [];
      if (_selectedMedia.isNotEmpty) {
        final imageFiles = _selectedMedia.where((m) => !m.isVideo).map((m) => m.file).toList();
        final videoFiles = _selectedMedia.where((m) => m.isVideo).map((m) => m.file).toList();
        if (imageFiles.isNotEmpty) {
          imageUrls.addAll(await _uploadService.uploadXFiles(imageFiles));
        }
        for (final vf in videoFiles) {
          final url = await _uploadService.uploadVideo(vf);
          if (url != null) imageUrls.add(url);
        }
      }

      double? rewardAmount;
      if (_enableReward) {
        rewardAmount = double.tryParse(_rewardCtrl.text.trim());
      }

      final res = await _postService.create(
        category: _category,
        name: _nameCtrl.text.trim(),
        appearance: _appearanceCtrl.text.trim(),
        description: '',
        lostAt: _lostAt.toIso8601String(),
        lostCity: _lostCityCtrl.text.trim(),
        lostLongitude: _lostLongitude,
        lostLatitude: _lostLatitude,
        images: imageUrls,
        visibility: _isPublic ? 1 : 2,
        rewardAmount: rewardAmount,
      );

      if (!mounted) return;

      if (res['code'] == 0) {
        _showSuccess(l.get('create_success'));
        Navigator.pop(context, true);
      } else {
        _showError(res['msg'] ?? l.get('publish_failed'));
      }
    } catch (e) {
      _showError(AppLocalizations.of(context)!.get('network_error'));
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

  // ============================================================
  //  Build
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l.get('publish_notice'))),
      body: Column(
        children: [
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  // 1. 类别选择
                  _buildCategorySelector(),
                  const SizedBox(height: 16),

                  // 2. 基本信息
                  _buildSection(
                    icon: Icons.edit_note_rounded,
                    title: l.get('basic_info'),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _nameCtrl,
                          decoration: InputDecoration(labelText: l.get('title_label'), hintText: null),
                          validator: (v) => Validators.required(v, l.get('title_label')),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _appearanceCtrl,
                          maxLines: 4,
                          decoration: InputDecoration(
                            labelText: l.get('detail_desc_required'),
                            hintText: _category == 4
                                ? l.get('desc_hint_item')
                                : l.get('desc_hint_pet'),
                            alignLabelWithHint: true,
                          ),
                          validator: (v) => Validators.minLength(v, 10, l.get('detail_desc_required')),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 3. 走失/丢失信息
                  _buildSection(
                    icon: Icons.location_on_outlined,
                    title: _category == 4 ? l.get('lost_section_item') : l.get('lost_info'),
                    child: Column(
                      children: [
                        // 时间选择
                        InkWell(
                          onTap: _selectDate,
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today, size: 18, color: AppTheme.textSecondary),
                                const SizedBox(width: 10),
                                Text(
                                  _category == 4 ? l.get('lost_time_item') : l.get('lost_time'),
                                  style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                                ),
                                const Spacer(),
                                Text(
                                  '${_lostAt.year}-${_lostAt.month.toString().padLeft(2, '0')}-${_lostAt.day.toString().padLeft(2, '0')} '
                                  '${_lostAt.hour.toString().padLeft(2, '0')}:${_lostAt.minute.toString().padLeft(2, '0')}',
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.chevron_right, size: 18, color: AppTheme.textHint),
                              ],
                            ),
                          ),
                        ),
                        const Divider(height: 1),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _lostCityCtrl,
                          decoration: InputDecoration(
                            labelText: l.get('location_required'),
                            hintText: l.get('location_hint'),
                          ),
                          validator: (v) => Validators.required(v, l.get('location_required')),
                        ),
                        const SizedBox(height: 12),
                        _buildLocationButton(l),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 4. 上传照片/视频
                  _buildSection(
                    icon: Icons.photo_library_outlined,
                    title: l.get('upload_media'),
                    trailing: Text(
                      '${_selectedMedia.length}/9',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textHint),
                    ),
                    child: ImagePickerSection(
                      newMedia: _selectedMedia,
                      onPickImages: _pickImages,
                      onTakePhoto: _takePhoto,
                      onPickVideo: _pickVideo,
                      onRemoveNewImage: (index) {
                        setState(() => _selectedMedia.removeAt(index));
                      },
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 5. 更多设置（可见性 + 悬赏）
                  _buildSection(
                    icon: Icons.settings_outlined,
                    title: l.get('more_settings'),
                    child: Column(
                      children: [
                        // 公开展示
                        Row(
                          children: [
                            const Icon(Icons.visibility_outlined, size: 18, color: AppTheme.textSecondary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(l.get('public_display'), style: const TextStyle(fontSize: 14)),
                                  Text(
                                    _isPublic ? l.get('after_review_public') : l.get('only_self_visible'),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: _isPublic ? AppTheme.textHint : Colors.orange[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _isPublic,
                              onChanged: (v) => setState(() => _isPublic = v),
                              activeColor: AppTheme.primaryColor,
                            ),
                          ],
                        ),
                        // 悬赏设置
                        _buildRewardRow(l),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 6. 隐私同意
                  _buildPrivacyConsent(l),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // 底部提交按钮
          _buildSubmitBar(l),
        ],
      ),
    );
  }

  // ============================================================
  //  通用卡片容器
  // ============================================================

  Widget _buildSection({
    required IconData icon,
    required String title,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppTheme.primaryColor),
              const SizedBox(width: 6),
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              if (trailing != null) ...[const Spacer(), trailing],
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  // ============================================================
  //  类别选择
  // ============================================================

  Widget _buildCategorySelector() {
    final config = context.watch<AppConfigProvider>();
    final categories = config.visibleCategories;

    if (categories.isEmpty) {
      final l = AppLocalizations.of(context)!;
      return Row(
        children: [
          _categoryButton(1, l.get('category_pet'), Icons.pets, AppTheme.petColor),
          const SizedBox(width: 8),
          _categoryButton(4, l.get('category_other'), Icons.inventory_2_outlined, AppTheme.otherColor),
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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: selected ? color : AppTheme.textHint, size: 20),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
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

  // ============================================================
  //  精准定位按钮
  // ============================================================

  Widget _buildLocationButton(AppLocalizations l) {
    final hasLocation = _lostLatitude != null && _lostLongitude != null;
    return GestureDetector(
      onTap: _pickLocation,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: hasLocation
              ? AppTheme.successColor.withOpacity(0.08)
              : AppTheme.primaryColor.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: hasLocation
                ? AppTheme.successColor.withOpacity(0.3)
                : AppTheme.primaryColor.withOpacity(0.2),
          ),
        ),
        child: Row(
          children: [
            Icon(
              hasLocation ? Icons.check_circle : Icons.my_location,
              size: 20,
              color: hasLocation ? AppTheme.successColor : AppTheme.primaryColor,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                hasLocation ? l.get('location_selected') : l.get('add_location_map'),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: hasLocation ? AppTheme.successColor : AppTheme.primaryColor,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: hasLocation ? AppTheme.successColor : AppTheme.primaryColor,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  //  悬赏行
  // ============================================================

  Widget _buildRewardRow(AppLocalizations l) {
    final appConfig = context.watch<AppConfigProvider>();
    if (!appConfig.walletEnabled) return const SizedBox.shrink();

    return Column(
      children: [
        const Divider(height: 20),
        Row(
          children: [
            const Icon(Icons.monetization_on_outlined, size: 18, color: Color(0xFFFF8F00)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(l.get('reward_setting'), style: const TextStyle(fontSize: 14)),
            ),
            Switch(
              value: _enableReward,
              onChanged: (v) => setState(() => _enableReward = v),
              activeColor: const Color(0xFFFF8F00),
            ),
          ],
        ),
        if (_enableReward) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _rewardCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                  decoration: InputDecoration(
                    hintText: l.get('reward_amount_hint'),
                    prefixText: '${CurrencyConfig.coinSymbol} ',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Consumer<WalletProvider>(
                builder: (_, wp, __) => CoinAmount(
                  amount: wp.balance,
                  iconSize: 12,
                  textStyle: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            l.get('reward_freeze_notice'),
            style: const TextStyle(fontSize: 11, color: AppTheme.textHint),
          ),
        ],
      ],
    );
  }

  // ============================================================
  //  隐私同意（紧凑）
  // ============================================================

  Widget _buildPrivacyConsent(AppLocalizations l) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 22,
          height: 22,
          child: Checkbox(
            value: _privacyAgreed,
            onChanged: (v) => setState(() => _privacyAgreed = v ?? false),
            activeColor: AppTheme.primaryColor,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
                height: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  //  底部提交区域
  // ============================================================

  Widget _buildSubmitBar(AppLocalizations l) {
    return Container(
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
                  : Text(l.get('submit_publish'), style: const TextStyle(fontSize: 16)),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l.get('submit_publish_notice'),
            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
