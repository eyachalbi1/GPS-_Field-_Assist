import 'package:flutter/material.dart';
import 'dart:html' as html; // web-only

Widget buildPdfViewer(String url) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Afficher le PDF dans un nouvel onglet', style: TextStyle(color: Colors.white)),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () {
              html.window.open(url, '_blank');
            },
            child: const Text('Ouvrir le PDF'),
          ),
        ],
      ),
    ),
  );
}
