import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:iptv/app_core.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xml/xml.dart';

// ---- Merged from services/local_library_store.dart ----

class LocalLibraryStore {
  LocalLibraryStore() : _preferences = SharedPreferencesAsync();
  final SharedPreferencesAsync _preferences;

  String _key(String provider, String feature) => 'unex.v1.$provider.$feature';

  Future<Set<String>> readFavorites(String provider) async =>
      (await _preferences.getStringList(_key(provider, 'favorites')) ?? const <String>[]).toSet();

  Future<void> writeFavorites(String provider, Set<String> favorites) =>
      _preferences.setStringList(_key(provider, 'favorites'), favorites.toList());

  Future<List<MediaItem>> readHistory(String provider) async {
    final raw = await _preferences.getStringList(_key(provider, 'history')) ?? const <String>[];
    final items = <MediaItem>[];
    for (final value in raw) {
      try {
        final json = jsonDecode(value);
        if (json is Map<String, dynamic>) items.add(MediaItem.fromJson(json));
      } on FormatException {
        // Skip only the damaged entry; preserve all other history records.
      }
    }
    return items;
  }

  Future<void> writeHistory(String provider, List<MediaItem> history) => _preferences.setStringList(
        _key(provider, 'history'),
        history.take(AppConstants.maxHistoryItems).map((item) => jsonEncode(item.toJson())).toList(),
      );

  Future<Map<String, int>> readProgress(String provider) async {
    final raw = await _preferences.getString(_key(provider, 'progress'));
    if (raw == null) return {};
    try {
      final json = jsonDecode(raw);
      if (json is! Map) return {};
      return json.map((key, value) => MapEntry(key.toString(), int.tryParse(value.toString()) ?? 0));
    } on FormatException {
      return {};
    }
  }

  Future<void> writeProgress(String provider, Map<String, int> progress) =>
      _preferences.setString(_key(provider, 'progress'), jsonEncode(progress));

  Future<bool> readAdultVisibility(String provider) async =>
      await _preferences.getBool(_key(provider, 'show_adult')) ?? false;

  Future<void> writeAdultVisibility(String provider, bool show) =>
      _preferences.setBool(_key(provider, 'show_adult'), show);

  Future<String> readPinSalt(String provider) async => await _preferences.getString(_key(provider, 'pin_salt')) ?? '';
  Future<String> readPinHash(String provider) async => await _preferences.getString(_key(provider, 'pin_hash')) ?? '';

  static const _pinIterations = 60000;

  Future<void> setPin(String provider, String pin) async {
    final salt = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    final saltText = base64Url.encode(salt);
    final derived = _derivePin(pin, salt, _pinIterations);
    final encodedHash = 'pbkdf2-sha256:$_pinIterations:${base64Url.encode(derived)}';
    await _preferences.setString(_key(provider, 'pin_salt'), saltText);
    await _preferences.setString(_key(provider, 'pin_hash'), encodedHash);
  }

  List<int> _derivePin(String pin, List<int> salt, int iterations) {
    final passwordBytes = utf8.encode(pin);
    final hmac = Hmac(sha256, passwordBytes);
    var block = hmac.convert([...salt, 0, 0, 0, 1]).bytes;
    final derived = List<int>.from(block);
    for (var iteration = 1; iteration < iterations; iteration++) {
      block = hmac.convert(block).bytes;
      for (var index = 0; index < derived.length; index++) {
        derived[index] ^= block[index];
      }
    }
    return derived;
  }

  Future<bool> hasPin(String provider) async => (await readPinHash(provider)).isNotEmpty;

  Future<bool> verifyPin(String provider, String pin) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final lockUntil = await _preferences.getInt(_key(provider, 'pin_lock_until')) ?? 0;
    if (lockUntil > now) return false;

    final saltText = await readPinSalt(provider);
    final expected = await readPinHash(provider);
    if (saltText.isEmpty || expected.isEmpty) return false;
    late final List<int> salt;
    try {
      salt = base64Url.decode(saltText);
    } on FormatException {
      return false;
    }
    var matches = false;
    if (expected.startsWith('pbkdf2-sha256:')) {
      final parts = expected.split(':');
      if (parts.length == 3) {
        final iterations = int.tryParse(parts[1]);
        if (iterations != null && iterations >= 10000 && iterations <= 200000) {
          final actual = base64Url.encode(_derivePin(pin, salt, iterations));
          matches = constantTimeEquals(actual, parts[2]);
        }
      }
    } else {
      // Backward compatibility: verify old SHA-256 PINs and upgrade on success.
      final legacy = sha256.convert(utf8.encode('$saltText:$pin')).toString();
      if (constantTimeEquals(legacy, expected)) {
        matches = true;
        await setPin(provider, pin);
      }
    }
    if (matches) {
      await _preferences.remove(_key(provider, 'pin_attempts'));
      await _preferences.remove(_key(provider, 'pin_lock_until'));
      return true;
    }

