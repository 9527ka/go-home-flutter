import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../config/routes.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../pages/friend/user_profile_page.dart';
import '../../services/friend_service.dart';
import '../../services/group_service.dart';

/// 扫一扫页面 — 扫描好友/群聊二维码
class ScanQrPage extends StatefulWidget {
  const ScanQrPage({super.key});

  @override
  State<ScanQrPage> createState() => _ScanQrPageState();
}

class _ScanQrPageState extends State<ScanQrPage> {
  final MobileScannerController _controller = MobileScannerController();
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;
    _handled = true;
    _handleQrData(barcode.rawValue!);
  }

  Future<void> _handleQrData(String data) async {
    final l = AppLocalizations.of(context)!;

    // 解析 deep link: gohome://user/<userCode> → 搜索并展示用户资料
    final userMatch = RegExp(r'gohome://user/(\w+)').firstMatch(data);
    if (userMatch != null) {
      final userCode = userMatch.group(1)!;
      final users = await FriendService().searchUsers(userCode);
      if (!mounted) return;
      if (users.isNotEmpty) {
        final u = users.first;
        Navigator.pop(context);
        UserProfilePage.show(
          context,
          userId: u.id,
          nickname: u.nickname,
          avatar: u.avatar,
          userCode: u.userCode,
          isOfficial: u.isOfficialService,
        );
      } else {
        Fluttertoast.showToast(msg: l.get('scan_invalid_qr'));
        _handled = false;
      }
      return;
    }

    // 解析群邀请链接：包含 32 位 hex token
    final tokenMatch = RegExp(r'([a-fA-F0-9]{32})').firstMatch(data);
    if (tokenMatch != null) {
      final token = tokenMatch.group(1)!;
      final result = await GroupService().joinByToken(token);
      if (!mounted) return;
      if (result != null) {
        final groupId = result['group_id'] as int? ?? 0;
        if (groupId > 0) {
          Navigator.pop(context);
          Navigator.pushNamed(context, AppRoutes.groupChat, arguments: groupId);
          return;
        }
      }
      Fluttertoast.showToast(msg: l.get('scan_invalid_qr'));
      _handled = false;
      return;
    }

    // 无法识别
    Fluttertoast.showToast(msg: l.get('scan_invalid_qr'));
    _handled = false;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(l.get('scan_qr')),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          // 扫描框遮罩
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.primaryColor, width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          // 底部提示
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Text(
              l.get('scan_qr_tip'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
