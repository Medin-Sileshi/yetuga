import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import '../providers/onboarding_provider.dart';
import '../providers/firebase_provider.dart';
import '../providers/user_cache_provider.dart';
import '../utils/logger.dart';

class ProfileImagePickerDialog extends ConsumerStatefulWidget {
  final String? currentImageUrl;

  const ProfileImagePickerDialog({
    Key? key,
    this.currentImageUrl,
  }) : super(key: key);

  @override
  ConsumerState<ProfileImagePickerDialog> createState() => _ProfileImagePickerDialogState();
}

class _ProfileImagePickerDialogState extends ConsumerState<ProfileImagePickerDialog> {
  final ImagePicker _imagePicker = ImagePicker();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Change Profile Picture',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (!_isLoading)
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ),

          // Error message
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Text(
                _errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
                textAlign: TextAlign.center,
              ),
            ),

          // Loading indicator
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: CircularProgressIndicator(),
              ),
            )
          // Options
          else
            Column(
              children: [
                _buildOptionTile(
                  icon: Icons.camera_alt,
                  title: 'Take a photo',
                  onTap: () => _handleImageSelection(ImageSource.camera),
                ),
                _buildOptionTile(
                  icon: Icons.photo_library,
                  title: 'Choose from gallery',
                  onTap: () => _handleImageSelection(ImageSource.gallery),
                ),
                if (widget.currentImageUrl != null && widget.currentImageUrl!.isNotEmpty) ...[

                  _buildOptionTile(
                    icon: Icons.delete_outline,
                    title: 'Remove current photo',
                    isDestructive: true,
                    onTap: _showRemovePhotoConfirmation,
                  ),
                ],
              ],
            ),

          // Bottom padding for safe area
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final color = isDestructive ? Colors.red : null;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleImageSelection(ImageSource source) async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Store theme colors before async gap
      final primaryColor = Theme.of(context).colorScheme.primary;
      final onPrimaryColor = Theme.of(context).colorScheme.onPrimary;

      // Pick image
      final pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      // Crop image
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Photo',
            toolbarColor: primaryColor,
            toolbarWidgetColor: onPrimaryColor,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: 'Crop Photo',
            aspectRatioLockEnabled: true,
          ),
        ],
      );

      if (!mounted) return;

      if (croppedFile == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Upload and update profile image
      final imageFile = File(croppedFile.path);
      await _uploadAndUpdateProfileImage(imageFile);

    } catch (e) {
      Logger.e('ProfileImagePickerDialog', 'Error selecting image', e);
      if (mounted) {
        setState(() {
          _errorMessage = 'Error selecting image: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _uploadAndUpdateProfileImage(File imageFile) async {
    try {
      // Upload the image to Firebase Storage
      final firebaseService = ref.read(firebaseServiceProvider);
      final imageUrl = await firebaseService.uploadProfileImage(imageFile);

      // Update the profile image in Firestore and Hive
      await ref.read(onboardingProvider.notifier).updateProfileImage(imageUrl);

      // Clear the image cache to force reload of the new image
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Get the user cache service
        final userCacheService = ref.read(userCacheServiceProvider);

        // Clear the image cache for this user
        await userCacheService.clearImageCache(user.uid);
        Logger.d('ProfileImagePickerDialog', 'Cleared image cache for user: ${user.uid}');

        // Also clear the Flutter image cache to ensure the UI updates
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
        Logger.d('ProfileImagePickerDialog', 'Cleared Flutter image cache');
      }

      if (mounted) {
        // Show success message and close dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile picture updated successfully')),
        );
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    } catch (e) {
      Logger.e('ProfileImagePickerDialog', 'Error uploading profile image', e);
      if (mounted) {
        setState(() {
          _errorMessage = 'Error uploading image: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  void _showRemovePhotoConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Profile Picture'),
        content: const Text('Are you sure you want to remove your profile picture?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // For now, we'll just close the dialog
              // In a future update, we could implement profile picture removal
              Navigator.of(context).pop();
            },
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
