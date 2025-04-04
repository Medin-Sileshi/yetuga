import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../providers/onboarding_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../providers/firebase_provider.dart';
import '../../../widgets/onboarding_template.dart';

class ProfileImageStep extends ConsumerStatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;

  const ProfileImageStep({
    super.key,
    required this.onNext,
    required this.onBack,
  });

  @override
  ConsumerState<ProfileImageStep> createState() => _ProfileImageStepState();
}

class _ProfileImageStepState extends ConsumerState<ProfileImageStep> {
  File? _imageFile;
  bool _isLoading = false;
  String? _error;

  Future<void> _pickImage(ImageSource source) async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 1000,
        maxHeight: 1000,
        imageQuality: 85,
      );

      if (image != null) {
        final file = File(image.path);
        if (file.lengthSync() > 2 * 1024 * 1024) {
          // 2MB limit
          setState(() {
            _error = 'Image size must be less than 2MB';
          });
          return;
        }

        // Upload image to Firebase Storage
        final firebaseService = ref.read(firebaseServiceProvider);
        final imageUrl = await firebaseService.uploadProfileImage(file);

        setState(() {
          _imageFile = file;
        });
        ref.read(onboardingProvider.notifier).setProfileImage(imageUrl);
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to pick image. Please try again.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingTemplate(
      title: 'Profile Picture',
      currentStep: 5,
      totalSteps: 6,
      onNext: _imageFile != null ? widget.onNext : null,
      onBack: widget.onBack,
      onThemeToggle: () {
        ref.read(themeProvider.notifier).toggleTheme();
      },
      content: Stack(
        children: [
          Column(
            children: [
              const SizedBox(height: 32),

              // Image preview or placeholder
              GestureDetector(
                onTap:
                    _isLoading ? null : () => _showImageSourceDialog(context),
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context).colorScheme.surfaceVariant,
                    image: _imageFile != null
                        ? DecorationImage(
                            image: FileImage(_imageFile!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: _imageFile == null
                      ? Icon(
                          Icons.add_a_photo,
                          size: 48,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : null,
                ),
              ),

              const SizedBox(height: 24),

              // Error message
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

              const SizedBox(height: 24),

              // Requirements
              Text(
                'Requirements:',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              _buildRequirement(
                'Square image (1:1 ratio)',
                _imageFile != null,
              ),
              _buildRequirement(
                'Less than 2MB',
                _imageFile != null &&
                    _imageFile!.lengthSync() <= 2 * 1024 * 1024,
              ),
              _buildRequirement(
                'High quality (1000x1000)',
                _imageFile != null,
              ),
            ],
          ),

          // Loading overlay
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }

  void _showImageSourceDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Image Source'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildRequirement(String text, bool isMet) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.circle_outlined,
            size: 16,
            color: isMet
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: isMet
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }
}
