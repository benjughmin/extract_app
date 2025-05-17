import 'dart:convert';
import 'package:flutter/services.dart'; 

/// Class to load and handle rule-based knowledge from JSON files
class KnowledgeImplementation {
  // Static maps store data that persists across the entire app lifetime
  // The underscore (_) prefix indicates these are private variables
  static final Map<String, RuleBase> _loadedRuleBases = {}; // Cache to avoid reloading
  
  // Store raw JSON data for access to additional structures
  static final Map<String, Map<String, dynamic>> _rawJsonData = {}; // Original JSON before parsing

  /// Load the rule base for a specific device category
  /// The "static" keyword means this method belongs to the class itself, not instances
  /// "Future<RuleBase>" means this is an asynchronous method that will eventually return a RuleBase
  static Future<RuleBase> loadRuleBase(String category) async {
    // Convert category to lowercase for consistent file naming
    // The replaceAll method creates a new string with spaces replaced by underscores
    final normalizedCategory = category.toLowerCase().replaceAll(' ', '_');
    
    print("Looking for rule base: assets/${normalizedCategory}_instructions.json");
    
    // Return cached rule base if already loaded (improves performance)
    if (_loadedRuleBases.containsKey(normalizedCategory)) {
      // The exclamation mark (!) is a null safety operator that tells Dart this value won't be null
      return _loadedRuleBases[normalizedCategory]!;
    }
    
    try {
      // Load rule base from JSON file in the assets folder
      // rootBundle gives access to the app's assets defined in pubspec.yaml
      // The "await" keyword pauses execution until the async operation completes
      final jsonString = await rootBundle.loadString(
        'assets/${normalizedCategory}_instructions.json'
      );
      
      print("JSON string loaded, length: ${jsonString.length}");
      
      // Parse JSON string into a Map (dictionary) structure
      // The "dynamic" type means the values can be of any type
      final Map<String, dynamic> jsonData = json.decode(jsonString);
      
      // Store the raw JSON data for access to additional structures
      _rawJsonData[normalizedCategory] = jsonData;
      
      print("JSON decoded successfully");
      
      // Create rule base object using the factory constructor fromJson
      final ruleBase = RuleBase.fromJson(jsonData);
      
      // Log successful parsing
      print("Rule base created with ${ruleBase.nodes.length} nodes");
      
      // Cache the loaded rule base for future use
      _loadedRuleBases[normalizedCategory] = ruleBase;
      
      return ruleBase;
    } catch (e) {
      // Error handling: print error and return empty rule base
      print('Error loading rule base for $category: $e');
      // Return empty rule base if there's an error (graceful failure)
      return RuleBase(nodes: []);
    }
  }
  
  /// Get the raw JSON data for the currently loaded rule base
  /// The square brackets [] indicate an optional parameter
  static Map<String, dynamic>? getRawJsonData([String? category]) {
    // The question mark (?) after the return type allows this method to return null
    if (_rawJsonData.isEmpty) return null;
    
    if (category != null) {
      final normalized = category.toLowerCase().replaceAll(' ', '_');
      return _rawJsonData[normalized];
    }
    
    // If no category is specified, return the first available one
    return _rawJsonData.values.first;
  }
}

/// Represents the complete rule base loaded from a JSON file
/// This is the main container for all the decision tree nodes
class RuleBase {
  final List<Node> nodes; // The list of all nodes in this rule base
  
  // Constructor with a required named parameter (nodes)
  RuleBase({required this.nodes});
  
  /// Create a RuleBase from JSON data
  /// Factory constructors create instances but with custom initialization logic
  factory RuleBase.fromJson(Map<String, dynamic> json) {
    // The ?? operator provides a default value (empty list) if json['nodes'] is null
    final List<dynamic> nodesList = json['nodes'] ?? [];
    // Use map() to transform each JSON object into a Node object
    final List<Node> nodes = nodesList.map((nodeJson) => Node.fromJson(nodeJson)).toList();
    
    return RuleBase(nodes: nodes);
  }
  
