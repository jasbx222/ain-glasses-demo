import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'settings.dart';

/// اختياري: أي خدمة متوافقة مع OpenAI (chat/completions بالصور).
/// المفتاح من الإعدادات فقط. التطبيق يشتغل بدونه.
class CloudAi {
  static Future<String> ask(String prompt, {File? image}) async {
    if (!AppSettings.hasCloud) throw Exception('ماكو مفتاح API بالإعدادات');
    final content = <Map<String, dynamic>>[
      {'type': 'text', 'text': prompt}
    ];
    if (image != null) {
      final b64 = base64Encode(await image.readAsBytes());
      content.add({
        'type': 'image_url',
        'image_url': {'url': 'data:image/jpeg;base64,$b64'}
      });
    }
    final base = AppSettings.apiBase.replaceAll(RegExp(r'/+$'), '');
    final res = await http
        .post(Uri.parse('$base/chat/completions'),
            headers: {
              'Authorization': 'Bearer ${AppSettings.apiKey.trim()}',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': AppSettings.apiModel,
              'messages': [
                {
                  'role': 'system',
                  'content':
                      'أنت مساعد لشخص كفيف بالعراق. جاوب بالعربي وباللهجة العراقية البسيطة وباختصار.'
                },
                {'role': 'user', 'content': content}
              ],
              'max_tokens': 500,
            }))
        .timeout(const Duration(seconds: 45));
    if (res.statusCode != 200) {
      throw Exception('خطأ من الخدمة (${res.statusCode})');
    }
    final j = jsonDecode(utf8.decode(res.bodyBytes));
    return (j['choices'][0]['message']['content'] as String).trim();
  }

  static Future<String> readText(File image) => ask(
      'اقرأ كل النص الموجود بالصورة (لوحة، علبة دوا، ورقة). إذا علبة دوا كول اسم الدوا والجرعة وتاريخ الانتهاء إذا مبين. إذا النص مو عربي ترجمه للعربي.',
      image: image);

  static Future<String> describe(File image) => ask(
      'وصف شنو موجود بالصورة لشخص كفيف بجملتين أو ثلاث، وانتبه لأي خطر قدامه.',
      image: image);
}
