import 'package:flutter/material.dart';
import 'package:yetuga/utils/logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';

class AuthPageTemplate extends ConsumerWidget {
  final String title;
  final Widget body;
  final List<Widget> bottomButtons;
  final bool showBackButton;
  final VoidCallback? onBackPressed;

  const AuthPageTemplate({
    super.key,
    required this.title,
    required this.body,
    this.bottomButtons = const [],
    this.showBackButton = false,
    this.onBackPressed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(
        leading:
            showBackButton
                ? IconButton(
                  icon: Icon(
                    Icons.arrow_back,
                    color: isDark ? AppColors.white : AppColors.primary,
                  ),
                  onPressed: onBackPressed ?? () => Navigator.pop(context),
                )
                : null,
        actions: [
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode : Icons.dark_mode,
              color: isDark ? AppColors.white : AppColors.primary,
            ),
            onPressed: () => ref.read(themeProvider.notifier).toggleTheme(),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                  minWidth: constraints.maxWidth,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        children: [
                          const SizedBox(height: 32),
                          // Logo
                          Image.asset(
                            isDark
                                ? 'assets/dark/logo_light.png'
                                : 'assets/light/logo_dark.png',
                            height: 60,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(height: 48),
                          // Title
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineLarge,
                          ),
                          const SizedBox(height: 60),
                          // Body
                          body,
                        ],
                      ),
                      // Bottom Buttons
                      if (bottomButtons.isNotEmpty) ...[
                        const SizedBox(height: 32),
                        ...bottomButtons,
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
