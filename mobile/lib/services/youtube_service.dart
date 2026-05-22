import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class YoutubeService {
  // Clé API YouTube Data v3 — à remplacer par votre clé
  static const String _apiKey = 'AIzaSyAMTlw9-KGixs8kztuYBLpaxwHSVEERB34';
  static const String _baseUrl = 'https://www.googleapis.com/youtube/v3/search';

  /// Recherche des vidéos YouTube selon une requête.
  /// Retourne une liste de maps : {videoId, title, thumbnail, channelTitle}
  static Future<List<Map<String, String>>> search(String query, {int maxResults = 4}) async {
    try {
      final uri = Uri.parse(_baseUrl).replace(queryParameters: {
        'part':       'snippet',
        'q':          query,
        'type':       'video',
        'maxResults': '$maxResults',
        'relevanceLanguage': 'fr',
        'key':        _apiKey,
      });

      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return [];

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final items = (data['items'] as List?) ?? [];

      return items.map((item) {
        final snippet = item['snippet'] as Map<String, dynamic>;
        final videoId = item['id']?['videoId'] as String? ?? '';
        return {
          'videoId':      videoId,
          'title':        snippet['title']        as String? ?? '',
          'thumbnail':    (snippet['thumbnails']?['medium']?['url'] ?? snippet['thumbnails']?['default']?['url'] ?? '') as String,
          'channelTitle': snippet['channelTitle'] as String? ?? '',
          'url':          'https://www.youtube.com/watch?v=$videoId',
        };
      }).where((v) => v['videoId']!.isNotEmpty).toList();
    } catch (e) {
      debugPrint('YoutubeService.search error: $e');
      return [];
    }
  }

  /// Construit la requête de recherche à partir du titre du tutoriel et du type de tâche.
  static String buildQuery(String tutorialTitle, String taskType) {
    const typeKeywords = {
      'installation':  'GPS tracker installation',
      'maintenance':   'GPS tracker maintenance',
      'diagnostic':    'GPS tracker diagnostic SMS',
      'configuration': 'GPS tracker configuration APN',
      'remplacement':  'GPS tracker remplacement',
    };
    final base = typeKeywords[taskType] ?? 'GPS tracker';
    return '$tutorialTitle $base';
  }
}
