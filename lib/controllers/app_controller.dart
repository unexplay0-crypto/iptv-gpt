import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../core/app_constants.dart';
import '../models/epg_program.dart';
import '../models/iptv_account.dart';
import '../models/media_item.dart';
import '../services/local_library_store.dart';
import '../services/metadata_service.dart';
import '../services/playlist_service.dart';
import '../services/secure_account_store.dart';
import '../services/update_service.dart';
import '../services/xmltv_service.dart';
import '../services/xtream_service.dart';

class AppController extends ChangeNotifier {
  AppController({
    SecureAccountStore? secureStore,
    LocalLibraryStore? libraryStore,
    PlaylistService? playlistService,
    XtreamService? xtreamService,
    XmltvService? xmltvService,
    MetadataService? metadataService,
    UpdateService? updateService,
  })  : _secureStore = secureStore ?? SecureAccountStore(),
        _libraryStore = libraryStore ?? LocalLibraryStore(),
        _playlistService = playlistService ?? PlaylistService(),
        _xtreamService = xtreamService ?? XtreamService(),
        _xmltvService = xmltvService ?? XmltvService(),
        _metadataService = metadataService ?? MetadataService(),
        _updateService = updateService ?? UpdateService();

  final SecureAccountStore _secureStore;
  final LocalLibraryStore _libraryStore;
  final PlaylistService _playlistService;
  final XtreamService _xtreamService;
  final XmltvService _xmltvService;
  final MetadataService _metadataService;
  final UpdateService _updateService;

  IptvAccount? account;
  List<MediaItem> _items = [];
  List<MediaItem> _history = [];
  Set<String> _favorites = {};
  Map<String, int> _progress = {};
  bool isInitializing = true;
  bool isLoading = false;
  bool showAdultContent = false;
  String? errorMessage;
  String tmdbApiKey = '';
  UpdateInfo? latestUpdate;

  bool get isConnected => account != null;
  List<MediaItem> get allItems => List.unmodifiable(_visible(_items));
  List<MediaItem> get liveChannels => List.unmodifiable(_visible(_items).where((item) => item.type == MediaType.live));
  List<MediaItem> get movies => List.unmodifiable(_visible(_items).where((item) => item.type == MediaType.movie));
  List<MediaItem> get series => List.unmodifiable(_visible(_items).where((item) => item.type == MediaType.series));
  List<MediaItem> get favorites => List.unmodifiable(_visible(_items).where((item) => _favorites.contains(item.id)));
  List<MediaItem> get history => List.unmodifiable(_visible(_history));
  int get totalItems => _items.length;

  List<MediaItem> _visible(Iterable<MediaItem> items) =>
      showAdultContent ? items.toList() : items.where((item) => !item.isAdult).toList();

  Future<void> initialize() async {
    try {
      account = await _secureStore.readAccount();
      tmdbApiKey = await _secureStore.readTmdbKey();
      final saved = account;
      if (saved != null) {
        try {
          await _loadContent(saved);
        } catch (error) {
          errorMessage = _friendlyError(error);
        }
      }
    } finally {
      isInitializing = false;
      notifyListeners();
    }
  }

  Future<void> connectXtream({
    required String serverUrl,
    required String username,
    required String password,
    String epgUrl = '',
  }) async {
    final server = serverUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    final candidate = IptvAccount(
      source: IptvSource.xtream,
      label: username.trim().isEmpty ? 'Conta IPTV' : username.trim(),
      serverUrl: server,
      username: username.trim(),
      password: password,
      epgUrl: epgUrl.trim(),
    );
    await _connect(candidate);
  }

  Future<void> connectM3uUrl({required String playlistUrl, String epgUrl = '', String label = 'Minha lista'}) async {
    final candidate = IptvAccount(
      source: IptvSource.m3uUrl,
      label: label.trim().isEmpty ? 'Minha lista' : label.trim(),
      playlistUrl: playlistUrl.trim(),
      epgUrl: epgUrl.trim(),
    );
    await _connect(candidate);
  }

  Future<void> connectM3uFile({required String filename, required String contents, String epgUrl = ''}) async {
    final label = filename.replaceAll(RegExp(r'\.(m3u8?|txt)$', caseSensitive: false), '').trim();
    final contentId = sha256.convert(utf8.encode(contents)).toString();
    final candidate = IptvAccount(
      source: IptvSource.m3uFile,
      label: label.isEmpty ? 'Lista importada' : label,
      localPlaylistId: contentId,
      epgUrl: epgUrl.trim(),
    );
    _playlistService.validateImportedContent(contents, providerKey: candidate.providerKey);
    final path = await _playlistService.saveImportedFile(filename, contents, candidate.providerKey);
    await _connect(IptvAccount(
      source: IptvSource.m3uFile,
      label: candidate.label,
      localPlaylistPath: path,
      localPlaylistId: contentId,
      epgUrl: candidate.epgUrl,
    ));
  }

