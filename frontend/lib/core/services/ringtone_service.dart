import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';

/// Manages ringtone playback for incoming and outgoing calls.
/// Uses flutter_sound to play programmatically-generated WAV tones —
/// no external audio assets required.
/// Call [stop] before WebRTC establishes a connection to release the audio
/// session and prevent conflicts with flutter_webrtc.
class RingtoneService {
  static final RingtoneService instance = RingtoneService._();
  RingtoneService._();

  FlutterSoundPlayer? _player;
  bool _looping = false;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Plays a repeating dual-tone ringback (caller hears this while waiting).
  Future<void> playOutgoing() async {
    await _playLoop(
      buildWav: () => _buildWav(frequencies: [480, 440], beepMs: 2000),
      silenceMs: 4000,
      label: 'outgoing',
    );
  }

  /// Plays a repeating phone-style ringtone (receiver hears this on incoming call).
  Future<void> playIncoming() async {
    await _playLoop(
      buildWav: () => _buildWav(frequencies: [900, 1100], beepMs: 1000),
      silenceMs: 2000,
      label: 'incoming',
    );
  }

  /// Stops all tones and releases the audio session so WebRTC can take over.
  Future<void> stop() async {
    _looping = false;
    try {
      final p = _player;
      _player = null;
      if (p != null) {
        if (p.isPlaying) await p.stopPlayer();
        await p.closePlayer();
      }
    } catch (_) {}
  }

  // ── Internal ────────────────────────────────────────────────────────────────

  Future<void> _playLoop({
    required Uint8List Function() buildWav,
    required int silenceMs,
    required String label,
  }) async {
    await stop();
    _looping = true;

    String? filePath;
    try {
      final dir = await getTemporaryDirectory();
      filePath = '${dir.path}/haulistry_$label.wav';
      if (!File(filePath).existsSync()) {
        await File(filePath).writeAsBytes(buildWav());
      }

      final p = FlutterSoundPlayer();
      _player = p;
      await p.openPlayer();
    } catch (_) {
      _looping = false;
      return;
    }

    void schedule() {
      final p = _player;
      if (!_looping || filePath == null || p == null) return;
      p.startPlayer(
        fromURI: filePath,
        codec: Codec.pcm16WAV,
        whenFinished: () {
          if (!_looping) return;
          Future.delayed(Duration(milliseconds: silenceMs), schedule);
        },
      ).catchError((_) => _looping = false);
    }

    schedule();
  }

  /// Generates a mono 22050 Hz 16-bit WAV buffer containing alternating tones
  /// from [frequencies] (one per 200ms slot) for [beepMs] total duration.
  /// A 20ms cosine envelope is applied to prevent audio clicks.
  Uint8List _buildWav({required List<int> frequencies, required int beepMs}) {
    const sr = 22050;
    final n = (sr * beepMs / 1000).round();
    final out = Uint8List(44 + n * 2);
    final v = ByteData.view(out.buffer);

    // RIFF / WAVE header
    out.setRange(0, 4, [0x52, 0x49, 0x46, 0x46]); // "RIFF"
    v.setUint32(4, 36 + n * 2, Endian.little);
    out.setRange(8, 12, [0x57, 0x41, 0x56, 0x45]); // "WAVE"
    out.setRange(12, 16, [0x66, 0x6d, 0x74, 0x20]); // "fmt "
    v.setUint32(16, 16, Endian.little);
    v.setUint16(20, 1, Endian.little); // PCM
    v.setUint16(22, 1, Endian.little); // mono
    v.setUint32(24, sr, Endian.little);
    v.setUint32(28, sr * 2, Endian.little);
    v.setUint16(32, 2, Endian.little);
    v.setUint16(34, 16, Endian.little);
    out.setRange(36, 40, [0x64, 0x61, 0x74, 0x61]); // "data"
    v.setUint32(40, n * 2, Endian.little);

    const ramp = 441; // 20 ms fade-in/out at 22050 Hz
    final slotSamples = (sr * 0.2).round(); // 200 ms per frequency slot

    for (int i = 0; i < n; i++) {
      final freq = frequencies[(i ~/ slotSamples) % frequencies.length].toDouble();
      var amp = 0.45 * 32767.0;
      if (i < ramp) amp *= i / ramp;
      if (i > n - ramp) amp *= (n - i) / ramp;
      final sample = (amp * math.sin(2 * math.pi * freq * i / sr))
          .round()
          .clamp(-32768, 32767);
      v.setInt16(44 + i * 2, sample, Endian.little);
    }

    return out;
  }
}
