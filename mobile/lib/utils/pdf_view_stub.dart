import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

Widget buildPdfViewer(String url) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('PDF viewer is not available on this platform.', style: TextStyle(color: Colors.white)),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () async {
              final uri = Uri.tryParse(url);
              if (uri != null && await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            child: const Text('Open PDF'),
          ),
        ],
      ),
    ),
  );
}
