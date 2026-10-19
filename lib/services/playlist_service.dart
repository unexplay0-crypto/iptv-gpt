import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../core/app_constants.dart';
import '../models/iptv_account.dart';
import '../models/media_item.dart';
import 'm3u_parser.dart';

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
