import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'base.dart';
import 'select_ewaste.dart';
import 'upload_or_camera.dart';

class ChatbotRedo extends StatefulWidget {
  final String initialCategory;
  final String? initialImagePath;
  final List<String> initialDetections;
  final Map<String, Map<String, String>> initialComponentImages;
  final List<int> initialBatch;

  const ChatbotRedo({
    super.key,
    required this.initialCategory,
    this.initialImagePath,
    required this.initialDetections,
    required this.initialComponentImages,
    required this.initialBatch,
  });

  @override
  State<ChatbotRedo> createState() => _ChatbotRedoState();
}

class _ChatbotRedoState extends State<ChatbotRedo> {
  late List<String> allDetections;
  late Map<String, Map<String, String>> allComponentImages;
  late List<int> allBatches;

  @override
  void initState() {
    super.initState();
    // Initialize with the initial data
    allDetections = List.from(widget.initialDetections);
    allComponentImages = Map.from(widget.initialComponentImages);
    allBatches = List.from(widget.initialBatch);
  }

  // Add method to show overlay
  void _showImageOverlay(BuildContext context, String imagePath) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(8),
          child: Stack(
            alignment: Alignment.center,
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  color: Colors.black87,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Container(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.8,
                        maxWidth: MediaQuery.of(context).size.width * 0.9,
                      ),
                      child: InteractiveViewer(
                        minScale: 0.5,
                        maxScale: 4.0,
                        child: Image.file(
                          File(imagePath),
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 30),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _addNewBatch({
    required List<String> newDetections,
    required Map<String, Map<String, String>> newComponentImages,
    required List<int> newBatch,
  }) {
    setState(() {
      allDetections.addAll(newDetections);
      allComponentImages.addAll(newComponentImages);
      allBatches.addAll(newBatch);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Base(
      title: 'AI Assistant',
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  Container(
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
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Device Category:',
                          style: GoogleFonts.montserrat(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.initialCategory,
                          style: GoogleFonts.montserrat(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (allComponentImages.isNotEmpty)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Input Images:',
                                style: GoogleFonts.montserrat(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white70,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                height: 150,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(15),
                                  child: ListView(
                                    scrollDirection: Axis.horizontal,
                                    children: [
                                      for (var imagePath in allComponentImages.keys)
                                        Padding(
                                          padding: const EdgeInsets.all(4.0),
                                          child: GestureDetector(
                                            onTap: () => _showImageOverlay(context, imagePath),
                                            child: Image.file(
                                              File(imagePath),
                                              fit: BoxFit.contain,
                                              width: MediaQuery.of(context).size.width * 0.8,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Detected Parts:',
                                style: GoogleFonts.montserrat(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white70,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                height: 150,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(15),
                                  child: ListView(
                                    scrollDirection: Axis.horizontal,
                                    children: [
                                      for (var entry in allComponentImages.entries)
                                        for (var componentEntry in entry.value.entries)
                                          Padding(
                                            padding: const EdgeInsets.all(4.0),
                                            child: GestureDetector(
                                              onTap: () => _showImageOverlay(context, componentEntry.value),
                                              child: Column(
                                                children: [
                                                  Expanded(
                                                    child: Image.file(
                                                      File(componentEntry.value),
                                                      fit: BoxFit.contain,
                                                    ),
                                                  ),
                                                  Text(
                                                    componentEntry.key.split('_')[0],
                                                    style: GoogleFonts.montserrat(
                                                      fontSize: 12,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SelectEwaste(fromChatbotRedo: true),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text('Change Device'),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => UploadOrCamera(
                          category: widget.initialCategory,
                          fromChatbotRedo: true,
                        ),
                      ),
                    );

                    if (result != null) {
                      setState(() {
                        allDetections.addAll(result['newDetections'] ?? []);
                        allComponentImages.addAll(result['newComponentImages'] ?? {});
                        allBatches.addAll(result['newBatch'] ?? []);
                      });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text('Upload New Batch'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}