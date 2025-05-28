import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class Base extends StatelessWidget {
  final String title;
  final Widget child;

  const Base({super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 30, 30, 30),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Colors.greenAccent, Colors.green],
            ).createShader(bounds),
            child: const Icon(Icons.keyboard_arrow_left_rounded, color: Colors.white, size: 32),
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Colors.greenAccent, Colors.green],
          ).createShader(bounds),
          child: Text(
            title,
            style: GoogleFonts.montserrat(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        centerTitle: true,
      ),
      body: Center(child: child),
    );
  }
}