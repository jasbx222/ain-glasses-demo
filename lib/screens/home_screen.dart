import 'package:flutter/material.dart';

import '../main.dart';
import '../services/source_manager.dart';
import '../services/voice.dart';
import 'inventory_screen.dart';
import 'read_screen.dart';
import 'settings_screen.dart';
import 'translate_screen.dart';
import 'widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    SourceManager.instance.addListener(_r);
    Future.delayed(const Duration(milliseconds: 600),
        () => Voice.instance.say('هلا بيك بعين. اختار: قراءة، ترجمة، لو جرد.'));
  }

  void _r() => setState(() {});

  @override
  void dispose() {
    SourceManager.instance.removeListener(_r);
    super.dispose();
  }

  void _go(Widget w, String say) {
    Voice.instance.say(say);
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('عين 👁️', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            tooltip: 'الإعدادات',
            iconSize: 34,
            icon: const Icon(Icons.settings),
            onPressed: () => _go(const SettingsScreen(), 'الإعدادات'),
          )
        ],
      ),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(20), children: [
          const Center(child: SourceChip()),
          const SizedBox(height: 8),
          const Text('مساعد النظارة الذكية — نسخة تجريبية',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 18, color: Colors.white70)),
          const SizedBox(height: 24),
          BigButton(
              label: 'قراءة للمكفوفين',
              icon: Icons.menu_book,
              height: 130,
              onTap: () => _go(const ReadScreen(),
                  'وضع القراءة. دوس صوّر وأقرالك اللوحة لو علبة الدوا.')),
          const SizedBox(height: 18),
          BigButton(
              label: 'ترجمة',
              icon: Icons.translate,
              height: 130,
              color: const Color(0xFF0E7490),
              onTap: () => _go(const TranslateScreen(),
                  'وضع الترجمة. صوّر نص لو احچي وأترجمه للعربي.')),
          const SizedBox(height: 18),
          BigButton(
              label: 'جرد باركود',
              icon: Icons.qr_code_scanner,
              height: 130,
              color: const Color(0xFF15803D),
              onTap: () => _go(const InventoryScreen(), 'وضع الجرد. وجّه الكاميرة على الباركود.')),
          const SizedBox(height: 18),
          BigButton(
              label: 'الإعدادات والنظارة',
              icon: Icons.bluetooth_searching,
              height: 90,
              color: const Color(0xFF27272A),
              onTap: () => _go(const SettingsScreen(), 'الإعدادات')),
          const SizedBox(height: 24),
          const Text('💡 هسه يشتغل بكاميرة التلفون. لما توصل النظارة اختارها من الإعدادات.',
              style: TextStyle(fontSize: 16, color: kYellow)),
        ]),
      ),
    );
  }
}
