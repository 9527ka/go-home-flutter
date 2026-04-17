import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import '../../services/upload_service.dart';
import '../../utils/url_helper.dart';
import '../../widgets/profile/avatar_source_picker.dart';
import '../../widgets/profile/system_avatar_picker.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _nicknameCtrl = TextEditingController();
  final _signatureCtrl = TextEditingController();
  final _uploadService = UploadService();
  final _authService = AuthService();
  final _picker = ImagePicker();

  String? _avatarUrl;
  String? _localAvatarPath;
  bool _isSaving = false;
  bool _isUploading = false;
  int _gender = 0; // 0=未设置 1=男 2=女

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    if (user != null) {
      _nicknameCtrl.text = user.nickname;
      _avatarUrl = user.avatar.isNotEmpty ? user.avatar : null;
      _gender = user.gender;
      _signatureCtrl.text = user.signature;
    }
  }

  @override
  void dispose() {
    _nicknameCtrl.dispose();
    _signatureCtrl.dispose();
    super.dispose();
  }

  /// Pick avatar from three sources.
  Future<void> _pickAvatar() async {
    final l = AppLocalizations.of(context)!;

    final choice = await AvatarSourcePicker.show(context);
    if (choice == null) return;

    if (choice == AvatarSource.system) {
      SystemAvatarPicker.show(
        context,
        currentAvatarUrl: _avatarUrl,
        onSelected: (path) {
          setState(() {
            _avatarUrl = path;
            _localAvatarPath = null;
          });
        },
      );
      return;
    }

    final source = choice == AvatarSource.camera ? ImageSource.camera : ImageSource.gallery;

    try {
      final xFile = await _picker.pickImage(source: source);
      if (xFile == null) return;

      final croppedFile = await ImageCropper().cropImage(
        sourcePath: xFile.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        maxWidth: 512,
        maxHeight: 512,
        compressQuality: 80,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: l.get('crop_avatar'),
            toolbarColor: AppTheme.primaryColor,
            toolbarWidgetColor: Colors.white,
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: l.get('crop_avatar'),
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
          ),
        ],
      );
      if (croppedFile == null) return;

      setState(() {
        _isUploading = true;
        _localAvatarPath = croppedFile.path;
      });

      final url = await _uploadService.uploadXFile(XFile(croppedFile.path));
      if (mounted) {
        setState(() {
          _avatarUrl = url;
          _isUploading = false;
        });
      }
    } catch (e) {
      debugPrint('[EditProfile] avatar upload error: $e');
      if (mounted) {
        setState(() {
          _isUploading = false;
          _localAvatarPath = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l.get('upload_failed')}: $e'),
            backgroundColor: AppTheme.dangerColor,
          ),
        );
      }
    }
  }

  /// Whether the current avatar is a system avatar.
  bool get _isSystemAvatar =>
      _avatarUrl != null && _avatarUrl!.startsWith('/system/avatars/');

  /// Get the current system avatar configuration.
  SystemAvatar? get _currentSystemAvatar {
    if (!_isSystemAvatar) return null;
    try {
      return systemAvatars.firstWhere((a) => a.path == _avatarUrl);
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
        gender: _gender,
        signature: _signatureCtrl.text.trim(),
      );

      if (!mounted) return;

      if (res['code'] == 0) {
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

            // ===== Avatar =====
            GestureDetector(
              onTap: _isUploading ? null : _pickAvatar,
              child: Stack(
                children: [
                  _buildAvatarPreview(user),
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

            // ===== Nickname =====
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

            const SizedBox(height: 16),

            // ===== Gender =====
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
                    l.get('gender'),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildGenderChip(0, l.get('gender_unknown'), Icons.help_outline),
                      const SizedBox(width: 8),
                      _buildGenderChip(1, l.get('gender_male'), Icons.male),
                      const SizedBox(width: 8),
                      _buildGenderChip(2, l.get('gender_female'), Icons.female),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ===== Signature =====
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
                    l.get('signature'),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _signatureCtrl,
                    maxLength: 100,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: l.get('signature_empty'),
                      counterText: '',
                      prefixIcon: const Icon(Icons.edit_note, size: 20),
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

            // ===== Save button =====
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

  /// Avatar preview: system avatar shows icon, custom avatar shows network image.
  Widget _buildAvatarPreview(dynamic user) {
    final sysAvatar = _currentSystemAvatar;

    if (sysAvatar != null) {
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

    ImageProvider? imageProvider;
    if (_localAvatarPath != null && _localAvatarPath!.isNotEmpty && !kIsWeb) {
      imageProvider = FileImage(File(_localAvatarPath!));
    } else if (_avatarUrl != null && _avatarUrl!.isNotEmpty) {
      final absUrl = UrlHelper.ensureAbsolute(_avatarUrl!);
      if (UrlHelper.isValidNetworkUrl(absUrl)) {
        imageProvider = NetworkImage(absUrl);
      }
    }

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
        image: imageProvider != null
            ? DecorationImage(
                image: imageProvider,
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: imageProvider == null
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

  Widget _buildGenderChip(int value, String label, IconData icon) {
    final selected = _gender == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _gender = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppTheme.primaryColor.withValues(alpha: 0.1) : AppTheme.scaffoldBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? AppTheme.primaryColor : AppTheme.dividerColor,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: selected ? AppTheme.primaryColor : AppTheme.textSecondary),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(
                fontSize: 14,
                color: selected ? AppTheme.primaryColor : AppTheme.textSecondary,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              )),
            ],
          ),
        ),
      ),
    );
  }
}
