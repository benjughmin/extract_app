import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:extract_app/part_detection.dart';
import 'base.dart';

class ChatbotScreen extends StatefulWidget {
  final String initialCategory;
  final String? initialImagePath;
  final List<String> initialDetections;
  final Map<dynamic, dynamic>? initialComponentImages; // Add this line

  const ChatbotScreen({
    super.key,
    required this.initialCategory,
    this.initialImagePath,
    this.initialDetections = const [],
    this.initialComponentImages, // Add this line
  });

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  Map<String, Map<String, String>> _componentImagesPerImage = {};
  String _selectedCategory = '';
  bool _showCategorySelector = false;
  List<String> _detectedParts = [];
  Map<String, dynamic> _knowledgeBase = {};
  bool _showPartOptions = false;
  bool _hasDetectedParts = false;
  bool _imageUploaded = false;
  List<String> _imagePaths = [];
  int _currentImageIndex = 0;
  Map<String, List<String>> _detectedPartsPerImage = {};
  Map<int, String> _processedImagePathsMap = {}; 
  List<List<int>> _uploadBatches = []; // Track images uploaded in batches
  Map<String, dynamic> _laptopInstructions = {};
  List<String> _currentOptions = [];
  String _currentStep = 'start';

  @override
  void initState() {
    super.initState();
    _loadKnowledgeBase();
    _loadLaptopInstructions();
    
    _selectedCategory = widget.initialCategory;
    
    // Add welcome message and start laptop instructions if category is Laptop
    if (_selectedCategory == 'Laptop') {
      _addBotMessage("Hello! I'm your e-waste assistant. I can help you identify and extract valuable parts from your Laptop.");
      _startLaptopInstructions();
    } else {
      _addBotMessage("Hello! I'm your e-waste assistant. I can help you identify and extract valuable parts from your ${widget.initialCategory}.");
    }
    
    // If we have an initial image, process it
    if (widget.initialImagePath != null) {
      _imagePaths.add(widget.initialImagePath!);
      _currentImageIndex = 0;
      _detectedParts = List.from(widget.initialDetections);
      _hasDetectedParts = _detectedParts.isNotEmpty;
      _showPartOptions = _hasDetectedParts;
      _imageUploaded = true;
      
      // Add the image to messages
      _messages.add(ChatMessage(
        text: '',
        isUser: true,
        timestamp: DateTime.now(),
        imagePath: widget.initialImagePath!,
        imageIndex: 0,
      ));
      
      // Process initial component images if available
      if (widget.initialComponentImages != null && widget.initialImagePath != null) {
        Map<String, String> componentImages = {};
        widget.initialComponentImages!.forEach((key, value) {
          componentImages[key.toString()] = value.toString();
        });
        _componentImagesPerImage[widget.initialImagePath!] = componentImages;
      }
      
      // Store detected parts for the initial image
      if (widget.initialImagePath != null && widget.initialDetections.isNotEmpty) {
        _detectedPartsPerImage[widget.initialImagePath!] = List<String>.from(widget.initialDetections);
      }
      
      // Add detection results
      if (widget.initialDetections.isNotEmpty) {
        _addBotMessage("I've detected the following parts in your ${widget.initialCategory}: ${widget.initialDetections.join(', ')}");
        
        // Add component images message if available
        if (widget.initialComponentImages != null && widget.initialComponentImages!.isNotEmpty) {
          Map<String, String> componentImages = {};
          widget.initialComponentImages!.forEach((key, value) {
            componentImages[key.toString()] = value.toString();
          });
          _addComponentImagesMessage(componentImages);
        }
      } else {
        _addBotMessage("I couldn't detect any components in your image. Try a clearer image or different angle.");
      }
    }
  }
  void _navigateImages(int currentIndex, int direction) {
    if (_imagePaths.isEmpty) return;
    
    // Find which batch this image belongs to
    int batchIndex = -1;
    List<int> currentBatch = [];
    
    for (int i = 0; i < _uploadBatches.length; i++) {
      if (_uploadBatches[i].contains(currentIndex)) {
        batchIndex = i;
        currentBatch = _uploadBatches[i];
        break;
      }
    }
    
    if (batchIndex == -1 || currentBatch.isEmpty) {
      // If not found in a batch, fallback to navigating all images
      int newIndex = (currentIndex + direction) % _imagePaths.length;
      if (newIndex < 0) newIndex = _imagePaths.length - 1;
      
      setState(() {
        _currentImageIndex = newIndex;
        _updateDisplayedParts(newIndex);
      });
      return;
    }
    
    // Navigate within the current batch only
    int currentPosInBatch = currentBatch.indexOf(currentIndex);
    int newPosInBatch = (currentPosInBatch + direction) % currentBatch.length;
    if (newPosInBatch < 0) newPosInBatch = currentBatch.length - 1;
    
    int newIndex = currentBatch[newPosInBatch];
    
    setState(() {
      _currentImageIndex = newIndex;
      _updateDisplayedParts(newIndex);
    });
  }
  
