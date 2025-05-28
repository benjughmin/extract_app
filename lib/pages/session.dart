// Stores the information about the user's progress
class SavedSession {
  final String id;
  final String deviceCategory;
  final String? mainImagePath;
  final DateTime savedAt;
  final List<String> detectedComponents;
  final Map<String, Map<String, String>> componentImages;
  final String? currentNodeId; 

  SavedSession({
    required this.id,
    required this.deviceCategory,
    this.mainImagePath,
    required this.savedAt,
    required this.detectedComponents,
    required this.componentImages,
    this.currentNodeId, 
  });

  factory SavedSession.fromJson(Map<String, dynamic> json) {
    return SavedSession(
      id: json['id'],
      deviceCategory: json['deviceCategory'],
      mainImagePath: json['mainImagePath'],
      savedAt: DateTime.parse(json['savedAt']),
      detectedComponents: List<String>.from(json['detectedComponents']),
      componentImages: (json['componentImages'] as Map).map((key, value) => 
        MapEntry(key, Map<String, String>.from(value))),
      currentNodeId: json['currentNodeId'], 
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'deviceCategory': deviceCategory,
      'mainImagePath': mainImagePath,
      'savedAt': savedAt.toIso8601String(),
      'detectedComponents': detectedComponents,
      'componentImages': componentImages,
      'currentNodeId': currentNodeId, 
    };
  }

  SavedSession copyWith({
    String? id,
    String? deviceCategory,
    String? mainImagePath,
    DateTime? savedAt,
    List<String>? detectedComponents,
    Map<String, Map<String, String>>? componentImages,
    String? currentNodeId,
  }) {
    return SavedSession(
      id: id ?? this.id,
      deviceCategory: deviceCategory ?? this.deviceCategory,
      mainImagePath: mainImagePath ?? this.mainImagePath,
      savedAt: savedAt ?? this.savedAt,
      detectedComponents: detectedComponents ?? this.detectedComponents,
      componentImages: componentImages ?? this.componentImages,
      currentNodeId: currentNodeId ?? this.currentNodeId,
    );
  }
}