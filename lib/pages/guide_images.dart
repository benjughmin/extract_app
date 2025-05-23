import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DeviceGuideImages {
  // Maps device categories to their sample image assets
  static Map<String, List<GuideImage>> categoryGuides = {
    'Smartphone': [
      GuideImage(
        assetPath: 'assets/guides/open_phone.png',
        description: "Ensure the device's casing is open, and is placed at an appropriate distance",
        iconData: Icons.ad_units,
      ),
      GuideImage(
        assetPath: 'assets/guides/dark_phone.png',
        additionalImages: [
          'assets/guides/light_phone.png',
        ],
        description: 'Make sure the device is well-lit to avoid shadows or glares',
        iconData: Icons.lightbulb_outline,
        isCollage: true,
      ),
      GuideImage(
        assetPath: 'assets/guides/blur_phone.png',
        additionalImages: [
          'assets/guides/unblur_phone.png',
        ],
        description: 'Ensure the photo is clear and steady',
        isCollage: true,
        iconData: Icons.center_focus_strong,
      ),
      GuideImage(
        assetPath: 'assets/guides/mul_phone1.png',
        additionalImages: [
          'assets/guides/mul_phone2.png',
          'assets/guides/mul_phone3.png',
        ],
        description: 'If necessary, capture multiple angles (top, side, and close-up)',
        isCollage: true,
        iconData: Icons.view_carousel,
      ),
      GuideImage(
        assetPath: 'assets/guides/add_img.png',
        description: 'Upload more images after removing parts to reveal hidden components and get further instructions',
        iconData: Icons.add_photo_alternate,
      ),
    ],
    'Laptop': [
      GuideImage(
        assetPath: 'assets/guides/open_laptop.png',
        description: "Ensure the device's casing is open, and is placed at an appropriate distance",
        iconData: Icons.laptop,
      ),
      GuideImage(
        assetPath: 'assets/guides/dark_laptop.png',
        additionalImages: [
          'assets/guides/light_laptop.png',
        ],
        description: 'Make sure the device is well-lit to avoid shadows or glares',
        iconData: Icons.lightbulb_outline,
        isCollage: true,
      ),
      GuideImage(
        assetPath: 'assets/guides/blur_laptop.png',
        additionalImages: [
          'assets/guides/unblur_laptop.png',
        ],
        description: 'Ensure the photo is clear and steady',
        isCollage: true,
        iconData: Icons.center_focus_strong,
      ),
      GuideImage(
        assetPath: 'assets/guides/mul_laptop1.png',
        additionalImages: [
          'assets/guides/mul_laptop2.png',
          'assets/guides/mul_laptop3.png',
        ],
        description: 'If necessary, capture multiple angles (top, side, and close-up)',
        isCollage: true,
        iconData: Icons.view_carousel,
      ),
      GuideImage(
        assetPath: 'assets/guides/add_img.png',
        description: 'Upload more images after removing parts to reveal hidden components and get further instructions',
        iconData: Icons.add_photo_alternate,
      ),
    ],
    'Desktop': [
      GuideImage(
        assetPath: 'assets/guides/open_desktop.png',
        description: "Ensure the device's casing is open, and is placed at an appropriate distance",
        iconData: Icons.desktop_windows,
      ),
      GuideImage(
        assetPath: 'assets/guides/dark_desktop.png',
        additionalImages: [
          'assets/guides/light_desktop.png',
        ],
        description: 'Make sure the device is well-lit to avoid shadows or glares',
        iconData: Icons.lightbulb_outline,
        isCollage: true,
      ),
      GuideImage(
        assetPath: 'assets/guides/blur_desktop.png',
        additionalImages: [
          'assets/guides/unblur_desktop.png',
        ],
        description: 'Ensure the photo is clear and steady',
        isCollage: true,
        iconData: Icons.center_focus_strong,
      ),
      GuideImage(
        assetPath: 'assets/guides/mul_desktop1.png',
        additionalImages: [
          'assets/guides/mul_desktop2.png',
          'assets/guides/mul_desktop3.png',
        ],
        description: 'If necessary, capture multiple angles (top, side, and close-up)',
        isCollage: true,
        iconData: Icons.view_carousel,
      ),
      GuideImage(
        assetPath: 'assets/guides/add_img.png',
        description: 'Upload more images after removing parts to reveal hidden components and get further instructions',
        iconData: Icons.add_photo_alternate,
      ),
    ],
    'Router': [
      GuideImage(
        assetPath: 'assets/guides/open_router.png',
        description: "Ensure the device's casing is open, and is placed at an appropriate distance",
        iconData: Icons.router,
      ),
      GuideImage(
        assetPath: 'assets/guides/dark_router.png',
        additionalImages: [
          'assets/guides/light_router.png',
        ],
        description: 'Make sure the device is well-lit to avoid shadows or glares',
        iconData: Icons.lightbulb_outline,
        isCollage: true,
      ),
      GuideImage(
        assetPath: 'assets/guides/blur_router.png',
        additionalImages: [
          'assets/guides/unblur_router.png',
        ],
        description: 'Ensure the photo is clear and steady',
        isCollage: true,
        iconData: Icons.center_focus_strong,
      ),
      GuideImage(
        assetPath: 'assets/guides/add_img.png',
        description: 'Upload more images after removing parts to reveal hidden components and get further instructions',
        iconData: Icons.add_photo_alternate,
      ),
    ],
    'Landline': [
      GuideImage(
        assetPath: 'assets/guides/open_landline.jpeg',
        description: "Ensure the device's casing is open, and is placed at an appropriate distance",
        iconData: Icons.phone,
      ),
      GuideImage(
        assetPath: 'assets/guides/dark_landline.png',
        additionalImages: [
          'assets/guides/light_landline.png',
        ],
        description: 'Make sure the device is well-lit to avoid shadows or glares',
        iconData: Icons.lightbulb_outline,
        isCollage: true,
      ),
      GuideImage(
        assetPath: 'assets/guides/blur_landline.png',
        additionalImages: [
          'assets/guides/unblur_landline.png',
        ],
        description: 'Ensure the photo is clear and steady',
        isCollage: true,
        iconData: Icons.center_focus_strong,
      ),
      GuideImage(
        assetPath: 'assets/guides/add_img.png',
        description: 'Upload more images after removing parts to reveal hidden components and get further instructions',
        iconData: Icons.add_photo_alternate,
      ),
    ],
  };

  // Get guide images for a specific category
  static List<GuideImage> getGuidesForCategory(String category) {
    return categoryGuides[category] ?? 
      // Default guides if the category isn't found
      [
        GuideImage(
          assetPath: 'assets/guides/app_icon.png',
          description: 'Take a clear photo of the entire device',
          iconData: Icons.photo_camera,
        ),  
        GuideImage(
          assetPath: 'assets/guides/app_icon.png',
          description: 'Open the device to expose internal components',
          iconData: Icons.build,
        ),
      ];
  }
}

