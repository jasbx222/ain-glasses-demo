// ignore_for_file: constant_identifier_names, non_constant_identifier_names
import 'dart:async';
import 'dart:io';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../services/settings.dart';
import 'glasses_source.dart';

/// ربط تجريبي بنظارات عائلة HeyCyan (ومنها AIMB G1 على الأغلب).
///
/// ⚠️ كل هذا الملف **غير مجرّب** على نظارة حقيقية. مبني من المشاريع المفتوحة:
///
/// [A] ebowwa/HeyCyanSmartGlassesSDK
///     - examples/untested/python/build_for_pypi.py : الخدمات والخصائص
///       (7905FFF0-..., 6e40fff0/1/2/3-b5a3-...) وأوامر التصوير
///       (photo=02 01 01، video 02 01 02/03، audio 02 01 08/0C).
///     - ios/QCSDKDemo/GlassesMediaDownloader.m : openWifiWithMode(Transfer)
///       ثم getDeviceWifiIP ثم تحميل `http://IP/files/media.config`.
///     - ios/QCSDK.framework/Headers/QCSDKCmdCreator.h : getDeviceBattery,
///       openWifiWithMode, getDeviceWifiIP (أسماء الأوامر بدون بايتات).
/// [B] FerSaiyan/Alternative-HeyCyan-App-and-SDK (CyanBridge)
///     - android/.../MainActivity.kt : glassesControl(02 01 01) تصوير،
///       glassesControl(02 04) عدد الوسائط غير المرفوعة.
///     - android/.../wifiadb/DefaultWifiAdbDebugControllerFactory.kt :
///       glassesControl(02 01 04) لدخول وضع نقل الواي فاي (Wi-Fi Direct).
///     - shared/.../media/IosMediaTransfer.kt : GET $ip/files/media.config
///       (اسم ملف بكل سطر) ثم تحميل كل ملف من `$ip/files/NAME`.
///     - BRIDGE_RESEARCH_NOTES.md : 0x2001/0x2002 كخصائص أوامر لنظارات
///       مشابهة (MemoMind/XGIMI) — نستخدمها احتياط فقط.
///
/// ملاحظة مهمة: CyanBridge يرسل الأوامر عبر مكتبة المصنع
/// (LargeDataHandler.glassesControl في glasses_sdk_*.aar) واللي ممكن تغلّف
/// البايتات بهيدر/طول. إحنا نكتب البايتات الخام على خاصية الأوامر، فإذا ما
/// استجابت النظارة لازم نفك تغليف الـ aar.
class HeyCyanGlassesSource implements GlassesSource {
  // [A] build_for_pypi.py
  static final SERVICE_PRIMARY = Guid('7905FFF0-B5CE-4E99-A40F-4B1E122D00D0');
  static final SERVICE_UART = Guid('6e40fff0-b5a3-f393-e0a9-e50e24dcca9e');
  static final CHAR_COMMAND = Guid('6e40fff1-b5a3-f393-e0a9-e50e24dcca9e');
  static final CHAR_NOTIFY = Guid('6e40fff2-b5a3-f393-e0a9-e50e24dcca9e');
  static final CHAR_DATA = Guid('6e40fff3-b5a3-f393-e0a9-e50e24dcca9e');
  // [B] BRIDGE_RESEARCH_NOTES.md (احتياط)
  static final CHAR_COMMAND_ALT = Guid('00002001-0000-1000-8000-00805f9b34fb');
  static final CHAR_NOTIFY_ALT = Guid('00002002-0000-1000-8000-00805f9b34fb');
  // خدمة البطارية القياسية من Bluetooth SIG (إذا موجودة)
  static final BATTERY_SERVICE = Guid('180F');
  static final BATTERY_LEVEL = Guid('2A19');

  // [A]+[B]
  static const CMD_TAKE_PHOTO = [0x02, 0x01, 0x01];
  static const CMD_VIDEO_START = [0x02, 0x01, 0x02];
  static const CMD_VIDEO_STOP = [0x02, 0x01, 0x03];
  static const CMD_WIFI_TRANSFER = [0x02, 0x01, 0x04]; // [B]
  static const CMD_AUDIO_START = [0x02, 0x01, 0x08];
  static const CMD_AUDIO_STOP = [0x02, 0x01, 0x0C];
  static const CMD_MEDIA_COUNT = [0x02, 0x04]; // [B]

