import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import '../core/app_constants.dart';
import '../models/epg_program.dart';

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
