import 'dart:io'; 
import 'package:flutter/material.dart'; 
import 'package:google_fonts/google_fonts.dart'; 
import 'dart:convert';
import 'package:flutter/services.dart';
import '/pages/base.dart'; 
import '/pages/knowledge_implementation.dart';
import '/pages/category.dart';
import '/pages/upload_or_camera.dart';
import '/pages/session.dart';
import '/pages/session_repository.dart'; 
import '/pages/summary.dart';

// StatefulWidget is used when the UI can change dynamically during runtime
class ChatbotRedo extends StatefulWidget {
  // These are parameters passed when creating the widget
  final String initialCategory; // Device category (e.g., "Laptop")
  final String? initialImagePath; // Optional main image path
  final List<String> initialDetections; // List of detected components
  final Map<String, Map<String, String>> initialComponentImages; // Nested map of image paths for components
  final List<dynamic> initialBatch; // Batch identifier for processing

  // Constructor with required and optional parameters
  const ChatbotRedo({
    super.key, // Widget key for Flutter's internal use
    required this.initialCategory, 
    this.initialImagePath, // Optional parameter (can be null)
    required this.initialDetections,
    required this.initialComponentImages,
    required this.initialBatch,
  });

  // Creates the mutable state object for this widget
  @override
  State<ChatbotRedo> createState() => _ChatbotRedoState();
}

// The mutable state class that contains all the dynamic logic and UI
class _ChatbotRedoState extends State<ChatbotRedo> {
  // UI state variables
  bool _isSummaryExpanded = true; // Controls if the top summary section is expanded
  
  // Rule system variables
  RuleBase? _ruleBase; // Contains all the decision nodes and rules
  Node? _currentNode; // Current instruction/question node being displayed
  bool _isLoading = true; // Loading indicator control
  
  // Component tracking variables
  String? _currentComponent; // Currently selected component (e.g., "ram")
  Map<String, dynamic>? _componentMapping; // Maps issue types to components
  Map<String, String>? _componentStartNodes; // Maps component names to their starting node IDs
  
  // Image handling
  Map<String, String> _componentImagePaths = {}; // Quick lookup for component images
  Map<String, String> _originalComponentNames = {}; // Maps unique keys back to component names
  Map<String, String>? _componentLabelMapping; // Maps UI labels to component internal names
  Map<String, dynamic>? _issueComponentMapping; // Maps issues to related components

  String? _sessionId; // Tracks the session

  // Guidelines variables
  bool _showedInitialGuide = false;
  Map<String, dynamic>? _guidelines;

  // Lifecycle method called when widget is first created
  @override
  void initState() {
    super.initState();
    _loadRuleBase(); // This now handles both rule base and guidelines
    _initializeComponentImagePaths();
    
    // Handle both string and integer batch IDs
    _sessionId = widget.initialBatch.isNotEmpty 
      ? widget.initialBatch[0].toString()
      : DateTime.now().millisecondsSinceEpoch.toString();
  }

  // Creates a flattened map for quick component image lookup
  void _initializeComponentImagePaths() {
    int imageIndex = 0;  // Add an image counter for uniqueness
    
    // Loop through the nested structure of images passed to this widget
    for (var entry in widget.initialComponentImages.entries) {
      String imagePath = entry.key;  // Get the original image path
      imageIndex++;  // Increment counter for each image
      
      for (var component in entry.value.entries) {
        // Create a unique key that combines component name with image source
        // Format: componentname_img1, componentname_img2, etc.
        String uniqueKey = "${component.key.toLowerCase()}_img$imageIndex";
        
        // Store the component image with unique key to prevent overwriting
        _componentImagePaths[uniqueKey] = component.value;
        
        // Also store original component name for searching
        _originalComponentNames[uniqueKey] = component.key.toLowerCase();
      }
    }
    
    print("Component image paths: $_componentImagePaths"); // Debug output
  }
  
