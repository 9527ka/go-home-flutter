import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';

/// Shared chat input bar used by public chat, private chat, and group chat.
///
/// Two layout variants:
/// - **Public chat room** (`variant: ChatInputBarVariant.publicRoom`):
///   Emoji icon inside text field as suffixIcon; separate + button and always-visible send button;
///   supports connection-state disabling.
/// - **Private/group chat** (`variant: ChatInputBarVariant.standard`):
///   Emoji icon as a standalone button between text field and send/media button;
///   send button replaces the + media button when there is input text.
class ChatInputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool voiceMode;
  final bool showEmojiPicker;
  final bool showMediaPanel;
  final bool isUploading;
  final bool hasInputText;
  final VoidCallback onSend;
  final VoidCallback onToggleVoice;
  final VoidCallback onToggleEmoji;
  final VoidCallback onToggleMedia;
  final VoidCallback onTapTextField;
  final VoidCallback onVoiceStart;
  final void Function(LongPressMoveUpdateDetails) onVoiceMove;
  final VoidCallback onVoiceEnd;
  final VoidCallback onVoiceCancel;
  final bool isRecording;
  final bool cancellingVoice;
  final ChatInputBarVariant variant;
  /// Only used for publicRoom variant
  final bool isDisconnected;

  const ChatInputBar({
    super.key,
    required this.controller,
    required this.voiceMode,
    required this.showEmojiPicker,
    required this.showMediaPanel,
    required this.isUploading,
    required this.hasInputText,
    required this.onSend,
    required this.onToggleVoice,
    required this.onToggleEmoji,
    required this.onToggleMedia,
    required this.onTapTextField,
    required this.onVoiceStart,
    required this.onVoiceMove,
    required this.onVoiceEnd,
    required this.onVoiceCancel,
    this.isRecording = false,
    this.cancellingVoice = false,
    this.variant = ChatInputBarVariant.standard,
    this.isDisconnected = false,
  });

  @override
  Widget build(BuildContext context) {
    if (variant == ChatInputBarVariant.publicRoom) {
      return _buildPublicRoomInputBar(context);
    }
    return _buildStandardInputBar(context);
  }

  // ===== Standard variant (private + group chat) =====

  Widget _buildStandardInputBar(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Container(
      padding: EdgeInsets.only(
        left: 8,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Voice / keyboard toggle
          IconButton(
            icon: Icon(
              voiceMode ? Icons.keyboard : Icons.mic_none,
              color: AppTheme.textSecondary,
              size: 24,
            ),
            onPressed: onToggleVoice,
          ),

          // Input area
          Expanded(
            child: voiceMode
                ? _buildVoiceButton(l)
                : TextField(
                    controller: controller,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: 500,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      hintText: l.get('chat_input_hint'),
                      hintStyle: const TextStyle(color: AppTheme.textHint),
                      counterText: '',
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      filled: true,
                      fillColor: AppTheme.scaffoldBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: const BorderSide(
                            color: AppTheme.primaryColor, width: 1.5),
                      ),
                    ),
                    onTap: onTapTextField,
                  ),
          ),

          // Emoji button
          if (!voiceMode)
            IconButton(
              icon: Icon(
                showEmojiPicker
                    ? Icons.keyboard
                    : Icons.emoji_emotions_outlined,
                color: AppTheme.textSecondary,
                size: 24,
              ),
              onPressed: onToggleEmoji,
            ),

          // Send / + media button
          if (hasInputText)
            Padding(
              padding: const EdgeInsets.only(bottom: 8, left: 4),
              child: GestureDetector(
                onTap: onSend,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF5BA0E8), Color(0xFF4A90D9)],
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.send_rounded,
                      color: Colors.white, size: 18),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.add_circle_outline,
                  color: AppTheme.textSecondary, size: 26),
              onPressed: onToggleMedia,
            ),
        ],
      ),
    );
  }

  // ===== Public room variant =====

  Widget _buildPublicRoomInputBar(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Container(
      padding: EdgeInsets.only(
        left: 8,
        right: 8,
        top: 8,
        bottom: (showEmojiPicker || showMediaPanel)
            ? 8
            : MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Voice / keyboard toggle
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: IconButton(
              icon: Icon(
                voiceMode ? Icons.keyboard_rounded : Icons.mic_rounded,
                color: voiceMode
                    ? AppTheme.primaryColor
                    : AppTheme.textSecondary,
                size: 24,
              ),
              onPressed: isDisconnected ? null : onToggleVoice,
            ),
          ),

          // Voice mode: hold-to-talk button / Text mode: input field
          Expanded(
            child: voiceMode
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: _buildPublicVoiceButton(l),
                  )
                : TextField(
                    controller: controller,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: 500,
                    textInputAction: TextInputAction.newline,
                    onTap: onTapTextField,
                    decoration: InputDecoration(
                      hintText: isDisconnected
                          ? l.get('chat_disconnected_hint')
                          : l.get('chat_input_hint'),
                      hintStyle: const TextStyle(color: AppTheme.textHint),
                      counterText: '',
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      filled: true,
                      fillColor: AppTheme.scaffoldBg,
                      suffixIcon: GestureDetector(
                        onTap: isDisconnected ? null : onToggleEmoji,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Icon(
                            showEmojiPicker
                                ? Icons.keyboard_rounded
                                : Icons.emoji_emotions_outlined,
                            color: showEmojiPicker
                                ? AppTheme.primaryColor
                                : AppTheme.textHint,
                            size: 22,
                          ),
                        ),
                      ),
                      suffixIconConstraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: const BorderSide(
                            color: AppTheme.primaryColor, width: 1.5),
                      ),
                    ),
                  ),
          ),

          const SizedBox(width: 4),

          // + media button
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: IconButton(
              icon: Icon(
                Icons.add_circle_outline,
                color: showMediaPanel
                    ? AppTheme.primaryColor
                    : AppTheme.textSecondary,
                size: 24,
              ),
              onPressed: isDisconnected ? null : onToggleMedia,
            ),
          ),

          // Send button (always visible)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GestureDetector(
              onTap: isDisconnected ? null : onSend,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDisconnected
                        ? [Colors.grey.shade400, Colors.grey.shade500]
                        : const [Color(0xFF5BA0E8), Color(0xFF4A90D9)],
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.send_rounded,
                    color: Colors.white, size: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===== Voice buttons =====

  Widget _buildVoiceButton(AppLocalizations l) {
    return GestureDetector(
      onLongPressStart: (_) => onVoiceStart(),
      onLongPressMoveUpdate: onVoiceMove,
      onLongPressEnd: (_) => onVoiceEnd(),
      onLongPressCancel: onVoiceCancel,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: isRecording
              ? (cancellingVoice
                  ? AppTheme.dangerColor.withOpacity(0.1)
                  : AppTheme.primaryColor.withOpacity(0.1))
              : AppTheme.scaffoldBg,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Center(
          child: Text(
            isRecording
                ? (cancellingVoice
                    ? l.get('voice_slide_cancel')
                    : l.get('voice_release_send'))
                : l.get('voice_hold_to_talk'),
            style: TextStyle(
              fontSize: 14,
              color: isRecording
                  ? (cancellingVoice
                      ? AppTheme.dangerColor
                      : AppTheme.primaryColor)
                  : AppTheme.textSecondary,
              fontWeight: isRecording ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPublicVoiceButton(AppLocalizations l) {
    return GestureDetector(
      onLongPressStart: isDisconnected ? null : (_) => onVoiceStart(),
      onLongPressMoveUpdate: isDisconnected ? null : onVoiceMove,
      onLongPressEnd: isDisconnected ? null : (_) => onVoiceEnd(),
      onLongPressCancel: isDisconnected ? null : onVoiceCancel,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 44,
        decoration: BoxDecoration(
          color: isRecording
              ? AppTheme.primaryColor.withOpacity(0.12)
              : AppTheme.scaffoldBg,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isRecording
                ? AppTheme.primaryColor.withOpacity(0.4)
                : Colors.transparent,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          isRecording
              ? l.get('voice_recording')
              : l.get('voice_hold_to_talk'),
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: isRecording
                ? AppTheme.primaryColor
                : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}

enum ChatInputBarVariant {
  /// Standard variant used in private and group chat
  standard,

  /// Public chat room variant with connection state and different layout
  publicRoom,
}