  Future<void> _connect(IptvAccount candidate) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final items = await _fetchContent(candidate);
      await _secureStore.saveAccount(candidate);
      account = candidate;
      _items = items;
      await _loadLibraryState(candidate);
      errorMessage = null;
    } catch (error) {
      errorMessage = _friendlyError(error);
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<List<MediaItem>> _fetchContent(IptvAccount source) async {
    if (source.source == IptvSource.xtream) {
      await _xtreamService.authenticate(source);
      final catalog = await _xtreamService.fetchCatalog(source);
      if (catalog.all.isEmpty) {
        throw const IptvConnectionException('Login aceito, mas o servidor retornou um catálogo vazio. Confira as permissões da conta.');
      }
      return catalog.all;
    }
    return _playlistService.load(source);
  }

  Future<void> _loadContent(IptvAccount source) async {
    isLoading = true;
    notifyListeners();
    try {
      _items = await _fetchContent(source);
      await _loadLibraryState(source);
      errorMessage = null;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadLibraryState(IptvAccount source) async {
    _favorites = await _libraryStore.readFavorites(source.providerKey);
    _history = await _secureStore.readHistory(source.providerKey);
    _progress = await _libraryStore.readProgress(source.providerKey);
    // Adult content unlock is session-only; always require the PIN again after restart.
    showAdultContent = false;
    await _libraryStore.writeAdultVisibility(source.providerKey, false);
  }

  Future<void> refreshCatalog() async {
    final current = account;
    if (current == null) return;
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      _items = await _fetchContent(current);
      await _loadLibraryState(current);
    } catch (error) {
      errorMessage = _friendlyError(error);
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> retryConnection() async {
    final current = account;
    if (current == null) return;
    await _loadContent(current);
  }

  Future<void> logout() async {
    await _secureStore.clearAccount();
    account = null;
    _items = [];
    _history = [];
    _favorites = {};
    _progress = {};
    showAdultContent = false;
    errorMessage = null;
    notifyListeners();
  }

  Future<void> toggleFavorite(MediaItem item) async {
    final current = account;
    if (current == null) return;
    if (_favorites.contains(item.id)) {
      _favorites.remove(item.id);
    } else {
      _favorites.add(item.id);
    }
    await _libraryStore.writeFavorites(current.providerKey, _favorites);
    notifyListeners();
  }

  bool isFavorite(MediaItem item) => _favorites.contains(item.id);

  Future<void> markPlayed(MediaItem item) async {
    final current = account;
    if (current == null) return;
    _history.removeWhere((entry) => entry.id == item.id);
    _history.insert(0, item);
    if (_history.length > AppConstants.maxHistoryItems) {
      _history = _history.take(AppConstants.maxHistoryItems).toList();
    }
    await _secureStore.saveHistory(current.providerKey, _history);
    notifyListeners();
  }

  Future<void> clearHistory() async {
    final current = account;
    if (current == null) return;
    _history = [];
    await _secureStore.clearHistory(current.providerKey);
    notifyListeners();
  }

  Future<void> saveProgress(MediaItem item, Duration position, Duration duration) async {
    final current = account;
    if (current == null || item.isLive) return;
    if (duration.inSeconds > 0 && position.inSeconds >= duration.inSeconds - 15) {
      _progress.remove(item.id);
    } else if (position.inSeconds > 5) {
      _progress[item.id] = position.inMilliseconds;
    }
    await _libraryStore.writeProgress(current.providerKey, _progress);
  }

  Duration progressFor(MediaItem item) => Duration(milliseconds: _progress[item.id] ?? 0);

  Future<List<MediaItem>> loadEpisodes(MediaItem show) async {
    final current = account;
    if (current == null || current.source != IptvSource.xtream || show.seriesId.isEmpty) return const [];
    try {
      final result = await _xtreamService.getSeriesEpisodes(current, show.seriesId);
      if (!showAdultContent) return result.where((item) => !item.isAdult).toList();
      return result;
    } catch (error) {
      errorMessage = _friendlyError(error);
      notifyListeners();
      rethrow;
    }
  }

  Future<List<EpgProgram>> loadPrograms(MediaItem channel) async {
    final current = account;
    if (current == null) return const [];
    if (current.source == IptvSource.xtream && channel.streamId.isNotEmpty) {
      try {
        final raw = await _xtreamService.getShortEpg(current, channel.streamId);
        final list = <EpgProgram>[];
        for (final entry in raw) {
          final start = _timestamp(entry['start_timestamp'] ?? entry['start']);
          final end = _timestamp(entry['stop_timestamp'] ?? entry['end']);
          if (start == null || end == null || !end.isAfter(start)) continue;
          list.add(EpgProgram(
            title: _decodeEpg(entry['title']?.toString() ?? 'Sem programação'),
            description: _decodeEpg(entry['description']?.toString() ?? ''),
            start: start,
            end: end,
            channelId: channel.tvgId,
          ));
        }
        if (list.isNotEmpty) return list;
      } catch (_) {
        // Fall through to XMLTV when the middleware endpoint is unavailable.
      }
    }
    if (current.epgUrl.trim().isEmpty) return const [];
    return _xmltvService.programsFor(
      current.epgUrl,
      channelId: channel.tvgId,
      channelName: channel.title,
    );
  }

  DateTime? _timestamp(Object? value) {
    if (value == null) return null;
    final input = value.toString().trim();
    final seconds = int.tryParse(input);
    if (seconds != null) return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true).toLocal();
    return DateTime.tryParse(input)?.toLocal();
  }

  String _decodeEpg(String input) => XmltvService.decodeMaybeBase64(input);

  Future<bool> hasParentalPin() async {
    final current = account;
    return current != null && await _libraryStore.hasPin(current.providerKey);
  }

  Future<void> setParentalPin(String pin) async {
    final current = account;
    if (current == null) throw StateError('Nenhuma conta conectada.');
    if (!RegExp(r'^\d{4,8}$').hasMatch(pin)) {
      throw const IptvConnectionException('O PIN deve ter entre 4 e 8 números.');
    }
    await _libraryStore.setPin(current.providerKey, pin);
  }

  Future<bool> verifyParentalPin(String pin) async {
    final current = account;
    if (current == null) return false;
    return _libraryStore.verifyPin(current.providerKey, pin);
  }

  Future<void> setAdultVisibility(bool show) async {
    final current = account;
    if (current == null) return;
    showAdultContent = show;
    // Never persist an unlocked state across app restarts.
    await _libraryStore.writeAdultVisibility(current.providerKey, false);
    notifyListeners();
  }

  Future<void> updateEpgUrl(String value) async {
    final current = account;
    if (current == null) return;
    final updated = current.copyWith(epgUrl: value.trim());
    account = updated;
    await _secureStore.saveAccount(updated);
    notifyListeners();
  }

  Future<void> saveTmdbApiKey(String value) async {
    tmdbApiKey = value.trim();
    await _secureStore.saveTmdbKey(tmdbApiKey);
    notifyListeners();
  }

  Future<MediaItem> enrichMetadata(MediaItem item) async {
    if (tmdbApiKey.isEmpty || (item.description.isNotEmpty && item.posterUrl.isNotEmpty)) return item;
    final match = await _metadataService.search(
      apiKey: tmdbApiKey,
      title: item.title,
      isSeries: item.type == MediaType.series || item.type == MediaType.episode,
    );
    if (match == null) return item;
    return item.copyWith(
      description: item.description.isNotEmpty ? item.description : match.overview,
      posterUrl: item.posterUrl.isNotEmpty ? item.posterUrl : match.posterUrl,
      backdropUrl: item.backdropUrl.isNotEmpty ? item.backdropUrl : match.backdropUrl,
      year: item.year.isNotEmpty ? item.year : match.releaseDate,
    );
  }

  Future<UpdateInfo?> checkForUpdate() async {
    latestUpdate = await _updateService.checkLatest();
    notifyListeners();
    return latestUpdate;
  }

  String _friendlyError(Object error) {
    if (error is IptvConnectionException || error is XtreamException || error is PlaylistException || error is XmltvException) {
      return error.toString();
    }
    if (error is SocketException) return 'Sem conexão com a rede. Confira o Wi-Fi e tente novamente.';
    return 'Não foi possível concluir a operação. Confira os dados e a conexão e tente novamente.';
  }

  @override
  void dispose() {
    _playlistService.dispose();
    _xtreamService.dispose();
    _xmltvService.dispose();
    _metadataService.dispose();
    _updateService.dispose();
    super.dispose();
  }
}

class IptvConnectionException implements Exception {
  const IptvConnectionException(this.message);
  final String message;
  @override
  String toString() => message;
}
