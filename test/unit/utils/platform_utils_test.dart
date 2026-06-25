import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_test/flutter_test.dart';
import 'package:memo_everywhere/core/utils/platform_utils.dart';

void main() {
  group('PlatformUtils', () {
    test('isWeb returns a bool', () {
      // AC-7: PlatformUtils.isWeb must return a boolean value
      expect(PlatformUtils.isWeb, isA<bool>());
    });

    test('isWeb matches kIsWeb at runtime', () {
      // AC-7: PlatformUtils.isWeb wraps kIsWeb — must match the Flutter constant
      expect(PlatformUtils.isWeb, equals(kIsWeb));
    });

    test('useRemoteStore is true when isWeb is true', () {
      // AC-9: web platform uses remote datasource
      // In unit tests kIsWeb == false, so useRemoteStore == false.
      // We verify the contract by checking the logical equivalence.
      expect(PlatformUtils.useRemoteStore, equals(PlatformUtils.isWeb));
    });
  });
}
