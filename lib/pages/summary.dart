import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

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

class SummaryScreen extends StatefulWidget {
  final String deviceCategory;
  final List<String> extractedComponents;
  final Map<String, Map<String, String>> componentImages;
  final List<String> userImagePaths;
  final Map<String, Map<String, dynamic>>?
  initialComponentValues; // <-- Add this

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

class _ParameterDialogState extends State<ParameterDialog> {
  final Map<String, String> _selectedValues = {};
  double _currentValue = 0.0;

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
                  isExpanded:
                      true, // Add this line to make dropdown expand to full width
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
                  style: GoogleFonts.montserrat(color: Colors.black87),
                  dropdownColor: Colors.white,
                  icon: const Icon(
                    Icons.arrow_drop_down,
                    color: Color(0xFF34A853),
                  ),
                  items:
                      options.map((option) {
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
            }),
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

  void _calculateValue() {
    double basePrice = 0.0;

    if (widget.parameters.containsKey('capacity')) {
      if (_selectedValues['capacity'] != null) {
        final capacityPriceRaw =
            widget
                .parameters['capacity']['base_prices']?[_selectedValues['capacity']] ??
            0.0;
        final capacityPrice =
            capacityPriceRaw is int
                ? capacityPriceRaw.toDouble()
                : (capacityPriceRaw as double);
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
}

class _SummaryScreenState extends State<SummaryScreen> {
  static bool _disclaimerDisabled = false;
  // Sellability score configuration
  static const double _baseSellabilityScore = 100.0;

  // can be modified to adjust the weight of each factor
  static const Map<String, double> _sellabilityModifiers = {
    'age': 0.3, // 30% weight for age
    'condition': 0.5, // 50% weight for condition
    'functionality': 0.2, // 20% weight for functionality
  };
  static const Map<String, Map<String, double>> _sellabilityMultiplier = {
    'age': {
      'Less than 1 year': 1.0,
      '1-2 years': 0.8,
      '2-3 years': 0.6,
      '3-5 years': 0.4,
      'Over 5 years': 0.3,
      'Other/Unsure':
          1.0, // will not affect sellability score pero didisplay warning icon
    },
    'condition': {
      'Like New': 1.0,
      'Good': 0.8,
      'Fair': 0.6,
      'Poor': 0.2,
      'Other/Unsure':
          1.0, // will not affect sellability score pero didisplay warning icon
    },
    'functionality': {
      'Working': 1.0,
      'Not Working': 0.25,
      'Unsure':
          1.0, // will not affect sellability score pero didisplay warning icon
    },
  };

  Map<String, Map<String, dynamic>>? _componentValues;

  bool _isLoading = true;

  StreamSubscription<DocumentSnapshot>? _firestoreSubscription;
  bool _disclaimerShown = false; // Track if disclaimer dialog has been shown

  // UI stuff
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Base(title: 'Extraction Summary', child: _buildLoadingState());
    }
    final componentCounts = _getComponentCounts();
    final uniqueComponents =
        _getUniqueComponents(); // Calculate total estimated value before building UI
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
        Navigator.pop(
          context,
          _componentValues != null
              ? jsonDecode(jsonEncode(_componentValues))
              : null,
        );
        return false;
      },
      child: Base(
        title: 'Extraction Summary',
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            MediaQuery.of(context).size.width * 0.035, // left
            MediaQuery.of(context).size.width * 0.035, // top
            MediaQuery.of(context).size.width * 0.035, // right
            MediaQuery.of(context).size.height * 0.02, // bottom - extra space
          ),
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
                  borderRadius: BorderRadius.circular(
                    MediaQuery.of(context).size.width *
                        0.05, // Responsive border radius
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: EdgeInsets.all(
                  MediaQuery.of(context).size.width * 0.05,
                ), // Responsive padding
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.deviceCategory,
                      style: GoogleFonts.montserrat(
                        fontSize:
                            MediaQuery.of(context).size.width *
                            0.06, // Responsive font size
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: MediaQuery.of(context).size.height * 0.01),
                    Text(
                      '${widget.extractedComponents.length} valuable components in your device',
                      style: GoogleFonts.montserrat(
                        fontSize: MediaQuery.of(context).size.width * 0.04,
                        color: Colors.white70,
                      ),
                    ),
                    SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                    const Divider(color: Colors.white24),
                    SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                    if (widget.deviceCategory.trim().toLowerCase() == 'router')
                      Text(
                        'Facility-dependent pricing',
                        style: GoogleFonts.montserrat(
                          fontSize: MediaQuery.of(context).size.width * 0.045,
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
                                fontSize:
                                    MediaQuery.of(context).size.width * 0.04,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                          Flexible(
                            child: Text(
                              '₱${totalValue.toStringAsFixed(2)}',
                              style: GoogleFonts.montserrat(
                                fontSize:
                                    MediaQuery.of(context).size.width * 0.06,
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
              SizedBox(height: MediaQuery.of(context).size.height * 0.03),

              // Add the e-waste disposal section here
              _buildEWasteDisposalSection(),

              // Add the buyer contacts section here
              _buildBuyerContactsSection(),

              // Components Found heading
              Padding(
                padding: EdgeInsets.symmetric(
                  vertical: MediaQuery.of(context).size.height * 0.02,
                  horizontal: MediaQuery.of(context).size.width * 0.02,
                ),
                child: Text(
                  'Components Found',
                  style: GoogleFonts.montserrat(
                    fontSize: MediaQuery.of(context).size.width * 0.055,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),

              // Components List
              ...uniqueComponents.map((component) {
                final values =
                    _componentValues?[component.toLowerCase()] ??
                    {'price': 0.0, 'notes': 'No data available'};
                final count = componentCounts[component] ?? 1;
                return Container(
                  margin: EdgeInsets.only(
                    bottom: MediaQuery.of(context).size.height * 0.01,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(
                      MediaQuery.of(context).size.width * 0.03,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.symmetric(
                      horizontal: MediaQuery.of(context).size.width * 0.03,
                      vertical: MediaQuery.of(context).size.height * 0.005,
                    ),
                    childrenPadding: EdgeInsets.zero,
                    dense: true,
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF34A853),
                      radius:
                          MediaQuery.of(context).size.width *
                          0.06, // Responsive radius
                      child: Icon(
                        _getIconForComponent(component),
                        color: Colors.white,
                      ),
                    ),
                    title: Text(
                      _formatComponentName(component),
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w600,
                        fontSize: MediaQuery.of(context).size.width * 0.04,
                      ),
                    ),
                    subtitle:
                        values['selected_parameters'] != null
                            ? Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal:
                                        MediaQuery.of(context).size.width *
                                        0.015,
                                    vertical:
                                        MediaQuery.of(context).size.height *
                                        0.003,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getSellabilityColor(
                                      _calculateSellabilityScore(values),
                                    ).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(
                                      MediaQuery.of(context).size.width * 0.02,
                                    ),
                                    border: Border.all(
                                      color: _getSellabilityColor(
                                        _calculateSellabilityScore(values),
                                      ),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Sellability: ${_calculateSellabilityScore(values).toStringAsFixed(0)}%',
                                        style: GoogleFonts.montserrat(
                                          fontSize:
                                              MediaQuery.of(
                                                context,
                                              ).size.width *
                                              0.03,
                                          fontWeight: FontWeight.w600,
                                          color: _getSellabilityColor(
                                            _calculateSellabilityScore(values),
                                          ),
                                        ),
                                      ),
                                      if (_hasUncertainParameters(values)) ...[
                                        SizedBox(
                                          width:
                                              MediaQuery.of(
                                                context,
                                              ).size.width *
                                              0.01,
                                        ),
                                        Icon(
                                          Icons.warning_amber_rounded,
                                          color: Colors.orange,
                                          size:
                                              MediaQuery.of(
                                                context,
                                              ).size.width *
                                              0.035,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            )
                            : null,
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          values['selected_parameters'] != null
                              ? '₱${(values['price'] ?? 0.0).toStringAsFixed(2)}' // Show price if configured
                              : '⋯', // Show ellipsis if not configured
                          style: GoogleFonts.montserrat(
                            fontSize: MediaQuery.of(context).size.width * 0.04,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF34A853),
                          ),
                        ),
                        Text(
                          values['selected_parameters'] != null
                              ? 'per piece (×$count)'
                              : widget.deviceCategory.trim().toLowerCase() ==
                                  'router'
                              ? ''
                              : 'Not configured',
                          style: GoogleFonts.montserrat(
                            fontSize: MediaQuery.of(context).size.width * 0.03,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    children: [
                      // Component details remain unchanged
                      Padding(
                        padding: EdgeInsets.all(
                          MediaQuery.of(context).size.width * 0.035,
                        ),
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
                              const SizedBox(
                                height: 8,
                              ), // Show parameters if they exist and have been configured
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
                                const SizedBox(
                                  height: 16,
                                ), // Sellability Score Breakdown
                                Container(
                                  padding: EdgeInsets.all(
                                    MediaQuery.of(context).size.width * 0.03,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[50],
                                    borderRadius: BorderRadius.circular(
                                      MediaQuery.of(context).size.width * 0.02,
                                    ),
                                    border: Border.all(
                                      color: Colors.grey.shade200,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Sellability Score',
                                            style: GoogleFonts.montserrat(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.grey[800],
                                            ),
                                          ),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: _getSellabilityColor(
                                                    _calculateSellabilityScore(
                                                      values,
                                                    ),
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  '${_calculateSellabilityScore(values).toStringAsFixed(1)}/100.0 (${_getSellabilityDescription(_calculateSellabilityScore(values))})',
                                                  style: GoogleFonts.montserrat(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                              if (_hasUncertainParameters(
                                                values,
                                              )) ...[
                                                const SizedBox(width: 6),
                                                Icon(
                                                  Icons.warning_amber_rounded,
                                                  color: Colors.orange,
                                                  size: 16,
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      // Breakdown of sellability factors
                                      ..._sellabilityModifiers.entries.map((
                                        modifier,
                                      ) {
                                        final paramName = modifier.key;
                                        final weight = modifier.value;
                                        if (values['selected_parameters'] !=
                                                null &&
                                            values['selected_parameters'][paramName] !=
                                                null) {
                                          String selectedValue =
                                              values['selected_parameters'][paramName]; // Use hardcoded multipliers instead of Firestore values
                                          double multiplier = 1.0;
                                          if (_sellabilityMultiplier
                                                  .containsKey(paramName) &&
                                              _sellabilityMultiplier[paramName]!
                                                  .containsKey(selectedValue)) {
                                            multiplier =
                                                _sellabilityMultiplier[paramName]![selectedValue]!;
                                          }

                                          double factorScore =
                                              multiplier * 100.0;

                                          return Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 4,
                                            ),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  flex: 2,
                                                  child: Text(
                                                    '${_formatParameterName(paramName)} (${(weight * 100).toInt()}%)',
                                                    style:
                                                        GoogleFonts.montserrat(
                                                          fontSize: 12,
                                                          color:
                                                              Colors.grey[600],
                                                        ),
                                                  ),
                                                ),
                                                Expanded(
                                                  flex: 1,
                                                  child: Text(
                                                    selectedValue,
                                                    style:
                                                        GoogleFonts.montserrat(
                                                          fontSize: 12,
                                                          color:
                                                              Colors.grey[700],
                                                        ),
                                                  ),
                                                ),
                                                SizedBox(
                                                  width: 40,
                                                  child: Text(
                                                    '${factorScore.toStringAsFixed(0)}%',
                                                    style: GoogleFonts.montserrat(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color:
                                                          _getSellabilityColor(
                                                            factorScore,
                                                          ),
                                                    ),
                                                    textAlign: TextAlign.right,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }
                                        return const SizedBox.shrink();
                                      }),
                                    ],
                                  ),
                                ), // Add warning text if there are uncertain parameters
                                if (_hasUncertainParameters(values)) ...[
                                  SizedBox(
                                    height:
                                        MediaQuery.of(context).size.height *
                                        0.01,
                                  ),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal:
                                          MediaQuery.of(context).size.width *
                                          0.02,
                                      vertical:
                                          MediaQuery.of(context).size.height *
                                          0.008,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade50,
                                      borderRadius: BorderRadius.circular(
                                        MediaQuery.of(context).size.width *
                                            0.015,
                                      ),
                                      border: Border.all(
                                        color: Colors.orange.shade200,
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.warning_amber_rounded,
                                          color: Colors.orange,
                                          size:
                                              MediaQuery.of(
                                                context,
                                              ).size.width *
                                              0.04,
                                        ),
                                        SizedBox(
                                          width:
                                              MediaQuery.of(
                                                context,
                                              ).size.width *
                                              0.02,
                                        ),
                                        Expanded(
                                          child: Text(
                                            'Score may be inaccurate due to uncertain parameter values.',
                                            style: GoogleFonts.montserrat(
                                              fontSize:
                                                  MediaQuery.of(
                                                    context,
                                                  ).size.width *
                                                  0.028,
                                              color: Colors.orange.shade700,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 16),
                              ] else ...[
                                if (widget.deviceCategory
                                        .trim()
                                        .toLowerCase() !=
                                    'router') ...[
                                  Text(
                                    'No parameters configured',
                                    style: GoogleFonts.montserrat(
                                      color: Colors.grey[600],
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],
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
                                                  _componentValues = Map<
                                                    String,
                                                    Map<String, dynamic>
                                                  >.from(_componentValues!);
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
              }),
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.04,
              ), // Extra bottom spacing
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _firestoreSubscription?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialComponentValues != null) {
      _componentValues = Map<String, Map<String, dynamic>>.from(
        widget.initialComponentValues!,
      );
      _isLoading = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showParameterDialogs();
      });
    } else {
      _showDisclaimerIfNeeded();
      // Do not call _checkConnectivity() here, wait for disclaimer
    }
  }

  Widget _buildEWasteDisposalSection() {
    return Container(
      margin: EdgeInsets.only(
        bottom: MediaQuery.of(context).size.height * 0.001,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          MediaQuery.of(context).size.width * 0.03,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue, // Changed background to blue
          radius: MediaQuery.of(context).size.width * 0.06,
          child: Icon(
            Icons.map,
            color: Colors.white, // Changed back to white
            size: MediaQuery.of(context).size.width * 0.06,
          ),
        ),
        title: Text(
          'E-Waste Disposal Locations',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w600,
            fontSize: MediaQuery.of(context).size.width * 0.04,
          ),
        ),
        subtitle: Text(
          'Find certified e-waste recycling centers near you for safe disposal.',
          style: GoogleFonts.montserrat(
            color: Colors.grey[600],
            fontSize: MediaQuery.of(context).size.width * 0.035,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          size: MediaQuery.of(context).size.width * 0.06,
        ),
        onTap: () async {
          try {
            // Fetch data from Firestore
            final querySnapshot =
                await FirebaseFirestore.instance
                    .collection('ewaste_locations')
                    .get();

            // Convert Firestore documents to a list of maps
            final locations =
                querySnapshot.docs.map((doc) {
                  final data = doc.data();
                  final latLong =
                      data['lat_long'] as GeoPoint; // Treat as GeoPoint

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

  Widget _buildBuyerContactsSection() {
    return Container(
      margin: EdgeInsets.only(
        bottom: MediaQuery.of(context).size.height * 0.02,
        top: MediaQuery.of(context).size.height * 0.01,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          MediaQuery.of(context).size.width * 0.03,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.yellow, // Changed to yellow
          radius: MediaQuery.of(context).size.width * 0.06,
          child: Icon(
            Icons.contacts,
            color: Colors.black, // Changed to black for better contrast on yellow
            size: MediaQuery.of(context).size.width * 0.06,
          ),
        ),
        title: Text(
          'Buyer Contacts',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w600,
            fontSize: MediaQuery.of(context).size.width * 0.04,
          ),
        ),
        subtitle: Text(
          'Find buyers and sellers for your e-waste components.',
          style: GoogleFonts.montserrat(
            color: Colors.grey[600],
            fontSize: MediaQuery.of(context).size.width * 0.035,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          size: MediaQuery.of(context).size.width * 0.06,
          color: const Color(0xFF2196F3), // Match the blue color
        ),
        onTap: _showBuyerContactsDialog,
      ),
    );
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
            style: GoogleFonts.montserrat(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  // Calculate sellability score for a component
  double _calculateSellabilityScore(Map<String, dynamic> componentData) {
    if (componentData['selected_parameters'] == null) {
      return _baseSellabilityScore; // Return base score if not configured
    }

    Map<String, String> selectedParams = Map<String, String>.from(
      componentData['selected_parameters'] as Map<String, dynamic>,
    );

    double score = _baseSellabilityScore;
    double totalWeight = 0.0;
    double weightedScoreSum =
        0.0; // Calculate weighted average of sellability factors
    _sellabilityModifiers.forEach((parameterName, weight) {
      if (selectedParams.containsKey(parameterName)) {
        String selectedValue =
            selectedParams[parameterName]!; // Use hardcoded multipliers instead of Firestore values
        double multiplier = 1.0;
        if (_sellabilityMultiplier.containsKey(parameterName) &&
            _sellabilityMultiplier[parameterName]!.containsKey(selectedValue)) {
          multiplier = _sellabilityMultiplier[parameterName]![selectedValue]!;
        }

        // Convert multiplier to score (0.0-1.0 range mapped to 0-100)
        double parameterScore = multiplier * 100.0;

        weightedScoreSum += parameterScore * weight;
        totalWeight += weight;
      }
    });

    if (totalWeight > 0) {
      score = weightedScoreSum / totalWeight;
    }

    // Ensure score is within reasonable bounds (0-100)
    return score.clamp(0.0, 100.0);
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

  // Fallback to load data from local JSON
  Future<void> _fallbackToLocalJson() async {
    try {
      print('📄 Falling back to local JSON');
      final normalizedCategory = widget.deviceCategory.toLowerCase().replaceAll(
        ' ',
        '_',
      );
      final jsonPath = 'assets/${normalizedCategory}_instructions.json';

      final String jsonString = await rootBundle.loadString(jsonPath);
      final Map<String, dynamic> jsonData = json.decode(jsonString);

      setState(() {
        _componentValues = Map<String, Map<String, dynamic>>.from(
          jsonData['component_values'] as Map<String, dynamic>,
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

  // Helper method to format component names
  String _formatComponentName(String name) {
    String firstPart = name.split('_')[0];
    return firstPart[0].toUpperCase() + firstPart.substring(1);
  }

  // Helper method to format parameter names
  String _formatParameterName(String name) {
    return name[0].toUpperCase() + name.substring(1).replaceAll('_', ' ');
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

  // Get images for a specific component
  List<String> _getComponentImages(String component) {
    List<String> images = [];
    for (var entry in widget.componentImages.entries) {
      for (var componentEntry in entry.value.entries) {
        if (componentEntry.key.toLowerCase().startsWith(
          component.toLowerCase(),
        )) {
          images.add(componentEntry.value);
        }
      }
    }
    return images;
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

  // Get sellability score color
  Color _getSellabilityColor(double score) {
    if (score >= 85) {
      return const Color(0xFF4CAF50); // Green
    } else if (score >= 70) {
      return const Color(0xFF8BC34A); // Light Green
    } else if (score >= 50) {
      return const Color(0xFFFFC107); // Amber
    } else if (score >= 30) {
      return const Color(0xFFFF9800); // Orange
    } else {
      return const Color(0xFFF44336); // Red
    }
  }

  // Get sellability score description
  String _getSellabilityDescription(double score) {
    if (score >= 85) {
      return 'Excellent';
    } else if (score >= 70) {
      return 'Good';
    } else if (score >= 50) {
      return 'Fair';
    } else if (score >= 30) {
      return 'Poor';
    } else {
      return 'Very Poor';
    }
  }

  // Get unique component types
  List<String> _getUniqueComponents() {
    return widget.extractedComponents
        .map((c) => c.split('_')[0].toLowerCase())
        .toSet()
        .toList();
  }

  // Check if component has uncertain parameters in sellability-affecting parameters only
  bool _hasUncertainParameters(Map<String, dynamic> componentData) {
    if (componentData['selected_parameters'] == null) {
      return false;
    }

    Map<String, String> selectedParams = Map<String, String>.from(
      componentData['selected_parameters'] as Map<String, dynamic>,
    );

    // Only check uncertainty for parameters that affect sellability score
    const sellabilityAffectingParams = ['age', 'condition', 'functionality'];

    for (String paramName in sellabilityAffectingParams) {
      if (selectedParams.containsKey(paramName)) {
        String value = selectedParams[paramName]!;
        if (value.toLowerCase().contains('other/unsure') ||
            value.toLowerCase() == 'unsure') {
          return true;
        }
      }
    }

    return false;
  }

  Future<void> _loadComponentValues() async {
    final normalizedCategory = widget.deviceCategory.toLowerCase().replaceAll(
      ' ',
      '_',
    );

    try {
      // Try to get data from Firestore (works offline if cached)
      final docRef = FirebaseFirestore.instance
          .collection('pricing')
          .doc(normalizedCategory);

      final docSnapshot = await docRef.get();

      if (docSnapshot.exists) {
        // If document exists in Firestore (or offline cache), use it
        final firestoreData = docSnapshot.data();

        if (firestoreData != null &&
            firestoreData['component_values'] != null) {
          setState(() {
            _componentValues = Map<String, Map<String, dynamic>>.from(
              firestoreData['component_values'] as Map<String, dynamic>,
            );
            _isLoading = false;
          });

          print(
            '🔥 Loaded component values from Firestore: ${_componentValues?.length} components',
          );
        } else {
          _fallbackToLocalJson();
        }
      } else {
        // If document doesn't exist in Firestore, fallback to local JSON
        _fallbackToLocalJson();
      }

      // Set up real-time listener for updates
      _firestoreSubscription = docRef.snapshots().listen(
        (doc) {
          if (doc.exists) {
            final firestoreData = doc.data();
            if (firestoreData != null &&
                firestoreData['component_values'] != null) {
              setState(() {
                _componentValues = Map<String, Map<String, dynamic>>.from(
                  firestoreData['component_values'] as Map<String, dynamic>,
                );
              });
              print('🔄 Updated component values from Firestore');
            }
          }
        },
        onError: (e) {
          print('❌ Error listening to Firestore updates: $e');
          // No need to fallback here as we already have data
        },
      );

      // Once data is loaded, show parameter dialogs
      _showParameterDialogs();
    } catch (e) {
      print('❌ Error loading from Firestore: $e');
      _fallbackToLocalJson();
    }
  }

  // Save JSON data to Firestore for future offline access
  Future<void> _saveToFirestore(
    String category,
    Map<String, dynamic> data,
  ) async {
    try {
      await FirebaseFirestore.instance.collection('pricing').doc(category).set({
        'component_values': data,
        'last_updated': FieldValue.serverTimestamp(),
      });
      print('💾 Saved local data to Firestore for future offline access');
    } catch (e) {
      print('❌ Error saving to Firestore: $e');
      // This is fine, we already have the data locally
    }
  }

  void _showDisclaimerDialog() {
    bool doNotShowAgain = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
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
                        const Icon(
                          Icons.info_outline,
                          color: Color(0xFF34A853),
                          size: 24,
                        ),
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
                            text:
                                '1. Component pricing used in this application is primarily sourced from publicly available platforms, including Shopee, Lazada, and Facebook Marketplace.\n\n',
                          ),
                          TextSpan(
                            text:
                                '2. Our pricing estimates are based on available market data but may vary due to platform availability, resale channels, regulatory changes, and other market conditions.\n\n',
                          ),
                          TextSpan(
                            text:
                                '3. Pricing at e-waste facilities ultimately depends on their specific policy regulations and operational practices.',
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
                              fillColor: WidgetStateProperty.resolveWith<Color>(
                                (states) {
                                  if (states.contains(WidgetState.selected)) {
                                    return const Color(0xFF34A853);
                                  }
                                  return Colors.white;
                                },
                              ),
                              checkColor: WidgetStateProperty.all<Color>(
                                Colors.white,
                              ),
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

  // Show buyer contacts dialog
  void _showBuyerContactsDialog() async {
    try {
      // Load buyer contacts from JSON file
      final String jsonString = await rootBundle.loadString('assets/buyers_contacts.json');
      final Map<String, dynamic> jsonData = json.decode(jsonString);
      final List<dynamic> buyers = jsonData['buyers'];

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (BuildContext context) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF34A853), // Changed back to green
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.contacts,
                          color: Colors.white, // Changed back to white
                          size: MediaQuery.of(context).size.width * 0.06,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Buyer Contacts',
                            style: GoogleFonts.montserrat(
                              color: Colors.white,
                              fontSize: MediaQuery.of(context).size.width * 0.045,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(
                            Icons.close,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Buyer list
                  Flexible(
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      shrinkWrap: true,
                      itemCount: buyers.length,
                      separatorBuilder: (context, index) => const Divider(),
                      itemBuilder: (context, index) {
                        final buyer = buyers[index];
                        final specialties = (buyer['specialties'] as List<dynamic>)
                            .map((e) => e.toString())
                            .toList();

                        return Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Buyer name
                                Text(
                                  buyer['name'],
                                  style: GoogleFonts.montserrat(
                                    fontWeight: FontWeight.bold,
                                    fontSize: MediaQuery.of(context).size.width * 0.04,
                                    color: const Color(0xFF34A853), // Changed back to green
                                  ),
                                ),
                                const SizedBox(height: 8),
                                // Address
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.location_on,
                                      size: MediaQuery.of(context).size.width * 0.04,
                                      color: Colors.grey[600],
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        buyer['address'],
                                        style: GoogleFonts.montserrat(
                                          fontSize: MediaQuery.of(context).size.width * 0.035,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                // Phone number
                                Row(
                                  children: [
                                    Icon(
                                      Icons.phone,
                                      size: MediaQuery.of(context).size.width * 0.04,
                                      color: Colors.grey[600],
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      buyer['number'],
                                      style: GoogleFonts.montserrat(
                                        fontSize: MediaQuery.of(context).size.width * 0.035,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                // Email
                                Row(
                                  children: [
                                    Icon(
                                      Icons.email,
                                      size: MediaQuery.of(context).size.width * 0.04,
                                      color: Colors.grey[600],
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        buyer['email'],
                                        style: GoogleFonts.montserrat(
                                          fontSize: MediaQuery.of(context).size.width * 0.035,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                // Specialties
                                Text(
                                  'Specialties:',
                                  style: GoogleFonts.montserrat(
                                    fontWeight: FontWeight.w600,
                                    fontSize: MediaQuery.of(context).size.width * 0.035,
                                    color: Colors.grey[800],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: specialties.map((specialty) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF34A853).withOpacity(0.1), // Changed back to green
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: const Color(0xFF34A853).withOpacity(0.3), // Changed back to green
                                        ),
                                      ),
                                      child: Text(
                                        specialty,
                                        style: GoogleFonts.montserrat(
                                          fontSize: MediaQuery.of(context).size.width * 0.03,
                                          color: const Color(0xFF34A853), // Changed back to green
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  // Footer
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: Text(
                        'Contact these buyers to get quotes for your e-waste components.',
                        style: GoogleFonts.montserrat(
                          fontSize: MediaQuery.of(context).size.width * 0.03,
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      print('Error loading buyer contacts: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error loading buyer contacts. Please try again.',
            style: GoogleFonts.montserrat(),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
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
              OverflowBar(
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
          builder:
              (context) => ParameterDialog(
                componentName: _formatComponentName(component),
                componentData: componentData,
                parameters: componentData['parameters'],
                onValueCalculated: (newValue, selectedParams) {
                  setState(() {
                    if (_componentValues != null) {
                      // Make a copy to trigger Flutter's state update
                      _componentValues = Map<String, Map<String, dynamic>>.from(
                        _componentValues!,
                      );
                      var componentMap =
                          _componentValues![component.toLowerCase()];
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
}
