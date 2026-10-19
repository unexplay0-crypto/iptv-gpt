import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/iptv_account.dart';
import '../models/media_item.dart';

class SecureAccountStore {
  SecureAccountStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _accountKey = 'unex_vision.active_account.v1';
  static const _tmdbKey = 'unex_vision.tmdb_key.v1';
  final FlutterSecureStorage _storage;

  Future<void> saveAccount(IptvAccount account) =>
      _storage.write(key: _accountKey, value: jsonEncode(account.toJson()));

  Future<IptvAccount?> readAccount() async {
    final value = await _storage.read(key: _accountKey);
    if (value == null || value.isEmpty) return null;
    try {
      final json = jsonDecode(value);
      if (json is! Map<String, dynamic>) return null;
      return IptvAccount.fromJson(json);
    } on FormatException {
      return null;
    }
  }

  Future<void> clearAccount() => _storage.delete(key: _accountKey);

  String _historyKey(String provider) => 'unex_vision.history.$provider.v1';

  Future<void> saveHistory(String provider, List<MediaItem> items) async {
    await _storage.write(
      key: _historyKey(provider),
      value: jsonEncode(items.take(40).map((item) => item.toJson()).toList()),
    );
  }

  Future<void> clearHistory(String provider) => _storage.delete(key: _historyKey(provider));

  Future<List<MediaItem>> readHistory(String provider) async {
    final raw = await _storage.read(key: _historyKey(provider));
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded.whereType<Map<String, dynamic>>().map(MediaItem.fromJson).toList();
    } on FormatException {
      return [];
    }
  }

  Future<String> readTmdbKey() async => await _storage.read(key: _tmdbKey) ?? '';

  Future<void> saveTmdbKey(String key) async {
    if (key.trim().isEmpty) {
      await _storage.delete(key: _tmdbKey);
    } else {
      await _storage.write(key: _tmdbKey, value: key.trim());
    }
  }
}
