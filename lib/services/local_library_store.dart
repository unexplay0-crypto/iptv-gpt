import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_constants.dart';
import '../models/media_item.dart';

class LocalLibraryStore {
  LocalLibraryStore() : _preferences = SharedPreferencesAsync();
  final SharedPreferencesAsync _preferences;

  String _key(String provider, String feature) => 'unex.v1.$provider.$feature';

  Future<Set<String>> readFavorites(String provider) async =>
      (await _preferences.getStringList(_key(provider, 'favorites')) ?? const <String>[]).toSet();

  Future<void> writeFavorites(String provider, Set<String> favorites) =>
      _preferences.setStringList(_key(provider, 'favorites'), favorites.toList());

  Future<List<MediaItem>> readHistory(String provider) async {
    final raw = await _preferences.getStringList(_key(provider, 'history')) ?? const <String>[];
    final items = <MediaItem>[];
    for (final value in raw) {
      try {
        final json = jsonDecode(value);
        if (json is Map<String, dynamic>) items.add(MediaItem.fromJson(json));
      } on FormatException {
        // Skip only the damaged entry; preserve all other history records.
      }
    }
    return items;
  }

  Future<void> writeHistory(String provider, List<MediaItem> history) => _preferences.setStringList(
        _key(provider, 'history'),
        history.take(AppConstants.maxHistoryItems).map((item) => jsonEncode(item.toJson())).toList(),
      );

  Future<Map<String, int>> readProgress(String provider) async {
    final raw = await _preferences.getString(_key(provider, 'progress'));
    if (raw == null) return {};
    try {
      final json = jsonDecode(raw);
      if (json is! Map) return {};
      return json.map((key, value) => MapEntry(key.toString(), int.tryParse(value.toString()) ?? 0));
    } on FormatException {
      return {};
    }
  }

  Future<void> writeProgress(String provider, Map<String, int> progress) =>
      _preferences.setString(_key(provider, 'progress'), jsonEncode(progress));

  Future<bool> readAdultVisibility(String provider) async =>
      await _preferences.getBool(_key(provider, 'show_adult')) ?? false;

  Future<void> writeAdultVisibility(String provider, bool show) =>
      _preferences.setBool(_key(provider, 'show_adult'), show);

  Future<String> readPinSalt(String provider) async => await _preferences.getString(_key(provider, 'pin_salt')) ?? '';
  Future<String> readPinHash(String provider) async => await _preferences.getString(_key(provider, 'pin_hash')) ?? '';

  static const _pinIterations = 60000;

  Future<void> setPin(String provider, String pin) async {
    final salt = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    final saltText = base64Url.encode(salt);
    final derived = _derivePin(pin, salt, _pinIterations);
    final encodedHash = 'pbkdf2-sha256:$_pinIterations:${base64Url.encode(derived)}';
    await _preferences.setString(_key(provider, 'pin_salt'), saltText);
    await _preferences.setString(_key(provider, 'pin_hash'), encodedHash);
  }

  List<int> _derivePin(String pin, List<int> salt, int iterations) {
    final passwordBytes = utf8.encode(pin);
    final hmac = Hmac(sha256, passwordBytes);
    var block = hmac.convert([...salt, 0, 0, 0, 1]).bytes;
    final derived = List<int>.from(block);
    for (var iteration = 1; iteration < iterations; iteration++) {
      block = hmac.convert(block).bytes;
      for (var index = 0; index < derived.length; index++) {
        derived[index] ^= block[index];
      }
    }
    return derived;
  }

  Future<bool> hasPin(String provider) async => (await readPinHash(provider)).isNotEmpty;

  Future<bool> verifyPin(String provider, String pin) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final lockUntil = await _preferences.getInt(_key(provider, 'pin_lock_until')) ?? 0;
    if (lockUntil > now) return false;

    final saltText = await readPinSalt(provider);
    final expected = await readPinHash(provider);
    if (saltText.isEmpty || expected.isEmpty) return false;
    late final List<int> salt;
    try {
      salt = base64Url.decode(saltText);
    } on FormatException {
      return false;
    }
    var matches = false;
    if (expected.startsWith('pbkdf2-sha256:')) {
      final parts = expected.split(':');
      if (parts.length == 3) {
        final iterations = int.tryParse(parts[1]);
        if (iterations != null && iterations >= 10000 && iterations <= 200000) {
          final actual = base64Url.encode(_derivePin(pin, salt, iterations));
          matches = constantTimeEquals(actual, parts[2]);
        }
      }
    } else {
      // Backward compatibility: verify old SHA-256 PINs and upgrade on success.
      final legacy = sha256.convert(utf8.encode('$saltText:$pin')).toString();
      if (constantTimeEquals(legacy, expected)) {
        matches = true;
        await setPin(provider, pin);
      }
    }
    if (matches) {
      await _preferences.remove(_key(provider, 'pin_attempts'));
      await _preferences.remove(_key(provider, 'pin_lock_until'));
      return true;
    }

    final attempts = (await _preferences.getInt(_key(provider, 'pin_attempts')) ?? 0) + 1;
    if (attempts >= 5) {
      await _preferences.setInt(
        _key(provider, 'pin_lock_until'),
        now + const Duration(minutes: 1).inMilliseconds,
      );
      await _preferences.remove(_key(provider, 'pin_attempts'));
    } else {
      await _preferences.setInt(_key(provider, 'pin_attempts'), attempts);
    }
    return false;
  }

  @visibleForTesting
  static bool constantTimeEquals(String left, String right) {
    if (left.length != right.length) return false;
    var diff = 0;
    for (var i = 0; i < left.length; i++) {
      diff |= left.codeUnitAt(i) ^ right.codeUnitAt(i);
    }
    return diff == 0;
  }
}
