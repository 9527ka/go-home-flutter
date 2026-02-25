import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/theme.dart';
import '../../models/post.dart';
import '../../services/post_service.dart';
import '../../services/upload_service.dart';
import '../../utils/validators.dart';

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
  late int _gender;
  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _speciesCtrl = TextEditingController();
  final _appearanceCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _lostCityCtrl = TextEditingController();
  final _lostDistrictCtrl = TextEditingController();
  final _lostAddressCtrl = TextEditingController();
  final _contactNameCtrl = TextEditingController();
  final _contactPhoneCtrl = TextEditingController();

  late DateTime _lostAt;
  List<XFile> _newImages = [];
  List<String> _existingImageUrls = []; // 已有的服务端图片URL
  bool _imagesChanged = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _prefillForm();
  }

  void _prefillForm() {
    final p = widget.post;
    _category = p.category;
    _gender = p.gender;
    _nameCtrl.text = p.name;
    _ageCtrl.text = p.age;
    _speciesCtrl.text = p.species;
    _appearanceCtrl.text = p.appearance;
    _descriptionCtrl.text = p.description;
    _lostCityCtrl.text = p.lostCity;
    _lostDistrictCtrl.text = p.lostDistrict;
    _lostAddressCtrl.text = p.lostAddress;
    _contactNameCtrl.text = p.contactName;
    _contactPhoneCtrl.text = p.contactPhone;
    _lostAt = DateTime.tryParse(p.lostAt) ?? DateTime.now();
    _existingImageUrls = p.images.map((img) => img.imageUrl).toList();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _speciesCtrl.dispose();
    _appearanceCtrl.dispose();
    _descriptionCtrl.dispose();
    _lostCityCtrl.dispose();
    _lostDistrictCtrl.dispose();
    _lostAddressCtrl.dispose();
    _contactNameCtrl.dispose();
    _contactPhoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final images = await _imagePicker.pickMultiImage(
      maxWidth: 1920, maxHeight: 1920, imageQuality: 80,
    );
    if (images.isNotEmpty) {
      setState(() {
        final total = _existingImageUrls.length + _newImages.length;
        final remaining = 9 - total;
        _newImages.addAll(images.take(remaining));
        _imagesChanged = true;
      });
    }
  }

  Future<void> _takePhoto() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1920, maxHeight: 1920, imageQuality: 80,
    );
    final total = _existingImageUrls.length + _newImages.length;
    if (image != null && total < 9) {
      setState(() {
        _newImages.add(image);
        _imagesChanged = true;
      });
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

    if (_category == 3) {
      final addrError = Validators.childAddress(_lostAddressCtrl.text);
      if (addrError != null) {
        _showError(addrError);
        return;
      }
    }

    setState(() => _isSubmitting = true);

    try {
      // 如果图片有变化，上传新图片并合并
      List<String>? finalImages;
      if (_imagesChanged) {
        List<String> uploadedUrls = [];
        if (_newImages.isNotEmpty) {
          uploadedUrls = await _uploadService.uploadXFiles(_newImages);
        }
        finalImages = [..._existingImageUrls, ...uploadedUrls];
      }

      final res = await _postService.update(
        id: widget.post.id,
        name: _nameCtrl.text.trim(),
        gender: _gender,
        age: _ageCtrl.text.trim(),
        species: _speciesCtrl.text.trim(),
        appearance: _appearanceCtrl.text.trim(),
        description: _descriptionCtrl.text.trim(),
        lostAt: _lostAt.toIso8601String(),
        lostCity: _lostCityCtrl.text.trim(),
        lostDistrict: _lostDistrictCtrl.text.trim(),
        lostAddress: _lostAddressCtrl.text.trim(),
        contactName: _contactNameCtrl.text.trim(),
        contactPhone: _contactPhoneCtrl.text.trim(),
        images: finalImages,
      );

      if (!mounted) return;

      if (res['code'] == 0) {
        _showSuccess('修改成功！已重新提交审核。');
        Navigator.pop(context, true);
      } else {
        _showError(res['msg'] ?? '修改失败');
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
      appBar: AppBar(title: const Text('编辑启事')),
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
                              '审核未通过，请修改后重新提交',
                              style: const TextStyle(color: Color(0xFF856404), fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 类别（编辑时不允许修改）
                  const Text('寻找类别', style: TextStyle(fontWeight: FontWeight.bold)),
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

                  const SizedBox(height: 20),

                  // 基本信息
                  const Text('基本信息', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),

                  TextFormField(
                    controller: _nameCtrl,
                    decoration: InputDecoration(
                      labelText: _category == 1 ? '宠物名字' : _category == 4 ? '物品名称' : '姓名/称呼',
                    ),
                    validator: (v) => Validators.required(v, '名字'),
                  ),

                  const SizedBox(height: 12),

                  if (_category != 4) ...[
                    Row(
                      children: [
                        const Text('性别：'),
                        Radio<int>(value: 0, groupValue: _gender, onChanged: (v) => setState(() => _gender = v!)),
                        const Text('未知'),
                        Radio<int>(value: 1, groupValue: _gender, onChanged: (v) => setState(() => _gender = v!)),
                        Text(_category == 1 ? '公' : '男'),
                        Radio<int>(value: 2, groupValue: _gender, onChanged: (v) => setState(() => _gender = v!)),
                        Text(_category == 1 ? '母' : '女'),
                      ],
                    ),
                  ],

                  if (_category != 4)
                    TextFormField(
                      controller: _ageCtrl,
                      decoration: const InputDecoration(labelText: '年龄'),
                    ),

                  if (_category == 1) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _speciesCtrl,
                      decoration: const InputDecoration(labelText: '品种'),
                    ),
                  ],

                  if (_category == 4) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _speciesCtrl,
                      decoration: const InputDecoration(labelText: '物品类型', hintText: '如：钱包、手机、钥匙等'),
                    ),
                  ],

                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _appearanceCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: _category == 4 ? '外观描述 *' : '体貌特征 *',
                      hintText: _category == 4 ? '请详细描述物品外观（至少10个字）' : '请详细描述体貌特征（至少10个字）',
                    ),
                    validator: (v) => Validators.minLength(v, 10, _category == 4 ? '外观描述' : '体貌特征'),
                  ),

                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descriptionCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: '补充说明',
                      hintText: _category == 4 ? '丢失经过等其他信息' : '走失经过等其他信息',
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 走失/丢失信息
                  Text(_category == 4 ? '丢失信息' : '走失信息', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),

                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(_category == 4 ? '丢失时间' : '走失时间'),
                    subtitle: Text(
                      '${_lostAt.year}-${_lostAt.month.toString().padLeft(2, '0')}-${_lostAt.day.toString().padLeft(2, '0')} '
                      '${_lostAt.hour.toString().padLeft(2, '0')}:${_lostAt.minute.toString().padLeft(2, '0')}',
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: _selectDate,
                  ),

                  TextFormField(
                    controller: _lostCityCtrl,
                    decoration: const InputDecoration(labelText: '城市 *'),
                    validator: (v) => Validators.required(v, '城市'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _lostAddressCtrl,
                    decoration: InputDecoration(
                      labelText: '详细地址',
                      hintText: _category == 3 ? '⚠️ 为保护儿童安全，请勿填写精确门牌号' : '街道、小区、标志性建筑等',
                    ),
                    validator: _category == 3 ? Validators.childAddress : null,
                  ),

                  const SizedBox(height: 20),

                  // 联系方式（同一行）
                  const Text('联系方式', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _contactNameCtrl,
                          decoration: const InputDecoration(labelText: '联系人'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          controller: _contactPhoneCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: '联系电话 *',
                            hintText: _category == 3 ? '建议使用固话或工作号码' : null,
                          ),
                          validator: Validators.contactPhone,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // 图片
                  const Text('照片 (最多9张)', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _buildImagePicker(),

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
                        : const Text('提交修改', style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '修改后将重新进入审核流程。',
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

  Widget _buildImagePicker() {
    final totalCount = _existingImageUrls.length + _newImages.length;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        // 已有的服务端图片
        ..._existingImageUrls.asMap().entries.map((entry) {
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
                  onTap: () {
                    setState(() {
                      _existingImageUrls.removeAt(entry.key);
                      _imagesChanged = true;
                    });
                  },
                  child: Container(
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    child: const Icon(Icons.close, size: 16, color: Colors.white),
                  ),
                ),
              ),
            ],
          );
        }),
        // 新选择的图片
        ..._newImages.asMap().entries.map((entry) {
          return Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _buildImagePreview(entry.value),
              ),
              Positioned(
                top: 0, right: 0,
                child: GestureDetector(
                  onTap: () => setState(() {
                    _newImages.removeAt(entry.key);
                    _imagesChanged = true;
                  }),
                  child: Container(
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    child: const Icon(Icons.close, size: 16, color: Colors.white),
                  ),
                ),
              ),
            ],
          );
        }),
        if (totalCount < 9)
          GestureDetector(
            onTap: _showImageSourceDialog,
            child: Container(
              width: 80, height: 80,
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

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('拍照'),
              onTap: () { Navigator.pop(ctx); _takePhoto(); },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('从相册选择'),
              onTap: () { Navigator.pop(ctx); _pickImages(); },
            ),
          ],
        ),
      ),
    );
  }
}