    final attempts = (await _preferences.getInt(_key(provider, 'pin_attempts')) ?? 0) + 1;
    if (attempts >= 5) {
      await _preferences.setInt(
        _key(provider, 'pin_lock_until'),
        now + const Duration(minutes: 1).inMilliseconds,
      );
      await _preferences.remove(_key(provider, 'pin_attempts'));
    } else {
      await _preferences.setInt(_key(provider, 'pin_attempts'), attempts);
    }
    return false;
  }

  @visibleForTesting
  static bool constantTimeEquals(String left, String right) {
    if (left.length != right.length) return false;
    var diff = 0;
    for (var i = 0; i < left.length; i++) {
      diff |= left.codeUnitAt(i) ^ right.codeUnitAt(i);
    }
    return diff == 0;
  }
}

// ---- Merged from services/m3u_parser.dart ----

class M3uParser {
  const M3uParser();

  List<MediaItem> parse(String content, {required String providerKey}) {
    final lines = const LineSplitter().convert(content.replaceFirst('\uFEFF', ''));
    final result = <MediaItem>[];
    String? extinf;
    String group = 'Geral';
    String tvgId = '';
    String logo = '';
    final headers = <String, String>{};

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      if (line.startsWith('#EXTINF')) {
        extinf = line;
        group = _attribute(line, 'group-title') ?? 'Geral';
        tvgId = _attribute(line, 'tvg-id') ?? '';
        logo = _attribute(line, 'tvg-logo') ?? '';
        headers.clear();
        continue;
      }
      if (line.startsWith('#EXTVLCOPT:')) {
        final option = line.substring('#EXTVLCOPT:'.length);
        final separator = option.indexOf('=');
        if (separator > 0) {
          final name = option.substring(0, separator).trim().toLowerCase();
          final value = option.substring(separator + 1).trim();
          if (name == 'http-user-agent' && value.isNotEmpty) {
            headers['User-Agent'] = value;
          } else if ((name == 'http-referrer' || name == 'http-referer') && value.isNotEmpty) {
            headers['Referer'] = value;
          }
        }
        continue;
      }
      if (line.startsWith('#')) continue;
      if (extinf == null) continue;

      final title = _titleFromExtinf(extinf).trim().isEmpty
          ? line.split('/').last
          : _titleFromExtinf(extinf).trim();
      final inferred = _inferType(group, title, extinf);
      final canonical = '$providerKey|${inferred.name}|$tvgId|$title|$line';
      final id = sha256.convert(utf8.encode(canonical)).toString().substring(0, 32);
      result.add(MediaItem(
        id: id,
        title: title,
        type: inferred,
        streamUrl: line,
        groupTitle: group.isEmpty ? 'Geral' : group,
        posterUrl: logo,
        tvgId: tvgId,
        headers: Map<String, String>.from(headers),
        isAdult: MediaItem.inferAdult('$group $title'),
      ));
      extinf = null;
      headers.clear();
    }
    return result;
  }

  String? _attribute(String line, String name) {
    final pattern = RegExp("(?:^|\\s)${RegExp.escape(name)}\\s*=\\s*(?:\"([^\"]*)\"|'([^']*)'|([^\\s]+))", caseSensitive: false);
    final match = pattern.firstMatch(line);
    return match?.group(1) ?? match?.group(2) ?? match?.group(3);
  }

  String _titleFromExtinf(String line) {
    var insideDoubleQuotes = false;
    var insideSingleQuotes = false;
    for (var index = 0; index < line.length; index++) {
      final char = line[index];
      if (char == '"' && !insideSingleQuotes) insideDoubleQuotes = !insideDoubleQuotes;
      if (char == "'" && !insideDoubleQuotes) insideSingleQuotes = !insideSingleQuotes;
      if (char == ',' && !insideDoubleQuotes && !insideSingleQuotes) {
        return line.substring(index + 1);
      }
    }
    return '';
  }

  MediaType _inferType(String group, String title, String extinf) {
    final titleFromExtinf = _titleFromExtinf(extinf);
    final extinfMetadata = titleFromExtinf.isEmpty
        ? extinf
        : extinf.substring(0, extinf.length - titleFromExtinf.length);
    final explicitType = (_attribute(extinf, 'tvg-type') ?? _attribute(extinf, 'type') ?? '').toLowerCase();
    if (RegExp(r'\b(series|serie|tvshow|show)\b').hasMatch(explicitType)) return MediaType.series;
    if (RegExp(r'\b(movie|film|vod)\b').hasMatch(explicitType)) return MediaType.movie;
    final metadata = '${group.toLowerCase()} ${extinfMetadata.toLowerCase()}';
    // Category/EXTINF metadata is a stronger signal than a title that merely
    // happens to contain words such as "movie" or "series".
    if (RegExp(r'\b(series|séries|serie|temporada|season|epis[oó]dio|episode)\b').hasMatch(metadata)) {
      return MediaType.series;
    }
    if (RegExp(r'\b(filmes|movie|movies|vod|cinema|film|filme)\b').hasMatch(metadata)) {
      return MediaType.movie;
    }
    final titleValue = title.toLowerCase();
    if (RegExp(r'\b(temporada|season|epis[oó]dio|episode)\b').hasMatch(titleValue)) {
      return MediaType.series;
    }
    return MediaType.live;
  }
}

