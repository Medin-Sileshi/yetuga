import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';


import '../../utils/logger.dart';
import '../profile/profile_screen.dart';

class QrScannerScreen extends ConsumerStatefulWidget {
  const QrScannerScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends ConsumerState<QrScannerScreen> {
  final MobileScannerController _scannerController = MobileScannerController();
  bool _isGeneratingQr = false;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  void _handleDetection(BarcodeCapture capture) {
    final List<Barcode> barcodes = capture.barcodes;

    for (final barcode in barcodes) {
      final String? code = barcode.rawValue;
      if (code != null && code.startsWith('yetuga://profile/')) {
        try {
          // Extract the user ID from the QR code
          final String userId = code.replaceFirst('yetuga://profile/', '');
          Logger.d('QrScannerScreen', 'Detected profile QR code for user: $userId');

          if (userId.isEmpty) {
            _showErrorSnackBar('Invalid QR code: User ID is empty');
            return;
          }

          // Pause scanning while navigating
          _scannerController.stop();

          // Navigate to the profile screen with the detected user ID
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ProfileScreen(userId: userId),
            ),
          ).then((_) {
            // Resume scanning when returning from profile screen
            if (mounted && !_isGeneratingQr) {
              _scannerController.start();
            }
          });
          return;
        } catch (e) {
          Logger.e('QrScannerScreen', 'Error handling QR code', e);
          _showErrorSnackBar('Error processing QR code: $e');
          return;
        }
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _toggleQrGeneration() {
    setState(() {
      _isGeneratingQr = !_isGeneratingQr;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUser = FirebaseAuth.instance.currentUser;
    final String? currentUserId = currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Code Scanner'),
        backgroundColor: theme.appBarTheme.backgroundColor,
        foregroundColor: theme.appBarTheme.foregroundColor,
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: _isGeneratingQr
                ? _buildProfileQrCode(currentUserId)
                : _buildQrScanner(),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _toggleQrGeneration,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                child: Text(
                  _isGeneratingQr ? 'Scan QR Code' : 'Share My Profile',
                  style: const TextStyle(fontSize: 16.0),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQrScanner() {
    return Stack(
      children: [
        // Scanner
        MobileScanner(
          controller: _scannerController,
          onDetect: _handleDetection,
        ),

        // Custom overlay
        QRScannerOverlay(
          overlayColor: Colors.black.withAlpha(128), // ~0.5 opacity
          borderColor: Theme.of(context).colorScheme.primary,
          borderRadius: 16.0,
          borderLength: 30.0,
          borderWidth: 3.0,
          cutOutSize: 250.0,
        ),
      ],
    );
  }

  Widget _buildProfileQrCode(String? userId) {
    if (userId == null) {
      return const Center(
        child: Text('You need to be logged in to share your profile'),
      );
    }

    // Create a unique data string for this profile
    final String qrData = 'yetuga://profile/$userId';

    // Create a GlobalKey to capture the QR code as an image
    final GlobalKey qrKey = GlobalKey();

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Your Profile QR Code',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const Text(
            'Others can scan this code to view your profile',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          RepaintBoundary(
            key: qrKey,
            child: Container(
              width: 250,
              height: 250,
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(26), // ~0.1 opacity
                    spreadRadius: 1,
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: QrImageView(
                data: qrData,
                version: QrVersions.auto,
                size: 220.0,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Colors.black,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Colors.black,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _downloadQrCode(context, qrKey, 'profile_${userId}_qr'),
            icon: const Icon(Icons.download),
            label: const Text('Download QR Code'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Download QR code as image
  Future<void> _downloadQrCode(BuildContext context, GlobalKey qrKey, String fileName) async {
    try {
      // Find the RenderRepaintBoundary
      final RenderRepaintBoundary boundary = qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;

      // Capture the image
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);

      // Convert to bytes
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('Failed to convert image to bytes');
      }

      final Uint8List pngBytes = byteData.buffer.asUint8List();

      // Get temporary directory
      final Directory tempDir = await getTemporaryDirectory();
      final String tempPath = tempDir.path;

      // Create file
      final File file = File('$tempPath/$fileName.png');
      await file.writeAsBytes(pngBytes);

      // Share the file
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'QR Code',
      );

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('QR code shared successfully!'))
        );
      }
    } catch (e) {
      Logger.e('QrScannerScreen', 'Error downloading QR code', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'))
        );
      }
    }
  }
}

// Custom overlay for the QR scanner
class QRScannerOverlay extends StatelessWidget {
  final Color overlayColor;
  final Color borderColor;
  final double borderRadius;
  final double borderLength;
  final double borderWidth;
  final double cutOutSize;

  const QRScannerOverlay({
    Key? key,
    required this.overlayColor,
    required this.borderColor,
    this.borderRadius = 10.0,
    this.borderLength = 30.0,
    this.borderWidth = 10.0,
    this.cutOutSize = 250.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Calculate the size of the screen
    final screenSize = MediaQuery.of(context).size;

    return Stack(
      children: [
        // Semi-transparent overlay
        Container(
          width: screenSize.width,
          height: screenSize.height,
          color: overlayColor,
        ),

        // Transparent center cutout
        Center(
          child: Container(
            width: cutOutSize,
            height: cutOutSize,
            decoration: BoxDecoration(
              color: Colors.transparent,
              border: Border.all(color: borderColor, width: borderWidth),
              borderRadius: BorderRadius.circular(borderRadius),
            ),
          ),
        ),

        // Corner indicators
        Center(
          child: Container(
            width: cutOutSize,
            height: cutOutSize,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            child: Stack(
              children: [
                // Top left corner
                Positioned(
                  top: 0,
                  left: 0,
                  child: _buildCorner(borderColor),
                ),
                // Top right corner
                Positioned(
                  top: 0,
                  right: 0,
                  child: Transform.rotate(
                    angle: 90 * 3.14159 / 180,
                    child: _buildCorner(borderColor),
                  ),
                ),
                // Bottom right corner
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Transform.rotate(
                    angle: 180 * 3.14159 / 180,
                    child: _buildCorner(borderColor),
                  ),
                ),
                // Bottom left corner
                Positioned(
                  bottom: 0,
                  left: 0,
                  child: Transform.rotate(
                    angle: 270 * 3.14159 / 180,
                    child: _buildCorner(borderColor),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Instruction text
        Positioned(
          bottom: 16,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                'Scan a profile QR code',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Helper method to build corner indicators
  Widget _buildCorner(Color color) {
    return Container(
      width: borderLength,
      height: borderLength,
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: color, width: borderWidth),
          left: BorderSide(color: color, width: borderWidth),
        ),
      ),
    );
  }
}
