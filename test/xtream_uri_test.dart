import 'package:flutter_test/flutter_test.dart';
import 'package:iptv/app_core.dart';
import 'package:iptv/app_services.dart';

void main() {
  group('Xtream URI builder', () {
    const account = IptvAccount(
      source: IptvSource.xtream,
      label: 'teste',
      serverUrl: 'https://iptv.example:8443/panel/',
      username: 'user&name/+@',
      password: 'p@ss:/?&%',
    );

    test('codifica credenciais como parâmetros de query sem quebrar a URL', () {
      final uri = XtreamService.buildApiUri(account, action: 'get_live_streams');
      expect(uri.path, '/panel/player_api.php');
      expect(uri.queryParameters['username'], account.username);
      expect(uri.queryParameters['password'], account.password);
      expect(uri.queryParameters['action'], 'get_live_streams');
    });

    test('codifica credenciais como segmentos em URLs de fluxo', () {
      final uri = XtreamService.buildStreamUri(account, kind: 'live', id: '420', extension: 'ts');
      expect(uri.pathSegments, contains('live'));
      expect(uri.pathSegments, contains(account.username));
      expect(uri.pathSegments, contains(account.password));
      expect(uri.pathSegments.last, '420.ts');
      expect(uri.scheme, 'https');
      expect(uri.host, 'iptv.example');
    });

    test('não aceita protocolo sem HTTP nem HTTPS', () {
      expect(() => XtreamService.normalizeServer('ftp://iptv.example'), throwsA(isA<XtreamException>()));
      expect(() => XtreamService.normalizeServer('sem-servidor'), throwsA(isA<XtreamException>()));
    });
  });
}
