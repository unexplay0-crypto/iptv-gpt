import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:iptv/app_services.dart';

void main() {
  test('rejects a valid M3U header with no playable entries', () async {
    final service = PlaylistService(client: _FakeClient('#EXTM3U\n#EXTVLCOPT:network-caching=1000\n'));
    await expectLater(
      service.loadUrl('https://example.com/list.m3u', providerKey: 'test'),
      throwsA(isA<PlaylistException>()),
    );
    service.dispose();
  });

  test('rejects a non-M3U HTTP response', () async {
    final service = PlaylistService(client: _FakeClient('<html>error</html>'));
    await expectLater(
      service.loadUrl('https://example.com/list.m3u', providerKey: 'test'),
      throwsA(isA<PlaylistException>()),
    );
    service.dispose();
  });
}

class _FakeClient extends http.BaseClient {
  _FakeClient(this.body);
  final String body;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async => http.StreamedResponse(
        Stream<List<int>>.value(utf8.encode(body)),
        200,
        headers: const {'content-type': 'application/x-mpegURL; charset=utf-8'},
      );
}