  /// أسماء متوقعة بالإعلان (تخمين، تتعدل بعد أول فحص حقيقي).
  static const nameHints = ['G1', 'AIMB', 'Cyan', 'QC', 'Glass', 'W610', 'M01'];

  final _events = StreamController<GlassesEvent>.broadcast();
  BluetoothDevice? _device;
  BluetoothCharacteristic? _cmd;
  BluetoothCharacteristic? _battery;
  StreamSubscription? _notifySub;
  StreamSubscription? _connSub;
  bool _connected = false;
  bool learningButton = false;
  final List<String> log = [];

  @override
  String get id => 'glasses';
  @override
  String get title => 'نظارة HeyCyan / G1 (تجريبي)';
  @override
  bool get isConnected => _connected;
  @override
  Stream<GlassesEvent> get events => _events.stream;

  void _log(String m) {
    final line = '${DateTime.now().toIso8601String().substring(11, 19)}  $m';
    log.insert(0, line);
    if (log.length > 300) log.removeLast();
    _events.add(GlassesEvent(GlassesEventType.log, message: line));
  }

  static String hex(List<int> b) =>
      b.map((e) => e.toRadixString(16).padLeft(2, '0')).join(' ');

  /// فحص بلوتوث: يرجع كل الأجهزة، والأجهزة اللي تشبه النظارة تطلع أول.
  Stream<List<ScanResult>> scan({Duration timeout = const Duration(seconds: 10)}) {
    FlutterBluePlus.startScan(timeout: timeout);
    return FlutterBluePlus.scanResults.map((list) {
      final l = [...list];
      l.sort((a, b) => (likelyGlasses(b) ? 1 : 0) - (likelyGlasses(a) ? 1 : 0));
      return l;
    });
  }

  Future<void> stopScan() => FlutterBluePlus.stopScan();

  static bool likelyGlasses(ScanResult r) {
    final n = r.advertisementData.advName.toLowerCase();
    final s = r.advertisementData.serviceUuids;
    return s.contains(SERVICE_PRIMARY) ||
        s.contains(SERVICE_UART) ||
        nameHints.any((h) => n.contains(h.toLowerCase()));
  }

  void remember(BluetoothDevice d, String name) {
    AppSettings.glassesId = d.remoteId.str;
    AppSettings.glassesName = name;
  }

  @override
  Future<bool> connect() async {
    final id = AppSettings.glassesId;
    if (id.isEmpty) {
      _log('ماكو نظارة محفوظة. افحص من الإعدادات.');
      return false;
    }
    try {
      final d = BluetoothDevice.fromId(id);
      _device = d;
      _log('اتصال بـ $id ...');
      await d.connect(license: License.nonprofit, timeout: const Duration(seconds: 15));
      _connSub = d.connectionState.listen((s) {
        _connected = s == BluetoothConnectionState.connected;
        _events.add(GlassesEvent(GlassesEventType.status,
            message: _connected ? 'متصلة' : 'انقطع الاتصال'));
      });
      final services = await d.discoverServices();
      BluetoothCharacteristic? notify;
      for (final s in services) {
        _log('خدمة ${s.uuid}');
        for (final c in s.characteristics) {
          _log('  خاصية ${c.uuid} ${c.properties}');
          if (c.uuid == CHAR_COMMAND) _cmd = c;
          if (c.uuid == CHAR_NOTIFY) notify = c;
          if (c.uuid == BATTERY_LEVEL) _battery = c;
        }
      }
      // احتياط [B]
      for (final s in services) {
        for (final c in s.characteristics) {
          if (_cmd == null && c.uuid == CHAR_COMMAND_ALT) _cmd = c;
          if (notify == null && c.uuid == CHAR_NOTIFY_ALT) notify = c;
        }
      }
      if (notify != null) {
        await notify.setNotifyValue(true);
        _notifySub = notify.onValueReceived.listen(_onNotify);
      }
      _connected = true;
      _log(_cmd == null
          ? 'اتصلت بس ما لكيت خاصية الأوامر المعروفة'
          : 'اتصلت. خاصية الأوامر ${_cmd!.uuid}');
      _events.add(const GlassesEvent(GlassesEventType.status, message: 'متصلة'));
      return true;
    } catch (e) {
      _log('فشل الاتصال: $e');
      return false;
    }
  }