class GuideImage {
  final String assetPath;
  final List<String> additionalImages;
  final String description;
  final bool isCollage;
  final IconData iconData;

  GuideImage({
    required this.assetPath,
    this.additionalImages = const [],
    required this.description,
    this.isCollage = false,
    this.iconData = Icons.help_outline, 
  });
}



class DeviceGuideSlider extends StatefulWidget {
  final String deviceCategory;

  const DeviceGuideSlider({
    super.key,
    required this.deviceCategory,
  });

  @override
  State<DeviceGuideSlider> createState() => _DeviceGuideSliderState();
}

class _DeviceGuideSliderState extends State<DeviceGuideSlider> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _pageController.addListener(() {
      int page = _pageController.page?.round() ?? 0;
      if (_currentPage != page) {
        setState(() {
          _currentPage = page;
        });
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _showMultiImageViewer(BuildContext context, List<GuideImage> guideImages, int initialIndex) {
    int currentIndex = initialIndex;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: Colors.black87,
              insetPadding: const EdgeInsets.all(8),
              child: GestureDetector(
                onHorizontalDragEnd: (details) {
                  if (details.primaryVelocity != null) {
                    if (details.primaryVelocity! < 0 && currentIndex < guideImages.length - 1) {
                      // Swipe left to go to the next image
                      setState(() {
                        currentIndex++;
                      });
                    } else if (details.primaryVelocity! > 0 && currentIndex > 0) {
                      // Swipe right to go to the previous image
                      setState(() {
                        currentIndex--;
                      });
                    }
                  }
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Image Viewer and Navigation
                    Expanded(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Background
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              color: Colors.black87,
                              width: double.infinity,
                              height: double.infinity,
                            ),
                          ),

                          // Image Viewer with Transition Animation
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                  constraints: BoxConstraints(
                                    maxHeight: MediaQuery.of(context).size.height * 0.7,
                                    maxWidth: MediaQuery.of(context).size.width * 0.9,
                                  ),
                                  child: guideImages[currentIndex].isCollage
                                      ? ListView(
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.only(bottom: 8),
                                              child: Image.asset(
                                                guideImages[currentIndex].assetPath,
                                                fit: BoxFit.contain,
                                              ),
                                            ),
                                            ...guideImages[currentIndex]
                                                .additionalImages
                                                .map((imagePath) => Padding(
                                                      padding: const EdgeInsets.only(bottom: 8),
                                                      child: Image.asset(
                                                        imagePath,
                                                        fit: BoxFit.contain,
                                                      ),
                                                    ))
                                                .toList(),
                                          ],
                                        )
                                      : InteractiveViewer(
                                          minScale: 0.5,
                                          maxScale: 4.0,
                                          child: Image.asset(
                                            guideImages[currentIndex].assetPath,
                                            fit: BoxFit.contain,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      guideImages[currentIndex].iconData,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        guideImages[currentIndex].description,
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                "${currentIndex + 1}/${guideImages.length}",
                                style: GoogleFonts.poppins(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),

                          // Navigation Buttons
                          if (guideImages.length > 1)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Previous button
                                if (currentIndex > 0)
                                  IconButton(
                                  icon: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                    ),
                                    child: const Padding(
                                    padding: EdgeInsets.only(left: 8),
                                    child: Icon(
                                      Icons.arrow_back_ios,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                    ),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                    currentIndex--;
                                    });
                                  },
                                  )
                                else
                                  const SizedBox(width: 48),

                                // Next button
                                if (currentIndex < guideImages.length - 1)
                                  IconButton(
                                    icon: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.arrow_forward_ios,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        currentIndex++;
                                      });
                                    },
                                  )
                                else
                                  const SizedBox(width: 48),
                              ],
                            ),
                        ],
                      ),
                    ),

                    // Green Check Button at the Bottom
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.8), // Green background
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check, // Check icon
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildVerticalCollage(GuideImage guideImage, List<GuideImage> guideImages, int index) {
    return GestureDetector(
      onTap: () => _showMultiImageViewer(context, guideImages, index),
      child: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Image.asset(
                  guideImage.assetPath,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                ),
                Positioned(
                  right: 10,
                  top: 10,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(134, 119, 119, 119),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.touch_app,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Dynamically render all additional images
          ...guideImage.additionalImages.map((imagePath) {
            return Expanded(
              child: Image.asset(
                imagePath,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final guideImages = DeviceGuideImages.getGuidesForCategory(widget.deviceCategory);

    return Column(
      children: [
        Container(
          height: 280,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Colors.transparent, Colors.transparent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              PageView.builder(
                controller: _pageController,
                itemCount: guideImages.length,
                itemBuilder: (context, index) {
                  final guideImage = guideImages[index];
                  return Column(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                          child: guideImage.isCollage
                              ? _buildVerticalCollage(guideImage, guideImages, index)
                              : GestureDetector(
                                  onTap: () => _showMultiImageViewer(context, guideImages, index),
                                  child: Stack(
                                    children: [
                                      Center(
                                        child: Image.asset(
                                          guideImage.assetPath,
                                          fit: BoxFit.cover,
                                          width: double.infinity,
                                          height: double.infinity,
                                        ),
                                      ),
                                      Positioned(
                                        right: 10,
                                        top: 10,
                                        child: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: const Color.fromARGB(134, 119, 119, 119),
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: const Icon(
                                            Icons.touch_app,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                      ),
                      Container(
                        width: double.infinity,
                        height: 60, // Fixed height for consistency
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF34A853), Color(0xFF0F9D58)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              guideImage.iconData, // Safely use iconData
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                guideImage.description,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                ),
                                textAlign: TextAlign.center, // Changed from left to center
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
              if (guideImages.length > 1) ...[
                Positioned(
                  left: 8,
                  top: 0,
                  bottom: 40,
                  child: Center(
                    child: IconButton(
                      onPressed: () {
                        _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      icon: const Icon(
                        Icons.arrow_back_ios_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 8,
                  top: 0,
                  bottom: 40,
                  child: Center(
                    child: IconButton(
                      onPressed: () {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      icon: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ],
              if (guideImages.length > 1)
                Positioned(
                  bottom: 76, // Increased from 46 to place above text container
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      guideImages.length,
                      (index) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _currentPage == index
                              ? Colors.white
                              : Colors.white.withOpacity(0.4),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}