import 'package:flutter/material.dart';
import '../providers/theme_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class OnboardingTemplate extends ConsumerWidget {
  final String title;
  final int currentStep;
  final int totalSteps;
  final VoidCallback? onNext;
  final VoidCallback? onBack;
  final String? backButtonLabel;
  final VoidCallback? onThemeToggle;
  final Widget content;

  const OnboardingTemplate({
    super.key,
    required this.title,
    required this.currentStep,
    required this.totalSteps,
    this.onNext,
    this.onBack,
    this.backButtonLabel,
    this.onThemeToggle,
    required this.content,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back button
                  if (onBack != null)
                    TextButton(
                      onPressed: onBack,
                      child: Text(
                        backButtonLabel ?? 'Back',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 80),
                  // Theme toggle
                  IconButton(
                    onPressed: onThemeToggle,
                    icon: Icon(
                      isDark ? Icons.light_mode : Icons.dark_mode,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            // Progress bar
            LinearProgressIndicator(
              value: currentStep / totalSteps,
              backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                title,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                textAlign: TextAlign.center,
              ),
            ),
            // Content
            Expanded(child: content),
            // Next button
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: onNext,
                child: const Text('Next'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
