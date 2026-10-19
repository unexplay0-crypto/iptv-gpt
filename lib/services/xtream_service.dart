import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/app_constants.dart';
import '../models/iptv_account.dart';
import '../models/media_item.dart';

class XtreamCatalog {
  const XtreamCatalog({required this.live, required this.movies, required this.series});
  final List<MediaItem> live;
  final List<MediaItem> movies;
  final List<MediaItem> series;
  List<MediaItem> get all => [...live, ...movies, ...series];
}

class XtreamService {
  XtreamService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  static Uri normalizeServer(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null || uri.host.isEmpty || !{'http', 'https'}.contains(uri.scheme.toLowerCase())) {
      throw const XtreamException('Endereço do servidor inválido. Use uma URL HTTP ou HTTPS.');
    }
    final normalizedPath = uri.path.replaceFirst(RegExp(r'/+$'), '');
    return uri.replace(userInfo: '', path: normalizedPath, query: null, fragment: null);
  }

  static Uri buildApiUri(IptvAccount account, {String? action, Map<String, String> extra = const {}}) {
    final base = normalizeServer(account.serverUrl);
    final prefix = base.path.replaceFirst(RegExp(r'/+$'), '');
    final query = <String, String>{
      'username': account.username,
      'password': account.password,
      if (action != null && action.isNotEmpty) 'action': action,
      ...extra,
    };
    return base.replace(path: '$prefix/player_api.php', queryParameters: query);
  }

  static Uri buildStreamUri(
    IptvAccount account, {
    required String kind,
    required String id,
    String extension = 'ts',
  }) {
    final base = normalizeServer(account.serverUrl);
    final prefix = base.pathSegments.where((segment) => segment.isNotEmpty).toList();
    final safeKind = {'live', 'movie', 'series'}.contains(kind) ? kind : 'live';
    final safeExtension = RegExp(r'^[a-zA-Z0-9]{1,8}$').hasMatch(extension) ? extension : 'ts';
    final user = account.username;
    final password = account.password;
    final filename = '$id.$safeExtension';
    return base.replace(pathSegments: [
      ...prefix,
      safeKind,
      user,
      password,
      filename,
    ]);
  }

  Future<Map<String, dynamic>> authenticate(IptvAccount account) async {
    final json = await _getJson(buildApiUri(account));
    if (json is! Map<String, dynamic>) {
      throw const XtreamException('O servidor retornou uma resposta de login inválida.');
    }
    final userInfo = json['user_info'];
    if (userInfo is Map) {
      final auth = userInfo['auth']?.toString();
      if (auth == '0') throw const XtreamException('Usuário e senha não foram aceitos pelo servidor.');
      final status = userInfo['status']?.toString().toLowerCase();
      if (status != null && {'disabled', 'banned', 'expired', 'inactive'}.contains(status)) {
        throw XtreamException('A conta está com status "$status" no servidor.');
      }
    }
    return json;
  }

  Future<XtreamCatalog> fetchCatalog(IptvAccount account) async {
    final categoryResponses = await Future.wait<Object?>([
      _tryAction(account, 'get_live_categories'),
      _tryAction(account, 'get_vod_categories'),
      _tryAction(account, 'get_series_categories'),
    ]);
    final liveCategories = _categoryMap(categoryResponses[0]);
    final movieCategories = _categoryMap(categoryResponses[1]);
    final seriesCategories = _categoryMap(categoryResponses[2]);

    final responses = await Future.wait<Object?>([
      _tryAction(account, 'get_live_streams'),
      _tryAction(account, 'get_vod_streams'),
      _tryAction(account, 'get_series'),
    ]);
    if (responses.every((response) => response == null)) {
      throw const XtreamException(
        'Não foi possível carregar canais, filmes ou séries. O servidor pode não suportar os endpoints Xtream ou estar indisponível.',
      );
    }
    return XtreamCatalog(
      live: _itemsFromXtream(responses[0], account, MediaType.live, liveCategories),
      movies: _itemsFromXtream(responses[1], account, MediaType.movie, movieCategories),
      series: _itemsFromXtream(responses[2], account, MediaType.series, seriesCategories),
    );
  }

  Future<List<MediaItem>> getSeriesEpisodes(IptvAccount account, String seriesId) async {
    final response = await _getJson(buildApiUri(account, action: 'get_series_info', extra: {'series_id': seriesId}));
    if (response is! Map) return const [];
    final episodesNode = response['episodes'];
    if (episodesNode is! Map) return const [];
    final episodes = <MediaItem>[];
    for (final entry in episodesNode.entries) {
      final season = int.tryParse(entry.key.toString()) ?? 0;
      final list = entry.value;
      if (list is! List) continue;
      for (final raw in list) {
        if (raw is! Map) continue;
        final id = raw['id']?.toString() ?? '';
        if (id.isEmpty) continue;
        final extension = _extension(raw['container_extension']?.toString() ?? 'mp4', fallback: 'mp4');
        final info = raw['info'] is Map ? raw['info'] as Map : const {};
        final title = raw['title']?.toString() ?? raw['name']?.toString() ?? 'Episódio';
        episodes.add(MediaItem(
          id: MediaItem.stableId(account.providerKey, 'episode', '$seriesId:$id'),
          title: title,
          type: MediaType.episode,
          streamUrl: buildStreamUri(account, kind: 'series', id: id, extension: extension).toString(),
          groupTitle: 'Temporada $season',
          posterUrl: info['movie_image']?.toString() ?? info['cover_big']?.toString() ?? '',
          description: info['plot']?.toString() ?? '',
          year: info['releasedate']?.toString() ?? '',
          duration: info['duration']?.toString() ?? '',
          streamId: id,
          seriesId: seriesId,
          seasonNumber: season,
          episodeNumber: int.tryParse(raw['episode_num']?.toString() ?? '') ?? 0,
          containerExtension: extension,
          isAdult: MediaItem.inferAdult(title),
        ));
      }
    }
    episodes.sort((a, b) {
      final seasonCompare = a.seasonNumber.compareTo(b.seasonNumber);
      return seasonCompare != 0 ? seasonCompare : a.episodeNumber.compareTo(b.episodeNumber);
    });
    return episodes;
  }

  Future<List<Map<String, dynamic>>> getShortEpg(IptvAccount account, String streamId, {int limit = 10}) async {
    final uri = buildApiUri(account, extra: {'stream_id': streamId, 'limit': '$limit'});
    final target = uri.replace(path: '${uri.path.substring(0, uri.path.lastIndexOf('/') + 1)}get_short_epg.php');
    final response = await _getJson(target);
    if (response is List) {
      return response.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    if (response is Map && response['epg_listings'] is List) {
      return (response['epg_listings'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return const [];
  }

  Map<String, String> _categoryMap(Object? raw) {
    final categories = <String, String>{};
    if (raw is List) {
      for (final entry in raw.whereType<Map>()) {
        final id = entry['category_id']?.toString();
        final name = entry['category_name']?.toString();
        if (id != null && name != null && name.isNotEmpty) categories[id] = name;
      }
    }
    return categories;
  }

  List<MediaItem> _itemsFromXtream(
    Object? raw,
    IptvAccount account,
    MediaType type,
    Map<String, String> categories,
  ) {
    if (raw is! List) return const [];
    final result = <MediaItem>[];
    for (final entry in raw.whereType<Map>()) {
      final id = entry['stream_id']?.toString() ?? entry['series_id']?.toString() ?? entry['id']?.toString() ?? '';
      if (id.isEmpty) continue;
      final title = entry['name']?.toString() ?? entry['title']?.toString() ?? 'Sem título';
      final categoryId = entry['category_id']?.toString() ?? '';
      final group = categories[categoryId] ?? entry['category_name']?.toString() ?? 'Geral';
      final extension = _extension(entry['container_extension']?.toString() ?? 'mp4', fallback: 'mp4');
      var url = '';
      if (type == MediaType.live) {
        url = buildStreamUri(account, kind: 'live', id: id, extension: _extension(entry['container_extension']?.toString() ?? 'ts', fallback: 'ts')).toString();
      } else if (type == MediaType.movie) {
        url = buildStreamUri(account, kind: 'movie', id: id, extension: extension).toString();
      }
      final info = entry['info'] is Map ? entry['info'] as Map : const {};
      final adult = MediaItem.inferAdult('$group $title');
      result.add(MediaItem(
        id: MediaItem.stableId(account.providerKey, type.name, id),
        title: title,
        type: type,
        streamUrl: url,
        groupTitle: group,
        posterUrl: type == MediaType.series
            ? entry['cover']?.toString() ?? ''
            : entry['stream_icon']?.toString() ?? entry['cover']?.toString() ?? '',
        backdropUrl: info['backdrop_path'] is List && (info['backdrop_path'] as List).isNotEmpty
            ? (info['backdrop_path'] as List).first.toString()
            : '',
        description: info['plot']?.toString() ?? info['description']?.toString() ?? '',
        year: info['releasedate']?.toString() ?? info['releaseDate']?.toString() ?? info['year']?.toString() ?? '',
        duration: info['duration']?.toString() ?? '',
        streamId: id,
        seriesId: type == MediaType.series ? id : '',
        containerExtension: extension,
        isAdult: adult,
      ));
    }
    return result;
  }

  Future<Object?> _tryAction(IptvAccount account, String action) async {
    try {
      return await _getJson(buildApiUri(account, action: action));
    } on Exception {
      return null;
    }
  }

  Future<Object?> _getJson(Uri uri) async {
    late final http.Response response;
    try {
      response = await _client.get(uri, headers: const {'Accept': 'application/json'}).timeout(AppConstants.requestTimeout);
    } on TimeoutException {
      throw const XtreamException('O servidor demorou demais para responder.');
    } on Exception {
      throw const XtreamException('Não foi possível conectar ao servidor IPTV. Confira o endereço e a rede.');
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const XtreamException('O servidor recusou o acesso (HTTP 401/403). Confira a conta e as permissões.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw XtreamException('O servidor respondeu com HTTP ${response.statusCode}.');
    }
    try {
      return jsonDecode(utf8.decode(response.bodyBytes, allowMalformed: true));
    } on FormatException {
      throw const XtreamException('O servidor não retornou JSON válido. Confira o endereço informado.');
    }
  }

  String _extension(String value, {required String fallback}) {
    final extension = value.trim().replaceFirst(RegExp(r'^\.'), '');
    return RegExp(r'^[a-zA-Z0-9]{1,8}$').hasMatch(extension) ? extension : fallback;
  }

  void dispose() => _client.close();
}

class XtreamException implements Exception {
  const XtreamException(this.message);
  final String message;
  @override
  String toString() => message;
}
