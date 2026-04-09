import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/post.dart';
import '../../widgets/avatar_widget.dart';

/// Card widget for displaying a single clue entry.
class ClueCard extends StatelessWidget {
  final ClueModel clue;
  final bool isMe;
  final bool isFriend;
  final bool isLoggedIn;
  final VoidCallback? onUserTap;
  final VoidCallback? onAddFriend;

  const ClueCard({
    super.key,
    required this.clue,
    required this.isMe,
    required this.isFriend,
    required this.isLoggedIn,
    this.onUserTap,
    this.onAddFriend,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final clueUser = clue.user;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.scaffoldBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: clueUser != null && !isMe ? onUserTap : null,
                child: AvatarWidget(avatarPath: clueUser?.avatar ?? '', name: clueUser?.nickname ?? '?', size: 32),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: clueUser != null && !isMe ? onUserTap : null,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(clueUser?.nickname ?? '匿名用户', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      Text(clue.createdAt.length > 16 ? clue.createdAt.substring(0, 16) : clue.createdAt,
                          style: const TextStyle(fontSize: 11, color: AppTheme.textHint)),
                    ],
                  ),
                ),
              ),
              if (clueUser != null && !isMe && !isFriend && isLoggedIn)
                _buildAddFriendButton(l),
            ],
          ),
          const SizedBox(height: 10),
          Text(clue.content, style: const TextStyle(fontSize: 14, height: 1.5)),
          if (clue.contactPhone != null && clue.contactPhone!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.phone_outlined, size: 14, color: AppTheme.textSecondary),
              const SizedBox(width: 4),
              Text(_maskPhone(clue.contactPhone!), style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
            ]),
          ],
          if (clue.images.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6, runSpacing: 6,
              children: clue.images.map((url) => ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(url, width: 60, height: 60, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(width: 60, height: 60, color: Colors.grey[200])),
              )).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAddFriendButton(AppLocalizations l) {
    return InkWell(
      onTap: onAddFriend,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.person_add_outlined, size: 14, color: AppTheme.primaryColor),
          const SizedBox(width: 3),
          Text(l.get('add_friend'), style: TextStyle(fontSize: 12, color: AppTheme.primaryColor, fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }

  String _maskPhone(String phone) {
    if (phone.length <= 6) return '****';
    return '${phone.substring(0, 3)}****${phone.substring(phone.length - 4)}';
  }
}
