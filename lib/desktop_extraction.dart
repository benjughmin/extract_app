import 'package:flutter/material.dart';
import 'dart:io';
import 'base.dart'; // Keep Base

class DesktopExtraction extends StatelessWidget {
  final String imagePath;

  const DesktopExtraction({super.key, required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return Base(
      title: 'Extraction', // Keep Base title
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Selected Image:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 10),
            Image.file(
              File(imagePath),
              width: 300,
              height: 300,
              fit: BoxFit.cover,
            ),
          ],
        ),
      ),
    );
  }
}
