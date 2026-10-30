import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/home_screen.dart';
import 'services/settings.dart';
import 'services/voice.dart';

const kPurple = Color(0xFF5B21B6);
const kYellow = Color(0xFFFFD60A);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppSettings.init();
  await Voice.instance.init();
  runApp(const AinApp());
}

class AinApp extends StatelessWidget {
  const AinApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'عين',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar', 'IQ'),
      supportedLocales: const [Locale('ar', 'IQ'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B0B12),
        colorScheme: ColorScheme.fromSeed(
            seedColor: kPurple, brightness: Brightness.dark, primary: kYellow),
        textTheme: Typography.whiteMountainView.apply(fontSizeFactor: 1.25),
        appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF0B0B12), centerTitle: true),
      ),
      home: const HomeScreen(),
    );
  }
}
