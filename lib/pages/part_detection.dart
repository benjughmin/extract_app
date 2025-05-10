import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import '/pages/assistant.dart';
import '/pages/base.dart';

class DetectionPage extends StatefulWidget {
  final String category;
  final List<File> selectedImages;
  final String sessionId;

  const DetectionPage({
    Key? key,
    required this.category,
    required this.selectedImages,
    required this.sessionId,
  }) : super(key: key);

  @override
  _DetectionPageState createState() => _DetectionPageState();
}

class _DetectionPageState extends State<DetectionPage> with SingleTickerProviderStateMixin {
  late Interpreter _interpreter;
  bool _isModelLoaded = false;
  List<String> _labels = [];
  
  List<List<Detection>> _allDetections = [];
  List<Map<String, String>> _allCroppedComponents = [];
  
  int _currentImageIndex = 0;
  late PageController _pageController;
  List<GlobalKey> _imageWithBoxesKeys = [];
  late AnimationController _animationController;
  List<bool> _processingStatus = [];

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();
    
    _pageController = PageController(initialPage: 0);
    
    _imageWithBoxesKeys = List.generate(
      widget.selectedImages.length,
      (index) => GlobalKey(),
    );
    
    _allDetections = List.generate(
      widget.selectedImages.length,
      (index) => [],
    );
    
    _allCroppedComponents = List.generate(
      widget.selectedImages.length,
      (index) => {},
    );

    _processingStatus = List.generate(
      widget.selectedImages.length,
      (index) => false,
    );
    
