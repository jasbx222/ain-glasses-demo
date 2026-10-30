import 'package:shared_preferences/shared_preferences.dart';

/// إعدادات محلية فقط. مفتاح الـ API يدخله المستخدم ويتخزن بالجهاز، ما ينكتب بالكود.
class AppSettings {
  static late SharedPreferences _p;
  static Future<void> init() async => _p = await SharedPreferences.getInstance();

  static String get source => _p.getString('source') ?? 'phone';
  static set source(String v) => _p.setString('source', v);

  static String get glassesId => _p.getString('glassesId') ?? '';
  static set glassesId(String v) => _p.setString('glassesId', v);
  static String get glassesName => _p.getString('glassesName') ?? '';
  static set glassesName(String v) => _p.setString('glassesName', v);

  /// IP النظارة على شبكة الواي فاي مالتها (غير مؤكد، يتعدل من الإعدادات).
  static String get glassesIp => _p.getString('glassesIp') ?? '192.168.49.1';
  static set glassesIp(String v) => _p.setString('glassesIp', v);

  /// بايتات إشعار زر النظارة اللي تعلّمها التطبيق (hex).
  static String get buttonPattern => _p.getString('buttonPattern') ?? '';
  static set buttonPattern(String v) => _p.setString('buttonPattern', v);

  static String get apiKey => _p.getString('apiKey') ?? '';
  static set apiKey(String v) => _p.setString('apiKey', v);
  static String get apiBase =>
      _p.getString('apiBase') ?? 'https://api.openai.com/v1';
  static set apiBase(String v) => _p.setString('apiBase', v);
  static String get apiModel => _p.getString('apiModel') ?? 'gpt-4o-mini';
  static set apiModel(String v) => _p.setString('apiModel', v);

  static bool get hasCloud => apiKey.trim().isNotEmpty;

  static double get speechRate => _p.getDouble('rate') ?? 0.45;
  static set speechRate(double v) => _p.setDouble('rate', v);
}
