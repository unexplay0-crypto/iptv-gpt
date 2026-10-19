import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class TmdbMetadata {
  const TmdbMetadata({this.posterUrl = '', this.backdropUrl = '', this.overview = '', this.releaseDate = '', this.rating = ''});
  final String posterUrl;
  final String backdropUrl;
  final String overview;
  final String releaseDate;
  final String rating;
}

/// Optional metadata enrichment. The TMDb key is supplied by the user and stored
/// in secure storage; the app ships with no embedded API key.
class MetadataService {
  MetadataService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  Future<TmdbMetadata?> search({required String apiKey, required String title, required bool isSeries}) async {
    if (apiKey.trim().isEmpty || title.trim().isEmpty) return null;
    final endpoint = isSeries ? 'tv' : 'movie';
    final uri = Uri.https('api.themoviedb.org', '/3/search/$endpoint', {
      'api_key': apiKey.trim(),
      'query': title.trim(),
      'include_adult': 'false',
    });
    late final http.Response response;
    try {
      response = await _client.get(uri).timeout(const Duration(seconds: 12));
    } on TimeoutException {
      return null;
    } on Exception {
      return null;
    }
    if (response.statusCode != 200) return null;
    try {
      final json = jsonDecode(utf8.decode(response.bodyBytes));
      if (json is! Map || json['results'] is! List || (json['results'] as List).isEmpty) return null;
      final first = (json['results'] as List).first;
      if (first is! Map) return null;
      String image(String field) {
        final path = first[field]?.toString() ?? '';
        return path.isEmpty ? '' : 'https://image.tmdb.org/t/p/w780$path';
      }
      return TmdbMetadata(
        posterUrl: image('poster_path'),
        backdropUrl: image('backdrop_path'),
        overview: first['overview']?.toString() ?? '',
        releaseDate: first[isSeries ? 'first_air_date' : 'release_date']?.toString() ?? '',
        rating: first['vote_average']?.toString() ?? '',
      );
    } on FormatException {
      return null;
    }
  }

  void dispose() => _client.close();
}
