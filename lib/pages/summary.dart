import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '/pages/base.dart';
import '/pages/ewaste_map_screen.dart';

class ParameterDialog extends StatefulWidget {
  final String componentName;
  final Map<String, dynamic> componentData; // Component data containing base price and parameters
  final Map<String, dynamic> parameters; // Parameters for the component, used for dropdown options and value multipliers
  final Function(double, Map<String, String>) onValueCalculated; // Callback function that returns the calculated value and selected parameters

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
  final Map<String, String> _selectedValues = {}; // Store selected values for each parameter
  double _currentValue = 0.0; // Stores latest calculated value based on parameters

  void _calculateValue() {
    double basePrice = 0.0;
    
    // For components with capacity parameter
    if (widget.parameters.containsKey('capacity')) {
      if (_selectedValues['capacity'] != null) {
        // Convert the capacity price to double, regardless of whether it's int or double
        final capacityPriceRaw = widget.parameters['capacity']['base_prices']?[_selectedValues['capacity']] ?? 0.0;
        final capacityPrice = capacityPriceRaw is int ? capacityPriceRaw.toDouble() : (capacityPriceRaw as double);
        print('💰 Capacity base price: $capacityPrice');
        basePrice = capacityPrice;
      }
    } else {
      // For components without capacity, use default_base_price
      final defaultPriceRaw = widget.componentData['default_base_price'] ?? 0.0;
      basePrice = defaultPriceRaw is int ? defaultPriceRaw.toDouble() : (defaultPriceRaw as double);
      print('💰 Default base price: $basePrice');
    }

    // Apply all parameter multipliers
    widget.parameters.forEach((paramName, paramData) {
      if (paramData['multipliers'] != null && _selectedValues[paramName] != null) {
        final multiplierRaw = paramData['multipliers'][_selectedValues[paramName]] ?? 1.0;
        final multiplier = multiplierRaw is int ? multiplierRaw.toDouble() : (multiplierRaw as double);
        basePrice *= multiplier;
        print('🔢 Applied $paramName multiplier: $multiplier');
      }
    });

    print('💵 Final calculated value: $basePrice');

    setState(() {
      _currentValue = basePrice;
    });
    widget.onValueCalculated(_currentValue, Map<String, String>.from(_selectedValues));
  }