// ---- Merged from services/metadata_service.dart ----

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

// ---- Merged from services/playlist_service.dart ----

class PlaylistService {
  PlaylistService({http.Client? client, this.parser = const M3uParser()})
      : _client = client ?? http.Client();

  final http.Client _client;
  final M3uParser parser;

  Future<List<MediaItem>> load(IptvAccount account) async {
    switch (account.source) {
      case IptvSource.m3uUrl:
        return loadUrl(account.playlistUrl, providerKey: account.providerKey);
      case IptvSource.m3uFile:
        final file = File(account.localPlaylistPath);
        if (!await file.exists()) {
          throw const PlaylistException('O arquivo da lista não está mais disponível. Importe a lista novamente.');
        }
        final content = await file.readAsString();
        return _parseAndValidate(content, account.providerKey);
      case IptvSource.xtream:
        throw StateError('PlaylistService não carrega contas Xtream.');
    }
  }

  Future<List<MediaItem>> loadUrl(String value, {required String providerKey}) async {
    final uri = Uri.tryParse(value.trim());
    if (uri == null || uri.host.isEmpty || !{'http', 'https'}.contains(uri.scheme.toLowerCase())) {
      throw const PlaylistException('Informe uma URL M3U válida usando HTTP ou HTTPS.');
    }
    final response = await _client.get(uri).timeout(AppConstants.requestTimeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw PlaylistException('O servidor da lista respondeu com HTTP ${response.statusCode}.');
    }
    final content = utf8.decode(response.bodyBytes, allowMalformed: true);
    if (!content.contains('#EXTM3U') && !content.contains('#EXTINF')) {
      throw const PlaylistException('A resposta não parece ser uma lista M3U válida.');
    }
    return _parseAndValidate(content, providerKey);
  }

  /// Validates an imported M3U before writing it to app storage.
  void validateImportedContent(String content, {required String providerKey}) {
    _parseAndValidate(content, providerKey);
  }

  List<MediaItem> _parseAndValidate(String content, String providerKey) {
    final items = parser.parse(content, providerKey: providerKey);
    if (items.isEmpty) {
      throw const PlaylistException('A lista M3U não contém canais ou mídias válidos. Confira o arquivo ou a URL.');
    }
    return items;
  }

  Future<String> saveImportedFile(String filename, String contents, String providerKey) async {
    final directory = await getApplicationSupportDirectory();
    final safeName = providerKey.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final file = File('${directory.path}/playlist_$safeName.m3u');
    await file.writeAsString(contents, encoding: utf8, flush: true);
    return file.path;
  }

  void dispose() => _client.close();
}

class PlaylistException implements Exception {
  const PlaylistException(this.message);
  final String message;
  @override
  String toString() => message;
}

// ---- Merged from services/secure_account_store.dart ----

class SecureAccountStore {
  SecureAccountStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _accountKey = 'unex_vision.active_account.v1';
  static const _tmdbKey = 'unex_vision.tmdb_key.v1';
  final FlutterSecureStorage _storage;

  Future<void> saveAccount(IptvAccount account) =>
      _storage.write(key: _accountKey, value: jsonEncode(account.toJson()));

  Future<IptvAccount?> readAccount() async {
    final value = await _storage.read(key: _accountKey);
    if (value == null || value.isEmpty) return null;
    try {
      final json = jsonDecode(value);
      if (json is! Map<String, dynamic>) return null;
      return IptvAccount.fromJson(json);
    } on FormatException {
      return null;
    }
  }

