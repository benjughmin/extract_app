import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class TestModelScreen extends StatefulWidget {
  const TestModelScreen({super.key});

  @override
  _TestModelScreenState createState() => _TestModelScreenState();
}

class _TestModelScreenState extends State<TestModelScreen> {
  Interpreter? _interpreter;
  File? _selectedImage;
  String _result = "No image selected.";

  @override
  void initState() {
    super.initState();
    loadModel();
  }

  /// Load the TFLite model
  Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/smartphone_model.tflite');
      setState(() {
        _result = "✅ Model Loaded Successfully!";
      });
    } catch (e) {
      setState(() {
        _result = "❌ Error loading model: $e";
      });
    }
  }

  /// Pick an image from camera or gallery
  Future<void> pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);
    
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
        _result = "📸 Image Loaded: ${pickedFile.name}";
      });
      runModelOnImage(_selectedImage!);
    }
  }

  /// Run the model on the selected image
  Future<void> runModelOnImage(File imageFile) async {
    if (_interpreter == null) {
      setState(() {
        _result = "❌ Model not loaded!";
      });
      return;
    }

    // Preprocess image into Float32List
    var input = await preprocessImage(imageFile);

    // Define the output shape (adjust based on your model's output)
    var output = List.filled(1 * 10, 0).reshape([1, 10]);

    // Run inference
    _interpreter!.run(input, output);

    // Interpret the result
    List<double> predictions = output[0];
    int predictedIndex = predictions.indexWhere((p) => p == predictions.reduce((a, b) => a > b ? a : b));

    setState(() {
      _result = "📌 Model Prediction: Class $predictedIndex (Confidence: ${predictions[predictedIndex].toStringAsFixed(2)})";
    });
  }

  /// Convert image to Float32List for model input
  Future<Float32List> preprocessImage(File imageFile) async {
    final imageBytes = await imageFile.readAsBytes();
    img.Image image = img.decodeImage(Uint8List.fromList(imageBytes))!;
    img.Image resizedImage = img.copyResize(image, width: 224, height: 224); // Adjust to match model input size

    List<double> imageList = [];

    for (int y = 0; y < 224; y++) {
      for (int x = 0; x < 224; x++) {
        final pixel = resizedImage.getPixel(x, y);
        imageList.add(pixel.r / 255.0); // Normalize R
        imageList.add(pixel.g / 255.0); // Normalize G
        imageList.add(pixel.b / 255.0); // Normalize B
      }
    }

    return Float32List.fromList(imageList);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Test Model"),
        backgroundColor: Colors.green,
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_selectedImage != null)
            Image.file(_selectedImage!, height: 200), // Display selected image
          const SizedBox(height: 20),
          Text(
            _result,
            style: const TextStyle(color: Colors.white),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () => pickImage(ImageSource.camera),
                child: const Text("📸 Capture Image"),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: () => pickImage(ImageSource.gallery),
                child: const Text("🖼 Select from Gallery"),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
