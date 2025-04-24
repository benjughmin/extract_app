import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'select_ewaste.dart';
import 'chatbot_screen.dart';
import 'part_detection.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Check if the app is opened for the first time
  final prefs = await SharedPreferences.getInstance();
  final bool isFirstOpen = prefs.getBool('isFirstOpen') ?? true; // Default to true if null

  runApp(MyApp(isFirstOpen: isFirstOpen));
}

class MyApp extends StatelessWidget {
  final bool isFirstOpen;

  const MyApp({super.key, required this.isFirstOpen});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'e-Xtract',
      theme: ThemeData(
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: const Color(0xFF1E1E1E),
      ),
      home: isFirstOpen ? const HomeScreen() : const SelectEwaste(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Get the screen dimensions for responsive layout
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(height: screenHeight * 0.04),
                      ShaderMask(
                        shaderCallback:
                            (bounds) => const LinearGradient(
                              colors: [Colors.greenAccent, Colors.green],
                            ).createShader(bounds),
                        child: Text(
                          'e-Xtract',
                          style: GoogleFonts.montserrat(
                            fontSize:
                                screenHeight * 0.07, // Responsive font size
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.01),
                      Text(
                        'Identify and extract valuable components in your e-waste instantly.',
                        style: GoogleFonts.montserrat(
                          fontSize:
                              screenHeight * 0.022, // Responsive font size
                          fontWeight: FontWeight.w600,
                          color: Colors.white70,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: screenHeight * 0.02),
                      SizedBox(
                        height: screenHeight * 0.35, // Responsive height
                        child: PageView(
                          children: [
                            _buildSlide(
                              context: context,
                              icon: Icons.document_scanner_rounded,
                              title: 'Scan',
                              subtitle: 'Analyze e-waste using your camera',
                            ),
                            _buildSlide(
                              context: context,
                              icon: Icons.precision_manufacturing_rounded,
                              title: 'Extract',
                              subtitle: 'Identify components for recovery',
                            ),
                            _buildSlide(
                              context: context,
                              icon: Icons.attach_money_rounded,
                              title: 'Profit',
                              subtitle: 'Discover the value of recovered parts',
                            ),
                            _buildSlide(
                              context: context,
                              icon: Icons.chat_bubble_outline,
                              title: 'Get Help',
                              subtitle: 'Chat with our AI assistant',
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.02),

                      // Get Started button
                      _buildButton(
                        context: context,
                        text: 'Get Started',
                        onTap: () async {
                          // Mark the app as no longer being opened for the first time
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setBool('isFirstOpen', false);

                          // Navigate to SelectEwaste screen
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SelectEwaste(),
                            ),
                          );
                        },
                      ),

                      SizedBox(height: screenHeight * 0.015),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSlide({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          height: screenHeight * 0.12,
          width: screenHeight * 0.12,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 8,
                offset: const Offset(2, 4),
              ),
            ],
          ),
          child: Icon(icon, size: screenHeight * 0.07, color: Colors.white),
        ),
        SizedBox(height: screenHeight * 0.015),
        Text(
          title,
          style: GoogleFonts.montserrat(
            fontSize: screenHeight * 0.045,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        SizedBox(height: screenHeight * 0.01),
        Text(
          subtitle,
          style: GoogleFonts.montserrat(
            fontSize: screenHeight * 0.02,
            color: Colors.white70,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildButton({
    required BuildContext context,
    required String text,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    final screenHeight = MediaQuery.of(context).size.height;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: screenHeight * 0.02),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF34A853), Color(0xFF0F9D58)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              offset: const Offset(0, 4),
              blurRadius: 10,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: screenHeight * 0.026, color: Colors.white),
              SizedBox(width: screenHeight * 0.01),
            ],
            Text(
              text,
              style: GoogleFonts.montserrat(
                fontSize: screenHeight * 0.022,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
