import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';

// ---- Merged from core/app_constants.dart ----

class AppConstants {
  AppConstants._();

  static const appName = 'UNEX Vision';
  static const version = '1.0.0';
  static const githubRepository = 'unexplay0-crypto/IPTV';
  static const requestTimeout = Duration(seconds: 25);
  static const playerInitTimeout = Duration(seconds: 22);
  static const maxHistoryItems = 40;
  static const maxEpgPrograms = 8000;
}

// ---- Merged from core/app_theme.dart ----

class AppTheme {
  AppTheme._();

  static const background = Color(0xFF070A0F);
  static const surface = Color(0xFF101720);
  static const surfaceRaised = Color(0xFF17222E);
  static const accent = Color(0xFF00D7F5);
  static const accentSecondary = Color(0xFF8A7DFF);
  static const textMuted = Color(0xFF9EADBB);

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.dark,
      surface: surface,
      primary: accent,
      secondary: accentSecondary,
      error: const Color(0xFFFF6B6B),
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        clipBehavior: Clip.antiAlias,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        hintStyle: const TextStyle(color: textMuted),
        labelStyle: const TextStyle(color: textMuted),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF253240))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: accent, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFFF6B6B))),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          side: const BorderSide(color: Color(0xFF344454)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF0D1219),
        indicatorColor: accent.withValues(alpha: 0.16),
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
          color: states.contains(WidgetState.selected) ? accent : textMuted,
          fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
        )),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: accent.withValues(alpha: 0.18),
        side: const BorderSide(color: Color(0xFF253240)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
      ),
      dividerColor: const Color(0xFF24303C),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: -0.7),
        headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.4),
        titleLarge: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
        titleMedium: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        bodyLarge: TextStyle(fontSize: 16, height: 1.35),
        bodyMedium: TextStyle(fontSize: 14, height: 1.35),
      ),
    );
  }
}

// ---- Merged from models/epg_program.dart ----

class EpgProgram {
  const EpgProgram({
    required this.title,
    required this.start,
    required this.end,
    this.description = '',
    this.channelId = '',
  });

  final String title;
  final DateTime start;
  final DateTime end;
  final String description;
  final String channelId;

  bool get isOnNow {
    final now = DateTime.now();
    return !now.isBefore(start) && now.isBefore(end);
  }

  int get progressPercent {
    final total = end.difference(start).inSeconds;
    if (total <= 0) return 0;
    final elapsed = DateTime.now().difference(start).inSeconds;
    return (elapsed * 100 / total).clamp(0, 100).round();
  }
}

// ---- Merged from models/iptv_account.dart ----

enum IptvSource { xtream, m3uUrl, m3uFile }

class IptvAccount {
  const IptvAccount({
    required this.source,
    required this.label,
    this.serverUrl = '',
    this.username = '',
    this.password = '',
    this.playlistUrl = '',
    this.localPlaylistPath = '',
    this.localPlaylistId = '',
    this.epgUrl = '',
  });

  final IptvSource source;
  final String label;
  final String serverUrl;
  final String username;
  final String password;
  final String playlistUrl;
  final String localPlaylistPath;
  /// Stable digest of imported playlist content; avoids collisions by filename.
  final String localPlaylistId;
  final String epgUrl;

  String get providerKey {
    final identity = switch (source) {
      IptvSource.xtream => 'xtream|${_normalizedServer(serverUrl)}|${username.trim()}',
      IptvSource.m3uUrl => 'm3u|${playlistUrl.trim()}',
      IptvSource.m3uFile => 'file|${localPlaylistId.isNotEmpty ? localPlaylistId : localPlaylistPath.trim()}',
    };
    return sha256.convert(utf8.encode(identity)).toString().substring(0, 24);
  }

  IptvAccount copyWith({String? label, String? epgUrl}) => IptvAccount(
        source: source,
        label: label ?? this.label,
        serverUrl: serverUrl,
        username: username,
        password: password,
        playlistUrl: playlistUrl,
        localPlaylistPath: localPlaylistPath,
        localPlaylistId: localPlaylistId,
        epgUrl: epgUrl ?? this.epgUrl,
      );

  Map<String, dynamic> toJson() => {
        'source': source.name,
        'label': label,
        'serverUrl': serverUrl,
        'username': username,
        'password': password,
        'playlistUrl': playlistUrl,
        'localPlaylistPath': localPlaylistPath,
        'localPlaylistId': localPlaylistId,
        'epgUrl': epgUrl,
      };

  factory IptvAccount.fromJson(Map<String, dynamic> json) {
    final sourceName = json['source']?.toString() ?? 'm3uUrl';
    final source = IptvSource.values.firstWhere(
      (value) => value.name == sourceName,
      orElse: () => IptvSource.m3uUrl,
    );
    return IptvAccount(
      source: source,
      label: json['label']?.toString() ?? 'Minha lista',
      serverUrl: json['serverUrl']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      password: json['password']?.toString() ?? '',
      playlistUrl: json['playlistUrl']?.toString() ?? '',
      localPlaylistPath: json['localPlaylistPath']?.toString() ?? '',
      localPlaylistId: json['localPlaylistId']?.toString() ?? '',
      epgUrl: json['epgUrl']?.toString() ?? '',
    );
  }