  // Helper to update displayed parts based on current image
  void _updateDisplayedParts(int imageIndex) {
    if (imageIndex >= 0 && imageIndex < _imagePaths.length) {
      String imagePath = _imagePaths[imageIndex];
      if (_detectedPartsPerImage.containsKey(imagePath)) {
        // Set parts to only those detected in the current image
        _detectedParts = List<String>.from(_detectedPartsPerImage[imagePath]!);
        _hasDetectedParts = _detectedParts.isNotEmpty;
        _showPartOptions = _hasDetectedParts;
      } else {
        _detectedParts = [];
        _hasDetectedParts = false;
        _showPartOptions = false;
      }
    }
  }

  void _showImageDetailsDialog(ChatMessage message) {
    if (message.imageIndex == null) return;
    int currentIdx = message.imageIndex!;
    
    // Find which batch this image belongs to
    List<int> currentBatch = [];
    for (var batch in _uploadBatches) {
      if (batch.contains(currentIdx)) {
        currentBatch = batch;
        break;
      }
    }
    
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Get detected parts for the CURRENT image being viewed
            List<String> getPartsForCurrentImage() {
              try {
                if (currentIdx < _imagePaths.length) {
                  String currentImagePath = _imagePaths[currentIdx];
                  if (_detectedPartsPerImage.containsKey(currentImagePath)) {
                    return _detectedPartsPerImage[currentImagePath] ?? [];
                  }
                }
              } catch (e) {
                print("Error getting parts for image: $e");
              }
              return [];
            }
            
            // NEW - Get component images for the current image
            Map<String, String> getComponentImagesForCurrentImage() {
              try {
                if (currentIdx < _imagePaths.length) {
                  String currentImagePath = _imagePaths[currentIdx];
                  if (_componentImagesPerImage.containsKey(currentImagePath)) {
                    return _componentImagesPerImage[currentImagePath] ?? {};
                  }
                }
              } catch (e) {
                print("Error getting component images: $e");
              }
              return {};
            }
            
            // Get components for the current image index
            List<String> imageParts = getPartsForCurrentImage();
            Map<String, String> componentImages = getComponentImagesForCurrentImage();
            
            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                width: double.maxFinite,
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: DefaultTabController(
                  length: 2,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppBar(
                        backgroundColor: Colors.transparent,
                        elevation: 0,
                        automaticallyImplyLeading: false,
                        centerTitle: true,
                        title: Text(
                          message.isResult ? 'Detection Results' : 'Image ${currentIdx + 1}',
                          style: GoogleFonts.montserrat(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        bottom: TabBar(
                          tabs: [
                            Tab(text: 'Full Image'),
                            Tab(text: 'Components'),
                          ],
                          indicatorColor: Colors.green,
                          labelColor: Colors.white,
                        ),
                      ),
                      Flexible(
                        child: TabBarView(
                          children: [
                            // Tab 1: Full Image View
                            SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Image with navigation overlay
                                  Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      // Display the image
                                      Image.file(
                                        File(message.isResult && _processedImagePathsMap.containsKey(currentIdx) 
                                            ? _processedImagePathsMap[currentIdx]!
                                            : _imagePaths[currentIdx]),
                                        width: double.infinity,
                                        fit: BoxFit.contain,
                                      ),
                                      
                                      // Navigation controls overlay
                                      if (currentBatch.length > 1)
                                        Positioned.fill(
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              // Previous image button
                                              GestureDetector(
                                                onTap: () {
                                                  int curPos = currentBatch.indexOf(currentIdx);
                                                  int prevPos = (curPos - 1) % currentBatch.length;
                                                  if (prevPos < 0) prevPos = currentBatch.length - 1;
                                                  int prevIdx = currentBatch[prevPos];
                                                  
                                                  setDialogState(() {
                                                    currentIdx = prevIdx;
                                                    // Update parts list for this image
                                                    imageParts = getPartsForCurrentImage();
                                                    componentImages = getComponentImagesForCurrentImage();
                                                  });
                                                },
                                                child: Container(
                                                  margin: const EdgeInsets.only(left: 8),
                                                  width: 40,
                                                  height: 40,
                                                  decoration: BoxDecoration(
                                                    color: Colors.black.withOpacity(0.5),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: const Icon(
                                                    Icons.arrow_back_ios_new,
                                                    color: Colors.white,
                                                    size: 20,
                                                  ),
                                                ),
                                              ),
                                              
                                              // Next image button
                                              GestureDetector(
                                                onTap: () {
                                                  int curPos = currentBatch.indexOf(currentIdx);
                                                  int nextPos = (curPos + 1) % currentBatch.length;
                                                  int nextIdx = currentBatch[nextPos];
                                                  
                                                  setDialogState(() {
                                                    currentIdx = nextIdx;
                                                    // Update parts list for this image
                                                    imageParts = getPartsForCurrentImage();
                                                    componentImages = getComponentImagesForCurrentImage();
                                                  });
                                                },
                                                child: Container(
                                                  margin: const EdgeInsets.only(right: 8),
                                                  width: 40,
                                                  height: 40,
                                                  decoration: BoxDecoration(
                                                    color: Colors.black.withOpacity(0.5),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: const Icon(
                                                    Icons.arrow_forward_ios,
                                                    color: Colors.white,
                                                    size: 20,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                  
                                  // Image counter
                                  if (currentBatch.length > 1)
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Center(
                                        child: Text(
                                          'Image ${currentBatch.indexOf(currentIdx) + 1} of ${currentBatch.length}',
                                          style: GoogleFonts.montserrat(
                                            color: Colors.white70,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ),
                                  
                                  // Display components section
                                  Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      children: [
                                        Text(
                                          'Detected Components',
                                          textAlign: TextAlign.center,
                                          style: GoogleFonts.montserrat(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        // Display components or "None detected" message
                                        if (imageParts.isNotEmpty)
                                          ...imageParts.map((part) => Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                                            child: Row(
                                              children: [
                                                const Icon(Icons.check_circle, color: Colors.green, size: 20),
                                                const SizedBox(width: 8),
                                                Text(
                                                  part,
                                                  style: GoogleFonts.montserrat(
                                                    color: Colors.white,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )).toList()
                                        else
                                          Padding(
                                            padding: const EdgeInsets.only(top: 8.0),
                                            child: Text(
                                              'No components detected in this image.',
                                              style: GoogleFonts.montserrat(
                                                color: Colors.white70,
                                                fontSize: 14,
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            // Tab 2: Component Images - NEW
                            SingleChildScrollView(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (componentImages.isNotEmpty)
                                      ...componentImages.entries.map((entry) {
                                        final componentName = entry.key;
                                        final imagePath = entry.value;
                                        
                                        return Padding(
                                          padding: const EdgeInsets.only(bottom: 16.0),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                componentName,
                                                style: GoogleFonts.montserrat(
                                                  color: Colors.white,
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              ClipRRect(
                                                borderRadius: BorderRadius.circular(8),
                                                child: Image.file(
                                                  File(imagePath),
                                                  width: double.infinity,
                                                  fit: BoxFit.contain,
                                                ),
                                              ),
                                              const SizedBox(height: 16),
                                              const Divider(color: Colors.white24),
                                            ],
                                          ),
                                        );
                                      }).toList()
                                    else
                                      Center(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 30.0),
                                          child: Column(
                                            children: [
                                              const Icon(Icons.crop_free, color: Colors.white38, size: 48),
                                              const SizedBox(height: 16),
                                              Text(
                                                'No component images available',
                                                style: GoogleFonts.montserrat(
                                                  color: Colors.white70,
                                                  fontSize: 16,
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
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF34A853),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Container(
                            width: double.infinity,
                            alignment: Alignment.center,
                            child: Text(
                              'Close',
                              style: GoogleFonts.montserrat(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
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
          },
        );
      },
    );
  }

  Future<void> _loadKnowledgeBase() async {
    try {
      final String jsonString = await rootBundle.loadString('assets/knowledge-base.json');
      setState(() {
        _knowledgeBase = json.decode(jsonString);
      });
    } catch (e) {
      print("Error loading knowledge base: $e");
    }
  }

  Future<void> _loadLaptopInstructions() async {
    try {
      final String jsonString = await rootBundle.loadString('assets/laptop_instructions.json');
      setState(() {
        _laptopInstructions = json.decode(jsonString);
        // Initialize with start options from the nodes array
        var startNode = (_laptopInstructions['nodes'] as List<dynamic>)
            .firstWhere((node) => node['id'] == 'start', 
                      orElse: () => null);
        
        if (startNode != null && startNode['options'] != null) {
          _currentOptions = startNode['options']
              .map<String>((option) => option['label'] as String)
              .toList();
        }
      });
      print("Laptop instructions loaded successfully: ${_laptopInstructions.toString().substring(0, 100)}..."); // Debug print
    } catch (e) {
      print("Error loading laptop instructions: $e");
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _addMessage(String text, bool isUser) {
    setState(() {
      _messages.add(ChatMessage(
        text: text,
        isUser: isUser,
        timestamp: DateTime.now(),
      ));
    });
    
    if (!_scrollController.hasClients) return;
    
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        try {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        } catch (e) {
          print('Error scrolling after adding message: $e');
        }
      }
    });
  }

  void _addBotMessage(String text) {
    _addMessage(text, false);
  }

  void _addUserMessage(String text) {
    _addMessage(text, true);
  }

  void _handlePredefinedResponse(String response) {
    _addUserMessage(response);
    
    // Process the predefined response
    if (response == "What parts can I extract?") {
      if (_selectedCategory.isNotEmpty) {
        _addBotMessage("Based on the image you uploaded, here are the parts I identified in your $_selectedCategory.");
      } else {
        _addBotMessage("Please select a device type first.");
        _showCategorySelector = true;
      }
    } else if (response == "How much are the parts worth?") {
      if (_selectedCategory.isNotEmpty) {
        _addBotMessage("I can provide an estimate of the value for each part. Select a part to see its value and more details.");
      } else {
        _addBotMessage("Please select a device type first.");
        _showCategorySelector = true;
      }
    } else if (response == "How do I recycle this device?") {
      if (_selectedCategory.isNotEmpty) {
        _addBotMessage("To properly recycle your $_selectedCategory, you can extract valuable parts first, then take the remaining components to a certified e-waste recycling center. Would you like to know how to extract specific parts?");
      } else {
        _addBotMessage("Please select a device type first.");
        _showCategorySelector = true;
      }
    } else if (response == "Change device type") {
      _selectedCategory = '';
      _showCategorySelector = true;
      _showPartOptions = false;
      _imageUploaded = false;
      _addBotMessage("Let's change your device type. What type of e-waste do you have?");
    } else if (_showPartOptions && (_detectedParts.contains(response) || response == "Camera" || response == "Battery")) {
      // Handle part extraction details
      _showPartExtractionDetails(response);
    }
  }

  void _showPartExtractionDetails(String partName) {
    if (_knowledgeBase.containsKey(_selectedCategory) && 
        _knowledgeBase[_selectedCategory].containsKey(partName)) {
      
      final partInfo = _knowledgeBase[_selectedCategory][partName];
      
      final value = partInfo['value'] ?? 'Unknown';
      final steps = partInfo['extraction_steps'] ?? [];
      final hazards = partInfo['hazards'] ?? [];
      final recyclingInfo = partInfo['recycling_info'] ?? 'No information available';
      
      String detailsMessage = "*$partName Details*\n\n";
      detailsMessage += "Value: $value\n\n";
      
      detailsMessage += "Extraction Steps:\n";
      for (int i = 0; i < steps.length; i++) {
        detailsMessage += "${i+1}. ${steps[i]}\n";
      }
      detailsMessage += "\n";
      
      detailsMessage += "Hazards:\n";
      for (final hazard in hazards) {
        detailsMessage += "• $hazard\n";
      }
      detailsMessage += "\n";
      
      detailsMessage += "Recycling Info: $recyclingInfo";
      
      _addBotMessage(detailsMessage);
      
      // Follow-up question
      _addBotMessage("Would you like to extract another part or get more information?");
    } else {
      _addBotMessage("I don't have detailed information about $partName for $_selectedCategory yet. Would you like to know about another part?");
    }
  }

  void _selectCategory(String category) {
    setState(() {
      _selectedCategory = category;
      _showCategorySelector = false;
      _hasDetectedParts = false;
      _showPartOptions = false;
      _imageUploaded = false;
    });
    _addBotMessage("Great! I can help identify valuable parts in your $category. Upload an image or take a photo to get started.");
  }

Future<void> _getImage(ImageSource source) async {
  final ImagePicker picker = ImagePicker();

  try {
    List<XFile> selectedImages = [];
    
    if (source == ImageSource.gallery) {
      final List<XFile>? images = await picker.pickMultiImage();
      if (images == null || images.isEmpty) return;
      selectedImages = images;
    } else {
      final XFile? image = await picker.pickImage(source: source);
      if (image == null) return;
      selectedImages = [image];
    }
    
    // Create a new batch to track these images
    List<int> newBatch = [];
    
    // Process each selected image
    for (int i = 0; i < selectedImages.length; i++) {
      var image = selectedImages[i];
      final String imagePath = image.path;
      final int imageIndex = _imagePaths.length;
      
      // Add this image index to the current batch
      newBatch.add(imageIndex);
      
      setState(() {
        _imagePaths.add(imagePath);
        _currentImageIndex = imageIndex;
        
        // Add image message
        _messages.add(ChatMessage(
          text: '',
          isUser: true,
          timestamp: DateTime.now(),
          imagePath: imagePath,
          imageIndex: imageIndex,
        ));
        _imageUploaded = true;
      });
      
      _scrollToBottom();
      
      // Processing message
      _addBotMessage("Processing image ${i + 1} of ${selectedImages.length}...");
      
      // Process the image if a category is selected
      if (_selectedCategory.isNotEmpty) {
        final result = await Navigator.push<Map<String, dynamic>>(
          context,
          MaterialPageRoute(
            builder: (context) => PartDetectionScreen(
              category: _selectedCategory,
              imagePath: imagePath,
            ),
          ),
        );
        
        if (result != null) {
          // Extract data from the result map
          final processedImagePath = result['imagePath'] as String;
          final List<dynamic> detectedComponentsRaw = result['detectedComponents'] as List<dynamic>? ?? [];
          final List<String> detectedParts = detectedComponentsRaw.cast<String>();
          
          // Extract cropped component images - NEW!
          final Map<dynamic, dynamic>? croppedImagesRaw = result['croppedComponentImages'] as Map<dynamic, dynamic>?;
          Map<String, String> croppedImages = {};
          if (croppedImagesRaw != null) {
            croppedImagesRaw.forEach((key, value) {
              croppedImages[key.toString()] = value.toString();
            });
            _componentImagesPerImage[imagePath] = croppedImages;
          }
          
          // Store processed image path mapped to its index for navigation
          _processedImagePathsMap[imageIndex] = processedImagePath;
          
          setState(() {
            // Store the detected parts specifically for this image
            _detectedPartsPerImage[imagePath] = detectedParts;
            
            // Only update the current parts if we're still looking at this image
            if (_currentImageIndex == imageIndex) {
              _detectedParts = List<String>.from(detectedParts);
              _hasDetectedParts = detectedParts.isNotEmpty;
              _showPartOptions = _hasDetectedParts;
            }
          });
          
          // Customize message based on whether parts were detected
          if (detectedParts.isNotEmpty) {
            _addBotMessage("I've analyzed image ${i + 1} of ${selectedImages.length}! Detected parts: ${detectedParts.join(', ')}");
            
            // Start the part-by-part instructions
            _handleDetectedPartsInstructions(detectedParts);
            
            // NEW - Add a message with the cropped component images
            if (croppedImages.isNotEmpty) {
              _addComponentImagesMessage(croppedImages);
            }
          } else {
            _addBotMessage("I've analyzed image ${i + 1} of ${selectedImages.length}, but couldn't detect any components. Try a clearer image or different angle.");
          }
          
          // Add result message with the processed image
          _messages.add(ChatMessage(
            text: "Analysis results for image ${i + 1}",
            isUser: false,
            timestamp: DateTime.now(),
            imagePath: processedImagePath,
            imageIndex: imageIndex,
            isResult: true,
            detectedParts: List<String>.from(detectedParts),
          ));
          
          _scrollToBottom();
        }
      }
    }
    
    // Add this batch to our tracking once, after processing all images
    if (newBatch.isNotEmpty) {
      _uploadBatches.add(newBatch);
    }
    
    if (_selectedCategory.isEmpty) {
      _addBotMessage("Please select a device category first before uploading images.");
      _showCategorySelector = true;
    }
  } catch (e) {
    print("Error processing images: $e");
    _addBotMessage("Sorry, there was an error processing your images. Please try again.");
  }
}

void _scrollToBottom() {
  if (!_scrollController.hasClients) return;
  
  Future.delayed(const Duration(milliseconds: 100), () {
    if (_scrollController.hasClients) {
      try {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      } catch (e) {
        print('Error scrolling to bottom: $e');
      }
    }
  });
}

void _addComponentImagesMessage(Map<String, String> componentImages) {
  setState(() {
    _messages.add(ChatMessage(
      text: "Here are the components I detected:",
      isUser: false,
      timestamp: DateTime.now(),
      componentImages: componentImages,
    ));
  });
  
  _scrollToBottom();
}

void _startLaptopInstructions() {
  if (_laptopInstructions.isEmpty) {
    _addBotMessage("Sorry, I couldn't load the laptop instructions. Please try again later.");
    return;
  }

  // Find the start node
  var startNode = (_laptopInstructions['nodes'] as List<dynamic>)
      .firstWhere((node) => node['id'] == 'start', 
                  orElse: () => null);

  if (startNode == null) {
    _addBotMessage("Error loading instructions. Please try again.");
    return;
  }

  setState(() {
    _currentStep = 'start';
    // Extract options from the node
    _currentOptions = startNode['options']
        .map<String>((option) => option['label'] as String)
        .toList();
    
    // Add initial message
    _addBotMessage(startNode['text'] ?? 
      "Welcome! Let's help you disassemble your laptop. What would you like to do?");
  });
}

void _handleInstructionChoice(String choice) {
  _addUserMessage(choice);

  if (choice == 'Start Over') {
    _startLaptopInstructions();
    return;
  }

  if (choice == 'Continue to next part' || choice == 'Skip this part') {
    // Safely parse the current step index
    if (_currentStep.startsWith('part_')) {
      int currentIndex = int.parse(_currentStep.split('_')[1]);
      _showNextPartInstructions(_detectedParts, currentIndex + 1);
    } else {
      // If `_currentStep` is not in the expected format, reset to the first part
      _showNextPartInstructions(_detectedParts, 0);
    }
    return;
  }

  // Handle other options (e.g., disposal instructions)
  if (_laptopInstructions.isEmpty) return;

  // Find current node
  var currentNode = (_laptopInstructions['nodes'] as List<dynamic>)
      .firstWhere((node) => node['id'] == _currentStep, orElse: () => null);

  if (currentNode == null) return;

  // Find the selected option and get the next node id
  String? nextNodeId;
  for (var option in currentNode['options']) {
    if (option['label'] == choice) {
      nextNodeId = option['next'];
      break;
    }
  }

  if (nextNodeId == null) return;

  // Find the next node
  var nextNode = (_laptopInstructions['nodes'] as List<dynamic>)
      .firstWhere((node) => node['id'] == nextNodeId, orElse: () => null);

  if (nextNode == null) return;

  setState(() {
    _currentStep = nextNodeId!;

    // Handle different node types
    if (nextNode.containsKey('steps')) {
      var steps = nextNode['steps'] as List<dynamic>;
      String message = "Here are the steps:\n\n";
      for (var step in steps) {
        message += "${step['order']}. ${step['action']}\n";
      }
      _addBotMessage(message);
      _currentOptions = ['Continue to next part'];
    } else if (nextNode.containsKey('instructions')) {
      var instructions = nextNode['instructions'] as List<dynamic>;
      String message = "Instructions:\n\n";
      for (var instruction in instructions) {
        message += "• ${instruction['step']}\n";
      }
      _addBotMessage(message);
      _currentOptions = ['Continue to next part'];
    } else if (nextNode.containsKey('text')) {
      _addBotMessage(nextNode['text']);
      if (nextNode.containsKey('options')) {
        _currentOptions = nextNode['options']
            .map<String>((option) => option['label'] as String)
            .toList();
      } else {
        _currentOptions = ['Continue to next part'];
      }
    }
  });
}

void _handleDetectedPartsInstructions(List<String> detectedParts, {String? relatedPart}) {
  // If a related part exists, handle it first
  if (relatedPart != null) {
    _addBotMessage("Let's start with the part related to the issue you selected: $relatedPart.");
    _showNextPartInstructions([relatedPart], 0, isRelatedPart: true);
  } else {
    // If no related part, proceed with all detected parts
    _addBotMessage("I'll guide you through extracting each detected part safely.");
    _showNextPartInstructions(detectedParts, 0);
  }
}

void _showNextPartInstructions(List<String> parts, int index, {bool isRelatedPart = false}) {
  if (index >= parts.length) {
    if (isRelatedPart) {
      // After the related part, proceed with the remaining parts
      _addBotMessage("Now let's move on to the other detected parts.");
      _showNextPartInstructions(_detectedParts, 0);
    } else {
      // If all parts are done, end the flow
      _addBotMessage("That's all the parts! Would you like to start over or try something else?");
      _currentOptions = ['Start Over', 'Change device type'];
    }
    return;
  }

  String part = parts[index].toLowerCase();
  String nodeId = _getInstructionNodeId(part);

  // Find the node for this part
  var node = (_laptopInstructions['nodes'] as List<dynamic>)
      .firstWhere((node) => node['id'] == nodeId, orElse: () => null);

  if (node != null) {
    _addBotMessage("Let's extract the ${parts[index]}:");

    // Show instructions or options based on node type
    if (node.containsKey('steps')) {
      String steps = node['steps']
          .map((step) => "${step['order']}. ${step['action']}")
          .join('\n');
      _addBotMessage(steps);

      // Add continue button
      _currentOptions = ['Continue to next part'];
      _currentStep = 'part_${index}'; // Properly set the current step
    } else if (node.containsKey('options')) {
      _currentOptions = node['options']
          .map<String>((option) => option['label'] as String)
          .toList();
      _currentStep = nodeId;
    }
  } else {
    // Skip unknown parts
    _showNextPartInstructions(parts, index + 1, isRelatedPart: isRelatedPart);
  }
}

String _getInstructionNodeId(String part) {
  switch (part) {
    case 'battery':
      return 'battery_type';
    case 'fan':
      return 'extract_fan';
    case 'ram':
      return 'ram_issue';
    case 'hard drive':
    case 'hdd':
      return 'hdd_flow';
    case 'ssd':
      return 'sata_flow';
    case 'wifi card':
    case 'wireless':
      return 'extract_wifi';
    default:
      return '';
  }
}

void _handleCauseSelection(String cause) {
  _addUserMessage(cause);

  // Map cause to related part
  String? relatedPart;
  switch (cause) {
    case "Laptop is not powering on":
      relatedPart = "battery";
      break;
    case "Overheating":
      relatedPart = "fan";
      break;
    case "Storage issue / Drive failure":
      relatedPart = "hard drive";
      break;
    case "Memory issue / RAM failure":
      relatedPart = "ram";
      break;
    case "Other / Wi-Fi & misc.":
      relatedPart = "wifi card";
      break;
  }

  // Start instructions with the related part
  _handleDetectedPartsInstructions(_detectedParts, relatedPart: relatedPart);
}

  @override
  Widget build(BuildContext context) {
    return Base(
      title: 'e-Waste Assistant',
      child: Scaffold(
        backgroundColor: const Color(0xFF1E1E1E),
        body: SafeArea(
          child: Column(
            children: [
              // Chat messages list
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    return _buildChatMessage(_messages[index]);
                  },
                ),
              ),

              // Instruction buttons (if any)
              if (_currentOptions.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: const Color(0xFF2A2A2A),
                  child: _buildInstructionButtons(),
                ),

              // Action buttons
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                    )
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildIconButton(Icons.camera_alt, () => _getImage(ImageSource.camera)),
                    _buildIconButton(Icons.photo_library, () => _getImage(ImageSource.gallery)),
                    if (_imageUploaded)
                      _buildIconButton(Icons.restart_alt, () {
                        setState(() {
                          _imageUploaded = false;
                          _detectedParts.clear();
                        });
                      }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

Widget _buildChatMessage(ChatMessage message) {
  // Find batch information outside the widget tree
  List<int> currentBatch = [];
  int currentPosInBatch = -1;
  
  if (message.imageIndex != null) {
    for (var batch in _uploadBatches) {
      if (batch.contains(message.imageIndex!)) {
        currentBatch = batch;
        currentPosInBatch = currentBatch.indexOf(message.imageIndex!);
        break;
      }
    }
  }
  
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      mainAxisAlignment: message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Avatar for bot messages
        if (!message.isUser)
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.greenAccent, Colors.green],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.smart_toy,
              color: Colors.white,
              size: 20,
            ),
          ),
        
        const SizedBox(width: 8),
        
        // Message content
        Flexible(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: message.isUser ? const Color(0xFF34A853) : const Color(0xFF3A3A3A),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(message.isUser ? 16 : 0),
                topRight: Radius.circular(message.isUser ? 0 : 16),
                bottomLeft: const Radius.circular(16),
                bottomRight: const Radius.circular(16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Text content
                if (message.text.isNotEmpty)
                  SelectableText(
                    message.text,
                    style: GoogleFonts.montserrat(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                
                // Main image
                if (message.imagePath != null) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () {
                      _showImageDetailsDialog(message);
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Stack(
                        children: [
                          Image.file(
                            File(message.imagePath!),
                            width: 200,
                            height: 200,
                            fit: BoxFit.cover,
                          ),
                          if (message.isResult)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.7),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'Results',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        message.isResult 
                            ? 'Analysis results' 
                            : 'Image ${message.imageIndex != null ? (message.imageIndex! + 1) : ""}',
                        style: GoogleFonts.montserrat(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      // Navigation controls
                      if (_imagePaths.length > 1 && message.imageIndex != null && currentBatch.length > 1)
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () {
                                // Navigate to previous image in this batch
                                int prevPos = (currentPosInBatch - 1) % currentBatch.length;
                                if (prevPos < 0) prevPos = currentBatch.length - 1;
                                int prevIdx = currentBatch[prevPos];
                                
                                String imagePath = message.isResult && _processedImagePathsMap.containsKey(prevIdx)
                                    ? _processedImagePathsMap[prevIdx]!
                                    : _imagePaths[prevIdx];
                                
                                setState(() {
                                  // Update this message
                                  int idx = _messages.indexOf(message);
                                  if (idx >= 0) {
                                    _messages[idx] = ChatMessage(
                                      text: message.text,
                                      isUser: message.isUser,
                                      timestamp: message.timestamp,
                                      imagePath: imagePath,
                                      imageIndex: prevIdx,
                                      isResult: message.isResult,
                                      detectedParts: message.isResult && _detectedPartsPerImage.containsKey(_imagePaths[prevIdx])
                                          ? _detectedPartsPerImage[_imagePaths[prevIdx]] : null,
                                    );
                                  }
                                  
                                  // Also update current state
                                  _currentImageIndex = prevIdx;
                                  _updateDisplayedParts(prevIdx);
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.black26,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.arrow_back_ios,
                                  color: Colors.white70,
                                  size: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${currentPosInBatch + 1}/${currentBatch.length}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                // Navigate to next image in this batch
                                int nextPos = (currentPosInBatch + 1) % currentBatch.length;
                                int nextIdx = currentBatch[nextPos];
                                
                                String imagePath = message.isResult && _processedImagePathsMap.containsKey(nextIdx)
                                    ? _processedImagePathsMap[nextIdx]!
                                    : _imagePaths[nextIdx];
                                
                                setState(() {
                                  // Update this message
                                  int idx = _messages.indexOf(message);
                                  if (idx >= 0) {
                                    _messages[idx] = ChatMessage(
                                      text: message.text,
                                      isUser: message.isUser,
                                      timestamp: message.timestamp,
                                      imagePath: imagePath,
                                      imageIndex: nextIdx,
                                      isResult: message.isResult,
                                      detectedParts: message.isResult && _detectedPartsPerImage.containsKey(_imagePaths[nextIdx])
                                          ? _detectedPartsPerImage[_imagePaths[nextIdx]] : null,
                                    );
                                  }
                                  
                                  // Also update current state
                                  _currentImageIndex = nextIdx;
                                  _updateDisplayedParts(nextIdx);
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.black26,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.arrow_forward_ios,
                                  color: Colors.white70,
                                  size: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
                
                // NEW - Component images in a horizontal scrollable list
                if (message.componentImages != null && message.componentImages!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Detected Components:',
                    style: GoogleFonts.montserrat(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 140,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: message.componentImages!.length,
                      itemBuilder: (context, index) {
                        final componentName = message.componentImages!.keys.elementAt(index);
                        final imagePath = message.componentImages![componentName]!;
                        
                        return Container(
                          width: 120,
                          margin: const EdgeInsets.only(right: 10),
                          child: Column(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  File(imagePath),
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                componentName,
                                style: GoogleFonts.montserrat(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        
        const SizedBox(width: 8),
        
        // Avatar placeholder for user messages
        if (message.isUser)
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.blueAccent,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.person,
              color: Colors.white,
              size: 20,
            ),
          ),
      ],
    ),
  );
}

  Widget _buildIconButton(IconData icon, VoidCallback onTap, {Color color = Colors.white}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color == Colors.white ? const Color(0xFF3A3A3A) : color,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }

  Widget _buildTextIconButton(String text, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF3A3A3A),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 4),
            Text(
              text,
              style: GoogleFonts.montserrat(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResponseButton(String text, {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF34A853), Color(0xFF0F9D58)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              offset: const Offset(0, 2),
              blurRadius: 6,
            ),
          ],
        ),
        child: Text(
          text,
          style: GoogleFonts.montserrat(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildCategoryButton(String category, IconData icon) {
    return GestureDetector(
      onTap: () => _selectCategory(category),
      child: Container(
        width: 80,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF34A853), Color(0xFF0F9D58)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              offset: const Offset(0, 2),
              blurRadius: 6,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(height: 4),
            Text(
              category.split(' ')[0],
              style: GoogleFonts.montserrat(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPartButton(String partName) {
    return GestureDetector(
      onTap: () => _handlePredefinedResponse(partName),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF34A853),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              offset: const Offset(0, 2),
              blurRadius: 4,
            ),
          ],
        ),
        child: Text(
          partName,
          style: GoogleFonts.montserrat(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildInstructionButtons() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _currentOptions.map((option) {
          bool isStartOver = option == 'Start Over';
          
          return ElevatedButton(
            onPressed: () {
              if (isStartOver) {
                _startLaptopInstructions();
              } else {
                _handleInstructionChoice(option);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isStartOver ? Colors.blue : const Color(0xFF34A853),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            child: Text(
              option,
              style: GoogleFonts.montserrat(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String? imagePath;
  final int? imageIndex;
  final bool isResult;
  final List<String>? detectedParts;
  final Map<String, String>? componentImages; // NEW - Map of component name to image path

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.imagePath,
    this.imageIndex,
    this.isResult = false,
    this.detectedParts,
    this.componentImages,
  });
}