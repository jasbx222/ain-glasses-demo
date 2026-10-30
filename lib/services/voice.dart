import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'settings.dart';

/// النطق والاستماع. إذا النظارة مربوطة كسماعة بلوتوث بإعدادات أندرويد،
/// الصوت والمايك يمرون منها تلقائياً.
class Voice {
  Voice._();
  static final instance = Voice._();
  final tts = FlutterTts();
  final stt = SpeechToText();
  bool _sttReady = false;

  Future<void> init() async {
    await tts.setLanguage('ar');
    await tts.setSpeechRate(AppSettings.speechRate);
    await tts.awaitSpeakCompletion(true);
  }

  Future<void> say(String text) async {
    if (text.trim().isEmpty) return;
    await tts.stop();
    await tts.setSpeechRate(AppSettings.speechRate);
    await tts.speak(text);
  }

  Future<void> stop() => tts.stop();

  Future<bool> get arabicTtsAvailable async {
    final r = await tts.isLanguageAvailable('ar');
    return r == true || r == 1;
  }

  Future<String?> listen({String localeId = 'ar_IQ'}) async {
    if (!_sttReady) _sttReady = await stt.initialize();
    if (!_sttReady) return null;
    String result = '';
    await stt.listen(
      listenOptions: SpeechListenOptions(
          localeId: localeId,
          listenFor: const Duration(seconds: 12),
          pauseFor: const Duration(seconds: 3)),
      onResult: (r) => result = r.recognizedWords,
    );
    while (stt.isListening) {
      await Future.delayed(const Duration(milliseconds: 200));
    }
    await Future.delayed(const Duration(milliseconds: 300));
    return result;
  }

  Future<void> stopListening() => stt.stop();
}
