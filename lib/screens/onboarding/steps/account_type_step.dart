import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/onboarding_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../widgets/onboarding_template.dart';

class AccountTypeStep extends ConsumerStatefulWidget {
  final VoidCallback onNext;

  const AccountTypeStep({super.key, required this.onNext});

  @override
  ConsumerState<AccountTypeStep> createState() => _AccountTypeStepState();
}

class _AccountTypeStepState extends ConsumerState<AccountTypeStep> {
  String? selectedType;
  String? description;

  void _selectAccountType(String type) {
    setState(() {
      selectedType = type;
      description = type == 'personal'
          ? 'Free account for adventurous individuals'
          : 'A paid account with features tailor-made for Businesses';
    });
    ref.read(onboardingProvider.notifier).setAccountType(type);
  }

  Future<void> _handleSignOut() async {
    try {
      await ref.read(authProvider.notifier).signOut();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error signing out: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingTemplate(
      title: 'Choose Account Type',
      currentStep: 1,
      totalSteps: 6,
      onNext: selectedType != null ? widget.onNext : null,
      onBack: _handleSignOut,
      backButtonLabel: 'Sign Out',
      onThemeToggle: () {
        ref.read(themeProvider.notifier).toggleTheme();
      },
      content: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 80),

          // Account type buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildAccountTypeButton('Personal', 'personal', context),
              _buildAccountTypeButton('Business', 'business', context),
            ],
          ),

          // Animated description
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: description != null
                ? Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Text(
                      description!,
                      key: ValueKey(description),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontSize: 16,
                          ),
                    ),
                  )
                : const SizedBox(height: 96),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountTypeButton(
    String label,
    String type,
    BuildContext context,
  ) {
    final isSelected = selectedType == type;

    return TextButton(
      onPressed: () => _selectAccountType(type),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        backgroundColor: isSelected
            ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
            : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.primary.withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontSize: 18,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    );
  }
}
