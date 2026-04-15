import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../services/group_service.dart';

/// 群二维码 + 邀请链接对话框
///
/// 调用方式：
///   showDialog(context: ctx, builder: (_) => GroupQrDialog(groupId: id, groupName: name));
class GroupQrDialog extends StatefulWidget {
  final int groupId;
  final String groupName;
  final String groupAvatar;

  const GroupQrDialog({
    super.key,
    required this.groupId,
    required this.groupName,
    this.groupAvatar = '',
  });

  @override
  State<GroupQrDialog> createState() => _GroupQrDialogState();
}

class _GroupQrDialogState extends State<GroupQrDialog> {
  final _service = GroupService();
  bool _loading = true;
  String? _inviteUrl;
  String? _expiresAt;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    setState(() => _loading = true);
    final res = await _service.createInviteToken(widget.groupId);
    if (!mounted) return;
    final data = res['data'] as Map<String, dynamic>?;
    final err  = (res['error'] as String?)?.trim() ?? '';
    setState(() {
      _loading = false;
      _inviteUrl = data?['invite_url'] as String?;
      _expiresAt = data?['expires_at'] as String?;
    });
    if (data == null) {
      Fluttertoast.showToast(
        msg: err.isNotEmpty ? err : AppLocalizations.of(context)!.get('network_error'),
      );
    }
  }

  Future<void> _copyLink() async {
    if (_inviteUrl == null) return;
    await Clipboard.setData(ClipboardData(text: _inviteUrl!));
    if (!mounted) return;
    Fluttertoast.showToast(msg: AppLocalizations.of(context)!.get('link_copied'));
  }

  Future<void> _shareLink() async {
    if (_inviteUrl == null) return;
    final l = AppLocalizations.of(context)!;
    await Share.share(
      '${l.get('group_invite_share_text').replaceAll('{name}', widget.groupName)}\n${_inviteUrl!}',
    );
  }

  String _formatExpire(String? raw) {
    if (raw == null) return '';
    try {
      final dt = DateTime.parse(raw).toLocal();
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l.get('group_qr_title'),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              widget.groupName,
              style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 20),
            if (_loading)
              const SizedBox(
                height: 220,
                child: Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)),
              )
            else if (_inviteUrl == null)
              SizedBox(
                height: 220,
                child: Center(child: Text(l.get('network_error'), style: const TextStyle(color: AppTheme.textHint))),
              )
            else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: AppTheme.dividerColor),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: QrImageView(
                  data: _inviteUrl!,
                  size: 200,
                  backgroundColor: Colors.white,
                  errorCorrectionLevel: QrErrorCorrectLevel.M,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                l.get('group_qr_expires_at').replaceAll('{date}', _formatExpire(_expiresAt)),
                style: const TextStyle(fontSize: 12, color: AppTheme.textHint),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _copyLink,
                      icon: const Icon(Icons.copy, size: 16),
                      label: Text(l.get('copy_link')),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryColor,
                        side: const BorderSide(color: AppTheme.primaryColor),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _shareLink,
                      icon: const Icon(Icons.share, size: 16),
                      label: Text(l.get('share')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l.get('close')),
            ),
          ],
        ),
      ),
    );
  }
}
