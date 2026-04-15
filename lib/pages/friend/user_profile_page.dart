import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import '../../config/routes.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/friend_provider.dart';
import '../../widgets/avatar_widget.dart';

/// User profile bottom sheet displayed when tapping a user's avatar in chat.
class UserProfilePage extends StatefulWidget {
  final int userId;
  final String nickname;
  final String avatar;
  final String userCode;
  final bool isOfficial;

  const UserProfilePage({
    super.key,
    required this.userId,
    required this.nickname,
    required this.avatar,
    this.userCode = '',
    this.isOfficial = false,
  });

  /// Show the user profile bottom sheet.
  static void show(
    BuildContext context, {
    required int userId,
    required String nickname,
    required String avatar,
    String userCode = '',
    bool isOfficial = false,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: AppTheme.cardBg,
      builder: (_) => UserProfilePage(
        userId: userId,
        nickname: nickname,
        avatar: avatar,
        userCode: userCode,
        isOfficial: isOfficial,
      ),
    );
  }

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  bool _isSendingRequest = false;
  bool _showGreetingForm = false;
  late final TextEditingController _greetingCtrl;

  @override
  void initState() {
    super.initState();
    _greetingCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _greetingCtrl.dispose();
    super.dispose();
  }

  void _showGreetingInput() {
    final l = AppLocalizations.of(context)!;
    _greetingCtrl.text = l.get('default_greeting');
    setState(() => _showGreetingForm = true);
  }

  Future<void> _confirmSendRequest() async {
    final message = _greetingCtrl.text.trim();
    setState(() => _isSendingRequest = true);
    final error = await context.read<FriendProvider>().sendRequest(
          toId: widget.userId,
          message: message,
        );
    if (!mounted) return;
    setState(() {
      _isSendingRequest = false;
      _showGreetingForm = false;
    });
    final l = AppLocalizations.of(context)!;
    Fluttertoast.showToast(msg: error ?? l.get('request_sent'));
  }

  void _handleSendMessage() {
    // 关闭底部弹窗，然后跳转到私聊页面
    Navigator.pop(context);
    Navigator.pushNamed(context, AppRoutes.privateChat, arguments: {
      'friendId': widget.userId,
      'friendName': widget.nickname,
      'friendAvatar': widget.avatar,
      'friendUserCode': widget.userCode,
      'friendIsOfficial': widget.isOfficial,
    });
  }

  void _handleReport() {
    final l = AppLocalizations.of(context)!;
    Fluttertoast.showToast(msg: l.get('coming_soon'));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    // 底部弹窗使用 read 而非 watch，避免 InheritedWidget _dependents 断言错误
    final friendProvider = context.read<FriendProvider>();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
            const SizedBox(height: 20),

            // Title
            Text(
              l.get('user_profile'),
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 24),

            // Avatar
            AvatarWidget(avatarPath: widget.avatar, name: widget.nickname, size: 72, isOfficial: widget.isOfficial),
            const SizedBox(height: 16),

            // Nickname
            Text(
              widget.nickname,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),

            // User ID
            Text(
              'ID: ${widget.userCode.isNotEmpty ? widget.userCode : 'GH${widget.userId}'}',
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textHint,
              ),
            ),
            const SizedBox(height: 20),

            // 打招呼表单（内联显示，避免 showDialog 导致 InheritedWidget 断言错误）
            if (_showGreetingForm && !friendProvider.isFriend(widget.userId)) ...[
              TextField(
                controller: _greetingCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: l.get('greeting_label'),
                  hintText: l.get('request_message_hint'),
                  hintStyle: const TextStyle(fontSize: 14, color: AppTheme.textHint),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                maxLines: 2,
                maxLength: 50,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      label: l.get('cancel'),
                      icon: Icons.close_rounded,
                      color: AppTheme.textHint,
                      isLoading: false,
                      onPressed: () => setState(() => _showGreetingForm = false),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildActionButton(
                      label: l.get('send_request'),
                      icon: Icons.send_rounded,
                      color: AppTheme.primaryColor,
                      isLoading: _isSendingRequest,
                      onPressed: _isSendingRequest ? null : _confirmSendRequest,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ] else ...[
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: friendProvider.isFriend(widget.userId)
                        ? _buildActionButton(
                            label: l.get('send_message'),
                            icon: Icons.chat_bubble_outline_rounded,
                            color: AppTheme.primaryColor,
                            isLoading: false,
                            onPressed: _handleSendMessage,
                          )
                        : _buildActionButton(
                            label: l.get('add_friend'),
                            icon: Icons.person_add_outlined,
                            color: AppTheme.primaryColor,
                            isLoading: _isSendingRequest,
                            onPressed: _showGreetingInput,
                          ),
                  ),
                  const SizedBox(width: 10),

                  // Report
                  Expanded(
                    child: _buildActionButton(
                      label: l.get('report'),
                      icon: Icons.flag_outlined,
                      color: AppTheme.warningColor,
                      isLoading: false,
                      onPressed: _handleReport,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required bool isLoading,
    VoidCallback? onPressed,
  }) {
    return SizedBox(
      height: 44,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          minimumSize: Size.zero,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 16),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

}