  // Helper to get all image paths for the current component
  List<String> _getCurrentComponentImagePaths() {
    if (_currentComponent == null) return [];
    
    // Find all images where the original component name matches current component
    List<String> paths = [];
    for (var entry in _componentImagePaths.entries) {
      String uniqueKey = entry.key;
      String? originalName = _originalComponentNames[uniqueKey];
      
      if (originalName != null) {
        // Normalize component names: convert hyphens to underscores ONLY for comparison. Hyphen is a special character that can cause issue if used.
        String normalizedCurrent = _currentComponent!.toLowerCase().replaceAll('-', '_');
        String normalizedOriginal = originalName.toLowerCase().replaceAll('-', '_');
        
        // Check if they match after normalization
        if (normalizedOriginal.startsWith(normalizedCurrent) || 
            normalizedCurrent.startsWith(normalizedOriginal)) {
          paths.add(entry.value);
          print("Found matching image: ${entry.value} for component: $_currentComponent");
        }
      }
    }
    return paths;
  }

  // Asynchronously loads the rule system from a JSON file
  Future<void> _loadRuleBase() async {
    try {
      print("Loading rule base for category: ${widget.initialCategory}");
      
      // Load rule base using existing KnowledgeImplementation
      final ruleBase = await KnowledgeImplementation.loadRuleBase(widget.initialCategory);
      
      // Get the raw JSON data that contains both rules and guidelines
      final rawData = KnowledgeImplementation.getRawJsonData(widget.initialCategory);
      
      if (rawData != null) {
        // Parse rule base structure as before
        _parseAdditionalRuleBaseStructure(ruleBase);
        
        // Also extract guidelines from the same JSON data
        if (rawData.containsKey('guidelines')) {
          setState(() {
            _guidelines = rawData['guidelines'] as Map<String, dynamic>;
          });
        }
      }

      // Check for session resumption
      String? startingNodeId = 'start';
      if (widget.initialBatch.length == 1 && widget.initialBatch[0] is String) {
        final repository = SessionRepository();
        final sessions = await repository.getSavedSessions();
        final session = sessions.firstWhere(
          (s) => s.id == widget.initialBatch[0],
          orElse: () => SavedSession(
            id: '',
            deviceCategory: '',
            savedAt: DateTime.now(),
            detectedComponents: [],
            componentImages: {},
          ),
        );
        
        if (session.currentNodeId != null) {
          startingNodeId = session.currentNodeId;
          print("Resuming session from node: $startingNodeId");
        }
      }
      
      // Find starting node
      Node? startingNode = ruleBase.findNodeById(startingNodeId ?? 'start');
      
      setState(() {
        _ruleBase = ruleBase;
        _currentNode = startingNode ?? ruleBase.startNode;
        _isLoading = false;
        _updateCurrentComponentFromNodeId(_currentNode?.id ?? '');
      });

      // Show guidelines dialog if not shown before
      // Added after setState to ensure UI is ready
      if (!_showedInitialGuide && _guidelines != null) {
        // Use post-frame callback to avoid showing dialog during build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showGuidelinesDialog();
        });
      }
    } catch (e) {
      print("Error loading rule base: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Extracts additional configuration from the JSON data
  void _parseAdditionalRuleBaseStructure(RuleBase ruleBase) {
    // Get the raw JSON data (before it was converted to RuleBase)
    final rawData = KnowledgeImplementation.getRawJsonData(widget.initialCategory);
    if (rawData != null) {
      // Extract various configuration maps from the JSON
      _componentMapping = rawData['component_mapping'];

      

      if (rawData.containsKey('issue_component_mapping')) {
        _issueComponentMapping = Map<String, dynamic>.from(rawData['issue_component_mapping']);
      }
      
      // Parse component starting nodes (if available)
      if (rawData.containsKey('component_start_nodes')) {
        _componentStartNodes = Map<String, String>.from(rawData['component_start_nodes']);
      }
      
      // Parse component label mappings (if available)
      if (rawData.containsKey('component_labels')) {
        _componentLabelMapping = Map<String, String>.from(rawData['component_labels']);
      }

      // Debug output
      print("Component mapping: $_componentMapping");
      print("Component start nodes: $_componentStartNodes");
      print("Component label mapping: $_componentLabelMapping");
      print("Issue component mapping: $_issueComponentMapping");
    }
  }
  
  // Handles navigation between nodes in the decision tree
  void _navigateToNode(String nodeIdOrComponent) {
    if (_ruleBase == null) return; // Safety check
    
    // Handle both direct node IDs and component names
    String nodeId = nodeIdOrComponent;
    if (_componentStartNodes != null && _componentStartNodes!.containsKey(nodeIdOrComponent)) {
      // If this is a component name, look up its starting node ID
      nodeId = _componentStartNodes![nodeIdOrComponent]!;
      print("Translating component '$nodeIdOrComponent' to node ID: '$nodeId'");
    }
    
    // Find the node in the rule base
    final node = _ruleBase!.findNodeById(nodeId);
    if (node != null) {
      // Update current component tracking based on node ID
      _updateCurrentComponentFromNodeId(nodeId);
      
      // Update UI with the new node
      setState(() {
        _currentNode = node;
      });
    } else {
      print("ERROR: Could not find node with ID: $nodeId");
    }
  }
  
  // Updates the current component tracking based on node ID conventions
  void _updateCurrentComponentFromNodeId(String nodeId) {
    // Check for extraction nodes (by convention they start with 'extract_')
    if (nodeId.startsWith('extract_')) {
      String withoutPrefix = nodeId.substring('extract_'.length);

      String componentName = withoutPrefix.split('_')[0];
      setState(() {
        _currentComponent = componentName;
      });
      print("Now working on component: $_currentComponent");
    } 
    // Check component mapping for issue nodes
    else if (_componentMapping != null) {
      _componentMapping!.forEach((issue, components) {
        if (nodeId == issue) {
          if (components is String) {
            setState(() {
              _currentComponent = components;
            });
            print("Selected component issue: $_currentComponent");
          } 
          // Multiple components case - don't set a specific component
        }
      });
    }
    
    // Reset component tracking when at selection screens
    if (nodeId == 'end' || 
        nodeId == 'start' || 
        nodeId == 'component_extraction' || 
        nodeId == 'issue') {
      setState(() {
        _currentComponent = null;
      });
      print("Reset current component - now at selection screen");
    }
  }
  

  // Shows a full-screen image overlay when an image is tapped
  void _showImageOverlay(BuildContext context, String imagePath) {
    showDialog(
      context: context, // Current build context
      builder: (BuildContext context) {
        // Create a custom dialog for the image
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(8),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Semi-transparent background that dismisses on tap
              GestureDetector(
                onTap: () => Navigator.pop(context), // Close dialog on tap
                child: Container(
                  color: Colors.black87,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Image with pinch zoom capability
                  Flexible(
                    child: Container(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.8,
                        maxWidth: MediaQuery.of(context).size.width * 0.9,
                      ),
                      child: InteractiveViewer(
                        minScale: 0.5,
                        maxScale: 4.0, // Allow zooming in up to 4x
                        child: Image.file(
                          File(imagePath),
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Close button
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

  // Show the guidelines dialog
  void _showGuidelinesDialog() {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: Color(0xFF34A853),
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Before We Get Started',
                      style: GoogleFonts.montserrat(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Safety Guidelines Section
                Text(
                  'Guidelines:',
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                ..._guidelines?['safety']?.map<Widget>((guideline) =>
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ', style: TextStyle(fontSize: 16)),
                        Expanded(
                          child: Text(
                            guideline,
                            style: GoogleFonts.montserrat(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )?.toList() ?? [],
                
                const SizedBox(height: 16),
                
                // Recommended Tools Section
                Text(
                  'Recommended Tools:',
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                ..._guidelines?['tools']?.map<Widget>((tool) =>
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ', style: TextStyle(fontSize: 16)),
                        Expanded(
                          child: Text(
                            tool,
                            style: GoogleFonts.montserrat(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )?.toList() ?? [],
                
                const SizedBox(height: 24),
                
                // OK Button
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _showedInitialGuide = true;
                        });
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0, // Remove button shadow
                      ),
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF34A853), Color(0xFF0F9D58)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Text(
                          'Got It',
                          style: GoogleFonts.montserrat(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Main build method for the widget UI
  @override
  Widget build(BuildContext context) {
    return Base(
      title: 'Extraction Assistant',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16), // Add padding around everything
        child: Column(
          children: [
            // Top collapsible summary section (green header)
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF34A853), Color(0xFF0F9D58)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20), // Rounded corners
                boxShadow: [ // Optional shadow for depth
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header row with title and toggle button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Device Category',
                          style: GoogleFonts.montserrat(
                            fontSize: 16,
                            color: Colors.white70,
                          ),
                        ),
                        // Toggle button for expanding/collapsing
                        IconButton(
                          icon: Icon(
                            _isSummaryExpanded 
                                ? Icons.keyboard_arrow_up 
                                : Icons.keyboard_arrow_down,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            // Update UI state when pressed
                            setState(() {
                              _isSummaryExpanded = !_isSummaryExpanded;
                            });
                          },
                        ),
                      ],
                    ),
                    
                    // Device category display (e.g., "Laptop")
                    Text(
                      widget.initialCategory,
                      style: GoogleFonts.montserrat(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    
                    // Component chips (small buttons) for each detected component
                    if (widget.initialDetections.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 12, bottom: 8),
                        child: Wrap( // Wrap automatically handles wrapping to next line
                          spacing: 8,
                          runSpacing: 8,
                          children: _getUniqueComponents().map((component) {
                            // Process component name for display
                            final displayName = component.split('_')[0];
                            final baseComponent = displayName.toLowerCase();
                            
                            // Check if this is the currently selected component
                            final isCurrentComponent = _currentComponent != null && 
                                baseComponent == _currentComponent!.toLowerCase();
                            
                            // Get appropriate icon for this component type
                            IconData iconData = _getIconForComponent(baseComponent);
                            
                            // Build chip UI
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: isCurrentComponent 
                                    ? Colors.white  // White background for selected
                                    : Colors.white10, // Translucent for others
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isCurrentComponent 
                                      ? Colors.white 
                                      : Colors.white30
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    iconData,
                                    color: isCurrentComponent 
                                        ? const Color(0xFF34A853) // Green for selected
                                        : Colors.white,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _formatComponentName(displayName),
                                    style: GoogleFonts.montserrat(
                                      color: isCurrentComponent 
                                          ? const Color(0xFF34A853) 
                                          : Colors.white,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    
                    // Additional sections only shown when expanded
                    if (_isSummaryExpanded && widget.initialComponentImages.isNotEmpty) ...[
                      // Input Images Section - shows original device photos
                      const SizedBox(height: 16),
                      Text(
                        'Input Images',
                        style: GoogleFonts.montserrat(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Horizontal scrolling list of images
                      SizedBox(
                        height: 120,
                        child: ListView(
                          scrollDirection: Axis.horizontal, // Horizontal scrolling
                          children: [
                            for (var imagePath in widget.initialComponentImages.keys)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: GestureDetector(
                                  onTap: () => _showImageOverlay(context, imagePath), // Show fullscreen on tap
                                  child: Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.white30),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.file(
                                        File(imagePath),
                                        height: 120,
                                        width: 160, // Set a fixed width to maintain aspect ratio
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      
                      // Detected Components Section - cropped component images
                      const SizedBox(height: 16),
                      Text(
                        'Detected Components',
                        style: GoogleFonts.montserrat(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Horizontal scrolling grid of component images
                      SizedBox(
                        height: 140,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            // Nested loops to get all component images
                            for (var entry in widget.initialComponentImages.entries)
                              for (var componentEntry in entry.value.entries)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: GestureDetector(
                                    onTap: () => _showImageOverlay(context, componentEntry.value),
                                    child: Container(
                                      width: 120,
                                      // Highlight the current component
                                      decoration: BoxDecoration(
                                        color: _isCurrentComponentImage(componentEntry.key) 
                                            ? Colors.white 
                                            : Colors.white10,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          // Component image thumbnail
                                          Expanded(
                                            child: ClipRRect(
                                              borderRadius: const BorderRadius.vertical(
                                                top: Radius.circular(8),
                                              ),
                                              child: Image.file(
                                                File(componentEntry.value),
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                          ),
                                          // Component name label
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 8,
                                              horizontal: 4,
                                            ),
                                            child: Text(
                                              _formatComponentName(componentEntry.key.split('_')[0]),
                                              style: GoogleFonts.montserrat(
                                                fontSize: 12,
                                                color: _isCurrentComponentImage(componentEntry.key)
                                                    ? const Color(0xFF34A853)
                                                    : Colors.white,
                                                fontWeight: FontWeight.w500,
                                              ),
                                              textAlign: TextAlign.center,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16), // Space between containers
            
            // Main instructions section (white area)
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20), // Rounded corners
                boxShadow: [ // Optional shadow for depth
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              // Show loading indicator or instructions based on state
              child: _isLoading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(color: Color(0xFF34A853)),
                    ),
                  )
                : _buildInstructionsContent(),
            ),
          ],
        ),
      ),
    );
  }

  // Check if a component image belongs to the current component
  bool _isCurrentComponentImage(String componentKey) {
    if (_currentComponent == null) return false;
    // Check if this image key starts with the current component name
    return componentKey.toLowerCase().startsWith(_currentComponent!.toLowerCase());
  }
  
  // Maps component types to appropriate Material Icons
  IconData _getIconForComponent(String component) {
    switch (component.toLowerCase()) {
      case 'ram':
        return Icons.memory; // Memory stick icon
      case 'battery':
      case 'cmos':
        return Icons.battery_full; // Battery icon
      case 'fan':
      case 'cooler':
        return Icons.air; // Fan/air icon
      case 'wifi':
      case 'card':
        return Icons.wifi; // WiFi icon
      case 'drive':
      case 'hdd':
      case 'ssd':
      case 'disk':
        return Icons.storage; // Storage icon
      case 'cpu':
        return Icons.developer_board; // Circuit board icon
      case 'gpu':
        return Icons.videogame_asset; // Graphics/gaming icon
      case 'psu':
        return Icons.power; // Power icon
      case 'mboard':
        return Icons.dashboard; // Dashboard icon for motherboard
      case 'case':
        return Icons.computer; // Computer case icon
      default:
        return Icons.memory; // Default fallback icon
    }
  }

  // Builds the main instruction content based on current node
  Widget _buildInstructionsContent() {
    if (_currentNode == null) {
      return const Center(
        child: Text('No instructions available for this device.'),
      );
    }
    
    // Get all images for current component
    final componentImagePaths = _getCurrentComponentImagePaths();
    
    // Main instructions UI structure
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Component title at top if we're on a component-specific node
          if (_currentComponent != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                _formatComponentName(_currentComponent!),
                style: GoogleFonts.montserrat(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
          
          // Instructions header with icon
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                color: const Color(0xFF34A853),
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Instructions',
                style: GoogleFonts.montserrat(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF34A853),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Component images if available for this step
          if (componentImagePaths.isNotEmpty) ...[
            SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: componentImagePaths.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: EdgeInsets.only(right: index < componentImagePaths.length - 1 ? 8 : 0),
                    child: GestureDetector(
                      onTap: () => _showImageOverlay(context, componentImagePaths[index]),
                      child: Container(
                        width: 120,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(componentImagePaths[index]),
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          // Node text - could be a question or instruction headline
          if (_currentNode!.text != null)
            Text(
              _currentNode!.text!,
              style: GoogleFonts.montserrat(
                fontSize: 18,
                color: Colors.grey[800],
              ),
            ),
          
          const SizedBox(height: 24),
          
          // Scrollable area for steps and options (allows for overflow content)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Step-by-step instructions (if this node has steps)
              if (_currentNode!.isStepNode) ...[
                ListView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: _currentNode!.steps.length,
                  itemBuilder: (context, index) {
                    final step = _currentNode!.steps[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Step number circle
                              Container(
                                width: 28,
                                height: 28,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [Color(0xFF34A853), Color(0xFF0F9D58)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    '${index + 1}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Step instruction text
                              Expanded(
                                child: Text(
                                  step.action,
                                  style: GoogleFonts.montserrat(
                                    fontSize: 16,
                                    color: Colors.grey[800],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          // Add image if available
                          if (step.image != null && step.image!.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            GestureDetector(
                              onTap: () => _showImageOverlay(context, step.image!),
                              child: Container(
                                height: 150,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.asset(
                                    step.image!,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
              ],

              // Options/answers for questions (if this node has options)
              if (_currentNode!.isQuestionNode) ...[
                // Only show label if there are no steps (avoids redundancy)
                if (!_currentNode!.isStepNode) 
                  Text(
                    'Select an option:',
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[600],
                    ),
                  ),
                if (!_currentNode!.isStepNode)  
                  const SizedBox(height: 16),
                
                // Generate buttons for each option
                ..._getFilteredOptions().map((option) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _navigateToNode(option.next), // Navigate on press
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF34A853), Color(0xFF0F9D58)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            option.label,
                            style: GoogleFonts.montserrat(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ],
            ],
          ),
          
          // Next button for step nodes (at bottom of screen)
          if (_currentNode!.isStepNode && _currentNode!.next != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _navigateToNode(_currentNode!.next!),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF34A853), Color(0xFF0F9D58)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'Next',
                      style: GoogleFonts.montserrat(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),

          // Navigation action buttons (always visible)
          const SizedBox(height: 24),
          
          // Navigation action buttons container
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                // Row for Change Device and Add Images buttons
                Row(
                  children: [
                    // Change Device button with gradient
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const Category(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF34A853), Color(0xFF0F9D58)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.change_circle, color: Colors.white),
                              const SizedBox(width: 8),
                              Text(
                                'Change Device',
                                style: GoogleFonts.montserrat(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12), // Space between the two buttons
                    
                    // Add Images button
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          // Extract all component image paths into a list of File objects
                          List<File> existingImages = [];
                          
                          // Add source/original images
                          for (var imagePath in widget.initialComponentImages.keys) {
                            existingImages.add(File(imagePath));
                          }
                          
                          // Navigate to UploadPage with existing images
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => UploadPage(
                                category: widget.initialCategory,
                                existingImages: existingImages,
                                sessionId: _sessionId, // Pass the current session ID
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF34A853), Color(0xFF0F9D58)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.add_photo_alternate, color: Colors.white),
                              const SizedBox(width: 8),
                              Text(
                                'Add Images',
                                style: GoogleFonts.montserrat(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 9), // Space between the row and Summary button
                
                // Summary button
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SummaryScreen(
                          deviceCategory: widget.initialCategory,
                          extractedComponents: widget.initialDetections,
                          componentImages: widget.initialComponentImages,
                          originalImagePath: widget.initialImagePath ?? ''
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF34A853), Color(0xFF0F9D58)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.summarize, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(
                          'Value Estimation',
                          style: GoogleFonts.montserrat(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 9), // Space between Summary and Save Session button
                
                // Save Session button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final repository = SessionRepository();
                      
                      // Create or update the session
                      final session = SavedSession(
                        id: _sessionId!,
                        deviceCategory: widget.initialCategory,
                        mainImagePath: widget.initialImagePath,
                        savedAt: DateTime.now(),
                        detectedComponents: widget.initialDetections,
                        componentImages: widget.initialComponentImages,
                        currentNodeId: _currentNode?.id, // Save the current node ID
                      );

                      // Check if this session already exists
                      final existingSessions = await repository.getSavedSessions();
                      final existingSessionIndex = existingSessions.indexWhere((s) => s.id == _sessionId);
                      
                      if (existingSessionIndex != -1) {
                        // Update existing session
                        existingSessions[existingSessionIndex] = session;
                      } else {
                        // Add new session
                        existingSessions.add(session);
                      }

                      // Save all sessions
                      final jsonList = existingSessions.map((s) => s.toJson()).toList();
                      await repository.saveAllSessions(jsonList);

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Session saved successfully'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    icon: const Icon(Icons.save, color: Colors.white),
                    label: Text(
                      'Save Session',
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4285F4), // Blue color
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper to capitalize first letter of component names
  String _formatComponentName(String name) {
    // Split by underscore and only use the first part
    String firstPart = name.split('_')[0];
    return firstPart[0].toUpperCase() + firstPart.substring(1);
  }

  // Helper to get unique component names from detected components
  List<String> _getUniqueComponents() {
    return widget.initialDetections.toSet().toList();
  }

  // Filters options shown based on detected components
  List<Option> _getFilteredOptions() {
    if (_currentNode == null || !_currentNode!.isQuestionNode) {
      return [];
    }
    
    // Special handling for component extraction screen - only show detected components
    if (_currentNode!.id == "component_extraction") {
      return _currentNode!.options.where((option) {
        // Always include navigation options like "Back" or "End"
        if (["Back", "End"].contains(option.label)) {
          return true;
        }
        
        // Convert option label to component name for comparison
        String componentName = _getComponentNameFromLabel(option.label).toLowerCase();
        
        // Only include options for components that were detected
        return widget.initialDetections.any((detection) {
          return detection.toLowerCase().startsWith(componentName);
        });
      }).toList();
    }
    
    // Special handling for issue screen - only show detected components
    else if (_currentNode!.id == "issue") {
      return _currentNode!.options.where((option) {
        // Always include navigation options
        if (["Back", "End"].contains(option.label)) {
          return true;
        }
        
        // Check if this issue is related to any detected component
        return _isIssueRelevantToDetectedComponents(option.label);
      }).toList();
    }

    // For other screens, show all available options
    return _currentNode!.options;
  }

  // Helper to extract a component name from a UI option label
  String _getComponentNameFromLabel(String label) {
    // If we have a mapping from the JSON configuration, use it
    if (_componentLabelMapping != null) {
      // Try exact match first
      if (_componentLabelMapping!.containsKey(label)) {
        return _componentLabelMapping![label]!;
      }
      
      // Then try partial matches
      for (var entry in _componentLabelMapping!.entries) {
        if (label.toLowerCase().contains(entry.key.toLowerCase())) {
          return entry.value;
        }
      }
    }
    
    // Default fallback: extract the first word and convert to lowercase
    return label.split(' ')[0].toLowerCase();
  }

  // Helper to determine if an issue should be shown based on detected components
  bool _isIssueRelevantToDetectedComponents(String issueLabel) {
    // If we have issue_component_mapping in JSON, use it
    if (_issueComponentMapping != null && _issueComponentMapping!.containsKey(issueLabel)) {
      final components = _issueComponentMapping![issueLabel];
      
      // Handle both string and list mappings
      if (components is List) {
        // Check if any of these components were detected
        return components.any((component) => 
          widget.initialDetections.any((detection) => 
            detection.toLowerCase().startsWith(component.toLowerCase())));
      } 
      else if (components is String) {
        // Check if this single component was detected
        return widget.initialDetections.any((detection) => 
          detection.toLowerCase().startsWith(components.toLowerCase()));
      }
    }
    
    // Fallback to component label mapping
    String componentName = _getComponentNameFromLabel(issueLabel).toLowerCase();
    return widget.initialDetections.any((detection) => 
      detection.toLowerCase().startsWith(componentName));
  }
}