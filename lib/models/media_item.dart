import 'dart:convert';

import 'package:crypto/crypto.dart';

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
