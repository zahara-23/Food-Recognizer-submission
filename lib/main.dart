import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'core/theme/app_theme.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Muat GEMINI_API_KEY dari .env (lihat README untuk cara mengisinya).
  await dotenv.load(fileName: '.env');

  // Firebase dipakai untuk fitur Firebase ML (download model dinamis).
  // Dibungkus try-catch agar aplikasi tetap bisa berjalan (memakai model
  // asset lokal sebagai fallback) meski project Firebase belum
  // dikonfigurasi, mis. saat baru clone project ini.
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase belum dikonfigurasi, memakai model asset lokal. ($e)');
  }

  runApp(const FoodRecognizerApp());
}

class FoodRecognizerApp extends StatelessWidget {
  const FoodRecognizerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Food Recognizer',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const HomeScreen(),
    );
  }
}
