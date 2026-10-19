import 'package:crypto/crypto.dart';
import 'dart:convert';

import '../models/media_item.dart';

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
      final inferred = _inferType('$group $title');
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

  MediaType _inferType(String input) {
    final value = input.toLowerCase();
    if (RegExp(r'\b(series|séries|serie|temporada|season|epis[oó]dio|episode)\b').hasMatch(value)) {
      return MediaType.series;
    }
    if (RegExp(r'\b(filmes|movie|movies|vod|cinema|film|filme)\b').hasMatch(value)) {
      return MediaType.movie;
    }
    return MediaType.live;
  }
}
