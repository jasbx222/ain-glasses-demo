import 'dart:io';

import 'package:flutter/material.dart';

import '../services/cloud_ai.dart';
import '../services/settings.dart';
import '../services/source_manager.dart';
import '../services/vision.dart';
import '../services/voice.dart';
import 'widgets.dart';

class TranslateScreen extends StatefulWidget {
  const TranslateScreen({super.key});
  @override
  State<TranslateScreen> createState() => _TranslateScreenState();
}

class _TranslateScreenState extends State<TranslateScreen>
    with GlassesButtonListener {
  bool _busy = false;
  String _src = '';
  String _ar = '';
  File? _img;
  String _speechLang = 'en_US';

  static const _langs = {
    'en_US': 'إنگليزي',
    'tr_TR': 'تركي',
    'fa_IR': 'فارسي',
    'fr_FR': 'فرنسي',
    'de_DE': 'ألماني',
  };

  @override
  void onGlassesButton() => _fromImage();

  Future<void> _run(Future<String?> Function() getText, {String? from}) async {
    if (_busy) return;
    setState(() => _busy = true);
    final v = Voice.instance;
    try {
      final t = await getText();
      if (t == null || t.trim().isEmpty) {
        await v.say('ما لكيت نص');
        return;
      }
      await v.say('دا أترجم');
      String ar;
      try {
        ar = await Vision.toArabic(t, from: from);
      } catch (e) {
        if (AppSettings.hasCloud) {
          ar = await CloudAi.ask('ترجم هذا للعربي بس، بدون شرح:\n$t');
        } else {
          ar = 'ما كدرت أترجم. أول مرة لازم نت حتى ينزل ملف اللغة.';
        }
      }
      setState(() {
        _src = t;
        _ar = ar;
      });
      await v.say(ar);
    } catch (e) {
      setState(() => _ar = 'صار خطأ: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _fromImage() => _run(() async {
        final f = await SourceManager.instance.current.capturePhoto();
        if (f == null) return null;
        _img = f;
        return Vision.ocrLatin(f);
      });

  Future<void> _fromSpeech() => _run(() async {
        await Voice.instance.say('احچي هسه');
        _img = null;
        return Voice.instance.listen(localeId: _speechLang);
      }, from: _speechLang.substring(0, 2));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ترجمة')),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(20), children: [
          const Center(child: SourceChip()),
          const SizedBox(height: 20),
          Center(child: ShutterButton(busy: _busy, onTap: _fromImage)),
          const SizedBox(height: 20),
          BigButton(
              label: 'اسمع وترجم',
              icon: Icons.mic,
              color: const Color(0xFF0E7490),
              onTap: _busy ? null : _fromSpeech),
          const SizedBox(height: 12),
          Row(children: [
            const Text('لغة الكلام: ', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            DropdownButton<String>(
              value: _speechLang,
              style: const TextStyle(fontSize: 20),
              items: _langs.entries
                  .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                  .toList(),
              onChanged: (v) => setState(() => _speechLang = v!),
            ),
          ]),
          const SizedBox(height: 16),
          if (_ar.isNotEmpty)
            ResultCard(
                text: _src.isEmpty ? _ar : '$_ar\n\n— الأصل —\n$_src',
                image: _img,
                onRepeat: () => Voice.instance.say(_ar)),
        ]),
      ),
    );
  }
}
