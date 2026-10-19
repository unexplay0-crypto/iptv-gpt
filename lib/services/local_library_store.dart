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

  Future<void> setPin(String provider, String pin) async {
    final salt = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    final saltText = base64Url.encode(salt);
    final hash = sha256.convert(utf8.encode('$saltText:$pin')).toString();
    await _preferences.setString(_key(provider, 'pin_salt'), saltText);
    await _preferences.setString(_key(provider, 'pin_hash'), hash);
  }

  Future<bool> hasPin(String provider) async => (await readPinHash(provider)).isNotEmpty;

  Future<bool> verifyPin(String provider, String pin) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final lockUntil = await _preferences.getInt(_key(provider, 'pin_lock_until')) ?? 0;
    if (lockUntil > now) return false;

    final salt = await readPinSalt(provider);
    final expected = await readPinHash(provider);
    if (salt.isEmpty || expected.isEmpty) return false;
    final actual = sha256.convert(utf8.encode('$salt:$pin')).toString();
    final matches = constantTimeEquals(actual, expected);
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
