import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/app_constants.dart';

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
