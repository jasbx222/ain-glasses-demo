import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../services/voice.dart';
import 'widgets.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});
  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final _ctrl = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal, formats: const [BarcodeFormat.all]);
  final Map<String, int> _counts = {};
  final Map<String, String> _types = {};
  final Map<String, DateTime> _last = {};
  bool _paused = false;

  int get _total => _counts.values.fold(0, (a, b) => a + b);

  void _onDetect(BarcodeCapture cap) {
    if (_paused) return;
    for (final b in cap.barcodes) {
      final v = b.rawValue;
      if (v == null || v.isEmpty) continue;
      final now = DateTime.now();
      // نفس الباركود ما ينحسب مرتين إلا بعد ثانيتين (حتى ما يعد وهو واكف عليه)
      if (_last[v] != null && now.difference(_last[v]!).inMilliseconds < 2000) {
        _last[v] = now;
        continue;
      }
      _last[v] = now;
      setState(() {
        _counts[v] = (_counts[v] ?? 0) + 1;
        _types[v] = b.format.name;
      });
      HapticFeedback.mediumImpact();
      SystemSound.play(SystemSoundType.click);
      Voice.instance.say('${_counts[v]}');
    }
  }

  Future<void> _export() async {
    if (_counts.isEmpty) {
      Voice.instance.say('القائمة فارغة');
      return;
    }
    final b = StringBuffer('\uFEFFbarcode,format,count\n');
    _counts.forEach((k, v) =>
        b.writeln('"${k.replaceAll('"', '""')}",${_types[k]},$v'));
    final dir = await getTemporaryDirectory();
    final ts = DateTime.now().toIso8601String().replaceAll(RegExp(r'[:.]'), '-');
    final f = File('${dir.path}/jard-$ts.csv');
    await f.writeAsString(b.toString());
    await SharePlus.instance
        .share(ShareParams(files: [XFile(f.path)], text: 'جرد عين — $_total قطعة'));
  }

  void _edit(String code, int delta) => setState(() {
        final n = (_counts[code] ?? 0) + delta;
        if (n <= 0) {
          _counts.remove(code);
        } else {
          _counts[code] = n;
        }
      });

  @override
  void dispose() {
    _ctrl.dispose();
    Voice.instance.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = _counts.entries.toList().reversed.toList();
    return Scaffold(
      appBar: AppBar(title: const Text('جرد باركود'), actions: [
        IconButton(
            tooltip: 'تصدير CSV',
            iconSize: 32,
            onPressed: _export,
            icon: const Icon(Icons.ios_share)),
      ]),
      body: Column(children: [
        SizedBox(
          height: 260,
          child: Stack(fit: StackFit.expand, children: [
            MobileScanner(controller: _ctrl, onDetect: _onDetect),
            if (_paused)
              Container(
                  color: Colors.black54,
                  alignment: Alignment.center,
                  child: const Text('متوقف', style: TextStyle(fontSize: 32))),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Expanded(
              child: Text('الأصناف: ${_counts.length}   المجموع: $_total',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            ),
            IconButton.filled(
              iconSize: 36,
              tooltip: _paused ? 'كمّل' : 'وقّف',
              onPressed: () => setState(() => _paused = !_paused),
              icon: Icon(_paused ? Icons.play_arrow : Icons.pause),
            ),
          ]),
        ),
        Expanded(
          child: items.isEmpty
              ? const Center(
                  child: Text('وجّه الكاميرة على باركود لو QR',
                      style: TextStyle(fontSize: 20, color: Colors.white70)))
              : ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final e = items[i];
                    return ListTile(
                      title: Text(e.key,
                          style: const TextStyle(fontSize: 20), maxLines: 2),
                      subtitle: Text(_types[e.key] ?? ''),
                      leading: CircleAvatar(
                          radius: 26,
                          child: Text('${e.value}',
                              style: const TextStyle(fontSize: 20))),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(
                            iconSize: 30,
                            onPressed: () => _edit(e.key, -1),
                            icon: const Icon(Icons.remove_circle)),
                        IconButton(
                            iconSize: 30,
                            onPressed: () => _edit(e.key, 1),
                            icon: const Icon(Icons.add_circle)),
                      ]),
                    );
                  }),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: BigButton(
              label: 'صدّر CSV',
              icon: Icons.file_download,
              height: 76,
              color: const Color(0xFF15803D),
              onTap: _export),
        ),
      ]),
    );
  }
}
