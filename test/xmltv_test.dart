import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:flutter_test/flutter_test.dart';
import 'package:iptv/app_services.dart';

void main() {
  group('XMLTV base64 decoder', () {
    test('decodifica Base64 UTF-8 válido', () {
      const source = 'Jornal da Noite';
      final encoded = base64.encode(utf8.encode(source));
      expect(XmltvService.decodeMaybeBase64(encoded), source);
    });

    test('preserva texto simples, vazio e Base64 inválido', () {
      expect(XmltvService.decodeMaybeBase64('Programação ao vivo'), 'Programação ao vivo');
      expect(XmltvService.decodeMaybeBase64(''), '');
      expect(XmltvService.decodeMaybeBase64('a?=='), 'a?==');
    });

    test('preserva uma sequência que não se decodifica para texto imprimível', () {
      const source = '////';
      expect(XmltvService.decodeMaybeBase64(source), source);
    });
  });

  group('XMLTV channel matching', () {
    test('matches channel display-name when the XMLTV ID differs from tvg-id', () async {
      final client = _FakeClient('''<?xml version="1.0" encoding="UTF-8"?>
<tv>
  <channel id="internal.channel.42"><display-name>Canal Brasil HD</display-name></channel>
  <programme start="20991231230000 +0000" stop="21000101000000 +0000" channel="internal.channel.42">
    <title>Programa de teste</title>
  </programme>
</tv>''');
      final service = XmltvService(client: client);
      final programs = await service.programsFor(
        'https://example.com/epg.xml',
        channelId: 'provider-channel-7',
        channelName: 'Canal Brasil HD',
      );
      expect(programs, hasLength(1));
      expect(programs.single.title, 'Programa de teste');
      service.dispose();
    });
  });
}


class _FakeClient extends http.BaseClient {
  _FakeClient(this.body);
  final String body;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async => http.StreamedResponse(
        Stream<List<int>>.value(utf8.encode(body)),
        200,
        headers: const {'content-type': 'application/xml; charset=utf-8'},
      );
}
