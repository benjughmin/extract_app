import 'package:flutter/material.dart'; 
import 'package:google_fonts/google_fonts.dart';
import '/pages/upload_or_camera.dart';
import '/pages/base.dart'; 


class Category extends StatelessWidget {
  const Category({super.key}); 

  @override
  Widget build(BuildContext context) {
    // Main UI of the screen
    return Base(
      title: 'Select E-Waste Type', // Title for the Base widget
      child: Padding(
        padding: const EdgeInsets.all(24.0), // Add space around the content
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center, // Center content horizontally
            children: [
            Text(
              // Instructional text
              'Select a device type below to get started with part extraction and recycling instructions.',
              textAlign: TextAlign.center, // Center the text
              style: GoogleFonts.montserrat(
                fontSize: 18,
                fontWeight: FontWeight.w600, // Font size
                color: Colors.white70, // Light white text color
                height: 1.5, // Line spacing
              ),
            ),
            const SizedBox(height: 30), // Add vertical space

            // Grid layout with 2 columns for the 4 e-waste types
            GridView.count(
              shrinkWrap: true, // Let grid take only needed space
              physics: const NeverScrollableScrollPhysics(), // Disable scrolling in grid
              crossAxisCount: 2, // 2 columns
              crossAxisSpacing: 16, // Horizontal spacing
              mainAxisSpacing: 16, // Vertical spacing
              children: [
              // Each box is created using a helper method
              _buildDeviceCard(
                context: context,
                icon: Icons.desktop_mac, // Icon for desktop
                label: 'Desktop',
              ),
              _buildDeviceCard(
                context: context,
                icon: Icons.laptop, // Icon for laptop
                label: 'Laptop',
              ),
              _buildDeviceCard(
                context: context,
                icon: Icons.smartphone, // Icon for smartphone
                label: 'Smartphone',
              ),
              _buildDeviceCard(
                context: context,
                icon: Icons.router, // Icon for router
                label: 'Router',
              ),
              ],
            ),

            const SizedBox(height: 16), // Space before next button

            // A full-width button for Landline Phone option
            Container(
              height: 90, // Shorter height for rectangular shape
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF34A853), Color(0xFF0F9D58)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => UploadPage(category: 'Landline'),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: EdgeInsets.zero,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.call,
                      color: Colors.white,
                      size: 50, // Smaller icon for rectangular shape
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Landline Phone',
                      style: GoogleFonts.montserrat(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // A reusable widget that creates a device card with icon, label and its functionalities
  Widget _buildDeviceCard({
    required BuildContext context, // Required context for UI
    required IconData icon, // Icon for the device
    required String label, // Label text for the device
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF34A853), Color(0xFF0F9D58)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20), // Rounded corners
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => UploadPage(category: label),
            ),
          );
        }, 
        
        borderRadius: BorderRadius.circular(20), // Ripple effect matches card shape
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center, // Center content vertically
          children: [
            Icon(
              icon, // Icon passed as parameter
              color: Colors.white, // White icon color
              size: 70, // Icon size
            ),
            const SizedBox(height: 8), // Space between icon and text
            Text(
              label, // Label passed as parameter
              style: GoogleFonts.montserrat(
                color: Colors.white, // White text color
                fontSize: 20, // Font size
                fontWeight: FontWeight.bold, // Bold text
              ),
            ),
          ],
        ),
      ),
    );
  }
}
