import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/conversation_provider.dart';
import '../../services/chat_service.dart';
import '../../widgets/avatar_widget.dart';
import '../../widgets/chat/chat_picker_page.dart';
import 'scan_qr_page.dart';

/// 我的二维码页面 — 仿微信风格
class MyQrCodePage extends StatefulWidget {
  const MyQrCodePage({super.key});

  @override
  State<MyQrCodePage> createState() => _MyQrCodePageState();
}

class _MyQrCodePageState extends State<MyQrCodePage> {
  final _cardKey = GlobalKey();
  bool _sharing = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final user = context.watch<AuthProvider>().user;
    if (user == null) return const SizedBox.shrink();

    final qrData = 'gohome://user/${user.userCode}';
    final screenWidth = MediaQuery.of(context).size.width;
    final qrSize = screenWidth - 64 - 48;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F0F0),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF0F0F0),
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_sharing)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
            )
          else
            IconButton(
              icon: const Icon(Icons.more_horiz, size: 24),
              onPressed: () => _shareToChat(context, l, user),
            ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Column(
            children: [
              // 可截图的卡片区域
              RepaintBoundary(
                key: _cardKey,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 用户信息行
                      Row(
                        children: [
                          AvatarWidget(avatarPath: user.avatar, name: user.nickname, size: 56),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.nickname,
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'ID: ${user.displayId}',
                                  style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // 二维码 + 中心头像
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            QrImageView(
                              data: qrData,
                              size: qrSize,
                              backgroundColor: Colors.white,
                              errorCorrectionLevel: QrErrorCorrectLevel.H,
                            ),
                            Container(
                              width: qrSize * 0.22,
                              height: qrSize * 0.22,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.white, width: 3),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: AvatarWidget(
                                  avatarPath: user.avatar,
                                  name: user.nickname,
                                  size: qrSize * 0.22,
                                  borderRadius: 8,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l.get('my_qr_code_tip'),
                        style: const TextStyle(fontSize: 13, color: AppTheme.textHint),
                      ),
                    ],
                  ),
                ),
              ),
              // 扫一扫（在截图区域外）
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ScanQrPage())),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SvgPicture.asset(
                      'assets/icon/scan.svg',
                      width: 18, height: 18,
                      colorFilter: const ColorFilter.mode(AppTheme.primaryColor, BlendMode.srcIn),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      l.get('scan_qr'),
                      style: const TextStyle(fontSize: 14, color: AppTheme.primaryColor, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 截图卡片区域并保存为临时文件
  Future<File?> _captureCard() async {
    try {
      final boundary = _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/qr_card_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());
      return file;
    } catch (e) {
      debugPrint('[QrCard] capture error: $e');
      return null;
    }
  }

  /// 截图 → 上传 → 以图片消息发送
  Future<void> _shareToChat(BuildContext context, AppLocalizations l, dynamic user) async {
    final chatProvider = context.read<ChatProvider>();
    final convProvider = context.read<ConversationProvider>();

    // 1. 选择聊天
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => ChatPickerPage(title: l.get('share_to_chat'))),
    );
    if (result == null || !mounted) return;

    final targetType = result['targetType'] as String;
    final targetId = result['targetId'] as int;
    final targetName = result['name'] as String;

    setState(() => _sharing = true);

    try {
      // 2. 等一帧确保 widget 渲染完毕后截图
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      final file = await _captureCard();
      if (file == null || !mounted) {
        Fluttertoast.showToast(msg: l.get('error_occurred'));
        return;
      }

      // 3. 上传图片
      final uploadResult = await ChatService().uploadImage(XFile(file.path));
      debugPrint('[QrShare] uploadResult: $uploadResult');
      if (uploadResult == null || !mounted) {
        Fluttertoast.showToast(msg: l.get('upload_failed'));
        return;
      }

      // 4. 发送图片消息
      final mediaUrl = (uploadResult['url'] ?? uploadResult['media_url'] ?? '') as String;
      final thumbUrl = (uploadResult['thumb_url'] ?? '') as String;
      if (mediaUrl.isEmpty) {
        Fluttertoast.showToast(msg: l.get('upload_failed'));
        return;
      }
      if (targetType == 'private') {
        chatProvider.sendPrivateMediaMessage(
          toUserId: targetId, msgType: 'image', mediaUrl: mediaUrl, thumbUrl: thumbUrl,
        );
      } else {
        chatProvider.sendGroupMediaMessage(
          groupId: targetId, msgType: 'image', mediaUrl: mediaUrl, thumbUrl: thumbUrl,
        );
      }

      // 5. 更新会话列表
      convProvider.onMessageSent(
        targetId: targetId,
        targetType: targetType,
        content: '',
        msgType: 'image',
        name: targetName,
      );

      Fluttertoast.showToast(msg: '${l.get('send_to')} $targetName');

      // 清理临时文件
      file.delete().catchError((_) {});
    } catch (e) {
      if (mounted) Fluttertoast.showToast(msg: l.get('error_occurred'));
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }
}
