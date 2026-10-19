import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:iptv/services/xmltv_service.dart';

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
}
