import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';

/// Voice recording overlay displayed in the center of the screen
/// while user is recording a voice message.
class VoiceRecordOverlay extends StatelessWidget {
  final bool isRecording;
  final bool cancelling;
  final int recordDuration;
  final List<double> amplitudes;
  final double currentAmplitude;

  const VoiceRecordOverlay({
    super.key,
    required this.isRecording,
    required this.cancelling,
    required this.recordDuration,
    required this.amplitudes,
    this.currentAmplitude = 0,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Positioned.fill(
      child: IgnorePointer(
        child: Align(
          alignment: Alignment.center,
          child: Container(
            width: 200,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.75),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Mic / cancel icon
                Icon(
                  cancelling ? Icons.close : Icons.mic,
                  size: 36,
                  color: cancelling ? AppTheme.dangerColor : Colors.white,
                ),
                const SizedBox(height: 12),

                // Waveform animation
                SizedBox(
                  height: 40,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(20, (i) {
                      final offset = amplitudes.length - 20 + i;
                      final amp = offset >= 0 ? amplitudes[offset] : 0.05;
                      final barHeight = (4 + amp * 36).clamp(4.0, 40.0);
                      return Container(
                        width: 3,
                        height: barHeight,
                        margin: const EdgeInsets.symmetric(horizontal: 1.5),
                        decoration: BoxDecoration(
                          color: cancelling
                              ? AppTheme.dangerColor.withOpacity(0.7)
                              : Colors.white.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 12),

                // Timer
                Text(
                  '${(recordDuration ~/ 60).toString().padLeft(2, '0')}:${(recordDuration % 60).toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 10),

                // Hint text
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: cancelling
                        ? AppTheme.dangerColor
                        : Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    cancelling
                        ? l.get('voice_release_cancel')
                        : l.get('voice_slide_cancel'),
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.white,
                      decoration: TextDecoration.none,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
