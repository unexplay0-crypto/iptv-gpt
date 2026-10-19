import 'package:flutter_test/flutter_test.dart';
import 'package:iptv/app_services.dart';

void main() {
  group('PIN parental', () {
    test('comparação de hashes é exata e percorre toda a entrada', () {
      expect(LocalLibraryStore.constantTimeEquals('abcdef', 'abcdef'), isTrue);
      expect(LocalLibraryStore.constantTimeEquals('abcdef', 'abcdeg'), isFalse);
      expect(LocalLibraryStore.constantTimeEquals('abcdef', 'abcde'), isFalse);
      expect(LocalLibraryStore.constantTimeEquals('', ''), isTrue);
    });
  });
}