  static String _normalizedServer(String value) =>
      value.trim().replaceFirst(RegExp(r'/+$'), '').toLowerCase();
}

// ---- Merged from models/media_item.dart ----

enum MediaType { live, movie, series, episode }

extension MediaTypeLabel on MediaType {
  String get label => switch (this) {
        MediaType.live => 'Ao vivo',
        MediaType.movie => 'Filme',
        MediaType.series => 'Série',
        MediaType.episode => 'Episódio',
      };
}

class MediaItem {
  const MediaItem({
    required this.id,
    required this.title,
    required this.type,
    this.streamUrl = '',
    this.groupTitle = 'Geral',
    this.posterUrl = '',
    this.backdropUrl = '',
    this.description = '',
    this.year = '',
    this.duration = '',
    this.tvgId = '',
    this.streamId = '',
    this.seriesId = '',
    this.seasonNumber = 0,
    this.episodeNumber = 0,
    this.containerExtension = '',
    this.headers = const <String, String>{},
    this.isAdult = false,
  });

  final String id;
  final String title;
  final MediaType type;
  final String streamUrl;
  final String groupTitle;
  final String posterUrl;
  final String backdropUrl;
  final String description;
  final String year;
  final String duration;
  final String tvgId;
  final String streamId;
  final String seriesId;
  final int seasonNumber;
  final int episodeNumber;
  final String containerExtension;
  final Map<String, String> headers;
  final bool isAdult;

  bool get isPlayable => streamUrl.trim().isNotEmpty;
  bool get isLive => type == MediaType.live;

  static String stableId(String provider, String kind, String identifier) =>
      sha256.convert(utf8.encode('$provider|$kind|$identifier')).toString().substring(0, 32);

  MediaItem copyWith({
    String? title,
    String? streamUrl,
    String? groupTitle,
    String? posterUrl,
    String? backdropUrl,
    String? description,
    String? year,
    String? duration,
    String? tvgId,
    String? streamId,
    String? seriesId,
    int? seasonNumber,
    int? episodeNumber,
    String? containerExtension,
    Map<String, String>? headers,
    bool? isAdult,
  }) =>
      MediaItem(
        id: id,
        title: title ?? this.title,
        type: type,
        streamUrl: streamUrl ?? this.streamUrl,
        groupTitle: groupTitle ?? this.groupTitle,
        posterUrl: posterUrl ?? this.posterUrl,
        backdropUrl: backdropUrl ?? this.backdropUrl,
        description: description ?? this.description,
        year: year ?? this.year,
        duration: duration ?? this.duration,
        tvgId: tvgId ?? this.tvgId,
        streamId: streamId ?? this.streamId,
        seriesId: seriesId ?? this.seriesId,
        seasonNumber: seasonNumber ?? this.seasonNumber,
        episodeNumber: episodeNumber ?? this.episodeNumber,
        containerExtension: containerExtension ?? this.containerExtension,
        headers: headers ?? this.headers,
        isAdult: isAdult ?? this.isAdult,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'type': type.name,
        'streamUrl': streamUrl,
        'groupTitle': groupTitle,
        'posterUrl': posterUrl,
        'backdropUrl': backdropUrl,
        'description': description,
        'year': year,
        'duration': duration,
        'tvgId': tvgId,
        'streamId': streamId,
        'seriesId': seriesId,
        'seasonNumber': seasonNumber,
        'episodeNumber': episodeNumber,
        'containerExtension': containerExtension,
        'headers': headers,
        'isAdult': isAdult,
      };

  factory MediaItem.fromJson(Map<String, dynamic> json) {
    final rawType = json['type']?.toString() ?? 'live';
    final type = MediaType.values.firstWhere(
      (value) => value.name == rawType,
      orElse: () => MediaType.live,
    );
    final rawHeaders = json['headers'];
    final headers = <String, String>{};
    if (rawHeaders is Map) {
      for (final entry in rawHeaders.entries) {
        headers[entry.key.toString()] = entry.value.toString();
      }
    }
    return MediaItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Sem título',
      type: type,
      streamUrl: json['streamUrl']?.toString() ?? '',
      groupTitle: json['groupTitle']?.toString() ?? 'Geral',
      posterUrl: json['posterUrl']?.toString() ?? '',
      backdropUrl: json['backdropUrl']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      year: json['year']?.toString() ?? '',
      duration: json['duration']?.toString() ?? '',
      tvgId: json['tvgId']?.toString() ?? '',
      streamId: json['streamId']?.toString() ?? '',
      seriesId: json['seriesId']?.toString() ?? '',
      seasonNumber: int.tryParse(json['seasonNumber']?.toString() ?? '') ?? 0,
      episodeNumber: int.tryParse(json['episodeNumber']?.toString() ?? '') ?? 0,
      containerExtension: json['containerExtension']?.toString() ?? '',
      headers: headers,
      isAdult: json['isAdult'] == true,
    );
  }

  static bool inferAdult(String value) => RegExp(
        r'(^|\b)(18\+|adult|xxx|porn|er[oó]tic[oa]|er[oó]tico|red.?light|sex.?channel)(?=\b|$|[^a-zA-Z0-9])',
        caseSensitive: false,
      ).hasMatch(value);
}
