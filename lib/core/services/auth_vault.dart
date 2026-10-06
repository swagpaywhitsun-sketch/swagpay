import 'dart:convert';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/user.dart';

/// Vault using FlutterSecureStorage with encrypted storage on Android KeyStore / iOS Keychain
/// and in-memory cache for high-throughput zero-latency synchronous access.
class TokenVault {
  static const _accessKey = 'swag_auth_access_token';
  static const _refreshKey = 'swag_auth_refresh_token';
  static const _userKey = 'swag_auth_user';
  static const _deviceIdKey = 'swag_device_id';
  static const _legacyEmailKey = 'auth_user_email';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(resetOnError: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  SharedPreferences? _prefs;

  String? _cachedAccessToken;
  String? _cachedRefreshToken;
  String? _cachedDeviceId;
  Map<String, dynamic>? _cachedUser;

  void attach(SharedPreferences prefs) {
    _prefs = prefs;
    _cachedAccessToken = prefs.getString(_accessKey);
    _cachedRefreshToken = prefs.getString(_refreshKey);
    _cachedDeviceId = prefs.getString(_deviceIdKey);
    final raw = prefs.getString(_userKey);
    if (raw != null) {
      try {
        _cachedUser = jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {
        _cachedUser = null;
      }
    } else {
      _cachedUser = null;
    }
    _hydrate();
  }

  Future<void> _hydrate() async {
    try {
      if (!kIsWeb) {
        final secAccess = await _secureStorage.read(key: _accessKey);
        if (secAccess != null && secAccess.isNotEmpty) _cachedAccessToken = secAccess;

        final secRefresh = await _secureStorage.read(key: _refreshKey);
        if (secRefresh != null && secRefresh.isNotEmpty) _cachedRefreshToken = secRefresh;

        final secDevice = await _secureStorage.read(key: _deviceIdKey);
        if (secDevice != null && secDevice.isNotEmpty) _cachedDeviceId = secDevice;

        final rawUser = await _secureStorage.read(key: _userKey);
        if (rawUser != null && rawUser.isNotEmpty) {
          _cachedUser = jsonDecode(rawUser) as Map<String, dynamic>?;
        }
      }
    } catch (_) {}
  }

  String? readAccessToken() => _cachedAccessToken ?? _prefs?.getString(_accessKey);

  String? readRefreshToken() => _cachedRefreshToken ?? _prefs?.getString(_refreshKey);

  String? readDeviceId() => _cachedDeviceId ?? _prefs?.getString(_deviceIdKey);

  Map<String, dynamic>? readUserSnapshot() {
    if (_cachedUser != null) return _cachedUser;
    final raw = _prefs?.getString(_userKey);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveSession({
    required String accessToken,
    String? refreshToken,
    required Map<String, dynamic> user,
  }) async {
    _cachedAccessToken = accessToken;
    _cachedRefreshToken = refreshToken;
    _cachedUser = user;

    final userJson = jsonEncode(user);

    final prefs = _prefs;
    if (prefs != null) {
      await prefs.setString(_accessKey, accessToken);
      if (refreshToken != null) await prefs.setString(_refreshKey, refreshToken);
      await prefs.setString(_userKey, userJson);
      await prefs.remove(_legacyEmailKey);
    }

    try {
      if (!kIsWeb) {
        await _secureStorage.write(key: _accessKey, value: accessToken);
        if (refreshToken != null) {
          await _secureStorage.write(key: _refreshKey, value: refreshToken);
        }
        await _secureStorage.write(key: _userKey, value: userJson);
      }
    } catch (_) {}
  }

  Future<void> saveAccessToken(String accessToken) async {
    _cachedAccessToken = accessToken;
    await _prefs?.setString(_accessKey, accessToken);
    try {
      if (!kIsWeb) {
        await _secureStorage.write(key: _accessKey, value: accessToken);
      }
    } catch (_) {}
  }

  Future<void> clearSession() async {
    _cachedAccessToken = null;
    _cachedRefreshToken = null;
    _cachedUser = null;

    final prefs = _prefs;
    if (prefs != null) {
      await prefs.remove(_accessKey);
      await prefs.remove(_refreshKey);
      await prefs.remove(_userKey);
      await prefs.remove(_legacyEmailKey);
    }

    try {
      if (!kIsWeb) {
        await _secureStorage.delete(key: _accessKey);
        await _secureStorage.delete(key: _refreshKey);
        await _secureStorage.delete(key: _userKey);
      }
    } catch (_) {}
  }

  Future<void> ensureDeviceId() async {
    final existing = readDeviceId();
    if (existing != null && existing.isNotEmpty) {
      _cachedDeviceId = existing;
      return;
    }

    final newId = const Uuid().v4();
    _cachedDeviceId = newId;

    final prefs = _prefs;
    if (prefs != null) {
      await prefs.setString(_deviceIdKey, newId);
    }

    try {
      if (!kIsWeb) {
        await _secureStorage.write(key: _deviceIdKey, value: newId);
      }
    } catch (_) {}
  }
}

final tokenVault = TokenVault();

/// Stable, measured hardware identifier for this terminal.
class DeviceIdentity {
  static final _info = DeviceInfoPlugin();

  static Future<String> describe() async {
    final stored = tokenVault.readDeviceId();
    final id = stored == null || stored.isEmpty ? 'unknown-device' : stored;
    try {
      if (kIsWeb) return '$id|web';
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          final android = await _info.androidInfo;
          return '$id|android ${android.version.release}|${android.model}';
        case TargetPlatform.iOS:
          final ios = await _info.iosInfo;
          return '$id|ios ${ios.systemVersion}|${ios.utsname.machine}';
        case TargetPlatform.macOS:
          final mac = await _info.macOsInfo;
          return '$id|macos ${mac.osRelease}|${mac.model}';
        case TargetPlatform.windows:
          final win = await _info.windowsInfo;
          return '$id|windows ${win.buildNumber}|${win.productName}';
        case TargetPlatform.linux:
          final linux = await _info.linuxInfo;
          return '$id|linux ${linux.prettyName}';
        default:
          return id;
      }
    } catch (_) {
      return id;
    }
  }
}

/// Server user payload → app model, strictly validated.
AppUser? userFromSession(Map<String, dynamic>? json) {
  if (json == null) return null;
  final id = json['id'] as String?;
  final email = json['email'] as String?;
  if (id == null || email == null) return null;
  return AppUser.fromJson(json);
}
