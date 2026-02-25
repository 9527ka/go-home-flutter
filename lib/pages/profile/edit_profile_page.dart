import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import '../../services/upload_service.dart';

/// 系统预设头像配置
class _SystemAvatar {
  final String path;
  final Color color;
  final IconData icon;

  const _SystemAvatar({required this.path, required this.color, required this.icon});
}

const _systemAvatars = <_SystemAvatar>[
  _SystemAvatar(path: '/system/avatars/avatar_1.svg', color: Color(0xFF4A90D9), icon: Icons.person),
  _SystemAvatar(path: '/system/avatars/avatar_2.svg', color: Color(0xFF5BA0E8), icon: Icons.person_outline),
  _SystemAvatar(path: '/system/avatars/avatar_3.svg', color: Color(0xFF34A853), icon: Icons.face),
  _SystemAvatar(path: '/system/avatars/avatar_4.svg', color: Color(0xFF8B5CF6), icon: Icons.sentiment_satisfied_alt),
  _SystemAvatar(path: '/system/avatars/avatar_5.svg', color: Color(0xFFF97316), icon: Icons.emoji_people),
  _SystemAvatar(path: '/system/avatars/avatar_6.svg', color: Color(0xFFEC4899), icon: Icons.face_3),
  _SystemAvatar(path: '/system/avatars/avatar_7.svg', color: Color(0xFFF43F5E), icon: Icons.face_4),
  _SystemAvatar(path: '/system/avatars/avatar_8.svg', color: Color(0xFFA855F7), icon: Icons.face_2),
  _SystemAvatar(path: '/system/avatars/avatar_9.svg', color: Color(0xFF06B6D4), icon: Icons.face_5),
  _SystemAvatar(path: '/system/avatars/avatar_10.svg', color: Color(0xFFEAB308), icon: Icons.face_6),
];

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _nicknameCtrl = TextEditingController();
  final _uploadService = UploadService();
  final _authService = AuthService();
  final _picker = ImagePicker();

  String? _avatarUrl;
  bool _isSaving = false;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    if (user != null) {
      _nicknameCtrl.text = user.nickname;
      _avatarUrl = user.avatar.isNotEmpty ? user.avatar : null;
    }
  }

  @override
  void dispose() {
    _nicknameCtrl.dispose();
    super.dispose();
  }

  /// 选择头像（三种方式）
  Future<void> _pickAvatar() async {
    final l = AppLocalizations.of(context)!;

    final choice = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.emoji_emotions_outlined, color: AppTheme.warningColor),
              title: Text(l.get('system_avatar')),
              onTap: () => Navigator.pop(ctx, 'system'),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: AppTheme.primaryColor),
              title: Text(l.get('take_photo')),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppTheme.primaryColor),
              title: Text(l.get('choose_from_album')),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (choice == null) return;

    if (choice == 'system') {
      _showSystemAvatarPicker();
      return;
    }

    final source = choice == 'camera' ? ImageSource.camera : ImageSource.gallery;

    try {
      final xFile = await _picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
      if (xFile == null) return;

      setState(() => _isUploading = true);

      final url = await _uploadService.uploadXFile(xFile);
      if (url != null && mounted) {
        setState(() {
          _avatarUrl = url;
          _isUploading = false;
        });
      } else {
        if (mounted) {
          setState(() => _isUploading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l.get('upload_failed')),
              backgroundColor: AppTheme.dangerColor,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  /// 显示系统头像选择弹窗
  void _showSystemAvatarPicker() {
    final l = AppLocalizations.of(context)!;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 拖拽条
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l.get('select_system_avatar'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 20),
              // 头像网格 - 5列2行
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                ),
                itemCount: _systemAvatars.length,
                itemBuilder: (_, index) {
                  final avatar = _systemAvatars[index];
                  final isSelected = _avatarUrl == avatar.path;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _avatarUrl = avatar.path;
                      });
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: avatar.color.withOpacity(0.15),
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: avatar.color, width: 3)
                            : null,
                        boxShadow: isSelected
                            ? [BoxShadow(color: avatar.color.withOpacity(0.3), blurRadius: 8)]
                            : null,
                      ),
                      child: Center(
                        child: Icon(
                          avatar.icon,
                          size: 28,
                          color: avatar.color,
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  /// 判断是否为系统头像路径
  bool get _isSystemAvatar =>
      _avatarUrl != null && _avatarUrl!.startsWith('/system/avatars/');

  /// 获取系统头像配置
  _SystemAvatar? get _currentSystemAvatar {
    if (!_isSystemAvatar) return null;
    try {
      return _systemAvatars.firstWhere((a) => a.path == _avatarUrl);
    } catch (_) {
      return null;
    }
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context)!;
    final nickname = _nicknameCtrl.text.trim();

    if (nickname.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.get('nickname_empty')),
          backgroundColor: AppTheme.dangerColor,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final res = await _authService.updateProfile(
        nickname: nickname,
        avatar: _avatarUrl,
      );

      if (!mounted) return;

      if (res['code'] == 0) {
        // 更新本地状态
        await context.read<AuthProvider>().refreshProfile();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l.get('save_success')),
              backgroundColor: AppTheme.successColor,
            ),
          );
          Navigator.pop(context);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['msg'] ?? l.get('save_failed')),
            backgroundColor: AppTheme.dangerColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l.get('network_error')),
            backgroundColor: AppTheme.dangerColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: Text(l.get('edit_profile')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 16),

            // ===== 头像 =====
            GestureDetector(
              onTap: _isUploading ? null : _pickAvatar,
              child: Stack(
                children: [
                  _buildAvatarPreview(user),
                  // 上传中
                  if (_isUploading)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: const Center(
                          child: SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  // 编辑图标
                  if (!_isUploading)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 8),
            Text(
              l.get('change_avatar'),
              style: const TextStyle(fontSize: 13, color: AppTheme.textHint),
            ),

            const SizedBox(height: 36),

            // ===== 昵称 =====
            Container(
              decoration: BoxDecoration(
                color: AppTheme.cardBg,
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppTheme.cardShadow,
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.get('nickname_label'),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nicknameCtrl,
                    maxLength: 20,
                    decoration: InputDecoration(
                      hintText: l.get('nickname_hint'),
                      counterText: '',
                      prefixIcon: const Icon(Icons.person_outline, size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppTheme.dividerColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppTheme.dividerColor),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 36),

            // ===== 保存按钮 =====
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSaving || _isUploading ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        l.get('save'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 头像预览：系统头像用图标显示，自定义头像用网络图片
  Widget _buildAvatarPreview(dynamic user) {
    final sysAvatar = _currentSystemAvatar;

    if (sysAvatar != null) {
      // 系统头像：显示彩色图标
      return Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          color: sysAvatar.color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: sysAvatar.color.withOpacity(0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Icon(
            sysAvatar.icon,
            size: 48,
            color: sysAvatar.color,
          ),
        ),
      );
    }

    // 自定义头像或默认
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        color: AppTheme.primaryLight,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        image: _avatarUrl != null && _avatarUrl!.isNotEmpty
            ? DecorationImage(
                image: NetworkImage(_avatarUrl!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: _avatarUrl == null || _avatarUrl!.isEmpty
          ? Center(
              child: Text(
                user?.nickname.isNotEmpty == true
                    ? user!.nickname.substring(0, 1).toUpperCase()
                    : '?',
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryColor,
                ),
              ),
            )
          : null,
    );
  }
}
