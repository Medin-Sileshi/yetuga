import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class VersionNagBanner extends StatefulWidget {
  const VersionNagBanner({super.key});

  @override
  State<VersionNagBanner> createState() => _VersionNagBannerState();
}

class _VersionNagBannerState extends State<VersionNagBanner> {
  bool _shouldShow = false;
  String? _updateUrl;

  @override
  void initState() {
    super.initState();
    _checkVersion();
  }

  Future<void> _checkVersion() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('version')
          .get();
      final data = doc.data();
      if (data == null) return;

      final latest = data['latest_version'] ?? '1.0.0';
      final updateUrl = data['update_url'] as String?;

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      if (_isVersionLower(currentVersion, latest)) {
        setState(() {
          _shouldShow = true;
          _updateUrl = updateUrl;
        });
      }
    } catch (e) {
      // Ignore errors, don't show banner
    }
  }

  bool _isVersionLower(String v1, String v2) {
    final v1Parts = v1.split('.').map(int.parse).toList();
    final v2Parts = v2.split('.').map(int.parse).toList();
    for (int i = 0; i < v1Parts.length; i++) {
      if (v1Parts[i] < v2Parts[i]) return true;
      if (v1Parts[i] > v2Parts[i]) return false;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (!_shouldShow) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orange),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'A new version of Yetuga is available. Please update for the best experience.',
              style: TextStyle(color: Colors.black87),
            ),
          ),
          if (_updateUrl != null)
            TextButton(
              onPressed: () async {
                final url = Uri.parse(_updateUrl!);
                if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
                  throw Exception('Could not launch $url');
                }
              },
              child: const Text('Update'),
            ),
        ],
      ),
    );
  }
}
