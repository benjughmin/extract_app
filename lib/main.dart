import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'pages/splash_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'pages/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    // Correct way to set settings (no await)
    FirebaseFirestore.instance.settings = Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
    
    print('🔥 Firebase initialized with offline persistence');
  } catch (e) {
    print('❌ Error initializing Firebase: $e');
    // Continue with app initialization even if Firebase fails
  }
  
  // Set preferred device orientation
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final authService = AuthService();
  await authService.signInAnonymously();
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'e-Xtract',
      theme: ThemeData(
        primaryColor: const Color(0xFF34A853),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF34A853),
          primary: const Color(0xFF34A853),
          secondary: const Color(0xFF0F9D58),
        ),
        textTheme: GoogleFonts.montserratTextTheme(
          Theme.of(context).textTheme,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: const Color(0xFF34A853),
          foregroundColor: Colors.white,
          elevation: 0,
          titleTextStyle: GoogleFonts.montserrat(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF34A853),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            textStyle: GoogleFonts.montserrat(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      home: const AnimatedSplashScreenWidget(),
    );
  }
}