import 'dart:async';
import 'dart:io';

/// حدث صادر من المصدر (زر، بطارية، حالة، سجل).
class GlassesEvent {
  final GlassesEventType type;
  final String? message;
  final int? value;
  const GlassesEvent(this.type, {this.message, this.value});
}

enum GlassesEventType { button, battery, status, log }

/// واجهة موحّدة: التطبيق ما يهمه الصورة جاية من التلفون لو من النظارة.
abstract class GlassesSource {
  String get id;
  String get title;
  bool get isConnected;
  Stream<GlassesEvent> get events;

  Future<bool> connect();
  Future<void> disconnect();

  /// يلتقط صورة ويرجع ملفها، أو null إذا انلغى/فشل.
  Future<File?> capturePhoto();

  /// نسبة البطارية إذا معروفة.
  Future<int?> batteryLevel();

  void dispose();
}