  /// Find a node by its ID
  /// Returns null if no node with that ID exists
  Node? findNodeById(String id) {
    try {
      // firstWhere returns the first element that satisfies the condition
      return nodes.firstWhere((node) => node.id == id);
    } catch (e) {
      // If no node is found, firstWhere throws an exception, so we return null
      return null;
    }
  }
  
  /// Get the starting node (usually with ID 'start')
  /// This is a "getter" - it looks like a property but is actually a computed value
  Node? get startNode {
    return findNodeById('start');
  }
}

/// Represents a single node in the rule base
/// Each node can be either a question (with options) or instructions (with steps)
class Node {
  final String id; // Unique identifier for the node
  final String? text; // The main text/question displayed to the user (optional)
  final List<Option> options; // List of possible answers/options for this node
  final List<Step> steps; // List of step-by-step instructions for this node
  final String? next; // ID of the next node to navigate to (if this is a step node)
  final String? image; // Single image for this node
  final List<String> images; // Multiple images for this node
  
  // Constructor with one required parameter and several optional parameters
  // The const [] creates empty immutable lists as defaults
  Node({
    required this.id,
    this.text,
    this.options = const [],
    this.steps = const [],
    this.next,
    this.image,
    this.images = const [],
  });
  
  /// Create a Node from JSON data
  factory Node.fromJson(Map<String, dynamic> json) {
    // Parse options if present
    final List<Option> options = [];
    if (json.containsKey('options')) {
      final List<dynamic> optionsList = json['options'];
      // Parse each option JSON object into an Option object
      options.addAll(optionsList.map((option) => Option.fromJson(option)));
    }
    
    // Parse steps if present
    final List<Step> steps = [];
    if (json.containsKey('steps')) {
      final List<dynamic> stepsList = json['steps'];
      // Parse each step JSON object into a Step object
      steps.addAll(stepsList.map((step) => Step.fromJson(step)));
      
      // Sort steps by order number to ensure correct sequence
      steps.sort((a, b) => a.order.compareTo(b.order));
    }
    
    // Parse images if present
    List<String> images = [];
    if (json.containsKey('images')) {
      final List<dynamic> imagesList = json['images'];
      images = imagesList.map((img) => img.toString()).toList();
    }
    
    return Node(
      id: json['id'],
      text: json['text'],
      options: options,
      steps: steps,
      next: json['next'],
      image: json['image'], // Add single image
      images: images, // Add multiple images
    );
  }
  
  /// Determines if this node is a question node (has options)
  /// This is another getter that computes a boolean value
  bool get isQuestionNode => options.isNotEmpty; // Using arrow syntax for a one-line getter
  
  /// Determines if this node is a step-by-step instruction node
  bool get isStepNode => steps.isNotEmpty;
  
  /// Check if this node has any images (either single or multiple)
  bool get hasImages => image != null || images.isNotEmpty;
}

/// Represents a choice option in a question node
/// Example: "Yes" or "No" button that leads to different nodes
class Option {
  final String label; // The text displayed on the button/option
  final String next; // The ID of the node to navigate to when this option is selected
  
  Option({required this.label, required this.next});
  
  // Convert JSON data to an Option object
  factory Option.fromJson(Map<String, dynamic> json) {
    return Option(
      label: json['label'],
      next: json['next'],
    );
  }
}

/// Represents a single step in an instruction
/// Used to show step-by-step guides to the user
class Step {
  final int order; // The sequence number of this step
  final String action; // The instruction text for this step
  final String? image;  // Add this property for images
  
  Step({
    required this.order, 
    required this.action,
    this.image,  // Add to constructor
  });
  
  // Convert JSON data to a Step object
  factory Step.fromJson(Map<String, dynamic> json) {
    return Step(
      order: json['order'],
      action: json['action'],
      image: json['image'],  // Parse image from JSON
    );
  }
}