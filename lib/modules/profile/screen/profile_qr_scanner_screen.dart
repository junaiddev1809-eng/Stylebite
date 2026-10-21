import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/theme/app_fonts.dart';
import '../../../core/widgets/app_hero_icon.dart';
import '../utils/profile_open_helper.dart';

class ProfileQrScannerScreen extends StatefulWidget {
  const ProfileQrScannerScreen({super.key});

  @override
  State<ProfileQrScannerScreen> createState() => _ProfileQrScannerScreenState();
}

class _ProfileQrScannerScreenState extends State<ProfileQrScannerScreen> {
  final MobileScannerController _scannerController = MobileScannerController();
  final ImagePicker _picker = ImagePicker();
  bool _isHandlingCode = false;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _scanFromGallery() async {
    if (_isHandlingCode) return;

    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      final BarcodeCapture? capture = await _scannerController.analyzeImage(image.path);
      if (capture == null || capture.barcodes.isEmpty) {
        Get.snackbar(
          'Scan Failed',
          'No valid QR code found in the selected image.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.withValues(alpha: 0.8),
          colorText: Colors.white,
        );
        return;
      }

      final String? rawValue = capture.barcodes.first.rawValue;
      print('DEBUG: QR Scanned from Gallery: $rawValue');
      _handleScanResult(rawValue);
    } catch (e) {
      print('DEBUG: Error scanning from gallery: $e');
    }
  }

  void _handleScanResult(String? rawValue) async {
    if (_isHandlingCode || rawValue == null) return;

    final username = _extractProfileUsername(rawValue);
    print('DEBUG: Raw Value: $rawValue');
    print('DEBUG: Extracted Username: $username');

    if (username == null) {
      Get.snackbar(
        'Invalid QR',
        'This QR code does not contain a valid profile link.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.withValues(alpha: 0.8),
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );
      return;
    }

    _isHandlingCode = true;
    
    try {
      await _scannerController.stop();
    } catch (e) {
      print('DEBUG: Error stopping scanner: $e');
    }

    if (!mounted) return;

    print('DEBUG: Navigating to profile for: $username');
    
    // Replace current scanner screen with UserProfileScreen
    ProfileOpenHelper.open(username: username, replaceCurrent: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: (capture) {
              if (_isHandlingCode) return;
              final rawValue = capture.barcodes.isEmpty
                  ? null
                  : capture.barcodes.first.rawValue;
              if (rawValue != null) {
                _handleScanResult(rawValue);
              }
            },
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.72),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.82),
                ],
                stops: const [0, 0.28, 1],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              child: Column(
                children: [
                  Row(
                    children: [
                      InkWell(
                        onTap: () => Get.back(),
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const AppHeroIconData(Icons.arrow_back_rounded,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const Spacer(),
                      InkWell(
                        onTap: _scanFromGallery,
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Icon(
                            Icons.photo_library_outlined,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Scan Profile QR',
                    style: AppFonts.plusJakarta(
                      size: 24,
                      weight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Point your camera at a StyleBite profile QR code.',
                    textAlign: TextAlign.center,
                    style: AppFonts.beVietnam(
                      size: 13,
                      weight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.78),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxWidth: 320),
                    height: 320,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.9),
                        width: 2.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Scanning opens the matching profile inside the app.',
                    textAlign: TextAlign.center,
                    style: AppFonts.beVietnam(
                      size: 12,
                      weight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 42),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _extractProfileUsername(String? rawValue) {
    final value = rawValue?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }

    // 1. Simple text check (no spaces, no dots, no protocol)
    if (!value.contains('://') && !value.contains(' ') && !value.contains('.')) {
      return value;
    }

    final uri = Uri.tryParse(value);
    if (uri == null) return null;

    // 2. Web URL: https://stylebite.com/profile/username
    if (uri.pathSegments.contains('profile')) {
      final index = uri.pathSegments.indexOf('profile');
      if (index + 1 < uri.pathSegments.length) {
        return uri.pathSegments[index + 1].trim();
      }
    }

    // 3. Custom Scheme: stylebite://profile/username
    if (uri.scheme == 'stylebite') {
      if (uri.pathSegments.contains('profile')) {
        final index = uri.pathSegments.indexOf('profile');
        if (index + 1 < uri.pathSegments.length) {
          return uri.pathSegments[index + 1].trim();
        }
      }
      if (uri.host.isNotEmpty && uri.host != 'profile') {
        return uri.host;
      }
    }

    return null;
  }
}
