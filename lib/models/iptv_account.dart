import 'dart:convert';

import 'package:crypto/crypto.dart';

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
    this.epgUrl = '',
  });

  final IptvSource source;
  final String label;
  final String serverUrl;
  final String username;
  final String password;
  final String playlistUrl;
  final String localPlaylistPath;
  final String epgUrl;

  String get providerKey {
    final identity = switch (source) {
      IptvSource.xtream => 'xtream|${_normalizedServer(serverUrl)}|${username.trim()}',
      IptvSource.m3uUrl => 'm3u|${playlistUrl.trim()}',
      IptvSource.m3uFile => 'file|${label.trim().toLowerCase()}',
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
      epgUrl: json['epgUrl']?.toString() ?? '',
    );
  }

  static String _normalizedServer(String value) =>
      value.trim().replaceFirst(RegExp(r'/+$'), '').toLowerCase();
}