    _loadModelAndLabels().then((_) {
      _processNextImage();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pageController.dispose();
    if (_isModelLoaded) {
      _interpreter.close();
    }
    super.dispose();
  }

  Future<void> _loadModelAndLabels() async {
    try {
      String modelPath = _getModelPathBasedOnCategory(widget.category);
      _interpreter = await Interpreter.fromAsset(modelPath);
      
      await _loadLabels();
      
      setState(() {
        _isModelLoaded = true;
      });
      
      print("Model loaded successfully");
      print("Input shape: ${_interpreter.getInputTensor(0).shape}");
      print("Output shape: ${_interpreter.getOutputTensor(0).shape}");
    } catch (e) {
      print("Failed to load model: $e");
    }
  }

  Future<void> _loadLabels() async {
    try {
      final labelData = await rootBundle.loadString(
        _getLabelPathBasedOnCategory(widget.category),
      );
      setState(() {
        _labels = labelData.split('\n')
            .map((label) => label.trim())
            .where((label) => label.isNotEmpty)
            .toList();
      });
      print("Labels loaded: ${_labels.length}");
    } catch (e) {
      print("Failed to load labels: $e");
    }
  }

  Future<void> _processNextImage() async {
    if (_currentImageIndex >= widget.selectedImages.length) {
      return;
    }

    setState(() {
      _processingStatus[_currentImageIndex] = true;
    });

    try {
      await _processImage(widget.selectedImages[_currentImageIndex], _currentImageIndex);
    } finally {
      setState(() {
        _processingStatus[_currentImageIndex] = false;
      });

      _currentImageIndex++;
      if (_currentImageIndex < widget.selectedImages.length) {
        _processNextImage();
      } else {
        setState(() {
          _currentImageIndex = 0;
        });
      }
    }
  }

  Future<void> _processImage(File imageFile, int imageIndex) async {
    try {
      print("Processing image ${imageIndex + 1} of ${widget.selectedImages.length}");
      
      final rawBytes = await imageFile.readAsBytes();
      final decoded = img.decodeImage(rawBytes);
      if (decoded == null) {
        print("Failed to decode image.");
        return;
      }
      
      await Future.delayed(Duration.zero);
      
      final resized = img.copyResize(decoded, width: 1280, height: 1280);
      final inputImage = Float32List(1280 * 1280 * 3);
      
      int index = 0;
      for (int y = 0; y < 1280; y++) {
        for (int x = 0; x < 1280; x++) {
          final p = resized.getPixel(x, y);
          inputImage[index++] = p.r / 255.0;
          inputImage[index++] = p.g / 255.0;
          inputImage[index++] = p.b / 255.0;
        }
        
        if (y % 128 == 0) {
          await Future.delayed(Duration.zero);
        }
      }
      
      final input = inputImage.reshape([1, 1280, 1280, 3]);
      final outputShape = _interpreter.getOutputTensor(0).shape;
      final output = List.generate(
        outputShape[0],
        (_) => List.generate(
          outputShape[1],
          (_) => List.filled(outputShape[2], 0.0),
        ),
      );
      
      _interpreter.run(input, output);
      
      _parseAndStoreDetections(output[0], imageIndex);
      
    } catch (e) {
      print("Error processing image: $e");
    }
  }

  void _parseAndStoreDetections(
    List<List<double>> detections,
    int imageIndex, {
    double threshold = 0.25,
  }) {
    List<Detection> dets = [];
    
    for (int i = 0; i < detections[0].length; i++) {
      final pred = List.generate(detections.length, (j) => detections[j][i]);
      if (pred.length < 5) continue;
      
      final cx = pred[0];
      final cy = pred[1];
      final w = pred[2];
      final h = pred[3];
      
      final x = cx - w / 2;
      final y = cy - h / 2;
      
      final scores = pred.sublist(4);
      final maxScore = scores.reduce((a, b) => a > b ? a : b);
      final clsIdx = scores.indexOf(maxScore);
      
      if (maxScore < threshold) continue;
      
      final name = (clsIdx < _labels.length) ? _labels[clsIdx] : 'Unknown';

      // Add filtering for unwanted components
      if (!_shouldIncludeComponent(name)) continue;

      dets.add(
        Detection(
          score: maxScore,
          boundingBox: Rect(x: x, y: y, width: w, height: h),
          className: name,
        ),
      );
    }
    
    final filteredDetections = _applyNMS(dets, 0.4);
    filteredDetections.sort((a, b) => b.score.compareTo(a.score));
    
    print("DETECTED PARTS FOR IMAGE $imageIndex:");
    for (var det in filteredDetections) {
      print("  - ${det.className} (${(det.score * 100).toStringAsFixed(1)}%)");
    }
    
    setState(() {
      _allDetections[imageIndex] = filteredDetections;
    });
  }

  List<Detection> _applyNMS(List<Detection> dets, double iouThreshold) {
    dets.sort((a, b) => b.score.compareTo(a.score));
    List<Detection> kept = [];
    
    while (dets.isNotEmpty) {
      final cur = dets.removeAt(0);
      dets.removeWhere((d) => _calculateIoU(cur.boundingBox, d.boundingBox) > iouThreshold);
      kept.add(cur);
    }
    
    return kept;
  }

  double _calculateIoU(Rect box1, Rect box2) {
    final intersectionX = (box1.x + box1.width).clamp(box2.x, box2.x + box2.width) - 
                         box1.x.clamp(box2.x, box2.x + box2.width);
    final intersectionY = (box1.y + box1.height).clamp(box2.y, box2.y + box2.height) - 
                         box1.y.clamp(box2.y, box2.y + box2.height);
    
    if (intersectionX < 0 || intersectionY < 0) return 0;
    
    final intersectionArea = intersectionX * intersectionY;
    final box1Area = box1.width * box1.height;
    final box2Area = box2.width * box2.height;
    final unionArea = box1Area + box2Area - intersectionArea;
    
    return intersectionArea / unionArea;
  }

  String _getModelPathBasedOnCategory(String category) {
    switch (category) {
      case 'Smartphone':
        return 'assets/models/smartphone/best_phone_float16.tflite';
      case 'Laptop':
        return 'assets/models/laptop/best_laptop_float16.tflite';
      case 'Desktop':
        return 'assets/models/computer/best_computer_float16.tflite';
      case 'Router':
      case 'Landline':
        return 'assets/models/telecom/best_router-1_float16.tflite';
      default:
        throw Exception("Model not found for category: $category");
    }
  }

  String _getLabelPathBasedOnCategory(String category) {
    switch (category) {
      case 'Smartphone':
        return 'assets/models/smartphone/labels.txt';
      case 'Laptop':
        return 'assets/models/laptop/labels.txt';
      case 'Desktop':
        return 'assets/models/computer/labels.txt';
      case 'Router':
      case 'Landline':
        return 'assets/models/telecom/labels.txt';
      default:
        throw Exception("Label file not found for category: $category");
    }
  }

  Future<Map<String, String>> _cropAllDetectedComponents(
    String imagePath,
    List<Detection> detections,
  ) async {
    Map<String, String> componentImages = {};

    for (var detection in detections) {
      // Skip unwanted components
      if (!_shouldIncludeComponent(detection.className)) continue;

      final componentPath = await _cropComponentImage(
        imagePath,
        detection.boundingBox,
        detection.className,
      );

      if (componentPath.isNotEmpty) {
        String key = detection.className;
        int counter = 1;
        while (componentImages.containsKey(key)) {
          key = "${detection.className}_$counter";
          counter++;
        }
        componentImages[key] = componentPath;
      }
    }

    return componentImages;
  }

  Future<String> _cropComponentImage(
    String imagePath,
    Rect boundingBox,
    String componentName,
  ) async {
    try {
      final rawBytes = await File(imagePath).readAsBytes();
      final decoded = img.decodeImage(rawBytes);
      
      if (decoded == null) return "";
      
      final imageWidth = decoded.width.toDouble();
      final imageHeight = decoded.height.toDouble();
      
      int padX = (boundingBox.width * imageWidth * 0.1).round();
      int padY = (boundingBox.height * imageHeight * 0.1).round();
      
      int x = (boundingBox.x * imageWidth - padX).round().clamp(0, decoded.width - 1);
      int y = (boundingBox.y * imageHeight - padY).round().clamp(0, decoded.height - 1);
      int width = (boundingBox.width * imageWidth + padX * 2).round().clamp(1, decoded.width - x);
      int height = (boundingBox.height * imageHeight + padY * 2).round().clamp(1, decoded.height - y);
      
      final cropped = img.copyCrop(
        decoded,
        x: x,
        y: y,
        width: width,
        height: height,
      );
      
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final sanitizedName = componentName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      final path = '${tempDir.path}/component_${sanitizedName}_$timestamp.jpg';
      
      final file = File(path);
      await file.writeAsBytes(img.encodeJpg(cropped, quality: 90));
      
      return path;
    } catch (e) {
      print("Error cropping component: $e");
      return "";
    }
  }

  String _formatClassName(String rawName) {
    return rawName
        .split('_')
        .map((word) => word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  // New method to filter unwanted components based on category
  bool _shouldIncludeComponent(String componentName) {
    if ((widget.category == 'Landline' && componentName == 'antenna') ||
        (widget.category == 'Router' && componentName == 'speaker')) {
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    
    return Base(
      title: 'Detection Results',
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.04,
            vertical: screenHeight * 0.02,
          ),
          child: Column(
            children: [
              RepaintBoundary(
                key: _currentImageIndex < widget.selectedImages.length 
                    ? _imageWithBoxesKeys[_currentImageIndex]
                    : GlobalKey(),
                child: Container(
                  width: double.infinity,
                  height: screenHeight * 0.3,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: widget.selectedImages.length,
                    onPageChanged: (index) {
                      print("PAGE CHANGED TO: $index");
                      setState(() {
                        _currentImageIndex = index;
                      });
                    },
                    itemBuilder: (context, index) {
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.file(
                            widget.selectedImages[index],
                            fit: BoxFit.contain,
                          ),
                          
                          _processingStatus[index]
                              ? const Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.greenAccent,
                                  ),
                                )
                              : _buildBoundingBoxes(index),
                              
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${index + 1}/${widget.selectedImages.length}',
                                style: GoogleFonts.robotoCondensed(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              SizedBox(height: screenHeight * 0.024),
              
              Text(
                'Detected Parts',
                style: GoogleFonts.montserrat(
                  color: Colors.white,
                  fontSize: screenHeight * 0.03,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              
              Expanded(
                child: _buildDetectedPartsList(),
              ),
              
              GestureDetector(
                onTap: () async {
                  // Disable tap if processing is ongoing or no detections exist for the current image
                  if (_processingStatus.contains(true) ||
                      (_currentImageIndex < _allDetections.length &&
                       _allDetections[_currentImageIndex].isEmpty)) {
                    return;
                  }

                  List<String> allDetectedComponents = [];
                  Map<String, Map<String, String>> allComponentImages = {};

                  for (int i = 0; i < widget.selectedImages.length; i++) {
                    if (_allDetections[i].isNotEmpty) {
                      // Collect detected components
                      allDetectedComponents.addAll(
                        _allDetections[i]
                            .where((detection) => _shouldIncludeComponent(detection.className))
                            .map((det) => det.className),
                      );

                      final String imagePath = widget.selectedImages[i].path;

                      // Crop components if not already cropped
                      if (_allCroppedComponents[i].isEmpty) {
                        _allCroppedComponents[i] = await _cropAllDetectedComponents(
                          imagePath,
                          _allDetections[i],
                        );
                      }

                      allComponentImages[imagePath] = _allCroppedComponents[i];
                    }
                  }

                  // Navigate to the next page with the collected data
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => ChatbotRedo(
                        initialCategory: widget.category,
                        initialImagePath: widget.selectedImages.isNotEmpty
                            ? widget.selectedImages[0].path
                            : null,
                        initialDetections: allDetectedComponents,
                        initialComponentImages: allComponentImages,
                        initialBatch: [widget.sessionId],
                      ),
                    ),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: screenHeight * 0.018),
                  margin: const EdgeInsets.only(top: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: (_processingStatus.contains(true) ||
                              (_currentImageIndex < _allDetections.length &&
                               _allDetections[_currentImageIndex].isEmpty))
                          ? [Colors.grey.shade700, Colors.grey.shade600]
                          : [Color(0xFF34A853), Color(0xFF0F9D58)],
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
                        fontSize: screenHeight * 0.02,
                        fontWeight: FontWeight.bold,
                        color: (_processingStatus.contains(true) ||
                                (_currentImageIndex < _allDetections.length &&
                                 _allDetections[_currentImageIndex].isEmpty))
                            ? Colors.grey.shade300
                            : Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildBoundingBoxes(int imageIndex) {
    if (imageIndex >= _allDetections.length || _allDetections[imageIndex].isEmpty) {
      return Container();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final imageWidth = constraints.maxWidth;
        final imageHeight = constraints.maxHeight;

        return Stack(
          children: _allDetections[imageIndex]
              .where((detection) => _shouldIncludeComponent(detection.className))
              .map((detection) {
                final left = detection.boundingBox.x * imageWidth;
                final top = detection.boundingBox.y * imageHeight;
                final width = detection.boundingBox.width * imageWidth;
                final height = detection.boundingBox.height * imageHeight;

                return Positioned(
                  left: left,
                  top: top,
                  width: width,
                  height: height,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.greenAccent, width: 2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.8),
                          borderRadius: const BorderRadius.only(
                            bottomRight: Radius.circular(4),
                          ),
                        ),
                        child: Text(
                          '${_formatClassName(detection.className)} ${(detection.score * 100).toStringAsFixed(1)}%',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                );
              })
              .toList(),
        );
      },
    );
  }
  
  Widget _buildDetectedPartsList() {
    if (_processingStatus[_currentImageIndex]) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RotationTransition(
              turns: _animationController,
              child: const CircularProgressIndicator(color: Colors.greenAccent),
            ),
            const SizedBox(height: 16),
            Text(
              'Analyzing image...',
              style: GoogleFonts.montserrat(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      );
    }
    
    if (_currentImageIndex >= _allDetections.length || 
        _allDetections[_currentImageIndex].isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'No components detected.',
              style: GoogleFonts.robotoCondensed(
                fontSize: MediaQuery.of(context).size.height * 0.022,
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: MediaQuery.of(context).size.height * 0.018),
            Text(
              'Please try again with a clearer image or different angle.',
              textAlign: TextAlign.center,
              style: GoogleFonts.robotoCondensed(
                fontSize: MediaQuery.of(context).size.height * 0.018,
                color: Colors.white60,
              ),
            ),
            SizedBox(height: MediaQuery.of(context).size.height * 0.024),
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
              },
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: MediaQuery.of(context).size.width * 0.1,
                  vertical: MediaQuery.of(context).size.height * 0.014,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.redAccent, Colors.red],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      offset: const Offset(0, 3),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Text(
                  'Try Another Image',
                  style: GoogleFonts.montserrat(
                    fontSize: MediaQuery.of(context).size.height * 0.018,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      itemCount: _allDetections[_currentImageIndex]
          .where((detection) => _shouldIncludeComponent(detection.className))
          .toList()
          .length,
      itemBuilder: (context, index) {
        final filteredDetections = _allDetections[_currentImageIndex]
            .where((detection) => _shouldIncludeComponent(detection.className))
            .toList();

        final detection = filteredDetections[index];

        return Card(
          color: Colors.white10,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFF1E1E1E),
              child: Text(
                '${index + 1}',
                style: const TextStyle(color: Colors.white),
              ),
            ),
            title: Text(
              _formatClassName(detection.className),
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            trailing: Text(
              '${(detection.score * 100).toStringAsFixed(1)}%',
              style: GoogleFonts.robotoCondensed(
                color: Colors.greenAccent,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        );
      },
    );
  }
}

class Detection {
  final double score;
  final Rect boundingBox;
  final String className;
  
  Detection({
    required this.score,
    required this.boundingBox,
    required this.className,
  });
}

class Rect {
  final double x, y, width, height;
  
  Rect({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });
}