import 'package:flutter/material.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'select_ewaste.dart';
import 'test_model.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized(); // Ensures async operations work in main
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'e-Xtract',
      theme: ThemeData(
        primarySwatch: Colors.green,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _modelStatus = "Loading model...";
  Interpreter? _interpreter;

  @override
  void initState() {
    super.initState();
    loadModel();
  }

  Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/smartphone_model.tflite');
      setState(() {
        _modelStatus = "Model Loaded Successfully!";
      });
    } catch (e) {
      setState(() {
        _modelStatus = "Error loading model: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 48, 48, 48),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 50, 174, 59),
        title: const Text(
          'e-Xtract',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1.5,
          ),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'e-Xtract',
              style: TextStyle(
                fontSize: 24, 
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Upload pictures of your e-waste or use your camera.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Navigate to the e-waste selection screen
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SelectEwaste()),
                );
              },
              child: const Text('Get Started'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const TestModelScreen()),
                );
              },
              child: const Text('Test Model'),
            ),

            const SizedBox(height: 10),
            // Display model load status
            Text(
              _modelStatus,
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
