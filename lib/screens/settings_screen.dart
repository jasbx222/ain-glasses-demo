import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../main.dart';
import '../services/settings.dart';
import '../services/source_manager.dart';
import '../services/voice.dart';
import '../sources/glasses_source.dart';
import '../sources/heycyan_glasses_source.dart';
import 'widgets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final sm = SourceManager.instance;
  HeyCyanGlassesSource get g => sm.glasses;
  List<ScanResult> _results = [];
  StreamSubscription? _scanSub, _evSub;
  bool _scanning = false;
  int? _battery;
  late final _key = TextEditingController(text: AppSettings.apiKey);
  late final _base = TextEditingController(text: AppSettings.apiBase);
  late final _model = TextEditingController(text: AppSettings.apiModel);
  late final _ip = TextEditingController(text: AppSettings.glassesIp);

  @override
  void initState() {
    super.initState();
    _evSub = g.events.listen((e) {
      if (!mounted) return;
      if (e.type == GlassesEventType.status && e.message != null) {
        Voice.instance.say(e.message!);
      }
      if (e.type == GlassesEventType.button) Voice.instance.say('انداس زر النظارة');
      setState(() {});
    });
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _evSub?.cancel();
    g.stopScan();
    super.dispose();
  }

  Future<void> _scan() async {
    final st = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();
    if (st[Permission.bluetoothScan]?.isDenied == true) {
      Voice.instance.say('لازم توافق على البلوتوث');
      return;
    }
    if (await FlutterBluePlus.adapterState.first != BluetoothAdapterState.on) {
      Voice.instance.say('شغّل البلوتوث');
      return;
    }
    setState(() => _scanning = true);
    Voice.instance.say('دا أدوّر على النظارة');
    _scanSub?.cancel();
    _scanSub = g.scan().listen((r) => setState(() => _results = r));
    await Future.delayed(const Duration(seconds: 10));
    if (mounted) setState(() => _scanning = false);
  }

  Future<void> _pick(ScanResult r) async {
    await g.stopScan();
    final name = r.advertisementData.advName.isEmpty
        ? r.device.remoteId.str
        : r.advertisementData.advName;
    g.remember(r.device, name);
    sm.select('glasses');
    final ok = await g.connect();
    _battery = await g.batteryLevel();
    Voice.instance.say(ok ? 'انربطت النظارة' : 'ما انربطت');
    setState(() {});
  }

  Widget _section(String t) => Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Text(t,
          style: const TextStyle(
              fontSize: 24, fontWeight: FontWeight.bold, color: kYellow)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        _section('مصدر الصورة'),
        RadioGroup<String>(
          groupValue: AppSettings.source,
          onChanged: (v) => setState(() => sm.select(v!)),
          child: const Column(children: [
            RadioListTile(
                value: 'phone',
                title: Text('كاميرة التلفون (يشتغل هسه)', style: TextStyle(fontSize: 20))),
            RadioListTile(
                value: 'glasses',
                title: Text('نظارة HeyCyan / AIMB G1 (تجريبي، غير مجرّب)',
                    style: TextStyle(fontSize: 20))),
          ]),
        ),
        _section('النظارة'),
        Text(
            AppSettings.glassesName.isEmpty
                ? 'ماكو نظارة محفوظة'
                : 'المحفوظة: ${AppSettings.glassesName} — ${g.isConnected ? "متصلة" : "مو متصلة"}'
                    '${_battery != null ? " — بطارية $_battery٪" : ""}',
            style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 12),
        BigButton(
            label: _scanning ? 'دا أدوّر…' : 'دوّر على النظارة',
            icon: Icons.bluetooth_searching,
            height: 80,
            onTap: _scanning ? null : _scan),
        ..._results.take(20).map((r) {
          final likely = HeyCyanGlassesSource.likelyGlasses(r);
          final n = r.advertisementData.advName;
          return ListTile(
            leading: Icon(likely ? Icons.visibility : Icons.bluetooth,
                color: likely ? kYellow : null),
            title: Text(n.isEmpty ? '(بدون اسم)' : n),
            subtitle: Text('${r.device.remoteId.str}  RSSI ${r.rssi}'),
            trailing: const Icon(Icons.link),
            onTap: () => _pick(r),
          );
        }),
        if (AppSettings.glassesId.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton(
                onPressed: () async {
                  await g.connect();
                  _battery = await g.batteryLevel();
                  setState(() {});
                },
                child: const Text('اتصل')),
            FilledButton(
                onPressed: () => g.send(HeyCyanGlassesSource.CMD_TAKE_PHOTO),
                child: const Text('أمر تصوير')),
            FilledButton(
                onPressed: () => g.send(HeyCyanGlassesSource.CMD_WIFI_TRANSFER),
                child: const Text('وضع نقل الواي فاي')),
            FilledButton(
                onPressed: () => g.send(HeyCyanGlassesSource.CMD_MEDIA_COUNT),
                child: const Text('عدد الوسائط')),
            FilledButton(
                onPressed: () {
                  g.learningButton = true;
                  Voice.instance.say('دوس زر النظارة هسه');
                },
                child: const Text('تعلّم زر النظارة')),
            OutlinedButton(
                onPressed: () async {
                  await g.disconnect();
                  setState(() {});
                },
                child: const Text('افصل')),
          ]),
          const SizedBox(height: 12),
          TextField(
            controller: _ip,
            decoration: const InputDecoration(
                labelText: 'IP النظارة على الواي فاي مالتها',
                helperText: 'اربط التلفون بواي فاي النظارة أول. القيمة غير مؤكدة.'),
            onChanged: (v) => AppSettings.glassesIp = v.trim(),
          ),
          const SizedBox(height: 8),
          Text('نمط الزر: ${AppSettings.buttonPattern.isEmpty ? "مو متعلَّم" : AppSettings.buttonPattern}'),
          const SizedBox(height: 8),
          const Text('سجل البلوتوث:', style: TextStyle(fontSize: 18)),
          Container(
            height: 200,
            color: Colors.black,
            padding: const EdgeInsets.all(8),
            child: ListView(
                children: g.log
                    .map((l) => Text(l,
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(fontSize: 12, fontFamily: 'monospace')))
                    .toList()),
          ),
          const Text('🔊 الصوت: اربط النظارة كسماعة بلوتوث من إعدادات أندرويد، وصوت التطبيق والمايك يمرون منها.',
              style: TextStyle(fontSize: 16, color: Colors.white70)),
        ],
        _section('الذكاء السحابي (اختياري)'),
        const Text(
            'يحتاجه قراءة العربي ووصف المكان. أي خدمة متوافقة مع OpenAI. المفتاح يتخزن بالتلفون بس.',
            style: TextStyle(fontSize: 16, color: Colors.white70)),
        TextField(
          controller: _key,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'مفتاح API'),
          onChanged: (v) => AppSettings.apiKey = v.trim(),
        ),
        TextField(
          controller: _base,
          textDirection: TextDirection.ltr,
          decoration: const InputDecoration(labelText: 'عنوان الخدمة'),
          onChanged: (v) => AppSettings.apiBase = v.trim(),
        ),
        TextField(
          controller: _model,
          textDirection: TextDirection.ltr,
          decoration: const InputDecoration(labelText: 'الموديل'),
          onChanged: (v) => AppSettings.apiModel = v.trim(),
        ),
        _section('سرعة الحچي'),
        Slider(
          value: AppSettings.speechRate,
          min: 0.2,
          max: 0.8,
          divisions: 6,
          label: AppSettings.speechRate.toStringAsFixed(2),
          onChanged: (v) => setState(() => AppSettings.speechRate = v),
          onChangeEnd: (_) => Voice.instance.say('هاي سرعة الحچي'),
        ),
        const SizedBox(height: 40),
      ]),
    );
  }
}
