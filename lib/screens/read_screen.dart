import 'dart:io';

import 'package:flutter/material.dart';

import '../services/cloud_ai.dart';
import '../services/settings.dart';
import '../services/source_manager.dart';
import '../services/vision.dart';
import '../services/voice.dart';
import 'widgets.dart';

class ReadScreen extends StatefulWidget {
  const ReadScreen({super.key});
  @override
  State<ReadScreen> createState() => _ReadScreenState();
}

class _ReadScreenState extends State<ReadScreen> with GlassesButtonListener {
  bool _busy = false;
  String _text = '';
  File? _img;

  @override
  void onGlassesButton() => _capture();

  Future<void> _capture({bool describe = false}) async {
    if (_busy) return;
    setState(() => _busy = true);
    final v = Voice.instance;
    try {
      final f = await SourceManager.instance.current.capturePhoto();
      if (f == null) {
        await v.say('ما انلكطت صورة');
        return;
      }
      _img = f;
      await v.say('لحظة، دا أقرا');
      String out;
      if (describe) {
        out = await CloudAi.describe(f);
      } else if (AppSettings.hasCloud) {
        out = await CloudAi.readText(f);
      } else {
        final latin = await Vision.ocrLatin(f);
        if (latin.isEmpty) {
          out = 'ما لكيت نص واضح. قرّب الكاميرة وخلي ضوء أكثر.';
        } else {
          String ar;
          try {
            ar = await Vision.toArabic(latin);
          } catch (_) {
            ar = '';
          }
          out = ar.isEmpty || ar == latin
              ? 'النص: $latin'
              : 'مكتوب: $ar';
          out += '\n\n(القراءة العربية تحتاج مفتاح الذكاء من الإعدادات)';
        }
      }
      setState(() => _text = out);
      await v.say(out.split('\n\n(').first);
    } catch (e) {
      setState(() => _text = 'صار خطأ: $e');
      await v.say('صار خطأ');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('قراءة للمكفوفين')),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(20), children: [
          const Center(child: SourceChip()),
          const SizedBox(height: 20),
          Center(child: ShutterButton(busy: _busy, onTap: _capture)),
          const SizedBox(height: 20),
          BigButton(
            label: 'وصف المكان',
            icon: Icons.landscape,
            height: 80,
            color: const Color(0xFF27272A),
            onTap: _busy
                ? null
                : () {
                    if (!AppSettings.hasCloud) {
                      Voice.instance.say('وصف المكان يحتاج مفتاح الذكاء من الإعدادات');
                      return;
                    }
                    _capture(describe: true);
                  },
          ),
          const SizedBox(height: 20),
          if (_text.isNotEmpty)
            ResultCard(
                text: _text,
                image: _img,
                onRepeat: () => Voice.instance.say(_text.split('\n\n(').first)),
        ]),
      ),
    );
  }
}
