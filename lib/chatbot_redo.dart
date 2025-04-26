import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'base.dart';
import 'assistant_logic.dart';

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
  late AssistantLogic _assistant;
  bool _isInitialized = false;
  final ScrollController _scrollController = ScrollController();
  bool _isExpandedView = false;

  @override
  void initState() {
    super.initState();
    _initializeAssistant();
  }

  Future<void> _initializeAssistant() async {
    _assistant = AssistantLogic(
      category: widget.initialCategory,
      detectedComponents: widget.initialComponentImages.values
          .expand((map) => map.keys)
          .map((key) => key.split('_')[0])
          .toList(),
      componentImages: widget.initialComponentImages,
    );
    await _assistant.initialize();
    setState(() {
      _isInitialized = true;
    });
  }

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

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }
  
  // Get list of unique component types
  List<String> _getUniqueComponentTypes() {
    Set<String> uniqueTypes = {};
    for (var imageMap in widget.initialComponentImages.values) {
      for (var component in imageMap.keys) {
        uniqueTypes.add(component.split('_')[0]);
      }
    }
    return uniqueTypes.toList();
  }

  // Add helper method to check if we're at the disposal cause selection
  bool _isAtDisposalCauseSelection() {
    return _assistant.currentNodeId == 'start' || 
           _assistant.currentNodeId.endsWith('_issue');
  }

  @override
  Widget build(BuildContext context) {
    return Base(
      title: 'Extraction Assistant',
      child: SingleChildScrollView(
        controller: _scrollController,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header with device category and toggle button
            Container(
              padding: const EdgeInsets.fromLTRB(20, 30, 20, 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF43A047), // Green shade
                    const Color(0xFF2E7D32), // Darker green shade
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Device Category',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                          Text(
                            widget.initialCategory,
                            style: GoogleFonts.poppins(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _isExpandedView = !_isExpandedView;
                          });
                        },
                        icon: Icon(
                          _isExpandedView
                              ? Icons.arrow_drop_up
                              : Icons.arrow_drop_down,
                          color: Colors.white,
                          size: 32,
                        ),
                        tooltip: _isExpandedView
                            ? 'Hide details'
                            : 'Show details',
                      ),
                    ],
                  ),
                  
                  // Component pills
                  if (_getUniqueComponentTypes().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _getUniqueComponentTypes().map((component) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _getIconForComponent(component),
                                  color: Colors.white,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _formatComponentName(component),
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    
                  // Expanded details view
                  if (_isExpandedView) ...[
                    const SizedBox(height: 20),
                    // Input images
                    if (widget.initialComponentImages.isNotEmpty) ...[
                      Text(
                        'Input Images',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.all(8),
                          itemCount: widget.initialComponentImages.keys.length,
                          itemBuilder: (context, index) {
                            String imagePath = widget.initialComponentImages.keys.elementAt(index);
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: GestureDetector(
                                onTap: () => _showImageOverlay(context, imagePath),
                                child: Container(
                                  width: 100,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.3),
                                    ),
                                    image: DecorationImage(
                                      image: FileImage(File(imagePath)),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      Text(
                        'Detected Components',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        height: 150,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.all(8),
                          itemCount: widget.initialComponentImages.values
                              .expand((map) => map.entries)
                              .length,
                          itemBuilder: (context, index) {
                            // Get element at index from the expanded map entries
                            var entry = widget.initialComponentImages.values
                                .expand((map) => map.entries)
                                .elementAt(index);
                            
                            String componentName = entry.key.split('_')[0];
                            String imagePath = entry.value;
                            
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: GestureDetector(
                                onTap: () => _showImageOverlay(context, imagePath),
                                child: Container(
                                  width: 100,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius: const BorderRadius.vertical(
                                            top: Radius.circular(8),
                                          ),
                                          child: Image.file(
                                            File(imagePath),
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.2),
                                          borderRadius: const BorderRadius.vertical(
                                            bottom: Radius.circular(8),
                                          ),
                                        ),
                                        child: Text(
                                          _formatComponentName(componentName),
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.white,
                                          ),
                                          textAlign: TextAlign.center,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
            
            // Instructions section
            if (_isInitialized)
              Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Progress indicator - displays progress of the extraction process
                    if (_assistant.currentNodeId != 'start' && _assistant.hasMoreComponents()) ...[
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.linear_scale,
                                  color: const Color(0xFF43A047), // Green for progress icon
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Extraction Progress',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: _getProgressValue(),
                              backgroundColor: Colors.grey[200],
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Color(0xFF43A047), // Green for progress bar
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ],
                        ),
                      ),
                    ],
                    
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Component Display
                          if (_assistant.currentNodeId != 'start' && !_isAtDisposalCauseSelection()) ...[
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF43A047).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    _getIconForComponent(_assistant.getCurrentComponent()?.split('_')[0] ?? ''),
                                    color: const Color(0xFF43A047),
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _formatComponentName(_assistant.getCurrentComponent()?.split('_')[0] ?? ''),
                                        style: GoogleFonts.poppins(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      Text(
                                        'Currently handling this component',
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                          ],
                          
                          // Component image (if available)
                          if (_assistant.getCurrentComponentImage() != null && !_isAtDisposalCauseSelection()) ...[
                            Container(
                              height: 180,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.grey[300]!,
                                  width: 1,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(
                                  File(_assistant.getCurrentComponentImage()!),
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],

                          // Instructions
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.grey[200]!,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.lightbulb_outline,
                                      color: Color(0xFF43A047), // Green for instructions icon
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Instructions',
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF2E7D32), // Dark green for text
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _assistant.getCurrentInstruction(),
                                  style: GoogleFonts.poppins(
                                    fontSize: 15,
                                    color: Colors.black87,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // Options buttons
                          if (_assistant.getCurrentOptionLabels().isNotEmpty) ...[
                            Text(
                              'Select an option:',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ..._assistant.getCurrentOptionLabels()
                                .asMap()
                                .entries
                                .map((entry) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: ElevatedButton(
                                    onPressed: () {
                                      setState(() {
                                        _assistant.selectOption(entry.key);
                                      });
                                      WidgetsBinding.instance.addPostFrameCallback((_) {
                                        _scrollToBottom();
                                      });
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF43A047), // Green for button background
                                      foregroundColor: Colors.white, // White text on green buttons
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                    ),
                                    child: Text(
                                      entry.value,
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                ))
                                .toList(),
                          ],
                          
                          // Next component button
                          if (_assistant.isAtEnd() && _assistant.hasMoreComponents())
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _assistant.moveToNextComponent();
                                  });
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                    _scrollToBottom();
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF43A047), // Green for button background
                                  foregroundColor: Colors.white, // White text on green buttons
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                ),
                                icon: const Icon(Icons.arrow_forward),
                                label: Text(
                                  'Next Component: ${_formatComponentName(_assistant.getNextComponentName() ?? "")}',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ),
                            
                          // Completion indicator
                          if (_assistant.isAtEnd() && !_assistant.hasMoreComponents())
                            Container(
                              margin: const EdgeInsets.only(top: 16),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF43A047).withOpacity(0.1), // Light green background
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFF43A047).withOpacity(0.3), // Green border
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.check_circle_outline,
                                    color: Color(0xFF43A047), // Green check icon
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Extraction process complete! All components have been processed.',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        color: const Color(0xFF43A047), // Green text
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  // Helper methods
  IconData _getIconForComponent(String? componentType) {
    if (componentType == null) return Icons.hardware;
    
    switch (componentType.toLowerCase()) {
      case 'battery':
        return Icons.battery_full;
      case 'fan':
        return Icons.toys;
      case 'ram':
        return Icons.memory;
      case 'hard-drive':
        return Icons.storage;
      case 'ssd-nvme':
      case 'ssd-sata':
        return Icons.sd_storage;
      case 'wifi-card':
        return Icons.wifi;
      default:
        return Icons.hardware;
    }
  }
  
  String _formatComponentName(String? componentType) {
    if (componentType == null) return '';
    
    // Format component names for better display
    switch (componentType.toLowerCase()) {
      case 'hard-drive':
        return 'Hard Drive';
      case 'ssd-nvme':
        return 'NVMe SSD';
      case 'ssd-sata':
        return 'SATA SSD';
      case 'wifi-card':
        return 'WiFi Card';
      case 'ram':
        return 'RAM';
      default:
        // Capitalize first letter of each word
        return componentType.split('-')
            .map((word) => word[0].toUpperCase() + word.substring(1))
            .join(' ');
    }
  }
  
  double _getProgressValue() {
    if (_assistant.currentNodeId == 'start' || 
        _assistant.getCurrentComponent() == null) {
      return 0.0;
    }
    
    // Calculate progress based on current component position
    List<String> uniqueComponents = _assistant.detectedComponents.toSet().toList();
    String currentComponent = _assistant.getCurrentComponent()!.split('_')[0];
    int currentIndex = uniqueComponents.indexOf(currentComponent);
    
    if (currentIndex == -1 || uniqueComponents.isEmpty) return 0.0;
    return (currentIndex + 1) / uniqueComponents.length;
  }
}