  Future<void> clearAccount() => _storage.delete(key: _accountKey);

  String _historyKey(String provider) => 'unex_vision.history.$provider.v1';

  Future<void> saveHistory(String provider, List<MediaItem> items) async {
    await _storage.write(
      key: _historyKey(provider),
      value: jsonEncode(items.take(40).map((item) => item.toJson()).toList()),
    );
  }

  Future<void> clearHistory(String provider) => _storage.delete(key: _historyKey(provider));

  Future<List<MediaItem>> readHistory(String provider) async {
    final raw = await _storage.read(key: _historyKey(provider));
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded.whereType<Map<String, dynamic>>().map(MediaItem.fromJson).toList();
    } on FormatException {
      return [];
    }
  }

  Future<String> readTmdbKey() async => await _storage.read(key: _tmdbKey) ?? '';

  Future<void> saveTmdbKey(String key) async {
    if (key.trim().isEmpty) {
      await _storage.delete(key: _tmdbKey);
    } else {
      await _storage.write(key: _tmdbKey, value: key.trim());
    }
  }
}

// ---- Merged from services/update_service.dart ----

class UpdateInfo {
  const UpdateInfo({required this.tag, required this.releaseUrl, required this.notes, required this.apkUrl});
  final String tag;
  final String releaseUrl;
  final String notes;
  final String apkUrl;
}

class UpdateService {
  UpdateService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  Future<UpdateInfo?> checkLatest() async {
    final uri = Uri.https('api.github.com', '/repos/${AppConstants.githubRepository}/releases/latest');
    late final http.Response response;
    try {
      response = await _client.get(uri, headers: const {
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
      }).timeout(const Duration(seconds: 12));
    } on TimeoutException {
      throw const UpdateException('A consulta de atualização excedeu o tempo limite.');
    } on Exception {
      throw const UpdateException('Não foi possível consultar as atualizações agora.');
    }
    if (response.statusCode == 404) {
      throw const UpdateException('Ainda não há uma versão publicada no GitHub.');
    }
    if (response.statusCode != 200) {
      throw UpdateException('O GitHub respondeu com HTTP ${response.statusCode}.');
    }
    try {
      final json = jsonDecode(utf8.decode(response.bodyBytes));
      if (json is! Map) return null;
      final assets = json['assets'] is List ? json['assets'] as List : const [];
      String apk = '';
      for (final asset in assets.whereType<Map>()) {
        final name = asset['name']?.toString().toLowerCase() ?? '';
        if (name.endsWith('.apk')) {
          apk = asset['browser_download_url']?.toString() ?? '';
          break;
        }
      }
      return UpdateInfo(
        tag: json['tag_name']?.toString() ?? 'versão desconhecida',
        releaseUrl: json['html_url']?.toString() ?? 'https://github.com/${AppConstants.githubRepository}/releases',
        notes: json['body']?.toString() ?? '',
        apkUrl: apk,
      );
    } on FormatException {
      throw const UpdateException('O GitHub retornou informações de versão inválidas.');
    }
  }

  void dispose() => _client.close();
}

class UpdateException implements Exception {
  const UpdateException(this.message);
  final String message;
  @override
  String toString() => message;
}

// ---- Merged from services/xmltv_service.dart ----

class XmltvService {
  XmltvService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  final Map<String, List<EpgProgram>> _cache = {};
  final Map<String, Map<String, List<String>>> _channelNames = {};
  final Map<String, DateTime> _cacheTime = {};

