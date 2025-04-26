import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';

class PartDetectionScreen extends StatefulWidget {
  final String category;
  final String imagePath;

  const PartDetectionScreen({
    super.key,
    required this.category,
    required this.imagePath,
  });

  @override
  State<PartDetectionScreen> createState() => _PartDetectionScreenState();
}

class _PartDetectionScreenState extends State<PartDetectionScreen>
    with SingleTickerProviderStateMixin {
  late Interpreter _interpreter;
  late File _image;
  bool _isProcessing = false;
  bool _isModelLoaded = false;
  List<String> _labels = [];
  List<Detection> _finalDetections = [];
  final GlobalKey _imageWithBoxesKey = GlobalKey();
  String? _processedImagePath;
  Map<String, String> _croppedComponentImages = {};

  // Animation controller for rotating progress indicator
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();

    // Initialize the animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(); // Continuously repeat the animation

    _image = File(widget.imagePath); // set image first
    _loadModelAndProcessImage(); // handles model loading + inference
  }

  @override
  void dispose() {
    _animationController.dispose(); // Clean up the controller
    super.dispose();
  }

  Future<void> _loadModelAndProcessImage() async {
    if (!_isModelLoaded) {
      await _loadModel();
    }
    if (_isModelLoaded) {
      await _loadLabels(); // Load labels after model is loaded

      // Set processing state to true and make sure UI updates
      setState(() => _isProcessing = true);

      // Give the UI thread time to update before heavy processing
      await Future.delayed(const Duration(milliseconds: 200));

      // Process the image on a microtask to not directly block the UI thread
      Future.microtask(() async {
        try {
          await _processImage(_image);
        } finally {
          // Update UI once processing is complete
          if (mounted) {
            setState(() => _isProcessing = false);
          }
        }
      });
    }
  }

  Future<void> _loadLabels() async {
    final labelData = await rootBundle.loadString(
      _getLabelPathBasedOnCategory(widget.category),
    );
    setState(() {
      _labels = labelData.split('\n').map((label) => label.trim()).toList();
    });
  }

  Future<void> _loadModel() async {
    try {
      print("Loading model...");
      String modelPath = _getModelPathBasedOnCategory(widget.category);
      _interpreter = await Interpreter.fromAsset(modelPath);
      setState(() {
        _isModelLoaded = true;
      });
      print("Model loaded successfully.");
      print("Input shape: ${_interpreter.getInputTensor(0).shape}");
      print("Output shape: ${_interpreter.getOutputTensor(0).shape}");
    } catch (e) {
      print("Failed to load model: $e");
    }
  }

  // Get model path based on category
  String _getModelPathBasedOnCategory(String category) {
    switch (category) {
      case 'Smartphone':
        return 'assets/models/smartphone/best_phone_float16.tflite';
      case 'Laptop':
        return 'assets/models/laptop/best_laptop_float16.tflite';
      case 'Desktop':
        return 'assets/models/computer/best_computer_float16.tflite';
      case 'Router':
      case 'Landline Phone':
        return 'assets/models/telecom/best_router-1_float16.tflite';
      default:
        throw Exception("Model not found for category: $category");
    }
  }

  // Get label path based on category
  String _getLabelPathBasedOnCategory(String category) {
    switch (category) {
      case 'Smartphone':
        return 'assets/models/smartphone/labels.txt';
      case 'Laptop':
        return 'assets/models/laptop/labels.txt';
      case 'Desktop':
        return 'assets/models/computer/labels.txt';
      case 'Router':
      case 'Landline Phone':
        return 'assets/models/telecom/labels.txt';
      default:
        throw Exception("Label file not found for category: $category");
    }
  }

  Future<void> _processImage(File imageFile) async {
    try {
      // Set processing state immediately
      setState(() {
        _isProcessing = true;
      });

      // Use compute to run in a separate isolate
      await Future.delayed(Duration.zero); // Allow UI to update first

      final rawBytes = await imageFile.readAsBytes();
      final decoded = img.decodeImage(rawBytes);
      if (decoded == null) {
        print("Failed to decode image.");
        return;
      }

      // Allow UI to update by yielding execution
      await Future.delayed(Duration.zero);

      final resized = img.copyResize(decoded, width: 1280, height: 1280);
      final inputImage = Float32List(1280 * 1280 * 3);

      // Process the image in chunks to avoid blocking UI
      int index = 0;
      for (int y = 0; y < 1280; y++) {
        for (int x = 0; x < 1280; x++) {
          final p = resized.getPixel(x, y);
          inputImage[index++] = p.r / 255.0;
          inputImage[index++] = p.g / 255.0;
          inputImage[index++] = p.b / 255.0;
        }

        // Every N rows, yield to UI thread
        if (y % 128 == 0) {
          await Future.delayed(Duration.zero);
        }
      }

      final input = inputImage.reshape([1, 1280, 1280, 3]);
      final outputTensor = _interpreter.getOutputTensor(0);
      final shape = outputTensor.shape;
      final output = List.generate(
        shape[0],
        (_) => List.generate(shape[1], (_) => List.filled(shape[2], 0.0)),
      );

      print("Running inference...");
      await Future.delayed(Duration.zero); // Allow UI to update

      _interpreter.run(input, output);
      print("Inference completed.");

      _parseDetections(output[0], threshold: 0.5);
    } catch (e) {
      print("Inference failed: $e");
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _parseDetections(
    List<List<double>> detections, {
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

      dets.add(
        Detection(
          score: maxScore,
          boundingBox: Rect(x: x, y: y, width: w, height: h),
          className: name,
        ),
      );
    }

    final filtered = applyNMS(dets, 0.4);

    for (var det in filtered) {
      print("Final Detection after NMS:");
      print(" - Class: ${det.className}");
      print(" - Confidence: ${det.score.toStringAsFixed(2)}");
      print(
        " - Bounding Box (x: ${det.boundingBox.x.toStringAsFixed(4)}, "
        "y: ${det.boundingBox.y.toStringAsFixed(4)}, "
        "w: ${det.boundingBox.width.toStringAsFixed(4)}, "
        "h: ${det.boundingBox.height.toStringAsFixed(4)})",
      );
      print("-------------------------");
    }

    setState(() => _finalDetections = filtered);
  }

  List<Detection> applyNMS(List<Detection> dets, double iouThreshold) {
    dets.sort((a, b) => b.score.compareTo(a.score));
    List<Detection> kept = [];
    while (dets.isNotEmpty) {
      final cur = dets.removeAt(0);
      dets.removeWhere(
        (d) =>
            cur.boundingBox.intersectionOverUnion(d.boundingBox) > iouThreshold,
      );
      kept.add(cur);
    }
    return kept;
  }

  @override
  Widget build(BuildContext context) {
    // Get screen dimensions for responsive layout
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: ShaderMask(
          shaderCallback:
              (bounds) => const LinearGradient(
                colors: [Colors.greenAccent, Colors.green],
              ).createShader(bounds),
          child: Text(
            'Detection Results',
            style: GoogleFonts.montserrat(
              color: Colors.white,
              fontSize: screenHeight * 0.03,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.04,
            vertical: screenHeight * 0.02,
          ),
          child: Column(
            children: [
              // Image container with bounding boxes - add the key
              RepaintBoundary(
                key: _imageWithBoxesKey,
                child: Container(
                  width: double.infinity,
                  height: screenHeight * 0.3,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.greenAccent.withOpacity(0.3),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Base image
                      Image.file(_image, fit: BoxFit.contain),

                      // Bounding boxes overlay
                      _buildBoundingBoxes(),
                    ],
                  ),
                ),
              ),
              SizedBox(height: screenHeight * 0.024),

              // Processing indicator
              if (_isProcessing)
                Column(
                  children: [
                    // Animated Rotating Circular Progress Indicator
                    RotationTransition(
                      turns: _animationController,
                      child: const CircularProgressIndicator(
                        color: Colors.greenAccent,
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.012),
                    Text(
                      'Analyzing image. This may take a while.',
                      style: GoogleFonts.montserrat(
                        fontSize: screenHeight * 0.018,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),

              // No detections message
              if (!_isProcessing && _finalDetections.isEmpty)
                Text(
                  'No objects detected.',
                  style: GoogleFonts.robotoCondensed(
                    fontSize: screenHeight * 0.018,
                    color: Colors.white70,
                  ),
                ),

              // Detected objects list
              if (!_isProcessing && _finalDetections.isNotEmpty) ...[
                Center(
                  child: Text(
                    'Detected Parts',
                    style: GoogleFonts.montserrat(
                      fontSize: screenHeight * 0.032,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                SizedBox(height: screenHeight * 0.012),

                SizedBox(
                  height: screenHeight * 0.3,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    itemCount: _finalDetections.length,
                    itemBuilder: (context, index) {
                      final det = _finalDetections[index];
                      return Card(
                        color: Colors.white10,
                        margin: EdgeInsets.only(bottom: screenHeight * 0.004),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFF1E1E1E),
                            child: Text('${index + 1}',
                                style: const TextStyle(color: Colors.white)),
                          ),
                          title: Text(
                            formatClassName(det.className),
                            style: GoogleFonts.montserrat(
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          subtitle: Text(
                            'Confidence: ${(det.score * 100).toStringAsFixed(1)}%',
                            style: GoogleFonts.robotoCondensed(color: Colors.white70),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],

              const Spacer(),

              // Replace the Back button with one that returns detection results
              GestureDetector(
                onTap: () async {
                  // Capture the processed image if we have detections
                  if (_finalDetections.isNotEmpty && !_isProcessing) {
                    await _captureProcessedImage();
                  }

                  // Get the list of detected component names
                  List<String> detectedComponents =
                      _finalDetections
                          .map((detection) => detection.className)
                          .toList();

                  // Return the processed image path, detected components, and cropped component images
                  Navigator.pop(context, {
                    'imagePath': _processedImagePath ?? widget.imagePath,
                    'detectedComponents': detectedComponents,
                    'croppedComponentImages': _croppedComponentImages,
                  });
                },
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: screenHeight * 0.018),
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
                        fontSize: screenHeight * 0.02,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
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

  String formatClassName(String rawName) {
    return rawName
        .replaceAll('-', ' ') // Replace underscores with spaces
        .split(' ')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  // Separate method to build bounding boxes as an overlay
  Widget _buildBoundingBoxes() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final imageWidth = constraints.maxWidth;
        final imageHeight = constraints.maxHeight;

        return Stack(
          children:
              _finalDetections.map((detection) {
                // Calculate position based on image dimensions
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
                          '${detection.className} ${(detection.score * 100).toStringAsFixed(1)}%',
                          style: GoogleFonts.robotoCondensed(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
        );
      },
    );
  }

  // New method to capture the processed image with bounding boxes
  Future<void> _captureProcessedImage() async {
    try {
      // Capture the image with bounding boxes
      final RenderRepaintBoundary boundary =
          _imageWithBoxesKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;

      final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      final ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );

      if (byteData != null) {
        final Uint8List pngBytes = byteData.buffer.asUint8List();

        // Create a filename for the processed image
        final directory = await getTemporaryDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final path = '${directory.path}/processed_${timestamp}.png';

        // Save the image
        final File imageFile = File(path);
        await imageFile.writeAsBytes(pngBytes);

        // Store the path to return to the chatbot
        setState(() {
          _processedImagePath = path;
        });

        // Crop all detected components
        _croppedComponentImages = await _cropAllDetectedComponents(
          widget.imagePath,
        );

        print('Processed image saved to: $path');
        print('Cropped ${_croppedComponentImages.length} component images');
      }
    } catch (e) {
      print('Error capturing processed image: $e');
    }
  }

  Future<String> _cropComponentImage(
    String originalImagePath,
    Rect boundingBox,
    String componentName,
  ) async {
    try {
      final rawBytes = await File(originalImagePath).readAsBytes();
      final decoded = img.decodeImage(rawBytes);

      if (decoded == null) {
        throw Exception("Failed to decode image for cropping");
      }

      // Calculate the absolute pixel coordinates from normalized coordinates
      final imageWidth = decoded.width.toDouble();
      final imageHeight = decoded.height.toDouble();

      // Apply padding around the bounding box (10%)
      int padX = (boundingBox.width * imageWidth * 0.1).round();
      int padY = (boundingBox.height * imageHeight * 0.1).round();

      // Calculate crop dimensions, ensuring they're within image bounds
      int cropX = (boundingBox.x * imageWidth - padX).round().clamp(
        0,
        decoded.width - 1,
      );
      int cropY = (boundingBox.y * imageHeight - padY).round().clamp(
        0,
        decoded.height - 1,
      );
      int cropW = (boundingBox.width * imageWidth + padX * 2).round();
      cropW = cropW.clamp(1, decoded.width - cropX);
      int cropH = (boundingBox.height * imageHeight + padY * 2).round();
      cropH = cropH.clamp(1, decoded.height - cropY);

      // Crop the image
      final img.Image croppedImg = img.copyCrop(
        decoded,
        x: cropX,
        y: cropY,
        width: cropW,
        height: cropH,
      );

      // Save to a temporary file
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final sanitizedName = componentName.replaceAll(
        RegExp(r'[^a-zA-Z0-9]'),
        '_',
      );
      final path = '${tempDir.path}/component_${sanitizedName}_$timestamp.jpg';
      final File croppedFile = File(path);

      await croppedFile.writeAsBytes(img.encodeJpg(croppedImg, quality: 90));
      return path;
    } catch (e) {
      print("Error cropping component image: $e");
      return ""; // Return empty string in case of error
    }
  }

  Future<Map<String, String>> _cropAllDetectedComponents(
    String originalImagePath,
  ) async {
    Map<String, String> componentImages = {};

    for (var detection in _finalDetections) {
      final componentPath = await _cropComponentImage(
        originalImagePath,
        detection.boundingBox,
        detection.className,
      );

      if (componentPath.isNotEmpty) {
        // If there are multiple components with the same name, append a number
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

// Add after the Detection class

// Store component bounding boxes with their names
Map<String, List<Rect>> _componentBoundingBoxes = {};

class Rect {
  final double x, y, width, height;
  Rect({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  double get area => width * height;

  double intersectionOverUnion(Rect o) {
    final dx =
        (x + width).clamp(o.x, o.x + o.width) - x.clamp(o.x, o.x + o.width);
    final dy =
        (y + height).clamp(o.y, o.y + o.height) - y.clamp(o.y, o.y + o.height);
    if (dx < 0 || dy < 0) return 0;
    final inter = dx * dy;
    final union = area + o.area - inter;
    return inter / union;
  }
}
