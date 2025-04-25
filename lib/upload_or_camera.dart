import 'package:extract_app/part_detection.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:extract_app/chatbot_screen.dart';
import 'package:extract_app/chatbot_redo.dart';
import 'dart:io';
import 'base.dart';

class UploadOrCamera extends StatefulWidget {
  final String category;
  final bool fromChatbotRedo;

  const UploadOrCamera({super.key, required this.category, this.fromChatbotRedo = false});

  @override
  State<UploadOrCamera> createState() => _UploadOrCameraState();
}

class _UploadOrCameraState extends State<UploadOrCamera> {
  final ImagePicker _picker = ImagePicker();
  List<XFile> _selectedImages = [];

  Future<void> _pickMultipleImages() async {
    final List<XFile>? images = await _picker.pickMultiImage();
    if (images != null && images.isNotEmpty) {
      setState(() {
        _selectedImages.addAll(images);
      });
    }
  }

  Future<void> _pickSingleImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(source: source);
    if (image != null) {
      setState(() {
        _selectedImages.add(image);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (widget.fromChatbotRedo) {
          // Ensure we return to ChatbotRedo with empty data if back is pressed
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => ChatbotRedo(
                initialCategory: widget.category,
                initialImagePath: null,
                initialDetections: [],
                initialComponentImages: {},
                initialBatch: [],
              ),
            ),
          );
          return false;
        }
        return true;
      },
      child: Base(
        title: widget.category,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 50),
              Text(
                'Upload pictures of your e-waste or use your camera.',
                style: GoogleFonts.montserrat(
                  color: Colors.white70,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              if (_selectedImages.isNotEmpty)
                SizedBox(
                  height: 300,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _selectedImages.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      return Stack(
                        children: [
                          Container(
                            width: 200,
                            height: 300,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.black, width: 4),
                            ),
                            child: ClipRRect(
                              child: Image.file(
                                File(_selectedImages[index].path),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedImages.removeAt(index);
                                });
                              },
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: Colors.redAccent,
                                  shape: BoxShape.circle,
                                ),
                                padding: const EdgeInsets.all(6),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),

              const SizedBox(height: 20),

              _buildUploadCameraButton(context, 'Upload Image', Icons.upload),
              const SizedBox(height: 10),
              _buildUploadCameraButton(context, 'Use Camera', Icons.camera_alt),

              if (_selectedImages.isNotEmpty) ...[
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () async {
                    List<Map<String, dynamic>> results = [];

                    for (var image in _selectedImages) {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PartDetectionScreen(
                            category: widget.category,
                            imagePath: image.path,
                          ),
                        ),
                      );

                      if (result != null) {
                        results.add({
                          'imagePath': image.path,
                          'detectedComponents': result['detectedComponents'] ?? [],
                          'croppedComponentImages': result['croppedComponentImages'] ?? {},
                        });
                      }
                    }

                    if (results.isNotEmpty) {
                      final List<String> newDetections = results
                          .expand((result) => result['detectedComponents'] as List<String>)
                          .toList();
                      final Map<String, Map<String, String>> newComponentImages = {
                        for (var result in results)
                          result['imagePath']: Map<String, String>.from(result['croppedComponentImages']),
                      };
                      final List<int> newBatch = List.generate(results.length, (i) => i);

                      // Navigate directly to ChatbotRedo with the new batch data
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatbotRedo(
                            initialCategory: widget.category,
                            initialImagePath: null,
                            initialDetections: newDetections,
                            initialComponentImages: newComponentImages,
                            initialBatch: newBatch,
                          ),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('No images were processed. Please try again.')),
                      );
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: MediaQuery.of(context).size.height * 0.018),
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
                    child: Center(
                      child: Text(
                        'Continue',
                        style: GoogleFonts.montserrat(
                          fontSize: MediaQuery.of(context).size.height * 0.02,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUploadCameraButton(
    BuildContext context,
    String label,
    IconData icon,
  ) {
    return GestureDetector(
      onTap: () {
        if (label == 'Upload Image') {
          _pickMultipleImages();
        } else if (label == 'Use Camera') {
          _pickSingleImage(ImageSource.camera);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF34A853), Color(0xFF0F9D58)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              offset: const Offset(0, 4),
              blurRadius: 10,
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 40),
            const SizedBox(width: 10),
            Text(
              label,
              style: GoogleFonts.montserrat(
                fontSize: 20,
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