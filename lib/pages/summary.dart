import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import '/pages/base.dart';
import '/pages/ewaste_map_screen.dart';
import '/pages/feedback_service.dart';

Future<void> ensureSignedIn() async {
  final auth = FirebaseAuth.instance;
  if (auth.currentUser == null) {
    await auth.signInAnonymously();
  }
}

// Parameter Dialog remains unchanged
class ParameterDialog extends StatefulWidget {
  final String componentName;
  final Map<String, dynamic> componentData;
  final Map<String, dynamic> parameters;
  final Function(double, Map<String, String>) onValueCalculated;

  const ParameterDialog({
    required this.componentName,
    required this.componentData,
    required this.parameters,
    required this.onValueCalculated,
    super.key,
  });

  @override
  State<ParameterDialog> createState() => _ParameterDialogState();
}

class _ParameterDialogState extends State<ParameterDialog> {
  final Map<String, String> _selectedValues = {};
  double _currentValue = 0.0;

  void _calculateValue() {
    double basePrice = 0.0;
    
    if (widget.parameters.containsKey('capacity')) {
      if (_selectedValues['capacity'] != null) {
        final capacityPriceRaw = widget.parameters['capacity']['base_prices']?[_selectedValues['capacity']] ?? 0.0;
        final capacityPrice = capacityPriceRaw is int ? capacityPriceRaw.toDouble() : (capacityPriceRaw as double);
        print('💰 Capacity base price: $capacityPrice');
        basePrice = capacityPrice;
      }
    } else {
      final defaultPriceRaw = widget.componentData['default_base_price'] ?? 0.0;
      basePrice =
          defaultPriceRaw is int
              ? defaultPriceRaw.toDouble()
              : (defaultPriceRaw as double);
      print('💰 Default base price: $basePrice');
    }

    widget.parameters.forEach((paramName, paramData) {
      if (_selectedValues[paramName] != null) {
        // Handle both 'multipliers' and 'multiplier' keys
        final multipliers = paramData['multipliers'] ?? paramData['multiplier'];
        if (multipliers != null) {
          final multiplierRaw = multipliers[_selectedValues[paramName]] ?? 1.0;
          final multiplier =
              multiplierRaw is int
                  ? multiplierRaw.toDouble()
                  : (multiplierRaw as double);
          basePrice *= multiplier;
          print('🔢 Applied $paramName multiplier: $multiplier');
        }
      }
    });

    print('💵 Final calculated value: $basePrice');

    setState(() {
      _currentValue = basePrice;
    });
    widget.onValueCalculated(
      _currentValue,
      Map<String, String>.from(_selectedValues),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Dialog UI remains unchanged
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Value Parameters - ${widget.componentName}',
              style: GoogleFonts.montserrat(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Estimated Value: ₱${_currentValue.toStringAsFixed(2)}',
              style: GoogleFonts.montserrat(
                fontSize: 16,
                color: const Color(0xFF34A853),
              ),
            ),
            const SizedBox(height: 16),
            ...widget.parameters.entries.map((entry) {
              final paramName = entry.key;
              final options = entry.value['options'] as List<dynamic>;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: DropdownButtonFormField<String>(
                  isExpanded: true,  // Add this line to make dropdown expand to full width
                  decoration: InputDecoration(
                    labelText:
                        paramName[0].toUpperCase() + paramName.substring(1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF34A853)),
                    ),
                    labelStyle: GoogleFonts.montserrat(color: Colors.grey[600]),
                  ),
                  value: _selectedValues[paramName],
                  style: GoogleFonts.montserrat(
                    color: Colors.black87,
                  ),
                  dropdownColor: Colors.white,
                  icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF34A853)),
                  items: options.map((option) {
                    return DropdownMenuItem(
                      value: option.toString(),
                      child: Text(
                        option.toString(),
                        style: GoogleFonts.montserrat(
                          color: Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedValues[paramName] = value;
                        _calculateValue();
                      });
                    }
                  },
                ),
              );
            }).toList(),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Done',
                    style: GoogleFonts.montserrat(
                      color: const Color(0xFF34A853),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class SummaryScreen extends StatefulWidget {
  final String deviceCategory;
  final List<String> extractedComponents;
  final Map<String, Map<String, String>> componentImages;
  final List<String> userImagePaths;
  final Map<String, Map<String, dynamic>>? initialComponentValues; // <-- Add this

  const SummaryScreen({
    super.key,
    required this.deviceCategory,
    required this.extractedComponents,
    required this.componentImages,
    required this.userImagePaths,
    this.initialComponentValues, // <-- Add this
  });

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  Map<String, Map<String, dynamic>>? _componentValues;
  bool _isLoading = true;
  StreamSubscription<DocumentSnapshot>? _firestoreSubscription;

  static bool _disclaimerDisabled = false;

  bool _disclaimerShown = false; // Track if disclaimer dialog has been shown

  @override
  void initState() {
    super.initState();
    if (widget.initialComponentValues != null) {
      _componentValues = Map<String, Map<String, dynamic>>.from(widget.initialComponentValues!);
      _isLoading = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showParameterDialogs();
      });
    } else {
      _showDisclaimerIfNeeded();
      // Do not call _checkConnectivity() here, wait for disclaimer
    }
  }

  void _showDisclaimerIfNeeded() {
    if (!_disclaimerDisabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showDisclaimerDialog();
      });
    } else {
      // Enable Firestore offline persistence if not already enabled
    _enableOfflinePersistence();
    _loadComponentValues();
    }
  }

  void _showDisclaimerDialog() {
    bool doNotShowAgain = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              height: 380, // Adjust as needed for your UI
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.info_outline, color: Color(0xFF34A853), size: 24),
                        const SizedBox(width: 12),
                        Text(
                          'Valuation Disclaimer',
                          style: GoogleFonts.montserrat(
                            fontSize: 17,
                            fontWeight: FontWeight.bold, // Make bold
                            color: Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    RichText(
                      text: TextSpan(
                        style: GoogleFonts.montserrat(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                        children: [
                          TextSpan(
                            text: '1. Component pricing used in this application is primarily sourced from publicly available platforms, including Shopee, Lazada, and Facebook Marketplace.\n\n',
                          ),
                          TextSpan(
                            text: '2. Our pricing estimates are based on available market data but may vary due to platform availability, resale channels, regulatory changes, and other market conditions.\n\n',
                          ),
                          TextSpan(
                            text: '3. Pricing at e-waste facilities ultimately depends on their specific policy regulations and operational practices.',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    StatefulBuilder(
                      builder: (context, setState) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            unselectedWidgetColor: const Color(0xFF34A853),
                            checkboxTheme: CheckboxThemeData(
                              fillColor: MaterialStateProperty.resolveWith<Color>(
                                (states) {
                                  if (states.contains(MaterialState.selected)) {
                                    return const Color(0xFF34A853);
                                  }
                                  return Colors.white;
                                },
                              ),
                              checkColor: MaterialStateProperty.all<Color>(Colors.white),
                            ),
                          ),
                          child: CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              'Don\'t show again this session',
                              style: GoogleFonts.montserrat(fontSize: 14),
                            ),
                            value: doNotShowAgain,
                            onChanged: (val) {
                              setState(() {
                                doNotShowAgain = val ?? false;
                              });
                            },
                            controlAffinity: ListTileControlAffinity.leading,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          if (doNotShowAgain) {
                            _disclaimerDisabled = true;
                          }
                          Navigator.of(context).pop();
                          // Only proceed to load after disclaimer is closed
                          if (!_disclaimerShown) {
                            _disclaimerShown = true;
                            _enableOfflinePersistence();
                            _loadComponentValues();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
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
                            'I understand',
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
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Setup offline persistence
  Future<void> _enableOfflinePersistence() async {
    try {
      // This only needs to be set once in the app, typically in main.dart
      // but we add it here for completeness since we're focusing on summary.dart
      FirebaseFirestore.instance.settings = Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
      print('✅ Firestore offline persistence enabled');
    } catch (e) {
      print('⚠️ Firestore settings may have already been set: $e');
      // This is fine, as settings can only be set once
    }
  }

  Future<void> _loadComponentValues() async {
    final normalizedCategory = widget.deviceCategory.toLowerCase().replaceAll(' ', '_');
    
    try {
      // Try to get data from Firestore (works offline if cached)
      final docRef = FirebaseFirestore.instance
          .collection('pricing')
          .doc(normalizedCategory);
          
      final docSnapshot = await docRef.get();
      
      if (docSnapshot.exists) {
        // If document exists in Firestore (or offline cache), use it
        final firestoreData = docSnapshot.data();
        
        if (firestoreData != null && firestoreData['component_values'] != null) {
          setState(() {
            _componentValues = Map<String, Map<String, dynamic>>.from(
              firestoreData['component_values'] as Map<String, dynamic>
            );
            _isLoading = false;
          });
          
          print('🔥 Loaded component values from Firestore: ${_componentValues?.length} components');
        } else {
          _fallbackToLocalJson();
        }
      } else {
        // If document doesn't exist in Firestore, fallback to local JSON
        _fallbackToLocalJson();
      }
      
      // Set up real-time listener for updates
      _firestoreSubscription = docRef.snapshots().listen((doc) {
        if (doc.exists) {
          final firestoreData = doc.data();
          if (firestoreData != null && firestoreData['component_values'] != null) {
            setState(() {
              _componentValues = Map<String, Map<String, dynamic>>.from(
                firestoreData['component_values'] as Map<String, dynamic>
              );
            });
            print('🔄 Updated component values from Firestore');
          }
        }
      }, onError: (e) {
        print('❌ Error listening to Firestore updates: $e');
        // No need to fallback here as we already have data
      });
      
      // Once data is loaded, show parameter dialogs
      _showParameterDialogs();
      
    } catch (e) {
      print('❌ Error loading from Firestore: $e');
      _fallbackToLocalJson();
    }
  }
  
  // Fallback to load data from local JSON
  Future<void> _fallbackToLocalJson() async {
    try {
      print('📄 Falling back to local JSON');
      final normalizedCategory = widget.deviceCategory.toLowerCase().replaceAll(' ', '_');
      final jsonPath = 'assets/${normalizedCategory}_instructions.json';
      
      final String jsonString = await rootBundle.loadString(jsonPath);
      final Map<String, dynamic> jsonData = json.decode(jsonString);
      
      setState(() {
        _componentValues = Map<String, Map<String, dynamic>>.from(
          jsonData['component_values'] as Map<String, dynamic>
        );
        _isLoading = false;
      });
      
      print('📝 Loaded component values from local JSON');
      
      // Also store this data to Firestore for future offline access
      _saveToFirestore(normalizedCategory, jsonData['component_values']);
      
      // Show parameter dialogs
      _showParameterDialogs();
      
    } catch (e) {
      print('❌ Error loading local JSON: $e');
      setState(() {
        _isLoading = false;
        _componentValues = {};
      });
    }
  }
  
  // Save JSON data to Firestore for future offline access
  Future<void> _saveToFirestore(String category, Map<String, dynamic> data) async {
    try {
      await FirebaseFirestore.instance
          .collection('pricing')
          .doc(category)
          .set({
            'component_values': data,
            'last_updated': FieldValue.serverTimestamp(),
          });
      print('💾 Saved local data to Firestore for future offline access');
    } catch (e) {
      print('❌ Error saving to Firestore: $e');
      // This is fine, we already have the data locally
    }
  }

  @override
  void dispose() {
    _firestoreSubscription?.cancel();
    super.dispose();
  }

  // Opens a ParameterDialog for each component with configurable parameters
  void _showParameterDialogs() async {
    if (_componentValues == null || _isLoading) {
      print('⏳ Waiting for component values to load before showing dialogs');
      return;
    }
    
    for (String component in _getUniqueComponents()) {
      final componentKey = component.toLowerCase();
      final componentData = _componentValues?[componentKey];
      if (componentData != null && componentData['parameters'] != null) {
        // ignore: use_build_context_synchronously
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => ParameterDialog(
            componentName: _formatComponentName(component),
            componentData: componentData,
            parameters: componentData['parameters'],
            onValueCalculated: (newValue, selectedParams) {
              setState(() {
                if (_componentValues != null) {
                  // Make a copy to trigger Flutter's state update
                  _componentValues = Map<String, Map<String, dynamic>>.from(_componentValues!);
                  var componentMap = _componentValues![component.toLowerCase()];
                  if (componentMap != null) {
                    componentMap['price'] = newValue;
                    componentMap['selected_parameters'] = selectedParams;
                  }
                }
              });
            },
          ),
        );
      }
    }
  }

  // Get images for a specific component
  List<String> _getComponentImages(String component) {
    List<String> images = [];
    for (var entry in widget.componentImages.entries) {
      for (var componentEntry in entry.value.entries) {
        if (componentEntry.key.toLowerCase().startsWith(component.toLowerCase())) {
          images.add(componentEntry.value);
        }
      }
    }
    return images;
  }

  void _showImageOverlay(BuildContext context, String imagePath) {
    // Image overlay implementation remains unchanged
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
                        child: Image.file(File(imagePath), fit: BoxFit.contain),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 30,
                    ),
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

  // Counts how many times a component appears
  Map<String, int> _getComponentCounts() {
    Map<String, int> counts = {};
    for (String component in widget.extractedComponents) {
      String baseComponent = component.split('_')[0].toLowerCase();
      counts[baseComponent] = (counts[baseComponent] ?? 0) + 1;
    }
    return counts;
  }

  // Get unique component types
  List<String> _getUniqueComponents() {
    return widget.extractedComponents
        .map((c) => c.split('_')[0].toLowerCase())
        .toSet()
        .toList();
  }

  Widget _buildEWasteDisposalSection() {
    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xFF34A853),
          child: Icon(Icons.map, color: Colors.white),
        ),
        title: Text(
          'E-Waste Disposal Locations',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          'Find certified e-waste recycling centers near you for safe disposal.',
          style: GoogleFonts.montserrat(color: Colors.grey[600]),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          try {
            // Fetch data from Firestore
            final querySnapshot = await FirebaseFirestore.instance
                .collection('ewaste_locations')
                .get();

            // Convert Firestore documents to a list of maps
            final locations = querySnapshot.docs.map((doc) {
              final data = doc.data();
              final latLong = data['lat_long'] as GeoPoint; // Treat as GeoPoint

              return {
                'id': doc.id,
                'name': data['name'],
                'address': data['address'],
                'latitude': latLong.latitude, // Extract latitude
                'longitude': latLong.longitude, // Extract longitude
                'phone': data['phone'],
                'hours': data['hours'],
                'website': data['website'],
                'notes': data['notes'],
              };
            }).toList();

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => EWasteMapScreen(locations: locations),
              ),
            );
          } catch (e) {
            print('Error fetching e-waste locations: $e');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to load e-waste locations'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildFeedbackButton() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF34A853),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: _showFeedbackDialog,
        icon: const Icon(Icons.upload_rounded, color: Colors.white),
        label: Text(
          'Share Input Image',
          style: GoogleFonts.montserrat(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // User feedback dialog
  void _showFeedbackDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Help Improve Detection',
                  style: GoogleFonts.montserrat(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Share your device images to help improve our detection model:',
                  style: GoogleFonts.montserrat(),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
              // Preview of original image
              Container(
                height: 150,
                width: 150,
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(widget.userImagePaths.first),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ButtonBar(
                alignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.montserrat(color: Colors.grey),
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF34A853),
                    ),
                    onPressed: () async {
                      await ensureSignedIn();
                      await _uploadDetectionFeedback();
                      Navigator.pop(context);
                    },
                    child: Text(
                      'Share Images',
                      style: GoogleFonts.montserrat(color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _uploadDetectionFeedback() async {
    int total = widget.userImagePaths.length;
    int uploaded = 0;

    // Controller for updating the overlay
    late void Function(int) updateProgress;
    late void Function() closeOverlay;

    // Show custom overlay
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            updateProgress = (int newUploaded) {
              setState(() {
                uploaded = newUploaded;
              });
            };
            closeOverlay = () {
              if (Navigator.of(context).canPop()) Navigator.of(context).pop();
            };
            return AnimatedOpacity(
              opacity: 1.0,
              duration: const Duration(milliseconds: 300),
              child: Container(
                color: Colors.black.withOpacity(0.7),
                child: Center(
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.8,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2A2A),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Uploading image ${uploaded + 1} of $total',
                          style: GoogleFonts.montserrat(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        const SizedBox(height: 20),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: total > 0 ? uploaded / total : 0,
                            backgroundColor: Colors.grey.shade800,
                            color: Colors.greenAccent,
                            minHeight: 10,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Please wait while your images are being uploaded.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.robotoCondensed(
                            fontSize: 18,
                            color: Colors.white,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Completed: $uploaded of $total',
                          style: GoogleFonts.robotoCondensed(
                            fontSize: 18,
                            color: Colors.white,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ); // <-- Close AnimatedOpacity
          },
        ); // <-- Close StatefulBuilder
      },
    ); // <-- Close showDialog

    try {
      final feedbackService = FeedbackService();
      await ensureSignedIn();

      for (final imagePath in widget.userImagePaths) {
        await feedbackService.uploadDetectionImage(
          imagePath: imagePath,
          detectionData: {
            'deviceCategory': widget.deviceCategory,
            'detectedComponents': widget.extractedComponents,
            'componentImages': widget.componentImages,
          },
          deviceCategory: widget.deviceCategory,
        );
        uploaded++;
        updateProgress(uploaded);
      }

      closeOverlay();

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Thank you for helping improve our detection models!',
              style: GoogleFonts.montserrat(),
            ),
            backgroundColor: const Color(0xFF34A853),
          ),
        );
      }
    } catch (e) {
      closeOverlay();
      print('❌ Error uploading feedback: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to upload images. Please try again.',
              style: GoogleFonts.montserrat(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // UI for loading state
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF34A853)),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading component data...',
            style: GoogleFonts.montserrat(
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  // UI stuff
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Base(
        title: 'Extraction Summary',
        child: _buildLoadingState(),
      );
    }

    final componentCounts = _getComponentCounts();
    final uniqueComponents = _getUniqueComponents();

    // Calculate total estimated value before building UI
    double totalValue = 0;
    for (String component in uniqueComponents) {
      final values = _componentValues?[component.toLowerCase()];
      if (values != null) {
        final price = values['price'];
        double safePrice = 0.0;
        if (price != null) {
          if (price is int) {
            safePrice = price.toDouble();
          } else if (price is double) {
            safePrice = price;
          }
        }
        totalValue += safePrice * (componentCounts[component] ?? 1);
      }
    }

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _componentValues != null
          ? jsonDecode(jsonEncode(_componentValues))
          : null);
        return false;
      },
      child: Base(
        title: 'Extraction Summary',
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Existing UI components...
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF34A853), Color(0xFF0F9D58)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.deviceCategory,
                      style: GoogleFonts.montserrat(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${widget.extractedComponents.length} valuable components in your device',
                      style: GoogleFonts.montserrat(
                        fontSize: 16,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Divider(color: Colors.white24),
                    const SizedBox(height: 16),
                    if (widget.deviceCategory.trim().toLowerCase() == 'router')
                      Text(
                        'Facility-dependent pricing',
                        style: GoogleFonts.montserrat(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      )
                    else
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Total Estimated Value: ',
                              style: GoogleFonts.montserrat(
                                fontSize: 16,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                          Flexible(
                            child: Text(
                              '\₱${totalValue.toStringAsFixed(2)}',
                              style: GoogleFonts.montserrat(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Add the e-waste disposal section here
              _buildEWasteDisposalSection(),

              // Add the feedback button here
              _buildFeedbackButton(),

              // Components List
              ...uniqueComponents.map((component) {
                final values =
                    _componentValues?[component.toLowerCase()] ??
                    {'price': 0.0, 'notes': 'No data available'};
                final count = componentCounts[component] ?? 1;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ExpansionTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF34A853),
                      child: Icon(
                        _getIconForComponent(component),
                        color: Colors.white,
                      ),
                    ),
                    title: Text(
                      _formatComponentName(component),
                      style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          values['selected_parameters'] != null
                              ? '\₱${(values['price'] ?? 0.0).toStringAsFixed(2)}' // Show price if configured
                              : '⋯', // Show ellipsis if not configured
                          style: GoogleFonts.montserrat(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF34A853),
                          ),
                        ),
                        Text(
                          values['selected_parameters'] != null
                              ? 'per piece (×$count)'
                              : widget.deviceCategory.trim().toLowerCase() == 'router'
                                  ? ''
                                  : 'Not configured',
                          style: GoogleFonts.montserrat(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    children: [
                      // Component details remain unchanged
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Component Images
                            if (_getComponentImages(component).isNotEmpty) ...[
                              SizedBox(
                                height: 120,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount:
                                      _getComponentImages(component).length,
                                  itemBuilder: (context, index) {
                                    String imagePath =
                                        _getComponentImages(component)[index];
                                    return Padding(
                                      padding: EdgeInsets.only(right: 8),
                                      child: GestureDetector(
                                        onTap:
                                            () => _showImageOverlay(
                                              context,
                                              imagePath,
                                            ),
                                        child: Container(
                                          width: 120,
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: Colors.grey.shade300,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            child: Image.file(
                                              File(imagePath),
                                              fit: BoxFit.cover,
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
                            // Notes section
                            Text(
                              values['notes'],
                              style: GoogleFonts.montserrat(
                                color: Colors.grey[600],
                              ),
                            ),
                            // Component Parameters
                            if (values['parameters'] != null) ...[
                              const SizedBox(height: 16),
                              const Divider(),
                              const SizedBox(height: 16),
                              Text(
                                'Configuration',
                                style: GoogleFonts.montserrat(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              // Show parameters if they exist and have been configured
                              if (values['selected_parameters'] != null) ...[
                                ...values['parameters'].entries.map((entry) {
                                  final paramName = entry.key;
                                  final selectedValue =
                                      (values['selected_parameters']
                                          as Map<String, String>)[paramName] ??
                                      'Not configured';

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          _formatParameterName(paramName),
                                          style: GoogleFonts.montserrat(
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        Text(
                                          selectedValue,
                                          style: GoogleFonts.montserrat(
                                            color: const Color(0xFF34A853),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                const SizedBox(height: 16),
                              ] else ...[
                                if (widget.deviceCategory.trim().toLowerCase() != 'router') ...[
                                  Text(
                                    'No parameters configured',
                                    style: GoogleFonts.montserrat(
                                      color: Colors.grey[600],
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ]
                              ],
                              // Edit Parameters button
                              Center(
                                child: TextButton.icon(
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      barrierDismissible: false,
                                      builder:
                                          (context) => ParameterDialog(
                                            componentName: _formatComponentName(
                                              component,
                                            ),
                                            componentData: values,
                                            parameters: values['parameters'],
                                            onValueCalculated: (
                                              newValue,
                                              selectedParams,
                                            ) {
                                              setState(() {
                                                if (_componentValues != null) {
                                                  // Make a copy to trigger Flutter's state update
                                                  _componentValues = Map<String, Map<String, dynamic>>.from(_componentValues!);
                                                  var componentMap =
                                                      _componentValues![component
                                                          .toLowerCase()];
                                                  if (componentMap != null) {
                                                    componentMap['price'] =
                                                        newValue;
                                                    componentMap['selected_parameters'] =
                                                        selectedParams;
                                                  }
                                                }
                                              });
                                            },
                                          ),
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.edit,
                                    color: Color(0xFF34A853),
                                    size: 20,
                                  ),
                                  label: Text(
                                    values['selected_parameters'] != null
                                        ? 'Edit Parameters'
                                        : 'Configure Parameters',
                                    style: GoogleFonts.montserrat(
                                      color: const Color(0xFF34A853),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // Helper method to get icons
  IconData _getIconForComponent(String component) {
    switch (component.toLowerCase()) {
      case 'ram':
        return Icons.memory;
      case 'battery':
      case 'cmos':
        return Icons.battery_full;
      case 'fan':
      case 'cooler':
        return Icons.air;
      case 'wifi':
      case 'card':
        return Icons.wifi;
      case 'drive':
      case 'hdd':
      case 'ssd':
      case 'disk':
        return Icons.storage;
      case 'cpu':
        return Icons.developer_board;
      case 'gpu':
        return Icons.videogame_asset;
      case 'psu':
        return Icons.power;
      case 'mboard':
        return Icons.dashboard;
      case 'case':
        return Icons.computer;
      default:
        return Icons.memory;
    }
  }

  // Helper method to format component names
  String _formatComponentName(String name) {
    String firstPart = name.split('_')[0];
    return firstPart[0].toUpperCase() + firstPart.substring(1);
  }

  // Helper method to format parameter names
  String _formatParameterName(String name) {
    return name[0].toUpperCase() + name.substring(1).replaceAll('_', ' ');
  }
}
