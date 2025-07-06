import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '/pages/base.dart';
import 'dart:io';

class TestingGuideScreen extends StatelessWidget {
  final List<String> detectedComponents;
  final Map<String, dynamic> testInstructions;
  final Map<String, Map<String, String>> componentImages;

  const TestingGuideScreen({
    super.key,
    required this.detectedComponents,
    required this.testInstructions,
    required this.componentImages,
  });

  @override
  Widget build(BuildContext context) {
    return Base(
      title: 'Testing Guide',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: detectedComponents.map((component) {
          final instructions = testInstructions[component.toLowerCase()] as List<dynamic>?;
          final images = componentImages.entries
              .where((entry) => entry.value.keys.map((k) => k.toLowerCase()).contains(component.toLowerCase()))
              .map((entry) => entry.value[component])
              .whereType<String>()
              .toList();

          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    component[0].toUpperCase() + component.substring(1),
                    style: GoogleFonts.montserrat(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (images.isNotEmpty)
                    SizedBox(
                      height: 100,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: images.map((imgPath) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (_) => Dialog(
                                  backgroundColor: Colors.black,
                                  insetPadding: const EdgeInsets.all(12),
                                  child: InteractiveViewer(
                                    child: Image.file(
                                      File(imgPath),
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                              );
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                File(imgPath),
                                width: 200,
                                height: 200,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        )).toList(),
                      ),
                    ),
                    const SizedBox(height: 8),
                  if (instructions != null && instructions.isNotEmpty)
                    ...instructions.map((step) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('• ', style: TextStyle(fontSize: 18)),
                              Expanded(
                                child: Text(
                                  step,
                                  style: GoogleFonts.montserrat(fontSize: 16),
                                ),
                              ),
                            ],
                          ),
                        )),
                  if (instructions == null || instructions.isEmpty)
                    Text(
                      'No test instructions available for this part.',
                      style: GoogleFonts.montserrat(color: Colors.grey),
                    ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}