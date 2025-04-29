import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/theme_provider.dart';
import '../test/test_menu_screen.dart';

class ThemeSettingsScreen extends ConsumerWidget {
  const ThemeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentThemeMode = ref.watch(themeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Theme Settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Choose Theme',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            RadioListTile<ThemeMode>(
              title: const Text('System Theme'),
              subtitle: const Text('Follow system theme settings'),
              value: ThemeMode.system,
              groupValue: currentThemeMode,
              onChanged: (ThemeMode? value) {
                if (value != null) {
                  ref.read(themeProvider.notifier).useSystemTheme();
                }
              },
            ),
            RadioListTile<ThemeMode>(
              title: const Text('Light Theme'),
              value: ThemeMode.light,
              groupValue: currentThemeMode,
              onChanged: (ThemeMode? value) {
                if (value != null && currentThemeMode != ThemeMode.light) {
                  // If coming from system theme, we need to toggle twice
                  if (currentThemeMode == ThemeMode.system) {
                    ref.read(themeProvider.notifier).toggleTheme();
                  } else if (currentThemeMode == ThemeMode.dark) {
                    ref.read(themeProvider.notifier).toggleTheme();
                  }
                }
              },
            ),
            RadioListTile<ThemeMode>(
              title: const Text('Dark Theme'),
              value: ThemeMode.dark,
              groupValue: currentThemeMode,
              onChanged: (ThemeMode? value) {
                if (value != null && currentThemeMode != ThemeMode.dark) {
                  // If coming from system theme, toggle once to light, then again to dark
                  if (currentThemeMode == ThemeMode.system) {
                    ref.read(themeProvider.notifier).toggleTheme(); // To light
                    ref.read(themeProvider.notifier).toggleTheme(); // To dark
                  } else if (currentThemeMode == ThemeMode.light) {
                    ref.read(themeProvider.notifier).toggleTheme();
                  }
                }
              },
            ),
            const SizedBox(height: 24),
            const Text(
              'Note: System theme will follow your device\'s dark/light mode settings.',
              style: TextStyle(
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            ),

            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),

            // Developer options section
            const Text(
              'Developer Options',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Optimization Tests'),
              subtitle: const Text('Test caching, prefetching, and retry mechanisms'),
              leading: const Icon(Icons.developer_mode),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const TestMenuScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
