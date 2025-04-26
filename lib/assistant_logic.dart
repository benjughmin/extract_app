import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class AssistantLogic {
  final String category;
  final List<String> detectedComponents;
  final Map<String, Map<String, String>> componentImages;
  
  Map<String, dynamic> _instructionData = {};
  String currentNodeId = 'start';
  List<String> _componentQueue = [];
  int _currentComponentIndex = -1;
  
  AssistantLogic({
    required this.category,
    required this.detectedComponents,
    required this.componentImages,
  });
  
  Future<void> initialize() async {
    // Load the appropriate JSON file based on category
    final jsonData = await _loadInstructionJson();
    _instructionData = jsonData;
    
    // Initialize component queue based on detected components
    _initializeComponentQueue();
    
    // Start with the first component
    if (_componentQueue.isNotEmpty) {
      _currentComponentIndex = 0;
    }
  }
  
  Future<Map<String, dynamic>> _loadInstructionJson() async {
    String jsonPath;
    
    // Determine which JSON file to load based on category
    switch (category) {
      case 'Smartphone':
        jsonPath = 'assets/smartphone_instructions.json';
        break;
      case 'Laptop':
        jsonPath = 'assets/laptop_instructions.json';
        break;
      case 'Desktop':
        jsonPath = 'assets/desktop_instructions.json';
        break;
      case 'Router':
        jsonPath = 'assets/router_instructions.json';
        break;
      case 'Landline Phone':
        jsonPath = 'assets/landline_instructions.json';
        break;
      default:
        jsonPath = 'assets/generic_instructions.json';
    }
    
    try {
      final String jsonString = await rootBundle.loadString(jsonPath);
      return jsonDecode(jsonString);
    } catch (e) {
      print('Error loading instruction data: $e');
      return {'nodes': []};
    }
  }
  
  void _initializeComponentQueue() {
    // Filter out duplicates and create a queue of components to process
    _componentQueue = detectedComponents
        .map((comp) => comp.split('_')[0]) // Remove any suffix after underscore
        .toSet()
        .toList();
  }
  
  String getCurrentInstruction() {
    if (_instructionData.isEmpty || !_nodeExists(currentNodeId)) {
      return 'No instructions available.';
    }
    
    final currentNode = _getNode(currentNodeId);
    
    // Check if the node has text
    if (currentNode.containsKey('text')) {
      return currentNode['text'];
    }
    
    // Check if the node has steps
    if (currentNode.containsKey('steps')) {
      List<Map<String, dynamic>> steps = List<Map<String, dynamic>>.from(currentNode['steps']);
      steps.sort((a, b) => a['order'].compareTo(b['order']));
      
      return steps.map((step) => '${step['order']}. ${step['action']}').join('\n\n');
    }
    
    // Check if the node has instructions
    if (currentNode.containsKey('instructions')) {
      List<Map<String, dynamic>> instructions = List<Map<String, dynamic>>.from(currentNode['instructions']);
      return instructions.map((instruction) => '• ${instruction['step']}').join('\n\n');
    }
    
    return 'Ready to process component.';
  }
  
  List<String> getCurrentOptionLabels() {
    if (_instructionData.isEmpty || 
        !_nodeExists(currentNodeId) || 
        !_getNode(currentNodeId).containsKey('options')) {
      return [];
    }
    
    final options = List<Map<String, dynamic>>.from(_getNode(currentNodeId)['options']);
    
    // If we're at the start node, filter options based on detected components
    if (currentNodeId == 'start') {
      // For Desktop category, directly show options for detected components
      if (category == 'Desktop') {
        return options
          .where((option) {
            String labelLower = option['label'].toString().toLowerCase();
            return _componentQueue.any((comp) => 
              _normalizeComponentName(comp).toLowerCase() == _normalizeComponentName(labelLower).toLowerCase() ||
              _normalizeComponentName(labelLower).toLowerCase().contains(_normalizeComponentName(comp).toLowerCase()) ||
              _normalizeComponentName(comp).toLowerCase().contains(_normalizeComponentName(labelLower).toLowerCase()));
          })
          .map<String>((option) => option['label'] as String)
          .toList();
      }
      
      // For other categories, show all options from the start node
      return options.map<String>((option) => option['label'] as String).toList();
    }
    
    return options.map<String>((option) => option['label'] as String).toList();
  }
  
  String _normalizeComponentName(String name) {
    return name
        .replaceAll('-', ' ')
        .replaceAll('_', ' ')
        .replaceAll('  ', ' ')
        .trim();
  }
  
  void selectOption(int index) {
    if (_instructionData.isEmpty || 
        !_nodeExists(currentNodeId) || 
        !_getNode(currentNodeId).containsKey('options')) {
      return;
    }
    
    final options = List<Map<String, dynamic>>.from(_getNode(currentNodeId)['options']);
    
    // If we're at start node and Desktop category, filter options based on detected components
    List<Map<String, dynamic>> filteredOptions = options;
    if (currentNodeId == 'start' && category == 'Desktop') {
      filteredOptions = options
        .where((option) {
          String labelLower = option['label'].toString().toLowerCase();
          return _componentQueue.any((comp) => 
            _normalizeComponentName(comp).toLowerCase() == _normalizeComponentName(labelLower).toLowerCase() ||
            _normalizeComponentName(labelLower).toLowerCase().contains(_normalizeComponentName(comp).toLowerCase()) ||
            _normalizeComponentName(comp).toLowerCase().contains(_normalizeComponentName(labelLower).toLowerCase()));
        })
        .toList();
    }
    
    if (index >= 0 && index < filteredOptions.length) {
      final nextNodeId = filteredOptions[index]['next'];
      currentNodeId = nextNodeId;
    }
  }
  
  bool hasMoreComponents() {
    return _componentQueue.isNotEmpty && _currentComponentIndex < _componentQueue.length - 1;
  }
  
  String? getNextComponentName() {
    if (!hasMoreComponents()) return null;
    
    if (_currentComponentIndex < 0 || _currentComponentIndex >= _componentQueue.length - 1) return null;
    
    return _componentQueue[_currentComponentIndex + 1];
  }
  
  void moveToNextComponent() {
    if (!hasMoreComponents()) return;
    
    if (_currentComponentIndex < 0 || _currentComponentIndex >= _componentQueue.length - 1) return;
    
    _currentComponentIndex++;
    currentNodeId = 'start';  // Reset to start node for the next component
  }
  
  String? getCurrentComponent() {
    if (_currentComponentIndex < 0 || _currentComponentIndex >= _componentQueue.length) {
      return null;
    }
    return _componentQueue[_currentComponentIndex];
  }
  
  String? getCurrentComponentImage() {
    String? current = getCurrentComponent();
    if (current == null) return null;
    
    // Look through all component images to find the current one
    for (var entry in componentImages.entries) {
      for (var component in entry.value.keys) {
        if (component == current || component.startsWith('${current}_')) {
          return entry.value[component];
        }
      }
    }
    
    return null;
  }
  
  bool isAtEnd() {
    if (_instructionData.isEmpty || !_nodeExists(currentNodeId)) {
      return false;
    }
    
    final currentNode = _getNode(currentNodeId);
    
    // If node has options, we're not at an end
    if (currentNode.containsKey('options') && 
        (currentNode['options'] as List).isNotEmpty) {
      return false;
    }
    
    // If node has next_component, we're potentially at an end for this component
    if (currentNode.containsKey('next_component')) {
      return true;
    }
    
    // Node with id "end" is explicitly an end
    if (currentNodeId == 'end') {
      return true;
    }
    
    // Node has no options and no next_component, must be an end
    return true;
  }
  
  bool _nodeExists(String nodeId) {
    if (!_instructionData.containsKey('nodes')) return false;
    
    final nodes = List<Map<String, dynamic>>.from(_instructionData['nodes']);
    return nodes.any((node) => node['id'] == nodeId);
  }
  
  Map<String, dynamic> _getNode(String nodeId) {
    if (!_instructionData.containsKey('nodes')) return {};
    
    final nodes = List<Map<String, dynamic>>.from(_instructionData['nodes']);
    return nodes.firstWhere(
      (node) => node['id'] == nodeId, 
      orElse: () => {},
    );
  }
}