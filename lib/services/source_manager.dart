import 'package:flutter/foundation.dart';

import '../sources/glasses_source.dart';
import '../sources/heycyan_glasses_source.dart';
import '../sources/phone_camera_source.dart';
import 'settings.dart';

/// يحتفظ بالمصدر الحالي ويبدّله حسب الإعدادات.
class SourceManager extends ChangeNotifier {
  SourceManager._();
  static final instance = SourceManager._();

  final phone = PhoneCameraSource();
  final glasses = HeyCyanGlassesSource();

  GlassesSource get current => AppSettings.source == 'glasses' ? glasses : phone;

  void select(String id) {
    AppSettings.source = id;
    notifyListeners();
  }

  void refresh() => notifyListeners();
}
