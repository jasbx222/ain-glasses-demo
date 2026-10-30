import 'dart:async';
import 'dart:io';

import 'package:image_picker/image_picker.dart';

import 'glasses_source.dart';

/// يشتغل هسه: كاميرة التلفون بدل النظارة. المايك والسماعة يجون من
/// speech_to_text و flutter_tts (وإذا أكو سماعة بلوتوث مربوطة يطلع منها).
class PhoneCameraSource implements GlassesSource {
  final _picker = ImagePicker();
  final _events = StreamController<GlassesEvent>.broadcast();

  @override
  String get id => 'phone';
  @override
  String get title => 'كاميرة التلفون';
  @override
  bool get isConnected => true;
  @override
  Stream<GlassesEvent> get events => _events.stream;

  @override
  Future<bool> connect() async => true;
  @override
  Future<void> disconnect() async {}

  @override
  Future<File?> capturePhoto() async {
    final x = await _picker.pickImage(
        source: ImageSource.camera, maxWidth: 2000, imageQuality: 90);
    return x == null ? null : File(x.path);
  }

  @override
  Future<int?> batteryLevel() async => null;

  @override
  void dispose() => _events.close();
}
