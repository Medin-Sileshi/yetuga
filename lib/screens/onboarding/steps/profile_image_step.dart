import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import '../../../providers/onboarding_form_provider.dart';
import '../../../providers/business_onboarding_form_provider.dart';
import '../../../providers/firebase_provider.dart';

class ProfileImageStep extends ConsumerStatefulWidget {
  final VoidCallback onNext;
  final ValueChanged<bool> onValidityChanged;

  const ProfileImageStep({
    super.key,
    required this.onNext,
    required this.onValidityChanged,
  });

  @override
  ConsumerState<ProfileImageStep> createState() => _ProfileImageStepState();
}

class _ProfileImageStepState extends ConsumerState<ProfileImageStep> {
  final _imagePicker = ImagePicker();
  File? _imageFile;
  bool _isUploading = false;
  String? _errorMessage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Initialize validity to false
    widget.onValidityChanged(false);
    // Load saved image after the widget is fully built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSavedImage();
    });
  }

  Future<void> _loadSavedImage() async {
    try {
      final formData = ref.read(onboardingFormProvider);
      final savedImageUrl = formData.profileImageUrl;

      if (savedImageUrl != null && savedImageUrl.isNotEmpty) {
        setState(() {
          _isLoading = true;
        });

        // We don't actually load the image here as it would require downloading
        // Instead, we just mark that an image was previously selected
        setState(() {
          _isLoading = false;
        });

        // Notify parent after state is updated
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            widget.onValidityChanged(true);
          }
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load saved image: ${e.toString()}';
        _isLoading = false;
      });

      // Notify parent after state is updated
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.onValidityChanged(false);
        }
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        try {
          final croppedFile = await ImageCropper().cropImage(
            sourcePath: pickedFile.path,
            aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
            uiSettings: [
              AndroidUiSettings(
                toolbarTitle: 'Crop Profile Image',
                toolbarColor: Colors.blue, // Use a fixed color to avoid BuildContext issues
                toolbarWidgetColor: Colors.white,
                initAspectRatio: CropAspectRatioPreset.square,
                lockAspectRatio: true,
                hideBottomControls: false,
                showCropGrid: true,
              ),
              IOSUiSettings(
                title: 'Crop Profile Image',
                aspectRatioLockEnabled: true,
              ),
            ],
          );

          if (croppedFile != null) {
            setState(() {
              _imageFile = File(croppedFile.path);
              _errorMessage = null;
              _isLoading = false;

            });

            // Upload the image immediately
            _uploadImage();

            // Notify parent after state is updated
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                widget.onValidityChanged(true);
              }
            });
          } else {
            setState(() {
              _isLoading = false;
            });
          }
        } catch (e) {
          // If cropping fails, use the original image
          setState(() {
            _imageFile = File(pickedFile.path);
            _errorMessage = null;
            _isLoading = false;

          });

          // Upload the image immediately
          _uploadImage();

          // Notify parent after state is updated
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              widget.onValidityChanged(true);
            }
          });
        }
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to pick image: ${e.toString()}';
        _isLoading = false;

      });

      // Notify parent after state is updated
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.onValidityChanged(false);
        }
      });
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                key: const Key('take_photo_option'),
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                key: const Key('choose_photo_option'),
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _uploadImage() async {
    if (_imageFile == null) return;

    setState(() {
      _isUploading = true;
      _errorMessage = null;
    });

    try {
      final firebaseService = ref.read(firebaseServiceProvider);
      final imageUrl = await firebaseService.uploadProfileImage(_imageFile!);

      setState(() {
        _isUploading = false;
      });

      // Save to the appropriate form provider based on account type
      final formData = ref.read(onboardingFormProvider);
      final isBusiness = formData.accountType == 'business';

      // Save to personal form provider
      ref.read(onboardingFormProvider.notifier).setProfileImage(imageUrl);

      // Also save to business form provider if this is a business account
      if (isBusiness) {
        ref.read(businessOnboardingFormProvider.notifier).setProfileImage(imageUrl);
      }

      // Notify parent that the image is valid
      widget.onValidityChanged(true);
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to upload image: ${e.toString()}';
        _isUploading = false;

      });

      // Notify parent that the image is not valid
      widget.onValidityChanged(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (_isLoading)
          const Center(
            key: Key('loading_indicator'),
            child: CircularProgressIndicator(),
          )
        else
          _buildImageSelector(colorScheme),
        if (_errorMessage != null) ...[
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            key: const Key('error_message'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.error,
            ),
            textAlign: TextAlign.center,
          ),
        ],
        if (_isUploading) ...[
          const SizedBox(height: 16),
          const Center(
            child: CircularProgressIndicator(),
          ),
        ],
      ],
    );
  }

  Widget _buildImageSelector(ColorScheme colorScheme) {
    // Check if this is a business account
    final formData = ref.read(onboardingFormProvider);
    final isBusiness = formData.accountType == 'business';

    // Define border color based on account type
    final borderColor = isBusiness
        ? const Color(0xFFFFD700) // Gold color for business accounts
        : _imageFile != null
            ? colorScheme.primary
            : colorScheme.outline;

    // Define border width based on account type
    final borderWidth = isBusiness ? 3.0 : 2.0;

    return GestureDetector(
      key: const Key('image_selector'),
      onTap: _showImageSourceDialog,
      child: Container(
        width: 200,
        height: 200,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _imageFile == null ? colorScheme.surfaceContainerHighest : null,
          image: _imageFile != null
              ? DecorationImage(
                  image: FileImage(_imageFile!),
                  fit: BoxFit.cover,
                )
              : null,
          border: Border.all(
            color: borderColor,
            width: borderWidth,
          ),
          // Add a subtle shadow for business accounts
          boxShadow: isBusiness
              ? const [
                  BoxShadow(
                    color: Color.fromRGBO(255, 215, 0, 0.5), // Gold color with 0.5 opacity
                    blurRadius: 10,
                    spreadRadius: 2,
                  )
                ]
              : null,
        ),
        child: _imageFile == null
            ? Icon(
                Icons.add_a_photo,
                size: 48,
                color: isBusiness ? Colors.white : colorScheme.primary,
              )
            : Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withAlpha(128), // 0.5 opacity
                    ),
                  ),
                  Icon(
                    Icons.edit,
                    size: 48,
                    color: isBusiness ? Colors.white : Colors.white,
                  ),
                ],
              ),
      ),
    );
  }
}
