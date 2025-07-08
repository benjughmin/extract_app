import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class EducationalContentPage extends StatefulWidget {
  const EducationalContentPage({super.key});

  @override
  State<EducationalContentPage> createState() => _EducationalContentPageState();
}

class _EducationalContentPageState extends State<EducationalContentPage> {
  int _selectedTabIndex = 0;

  final List<Map<String, dynamic>> _educationalSections = [
    {
      'title': 'E-Waste Facts',
      'icon': Icons.info_outline,
      'content': [
        {
          'title': 'Global E-Waste Statistics',
          'facts': [
            'The world generates 57.4 million tons of e-waste annually',
            'Only 20% of global e-waste is properly recycled',
            'E-waste is growing 3x faster than the world population',
            'By 2030, e-waste generation is expected to reach 74.7 million tons',
            'The average smartphone contains over 60 different elements',
          ]
        },
        {
          'title': 'Hidden Dangers',
          'facts': [
            'E-waste contains over 1,000 toxic substances',
            'Lead in e-waste can damage the nervous system',
            'Mercury exposure can cause brain and kidney damage',
            'Cadmium is linked to cancer and organ damage',
            'Improper disposal affects soil quality for decades',
          ]
        }
      ]
    },
    {
      'title': 'Environmental Impact',
      'icon': Icons.eco,
      'content': [
        {
          'title': 'Soil & Water Contamination',
          'facts': [
            'Heavy metals leach into groundwater systems',
            'Contaminated water affects agriculture and drinking sources',
            'Soil contamination can persist for over 100 years',
            'Toxic chemicals accumulate in the food chain',
            'Aquatic ecosystems suffer from metal poisoning',
          ]
        },
        {
          'title': 'Air Pollution',
          'facts': [
            'Burning e-waste releases toxic fumes',
            'Dioxins and furans cause respiratory problems',
            'Heavy metal particles pollute the atmosphere',
            'Indoor air quality deteriorates in processing areas',
            'Long-term exposure increases cancer risk',
          ]
        }
      ]
    },
    {
      'title': 'Metal Recovery',
      'icon': Icons.recycling,
      'content': [
        {
          'title': 'Precious Metals in Electronics',
          'facts': [
            'Smartphones contain gold, silver, copper, and platinum',
            '1 ton of phones = 340g of gold (more than gold ore)',
            'Circuit boards are 40x richer in copper than ore',
            'Rare earth elements are essential for modern tech',
            'Proper extraction recovers 95% of valuable metals',
          ]
        },
        {
          'title': 'Recovery Benefits',
          'facts': [
            'Reduces need for harmful mining operations',
            'Saves energy: recycled aluminum uses 95% less energy',
            'Prevents toxic waste from entering landfills',
            'Creates jobs in the recycling industry',
            'Supports circular economy principles',
          ]
        }
      ]
    },
    {
      'title': 'Health Effects',
      'icon': Icons.health_and_safety,
      'content': [
        {
          'title': 'Human Health Risks',
          'facts': [
            'Lead exposure causes learning disabilities in children',
            'Mercury affects brain development and function',
            'Chromium exposure increases cancer risk',
            'Reproductive health issues from toxic exposure',
            'Respiratory problems from inhaling metal particles',
          ]
        },
        {
          'title': 'Vulnerable Populations',
          'facts': [
            'Children are most at risk from e-waste toxins',
            'Pregnant women face increased complications',
            'Workers in informal recycling suffer health issues',
            'Communities near dumpsites have higher illness rates',
            'Long-term exposure effects may take years to appear',
          ]
        }
      ]
    },
    {
      'title': 'Solutions',
      'icon': Icons.lightbulb_outline,
      'content': [
        {
          'title': 'Proper Disposal Methods',
          'facts': [
            'Use certified e-waste recycling centers',
            'Participate in manufacturer take-back programs',
            'Support electronics repair and refurbishment',
            'Donate working devices to extend their life',
            'Never throw electronics in regular trash',
          ]
        },
        {
          'title': 'Prevention Strategies',
          'facts': [
            'Buy quality electronics that last longer',
            'Upgrade software instead of hardware when possible',
            'Use protective cases to extend device life',
            'Consider refurbished devices for purchases',
            'Support companies with sustainable practices',
          ]
        }
      ]
    }
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'E-Waste Education',
          style: GoogleFonts.montserrat(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: const Color(0xFF34A853),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Tab Navigation
          Container(
            height: 60,
            color: Colors.grey[100],
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _educationalSections.length,
              itemBuilder: (context, index) {
                final section = _educationalSections[index];
                final isSelected = index == _selectedTabIndex;
                
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedTabIndex = index;
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF34A853) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF34A853) : Colors.grey[300]!,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          section['icon'],
                          size: 18,
                          color: isSelected ? Colors.white : Colors.grey[600],
                        ),
                        const SizedBox(width: 8),
                        Text(
                          section['title'],
                          style: GoogleFonts.montserrat(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isSelected ? Colors.white : Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          
          // Content Area
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section Title
                  Row(
                    children: [
                      Icon(
                        _educationalSections[_selectedTabIndex]['icon'],
                        size: 28,
                        color: const Color(0xFF34A853),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _educationalSections[_selectedTabIndex]['title'],
                        style: GoogleFonts.montserrat(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  // Content Cards
                  ...(_educationalSections[_selectedTabIndex]['content'] as List<Map<String, dynamic>>)
                      .map((contentSection) => _buildContentCard(contentSection)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentCard(Map<String, dynamic> contentSection) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              contentSection['title'],
              style: GoogleFonts.montserrat(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF34A853),
              ),
            ),
            const SizedBox(height: 12),
            ...(contentSection['facts'] as List<String>).map((fact) => 
              _buildFactItem(fact)
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFactItem(String fact) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6, right: 12),
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Color(0xFF34A853),
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(
              fact,
              style: GoogleFonts.montserrat(
                fontSize: 14,
                height: 1.5,
                color: Colors.grey[700],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
