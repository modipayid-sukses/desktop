import 'package:flutter_tts/flutter_tts.dart';

/// Wraps [FlutterTts] to announce events (e.g. incoming QRIS payments) in Indonesian.
class TtsService {
  TtsService._();

  static final TtsService instance = TtsService._();

  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;

  Future<void> _ensureInit() async {
    if (_initialized) return;
    final result = await _tts.setLanguage('id-ID');
    if (result != 1) {
      await _tts.setLanguage('id');
    }
    await _tts.setSpeechRate(0.45);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    _initialized = true;
  }

  /// Speaks [text]. Fire-and-forget — does not block the caller.
  Future<void> speak(String text) async {
    await _ensureInit();
    await _tts.speak(text);
  }
}
