import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

/// 通话铃声服务（单例）
///
/// - 主叫发起后播放回铃音（嘟…嘟…）
/// - 被叫收到来电时播放来电铃声
/// - 通话接通/结束时停止
class CallAudioService {
  CallAudioService._();
  static final instance = CallAudioService._();

  AudioPlayer? _player;

  /// 主叫回铃音（440+480 Hz 双音，2 秒响 4 秒静音循环）
  Future<void> playRingback() async {
    await stop();
    _player = AudioPlayer();
    try {
      await _player!.setAudioSource(_ToneSource(
        toneHz: const [440, 480],
        toneDurationMs: 2000,
        silenceDurationMs: 4000,
        amplitude: 0.25,
      ));
      await _player!.setLoopMode(LoopMode.one);
      await _player!.play();
    } catch (e) {
      debugPrint('[CallAudio] playRingback failed: $e');
    }
  }

  /// 来电铃声（800+1000 Hz，1 秒响 1 秒静音循环）
  Future<void> playRingtone() async {
    await stop();
    _player = AudioPlayer();
    try {
      await _player!.setAudioSource(_ToneSource(
        toneHz: const [800, 1000],
        toneDurationMs: 1000,
        silenceDurationMs: 1000,
        amplitude: 0.35,
      ));
      await _player!.setLoopMode(LoopMode.one);
      await _player!.play();
    } catch (e) {
      debugPrint('[CallAudio] playRingtone failed: $e');
    }
  }

  Future<void> stop() async {
    try {
      await _player?.stop();
      await _player?.dispose();
    } catch (_) {}
    _player = null;
  }
}

/// 程序化生成 WAV 双音信号的音频源
class _ToneSource extends StreamAudioSource {
  final List<double> toneHz;
  final int toneDurationMs;
  final int silenceDurationMs;
  final double amplitude;

  static const int _sampleRate = 16000;
  static const int _bitsPerSample = 16;
  static const int _channels = 1;

  late final Uint8List _wav;

  _ToneSource({
    required this.toneHz,
    required this.toneDurationMs,
    required this.silenceDurationMs,
    this.amplitude = 0.3,
  }) {
    _wav = _buildWav();
  }

  Uint8List _buildWav() {
    final totalMs = toneDurationMs + silenceDurationMs;
    final totalSamples = (_sampleRate * totalMs) ~/ 1000;
    final toneSamples = (_sampleRate * toneDurationMs) ~/ 1000;
    final fadeSamples = (_sampleRate * 10) ~/ 1000; // 10ms fade in/out

    final pcm = Int16List(totalSamples);
    for (int i = 0; i < toneSamples; i++) {
      final t = i / _sampleRate;
      double val = 0;
      for (final hz in toneHz) {
        val += sin(2 * pi * hz * t);
      }
      val /= toneHz.length;

      // fade in/out 消除爆音
      double envelope = 1.0;
      if (i < fadeSamples) {
        envelope = i / fadeSamples;
      } else if (i > toneSamples - fadeSamples) {
        envelope = (toneSamples - i) / fadeSamples;
      }

      pcm[i] = (val * envelope * amplitude * 32767).round().clamp(-32768, 32767);
    }
    // 静音段 pcm 默认 0

    final dataSize = totalSamples * (_bitsPerSample ~/ 8) * _channels;
    final fileSize = 44 + dataSize;
    final buf = ByteData(fileSize);

    // RIFF header
    _writeString(buf, 0, 'RIFF');
    buf.setUint32(4, fileSize - 8, Endian.little);
    _writeString(buf, 8, 'WAVE');

    // fmt chunk
    _writeString(buf, 12, 'fmt ');
    buf.setUint32(16, 16, Endian.little);
    buf.setUint16(20, 1, Endian.little); // PCM
    buf.setUint16(22, _channels, Endian.little);
    buf.setUint32(24, _sampleRate, Endian.little);
    buf.setUint32(28, _sampleRate * _channels * (_bitsPerSample ~/ 8), Endian.little);
    buf.setUint16(32, _channels * (_bitsPerSample ~/ 8), Endian.little);
    buf.setUint16(34, _bitsPerSample, Endian.little);

    // data chunk
    _writeString(buf, 36, 'data');
    buf.setUint32(40, dataSize, Endian.little);
    for (int i = 0; i < totalSamples; i++) {
      buf.setInt16(44 + i * 2, pcm[i], Endian.little);
    }

    return buf.buffer.asUint8List();
  }

  static void _writeString(ByteData buf, int offset, String s) {
    for (int i = 0; i < s.length; i++) {
      buf.setUint8(offset + i, s.codeUnitAt(i));
    }
  }

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    end ??= _wav.length;
    return StreamAudioResponse(
      sourceLength: _wav.length,
      contentLength: end - start,
      offset: start,
      stream: Stream.value(_wav.sublist(start, end)),
      contentType: 'audio/wav',
    );
  }
}
