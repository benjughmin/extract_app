import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

class EWasteMapScreen extends StatelessWidget {
  final List<Map<String, dynamic>> locations;

  const EWasteMapScreen({super.key, required this.locations});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('E-Waste Disposal Locations'),
      ),
      body: FlutterMap(
        options: MapOptions(
          center: LatLng(14.5995, 120.9842), // Default to Manila center
          zoom: 11.0,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.app',
          ),
          MarkerLayer(
            markers: locations.map((location) {
              return Marker(
                point: LatLng(
                  location['latitude'] as double,
                  location['longitude'] as double,
                ),
                builder: (ctx) => GestureDetector(
                  onTap: () => _showLocationDetails(context, location),
                  child: const Icon(
                    Icons.location_on,
                    color: Colors.red,
                    size: 40,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  void _showLocationDetails(BuildContext context, Map<String, dynamic> location) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(location['name']),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(location['address']),
              const SizedBox(height: 8),
              Text(location['hours']),
              const SizedBox(height: 8),
              Text('Phone: ${location['phone']}'),
              const SizedBox(height: 16),
              const Text('Accepted Materials:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              ...(location['accepted_materials'] as List).map((material) {
                return Text('- ${material.toString().replaceAll('_', ' ')}');
              }).toList(),
              if (location['notes'] != null) ...[
                const SizedBox(height: 16),
                Text(location['notes']),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (location['website'] != null)
            TextButton(
              onPressed: () => _launchUrl(location['website']),
              child: const Text('Website'),
            ),
          TextButton(
            onPressed: () => _launchDirections(location),
            child: const Text('Directions'),
          ),
        ],
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }

  void _launchDirections(Map<String, dynamic> location) async {
    final url =
        'https://www.openstreetmap.org/directions?engine=osrm_car&route=${location['latitude']},${location['longitude']}';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }
}