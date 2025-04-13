import 'package:flutter/material.dart';
import '../providers/theme_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class OnboardingTemplate extends ConsumerWidget {
  final String title;
  final int currentStep;
  final int totalSteps;
  final VoidCallback? onNext;
  final VoidCallback? onBack;
  final VoidCallback? onLogout;
  final VoidCallback? onThemeToggle;
  final Widget content;
  final bool isNextEnabled;

  const OnboardingTemplate({
    super.key,
    required this.title,
    required this.currentStep,
    required this.totalSteps,
    this.onNext,
    this.onBack,
    this.onLogout,
    this.onThemeToggle,
    required this.content,
    this.isNextEnabled = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Progress bar
            LinearProgressIndicator(
              value: currentStep / totalSteps,
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back/Logout button
                  if (currentStep == 1)
                    IconButton(
                      key: const Key('template_logout_button'),
                      onPressed: onLogout,
                      icon: const Icon(Icons.logout),
                      tooltip: 'Logout',
                    )
                  else if (onBack != null)
                    IconButton(
                      key: const Key('template_back_button'),
                      onPressed: onBack,
                      icon: const Icon(Icons.arrow_back),
                      tooltip: 'Back',
                    )
                  else
                    const SizedBox(width: 48),
                  // Theme toggle
                  IconButton(
                    key: const Key('template_theme_toggle'),
                    onPressed: onThemeToggle,
                    icon: Icon(
                      isDark ? Icons.light_mode : Icons.dark_mode,
                    ),
                  ),
                ],
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                title,
                style: Theme.of(context).textTheme.headlineLarge,
                textAlign: TextAlign.center,
              ),
            ),
            // Content
            Expanded(
              child: SingleChildScrollView(
                key: const Key('template_content_scroll_view'),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: content,
                ),
              ),
            ),
            // Next button
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                key: const Key('template_next_button'),
                onPressed: isNextEnabled ? onNext : null,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
                child: Text(
                  currentStep == totalSteps ? 'Finish' : 'Next',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