  // UI elements for popup dialog
  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
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
                  decoration: InputDecoration(
                    labelText: paramName[0].toUpperCase() + paramName.substring(1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF34A853)),
                    ),
                    labelStyle: GoogleFonts.montserrat(
                      color: Colors.grey[600],
                    ),
                  ),
                  value: _selectedValues[paramName],
                  style: GoogleFonts.montserrat(
                    color: Colors.black87, // Add text color for selected value
                  ),
                  dropdownColor: Colors.white,
                  icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF34A853)),
                  items: options.map((option) {
                    return DropdownMenuItem(
                      value: option.toString(),
                      child: Text(
                        option.toString(),
                        style: GoogleFonts.montserrat(
                          color: Colors.black87, // Add text color for dropdown items
                        ),
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

  const SummaryScreen({
    super.key,
    required this.deviceCategory,
    required this.extractedComponents,
    required this.componentImages,
  });

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  Map<String, Map<String, dynamic>>? _componentValues;
  bool _hasInternet = false;
  StreamSubscription<DocumentSnapshot>? _firestoreSubscription;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
  }

  // Check internet connectivity
  Future<void> _checkConnectivity() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      setState(() {
        _hasInternet = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      });
    } on SocketException catch (_) {
      setState(() {
        _hasInternet = false;
      });
    }
    _loadComponentValues();
  }

  // Modified _loadComponentValues to handle both online and offline data
  Future<void> _loadComponentValues() async {
    try {
      final normalizedCategory = widget.deviceCategory.toLowerCase().replaceAll(' ', '_');

      // Try Firestore first if internet is available
      if (_hasInternet) {
        try {
          print('📡 Attempting to load from Firestore first...');
          final doc = await FirebaseFirestore.instance
              .collection('pricing')
              .doc(normalizedCategory)
              .get();

          if (doc.exists) {
            final firestoreData = doc.data()?['component_values'] as Map<String, dynamic>?;
            if (firestoreData != null) {
              print('🔥 Firestore data loaded successfully');
              setState(() {
                _componentValues = Map<String, Map<String, dynamic>>.from(firestoreData);
              });

              // Set up real-time listener for future updates
              _firestoreSubscription = FirebaseFirestore.instance
                  .collection('pricing')
                  .doc(normalizedCategory)
                  .snapshots()
                  .listen((snapshot) {
                    if (snapshot.exists) {
                      final updatedData = snapshot.data()?['component_values'] as Map<String, dynamic>?;
                      if (updatedData != null) {
                        setState(() {
                          _componentValues = Map<String, Map<String, dynamic>>.from(updatedData);
                        });
                      }
                    }
                  });

              // Show parameter dialogs with Firestore data
              _showParameterDialogs();
              return; // Exit if Firestore load was successful
            }
          }
        } catch (e) {
          print('❌ Firestore load failed: $e');
        }
      }

      // Fallback to local JSON if Firestore failed or no internet
      print('📱 Falling back to local JSON...');
      final jsonPath = 'assets/${normalizedCategory}_instructions.json';
      final String jsonString = await rootBundle.loadString(jsonPath);
      final Map<String, dynamic> jsonData = json.decode(jsonString);

      setState(() {
        _componentValues = Map<String, Map<String, dynamic>>.from(
          jsonData['component_values'] as Map<String, dynamic>
        );
      });

      print('📄 Local JSON loaded successfully');
      // Show parameter dialogs with JSON data
      _showParameterDialogs();

    } catch (e) {
      print('❌ Error loading component values: $e');
    }
  }

  @override
  void dispose() {
    _firestoreSubscription?.cancel();
    super.dispose();
  }

  // Opens a ParameterDialog for each component with configurable parameters
  void _showParameterDialogs() async {
    for (String component in _getUniqueComponents()) { // Loops through each unique component
      final componentKey = component.toLowerCase();
      final componentData = _componentValues?[componentKey]; // Retrieves the component data from the loaded JSON
      if (componentData != null && componentData['parameters'] != null) { // Proceed if parameters exist
        // ignore: use_build_context_synchronously
        await showDialog(
          context: context,
          barrierDismissible: false, // Prevents closing the dialog by tapping outside
          builder: (context) => ParameterDialog(
            componentName: _formatComponentName(component),
            componentData: componentData,
            parameters: componentData['parameters'], // Used to build the dropdowns
            onValueCalculated: (newValue, selectedParams) {  // Add selectedParams parameter
              setState(() {
                if (_componentValues != null) {
                  var componentMap = _componentValues![componentKey];
                  if (componentMap != null) {
                    componentMap['price'] = newValue;
                    componentMap['selected_parameters'] = selectedParams;  // Save selected parameters
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
    List<String> images = []; // Create an empty list to store image paths
    for (var entry in widget.componentImages.entries) { // entry.key = source image path, entry.value = map of detected components
      for (var componentEntry in entry.value.entries) {
        if (componentEntry.key.toLowerCase().startsWith(component.toLowerCase())) { // Checks if component entry matches target component
          images.add(componentEntry.value);
        }
      }
    }
    return images;
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

  // Counts how many times a component appears
  Map<String, int> _getComponentCounts() {
    Map<String, int> counts = {}; // Creates a list that stores the number of times a component appears
    for (String component in widget.extractedComponents) { // Loops through each component in the list
      // Get base component name by:
      // 1. Splitting on underscore (e.g., "ram_1" becomes ["ram", "1"])
      // 2. Taking first part [0]
      // 3. Converting to lowercase for consistent comparison
      String baseComponent = component.split('_')[0].toLowerCase();
      // Increment count for this component
      // ?? 0 provides default value of 0 if component doesn't exist in map yet
      // Then add 1 to current/default count
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
      margin: const EdgeInsets.only(bottom: 24),
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
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          'Not looking to sell? Find certified e-waste recycling centers near you for safe disposal.',
          style: GoogleFonts.montserrat(
            color: Colors.grey[600],
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          try {
            final jsonString = await rootBundle.loadString('assets/e_waste_locations.json');
            final jsonData = json.decode(jsonString);
            final locations = jsonData['e_waste_locations'] as List<dynamic>;

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => EWasteMapScreen(locations: locations),
              ),
            );
          } catch (e) {
            print('Error loading e-waste locations: $e');
          }
        },
      ),
    );
  }

  // UI stuff
  @override
  Widget build(BuildContext context) {
    final componentCounts = _getComponentCounts();
    final uniqueComponents = _getUniqueComponents();

    // Calculate total estimated value before building UI
    double totalValue = 0;
    for (String component in uniqueComponents) {
      final values = _componentValues?[component.toLowerCase()];
      if (values != null) {
        totalValue += ((values['price'] ?? 0.0) as double) * 
                     (componentCounts[component] ?? 1);
      }
    }

    return Base(
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Estimated Value',
                        style: GoogleFonts.montserrat(
                          fontSize: 16,
                          color: Colors.white70,
                        ),
                      ),
                      Text(
                        '\₱${totalValue.toStringAsFixed(2)}',
                        style: GoogleFonts.montserrat(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
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

            // Components List
            ...uniqueComponents.map((component) {
              final values = _componentValues?[component.toLowerCase()] ?? 
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
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        values['selected_parameters'] != null 
                            ? '\₱${(values['price'] ?? 0.0).toStringAsFixed(2)}'  // Show price if configured
                            : '⋯',  // Show ellipsis if not configured
                        style: GoogleFonts.montserrat(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF34A853),
                        ),
                      ),
                      Text(
                        values['selected_parameters'] != null 
                            ? 'per piece (×$count)'
                            : 'Not configured',
                        style: GoogleFonts.montserrat(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  children: [
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
                                itemCount: _getComponentImages(component).length,
                                itemBuilder: (context, index) {
                                  String imagePath = _getComponentImages(component)[index];
                                  return Padding(
                                    padding: EdgeInsets.only(right: 8),
                                    child: GestureDetector(
                                      onTap: () => _showImageOverlay(context, imagePath),
                                      child: Container(
                                        width: 120,
                                        decoration: BoxDecoration(
                                          border: Border.all(color: Colors.grey.shade300),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
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
                                final selectedValue = (values['selected_parameters'] as Map<String, String>)[paramName] ?? 'Not configured';
                                
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                              Text(
                                'No parameters configured',
                                style: GoogleFonts.montserrat(
                                  color: Colors.grey[600],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                            // Edit Parameters button will always show if parameters exist
                            Center(
                              child: TextButton.icon(
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    barrierDismissible: false,
                                    builder: (context) => ParameterDialog(
                                      componentName: _formatComponentName(component),
                                      componentData: values,
                                      parameters: values['parameters'],
                                      onValueCalculated: (newValue, selectedParams) {
                                        setState(() {
                                          if (_componentValues != null) {
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
                                },
                                icon: const Icon(
                                  Icons.edit,
                                  color: Color(0xFF34A853),
                                  size: 20,
                                ),
                                label: Text(
                                  values['selected_parameters'] != null ? 'Edit Parameters' : 'Configure Parameters',
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
    );
  }

  // Helper method to get icons (copy from assistant.dart)
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

  // Helper method to format component names (copy from assistant.dart)
  String _formatComponentName(String name) {
    String firstPart = name.split('_')[0];
    return firstPart[0].toUpperCase() + firstPart.substring(1);
  }

  // Helper method to format parameter names
  String _formatParameterName(String name) {
    return name[0].toUpperCase() + name.substring(1).replaceAll('_', ' ');
  }
}