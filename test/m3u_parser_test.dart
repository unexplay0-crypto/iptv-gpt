import 'package:flutter_test/flutter_test.dart';
import 'package:iptv/app_core.dart';
import 'package:iptv/app_services.dart';

void main() {
  const parser = M3uParser();

  group('M3uParser', () {
    test('preserva acentos, vírgulas no título e atributos em ordens diferentes', () {
      const playlist = '''#EXTM3U
#EXTINF:-1 tvg-logo="https://images.example/logo.png" group-title="Notícias, Brasil" tvg-id="br.news",Notícias, ao vivo
https://stream.example/live.m3u8?token=a%2Fb&quality=hd
#EXTINF:-1 group-title="Filmes" tvg-id="movie-10" tvg-name="Ação",Ação, o filme
https://stream.example/movie/10.mp4?auth=abc
''';
      final items = parser.parse(playlist, providerKey: 'provider-test');
      expect(items, hasLength(2));
      expect(items.first.title, 'Notícias, ao vivo');
      expect(items.first.groupTitle, 'Notícias, Brasil');
      expect(items.first.tvgId, 'br.news');
      expect(items.first.streamUrl, contains('token=a%2Fb'));
      expect(items.first.type, MediaType.live);
      expect(items[1].title, 'Ação, o filme');
      expect(items[1].type, MediaType.movie);
      expect(items[1].posterUrl, isEmpty);
    });

    test('lê opções HTTP do EXT Vlc e aplica o cabeçalho ao item correspondente', () {
      const playlist = '''#EXTM3U
#EXTINF:-1 group-title="Esportes",Canal Esportes
#EXTVLCOPT:http-user-agent=UNEX-Test/1.0
#EXTVLCOPT:http-referrer=https://example.com/
https://stream.example/live.ts
''';
      final items = parser.parse(playlist, providerKey: 'x');
      expect(items, hasLength(1));
      expect(items.first.headers['User-Agent'], 'UNEX-Test/1.0');
      expect(items.first.headers['Referer'], 'https://example.com/');
    });

    test('ignora comentários sem entrada e evita IDs dependentes de String.hashCode', () {
      const playlist = '#EXTM3U\n#EXTVLCOPT:network-caching=1000\n';
      expect(parser.parse(playlist, providerKey: 'x'), isEmpty);
      const entry = '#EXTM3U\n#EXTINF:-1 group-title="News",Canal\nhttps://example.com/a.ts?x=1\n';
      final first = parser.parse(entry, providerKey: 'same').single.id;
      final second = parser.parse(entry, providerKey: 'same').single.id;
      final otherProvider = parser.parse(entry, providerKey: 'other').single.id;
      expect(first, second);
      expect(first, isNot(otherProvider));
      expect(first, hasLength(32));
    });

    test('separa episódios M3U por série, temporada e número do episódio', () {
      const playlist = '''#EXTM3U
#EXTINF:-1 group-title="Séries",The Office S01E02 - Dundies
https://stream.example/office-s01e02.mp4
#EXTINF:-1 group-title="Séries",The Office S02E01 - The Dundies
https://stream.example/office-s02e01.mp4
''';
      final items = parser.parse(playlist, providerKey: 'series-test');
      expect(items.map((item) => item.type), everyElement(MediaType.episode));
      expect(items.map((item) => item.seriesId).toSet(), hasLength(1));
      expect(items.map((item) => item.groupTitle).toSet(), {'The Office'});
      expect(items.map((item) => item.seasonNumber), [1, 2]);
      expect(items.map((item) => item.episodeNumber), [2, 1]);
    });

    test('marca nomes de conteúdo adulto para que sejam ocultados pelo filtro parental', () {
      const playlist = '#EXTM3U\n#EXTINF:-1 group-title="Adult XXX",Canal 18+\nhttps://example.com/a.ts\n';
      expect(parser.parse(playlist, providerKey: 'x').single.isAdult, isTrue);
      expect(MediaItem.inferAdult('Canal 18+'), isTrue);
    });
  });
}
