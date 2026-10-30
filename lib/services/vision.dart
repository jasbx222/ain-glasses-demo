import 'dart:io';

import 'package:google_mlkit_language_id/google_mlkit_language_id.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';

/// على الجهاز بدون إنترنت.
/// ملاحظة: ML Kit Text Recognition v2 ما يدعم الحروف العربية (يدعم
/// اللاتيني، الصيني، الديفاناغاري، الياباني، الكوري). فالنص العربي يحتاج
/// الخدمة السحابية الاختيارية. الترجمة على الجهاز تدعم العربي.
class Vision {
  static final _latin = TextRecognizer(script: TextRecognitionScript.latin);
  static final _langId = LanguageIdentifier(confidenceThreshold: 0.4);
  static final Map<String, OnDeviceTranslator> _translators = {};

  static Future<String> ocrLatin(File f) async {
    final r = await _latin.processImage(InputImage.fromFile(f));
    return r.blocks.map((b) => b.text.replaceAll('\n', ' ')).join('\n').trim();
  }

  static Future<String> detectLanguage(String text) async {
    try {
      return await _langId.identifyLanguage(text);
    } catch (_) {
      return 'und';
    }
  }

  static bool isArabic(String t) => RegExp(r'[\u0600-\u06FF]').hasMatch(t);

  /// يترجم للعربي على الجهاز. أول مرة ينزل موديل اللغة (~30MB) ويحتاج نت.
  static Future<String> toArabic(String text, {String? from}) async {
    if (text.trim().isEmpty || isArabic(text)) return text;
    final code = from ?? await detectLanguage(text);
    final src = TranslateLanguage.values.firstWhere((l) => l.bcpCode == code,
        orElse: () => TranslateLanguage.english);
    if (src == TranslateLanguage.arabic) return text;
    final t = _translators.putIfAbsent(
        src.bcpCode,
        () => OnDeviceTranslator(
            sourceLanguage: src, targetLanguage: TranslateLanguage.arabic));
    return t.translateText(text);
  }
}
