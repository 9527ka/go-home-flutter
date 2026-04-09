import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';

/// System avatar configuration model.
class SystemAvatar {
  final String path;
  final Color color;
  final IconData icon;

  const SystemAvatar({required this.path, required this.color, required this.icon});
}

/// All available system preset avatars.
const systemAvatars = <SystemAvatar>[
  SystemAvatar(path: '/system/avatars/avatar_1.svg', color: Color(0xFF4A90D9), icon: Icons.person),
  SystemAvatar(path: '/system/avatars/avatar_2.svg', color: Color(0xFF5BA0E8), icon: Icons.person_outline),
  SystemAvatar(path: '/system/avatars/avatar_3.svg', color: Color(0xFF34A853), icon: Icons.face),
  SystemAvatar(path: '/system/avatars/avatar_4.svg', color: Color(0xFF8B5CF6), icon: Icons.sentiment_satisfied_alt),
  SystemAvatar(path: '/system/avatars/avatar_5.svg', color: Color(0xFFF97316), icon: Icons.emoji_people),
  SystemAvatar(path: '/system/avatars/avatar_6.svg', color: Color(0xFFEC4899), icon: Icons.face_3),
  SystemAvatar(path: '/system/avatars/avatar_7.svg', color: Color(0xFFF43F5E), icon: Icons.face_4),
  SystemAvatar(path: '/system/avatars/avatar_8.svg', color: Color(0xFFA855F7), icon: Icons.face_2),
  SystemAvatar(path: '/system/avatars/avatar_9.svg', color: Color(0xFF06B6D4), icon: Icons.face_5),
  SystemAvatar(path: '/system/avatars/avatar_10.svg', color: Color(0xFFEAB308), icon: Icons.face_6),
];

/// Bottom sheet dialog displaying a grid of system avatars for selection.
class SystemAvatarPicker {
  /// Show the system avatar picker bottom sheet.
  ///
  /// [currentAvatarUrl] highlights the currently selected avatar.
  /// [onSelected] is called with the selected avatar's path.
  static void show(
    BuildContext context, {
    String? currentAvatarUrl,
    required ValueChanged<String> onSelected,
  }) {
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
              // Drag handle
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
              // Avatar grid - 5 columns x 2 rows
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                ),
                itemCount: systemAvatars.length,
                itemBuilder: (_, index) {
                  final avatar = systemAvatars[index];
                  final isSelected = currentAvatarUrl == avatar.path;

                  return GestureDetector(
                    onTap: () {
                      onSelected(avatar.path);
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
}
