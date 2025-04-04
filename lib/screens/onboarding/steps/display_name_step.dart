import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/onboarding_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../widgets/onboarding_template.dart';

class DisplayNameStep extends ConsumerStatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;

  const DisplayNameStep({
    super.key,
    required this.onNext,
    required this.onBack,
  });

  @override
  ConsumerState<DisplayNameStep> createState() => _DisplayNameStepState();
}

class _DisplayNameStepState extends ConsumerState<DisplayNameStep> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  String? _username;
  String? _error;

  String _generateUsername(String displayName) {
    return displayName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '')
        .substring(0, displayName.length.clamp(0, 15));
  }

  void _validateAndUpdate() {
    if (_formKey.currentState?.validate() ?? false) {
      final displayName = _displayNameController.text.trim();
      final username = _generateUsername(displayName);
      setState(() {
        _username = username;
        _error = null;
      });
      ref
          .read(onboardingProvider.notifier)
          .setDisplayName(displayName, username);
    }
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingTemplate(
      title: 'Your Display Name',
      currentStep: 2,
      totalSteps: 6,
      onNext: _username != null ? widget.onNext : null,
      onBack: widget.onBack,
      onThemeToggle: () {
        ref.read(themeProvider.notifier).toggleTheme();
      },
      content: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Display name field
            TextFormField(
              controller: _displayNameController,
              decoration: InputDecoration(
                labelText: 'Display Name',
                border: const UnderlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
                alignLabelWithHint: true,
              ),
              textAlign: TextAlign.center,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your display name';
                }
                if (value.length < 2) {
                  return 'Display name must be at least 2 characters';
                }
                return null;
              },
              onChanged: (value) {
                if (_formKey.currentState?.validate() ?? false) {
                  _validateAndUpdate();
                }
              },
            ),

            const SizedBox(height: 24),

            // Username preview
            if (_username != null) ...[
              Text(
                'Your username will be:',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '@$_username',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Requirements
            Text(
              'Requirements:',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            _buildRequirement(
              'At least 2 characters long',
              _displayNameController.text.length >= 2,
            ),
            _buildRequirement(
              'No special characters',
              !_displayNameController.text.contains(RegExp(r'[^a-zA-Z0-9\s]')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequirement(String text, bool isMet) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.circle_outlined,
            size: 16,
            color:
                isMet
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color:
                  isMet
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }
}