  void _onNotify(List<int> v) {
    final h = hex(v);
    _log('← $h');
    if (learningButton) {
      // أول إشعار بعد ما المستخدم يدوس الزر نحفظه كبصمة الزر (أول 3 بايتات)
      AppSettings.buttonPattern = hex(v.take(3).toList());
      learningButton = false;
      _log('تحفظ نمط الزر: ${AppSettings.buttonPattern}');
      _events.add(GlassesEvent(GlassesEventType.status,
          message: 'تعلّمت زر النظارة'));
      return;
    }
    final p = AppSettings.buttonPattern;
    if (p.isNotEmpty && h.startsWith(p)) {
      _events.add(const GlassesEvent(GlassesEventType.button));
    }
  }

  Future<bool> send(List<int> bytes) async {
    if (_cmd == null) {
      _log('ماكو خاصية أوامر');
      return false;
    }
    _log('→ ${hex(bytes)}');
    try {
      await _cmd!.write(bytes, withoutResponse: _cmd!.properties.writeWithoutResponse);
      return true;
    } catch (e) {
      _log('فشل الإرسال: $e');
      return false;
    }
  }

  @override
  Future<void> disconnect() async {
    await _notifySub?.cancel();
    await _connSub?.cancel();
    await _device?.disconnect();
    _connected = false;
    _cmd = null;
  }

  /// [A] [B]: صوّر بالنظارة، شغّل وضع نقل الواي فاي، وحمّل آخر صورة.
  /// لازم التلفون يكون متصل بواي فاي النظارة، والـ IP من الإعدادات.
  @override
  Future<File?> capturePhoto() async {
    if (!_connected && !await connect()) return null;
    final before = await _listMedia();
    if (!await send(CMD_TAKE_PHOTO)) return null;
    await Future.delayed(const Duration(seconds: 2));
    await send(CMD_WIFI_TRANSFER);
    for (var i = 0; i < 10; i++) {
      await Future.delayed(const Duration(seconds: 2));
      final now = await _listMedia();
      final fresh = now
          .where((f) => !before.contains(f))
          .where((f) => RegExp(r'\.(jpe?g|png)$', caseSensitive: false).hasMatch(f))
          .toList();
      final pick = fresh.isNotEmpty
          ? fresh.last
          : now.lastWhere(
              (f) => RegExp(r'\.(jpe?g|png)$', caseSensitive: false).hasMatch(f),
              orElse: () => '');
      if (pick.isNotEmpty) return _download(pick);
    }
    _log('ما وصلت صورة عبر الواي فاي');
    return null;
  }

  Future<List<String>> _listMedia() async {
    try {
      final r = await http
          .get(Uri.parse('http://${AppSettings.glassesIp}/files/media.config'))
          .timeout(const Duration(seconds: 4));
      if (r.statusCode != 200) return [];
      return r.body
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty && !e.contains('/') && !e.contains('..'))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<File?> _download(String name) async {
    try {
      final r = await http
          .get(Uri.parse('http://${AppSettings.glassesIp}/files/$name'))
          .timeout(const Duration(seconds: 30));
      if (r.statusCode != 200) return null;
      final dir = await getTemporaryDirectory();
      final f = File('${dir.path}/$name');
      await f.writeAsBytes(r.bodyBytes);
      _log('تحملت $name (${r.bodyBytes.length} بايت)');
      return f;
    } catch (e) {
      _log('فشل التحميل: $e');
      return null;
    }
  }

  @override
  Future<int?> batteryLevel() async {
    try {
      if (_battery != null) {
        final v = await _battery!.read();
        if (v.isNotEmpty) return v.first;
      }
    } catch (_) {}
    return null;
  }

  @override
  void dispose() => _events.close();
}
