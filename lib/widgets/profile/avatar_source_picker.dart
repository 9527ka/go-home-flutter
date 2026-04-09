import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';

/// Avatar source options.
enum AvatarSource { system, camera, gallery }

/// Bottom sheet for selecting the avatar source (system avatar, camera, or gallery).
class AvatarSourcePicker {
  /// Show the avatar source selection bottom sheet.
  ///
  /// Returns the selected [AvatarSource], or null if dismissed.
  static Future<AvatarSource?> show(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return showModalBottomSheet<AvatarSource>(
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
              onTap: () => Navigator.pop(ctx, AvatarSource.system),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: AppTheme.primaryColor),
              title: Text(l.get('take_photo')),
              onTap: () => Navigator.pop(ctx, AvatarSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppTheme.primaryColor),
              title: Text(l.get('choose_from_album')),
              onTap: () => Navigator.pop(ctx, AvatarSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
