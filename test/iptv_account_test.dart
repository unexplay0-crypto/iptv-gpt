import 'package:flutter_test/flutter_test.dart';
import 'package:iptv/app_core.dart';

void main() {
  group('IptvAccount identity', () {
    test('imported playlists with same filename but different content IDs stay separate', () {
      final first = IptvAccount(
        source: IptvSource.m3uFile,
        label: 'lista',
        localPlaylistPath: '/app/playlist_a.m3u',
        localPlaylistId: 'content-a',
      );
      final second = IptvAccount(
        source: IptvSource.m3uFile,
        label: 'lista',
        localPlaylistPath: '/app/playlist_b.m3u',
        localPlaylistId: 'content-b',
      );
      expect(first.providerKey, isNot(second.providerKey));
    });

    test('serializes imported playlist identity', () {
      const account = IptvAccount(
        source: IptvSource.m3uFile,
        label: 'lista',
        localPlaylistPath: '/app/lista.m3u',
        localPlaylistId: 'stable-id',
      );
      final restored = IptvAccount.fromJson(account.toJson());
      expect(restored.localPlaylistId, 'stable-id');
      expect(restored.providerKey, account.providerKey);
    });
  });
}
