import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../main.dart';
import '../services/source_manager.dart';
import '../services/voice.dart';
import '../sources/glasses_source.dart';

/// زر كبير واضح مع وصف صوتي لقارئ الشاشة.
class BigButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final Color color;
  final Color fg;
  final double height;
  const BigButton(
      {super.key,
      required this.label,
      required this.icon,
      this.onTap,
      this.color = kPurple,
      this.fg = Colors.white,
      this.height = 96});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: fg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            textStyle: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
          onPressed: onTap,
          icon: Icon(icon, size: 40),
          label: Text(label),
        ),
      ),
    );
  }
}

/// زر «صوّر» الكبير الدائري، يقلّد زر النظارة.
class ShutterButton extends StatelessWidget {
  final VoidCallback? onTap;
  final bool busy;
  final String label;
  const ShutterButton({super.key, this.onTap, this.busy = false, this.label = 'صوّر'});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: busy ? 'جاري الشغل' : label,
      child: GestureDetector(
        onTap: busy ? null : onTap,
        child: Container(
          width: 220,
          height: 220,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: busy ? Colors.grey.shade800 : kYellow,
            border: Border.all(color: Colors.white, width: 6),
            boxShadow: const [BoxShadow(blurRadius: 24, color: Colors.black54)],
          ),
          alignment: Alignment.center,
          child: busy
              ? const CircularProgressIndicator(strokeWidth: 6)
              : Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.camera_alt, size: 72, color: Colors.black),
                  Text(label,
                      style: const TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          color: Colors.black)),
                ]),
        ),
      ),
    );
  }
}

/// يربط زر النظارة (إذا متصلة) بنفس فعل زر «صوّر».
mixin GlassesButtonListener<T extends StatefulWidget> on State<T> {
  StreamSubscription<GlassesEvent>? _sub;
  void onGlassesButton();

  @override
  void initState() {
    super.initState();
    _sub = SourceManager.instance.current.events.listen((e) {
      if (e.type == GlassesEventType.button) onGlassesButton();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    Voice.instance.stop();
    super.dispose();
  }
}

class ResultCard extends StatelessWidget {
  final String text;
  final File? image;
  final VoidCallback? onRepeat;
  const ResultCard({super.key, required this.text, this.image, this.onRepeat});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF1C1B29),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (image != null)
            ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(image!, height: 160, fit: BoxFit.cover)),
          const SizedBox(height: 12),
          SelectableText(text, style: const TextStyle(fontSize: 24, height: 1.5)),
          if (onRepeat != null) ...[
            const SizedBox(height: 12),
            BigButton(
                label: 'عيد الحچي',
                icon: Icons.volume_up,
                height: 72,
                onTap: onRepeat),
          ]
        ]),
      ),
    );
  }
}

class SourceChip extends StatelessWidget {
  const SourceChip({super.key});
  @override
  Widget build(BuildContext context) {
    final s = SourceManager.instance.current;
    return Chip(
      avatar: Icon(s.id == 'phone' ? Icons.phone_android : Icons.visibility,
          color: s.isConnected ? Colors.greenAccent : Colors.redAccent),
      label: Text('المصدر: ${s.title}', style: const TextStyle(fontSize: 16)),
    );
  }
}