  Future<List<EpgProgram>> programsFor(String url, {required String channelId, required String channelName}) async {
    final target = Uri.tryParse(url.trim());
    if (target == null || target.host.isEmpty || !{'http', 'https'}.contains(target.scheme.toLowerCase())) {
      throw const XmltvException('A URL do EPG deve usar HTTP ou HTTPS.');
    }
    final key = target.toString();
    var programs = _cache[key];
    final cacheTime = _cacheTime[key];
    if (programs == null || cacheTime == null || DateTime.now().difference(cacheTime) > const Duration(minutes: 30)) {
      late final http.Response response;
      try {
        response = await _client.get(target).timeout(AppConstants.requestTimeout);
      } on TimeoutException {
        throw const XmltvException('O download do EPG excedeu o tempo limite.');
      } on Exception {
        throw const XmltvException('Não foi possível baixar o arquivo EPG.');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw XmltvException('O servidor EPG respondeu com HTTP ${response.statusCode}.');
      }
      final body = utf8.decode(response.bodyBytes, allowMalformed: true);
      if (body.length > 80 * 1024 * 1024) {
        throw const XmltvException('O arquivo EPG excede o limite de 80 MB desta versão.');
      }
      try {
        final document = XmlDocument.parse(body);
        programs = <EpgProgram>[];
        final namesById = <String, List<String>>{};
        for (final channel in document.findAllElements('channel')) {
          final id = channel.getAttribute('id')?.trim();
          if (id == null || id.isEmpty) continue;
          namesById[id.toLowerCase()] = channel
              .findElements('display-name')
              .map((node) => node.innerText.trim())
              .where((name) => name.isNotEmpty)
              .toList();
        }
        _channelNames[key] = namesById;
        for (final element in document.findAllElements('programme').take(AppConstants.maxEpgPrograms)) {
          final titleNode = element.findElements('title').firstOrNull;
          final descNode = element.findElements('desc').firstOrNull;
          final start = _parseXmltvDate(element.getAttribute('start'));
          final end = _parseXmltvDate(element.getAttribute('stop'));
          if (titleNode == null || start == null || end == null || !end.isAfter(start)) continue;
          programs.add(EpgProgram(
            title: decodeMaybeBase64(titleNode.innerText.trim()),
            description: descNode == null ? '' : decodeMaybeBase64(descNode.innerText.trim()),
            start: start,
            end: end,
            channelId: element.getAttribute('channel') ?? '',
          ));
        }
        _cache[key] = programs;
        _cacheTime[key] = DateTime.now();
      } on XmlParserException {
        throw const XmltvException('O arquivo fornecido não é um XMLTV válido.');
      }
    }
    final wantedId = channelId.trim().toLowerCase();
    final wantedName = _normalizeChannelName(channelName);
    final namesById = _channelNames[key] ?? const <String, List<String>>{};
    final matches = programs.where((item) {
      final itemId = item.channelId.trim().toLowerCase();
      if (wantedId.isNotEmpty && itemId == wantedId) return true;
      if (wantedName.isEmpty) return false;
      final displayNames = namesById[itemId] ?? const <String>[];
      return displayNames.any((name) {
        final normalized = _normalizeChannelName(name);
        if (normalized == wantedName) return true;
        return normalized.length >= 8 && wantedName.length >= 8 &&
            (normalized.contains(wantedName) || wantedName.contains(normalized));
      });
    }).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    return matches.where((item) => item.end.isAfter(DateTime.now())).take(30).toList();
  }

  static String _normalizeChannelName(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

  static String decodeMaybeBase64(String value) {
    final input = value.trim();
    if (input.isEmpty || input.length < 8 || input.length % 4 != 0) return value;
    if (!RegExp(r'^[A-Za-z0-9+/]*={0,2}$').hasMatch(input)) return value;
    try {
      final bytes = base64.decode(input);
      final decoded = utf8.decode(bytes, allowMalformed: false).trim();
      if (decoded.isEmpty) return value;
      final codepoints = decoded.runes.toList();
      final printable = codepoints.where((r) => r == 9 || r == 10 || r == 13 || (r >= 32 && r != 127)).length;
      if (codepoints.isEmpty || printable / codepoints.length < 0.88) return value;
      if (!RegExp(r'[A-Za-zÀ-ÿ0-9]').hasMatch(decoded)) return value;
      return decoded;
    } on FormatException {
      return value;
    } on ArgumentError {
      return value;
    }
  }

  DateTime? _parseXmltvDate(String? value) {
    if (value == null) return null;
    final match = RegExp(r'^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})(?:\s*([+-])(\d{2})(\d{2}))?').firstMatch(value.trim());
    if (match == null) return null;
    try {
      var date = DateTime.utc(
        int.parse(match.group(1)!),
        int.parse(match.group(2)!),
        int.parse(match.group(3)!),
        int.parse(match.group(4)!),
        int.parse(match.group(5)!),
        int.parse(match.group(6)!),
      );
      final sign = match.group(7);
      if (sign != null) {
        final minutes = int.parse(match.group(8)!) * 60 + int.parse(match.group(9)!);
        date = sign == '+' ? date.subtract(Duration(minutes: minutes)) : date.add(Duration(minutes: minutes));
      }
      return date.toLocal();
    } on FormatException {
      return null;
    }
  }

  void dispose() => _client.close();
}

class XmltvException implements Exception {
  const XmltvException(this.message);
  final String message;
  @override
  String toString() => message;
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}

// ---- Merged from services/xtream_service.dart ----

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
