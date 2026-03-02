import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/models/website_monitor.dart';
import '../../firebase_options.dart';

final firebaseServiceProvider = Provider<FirebaseService>((ref) {
  return FirebaseService();
});

/// Cloud sync service using Firebase REST API (Firestore + Auth).
/// No native Firebase SDK needed — works on all platforms via HTTP.
/// Data flows: Hive (local primary) → Firebase REST (background sync).
class FirebaseService {
  final Dio _dio = Dio();
  String? _idToken;
  String? _userId;
  String? _refreshToken;

  bool get isAvailable => isFirebaseConfigured;
  bool get isSignedIn => _idToken != null && _userId != null;
  String? get userId => _userId;

  static const String _authBaseUrl = 'https://identitytoolkit.googleapis.com/v1';
  String get _firestoreBaseUrl =>
      'https://firestore.googleapis.com/v1/projects/$firebaseProjectId/databases/(default)/documents';

  // ── Authentication (Firebase Auth REST API) ──

  Future<bool> signInAnonymously() async {
    if (!isAvailable) return false;
    try {
      final response = await _dio.post(
        '$_authBaseUrl/accounts:signUp?key=$firebaseApiKey',
        data: {'returnSecureToken': true},
      );
      _idToken = response.data['idToken'];
      _userId = response.data['localId'];
      _refreshToken = response.data['refreshToken'];
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> signInWithEmail(String email, String password) async {
    if (!isAvailable) return false;
    try {
      final response = await _dio.post(
        '$_authBaseUrl/accounts:signInWithPassword?key=$firebaseApiKey',
        data: {
          'email': email,
          'password': password,
          'returnSecureToken': true,
        },
      );
      _idToken = response.data['idToken'];
      _userId = response.data['localId'];
      _refreshToken = response.data['refreshToken'];
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> signUp(String email, String password) async {
    if (!isAvailable) return false;
    try {
      final response = await _dio.post(
        '$_authBaseUrl/accounts:signUp?key=$firebaseApiKey',
        data: {
          'email': email,
          'password': password,
          'returnSecureToken': true,
        },
      );
      _idToken = response.data['idToken'];
      _userId = response.data['localId'];
      _refreshToken = response.data['refreshToken'];
      return true;
    } catch (_) {
      return false;
    }
  }

  void signOut() {
    _idToken = null;
    _userId = null;
    _refreshToken = null;
  }

  Future<void> _refreshTokenIfNeeded() async {
    if (_refreshToken == null) return;
    try {
      final response = await _dio.post(
        'https://securetoken.googleapis.com/v1/token?key=$firebaseApiKey',
        data: {
          'grant_type': 'refresh_token',
          'refresh_token': _refreshToken,
        },
      );
      _idToken = response.data['id_token'];
      _refreshToken = response.data['refresh_token'];
    } catch (_) {}
  }

  // ── Firestore CRUD (REST API) ──

  Map<String, String> get _headers => {
    'Authorization': 'Bearer $_idToken',
    'Content-Type': 'application/json',
  };

  /// Convert a Dart map to Firestore document format
  Map<String, dynamic> _toFirestoreDoc(Map<String, dynamic> data) {
    final fields = <String, dynamic>{};
    data.forEach((key, value) {
      if (value is String) {
        fields[key] = {'stringValue': value};
      } else if (value is int) {
        fields[key] = {'integerValue': value.toString()};
      } else if (value is double) {
        fields[key] = {'doubleValue': value};
      } else if (value is bool) {
        fields[key] = {'booleanValue': value};
      } else if (value is List) {
        // Store lists as JSON string for simplicity
        fields[key] = {'stringValue': value.toString()};
      } else if (value is Map) {
        fields[key] = {'stringValue': value.toString()};
      } else if (value != null) {
        fields[key] = {'stringValue': value.toString()};
      }
    });
    return {'fields': fields};
  }

  /// Sync a monitor to Firestore
  Future<void> syncMonitor(WebsiteMonitor monitor) async {
    if (!isAvailable || !isSignedIn) return;
    try {
      // Trim history for cloud storage
      final trimmedHistory = monitor.history.length > 50
          ? monitor.history.sublist(monitor.history.length - 50)
          : monitor.history;
      final data = monitor.copyWith(history: trimmedHistory).toJson();
      // Remove complex nested data for REST simplicity
      data.remove('history');
      data['historyCount'] = trimmedHistory.length;
      data['lastStatus'] = monitor.currentStatus.name;

      await _dio.patch(
        '$_firestoreBaseUrl/users/$_userId/monitors/${monitor.id}',
        data: _toFirestoreDoc(data),
        options: Options(headers: _headers),
      );
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 401) {
        await _refreshTokenIfNeeded();
      }
    }
  }

  /// Delete a monitor from Firestore
  Future<void> deleteMonitor(String monitorId) async {
    if (!isAvailable || !isSignedIn) return;
    try {
      await _dio.delete(
        '$_firestoreBaseUrl/users/$_userId/monitors/$monitorId',
        options: Options(headers: _headers),
      );
    } catch (_) {}
  }

  /// Sync a connection to Firestore (strips passwords)
  Future<void> syncConnection(String id, Map<String, dynamic> data) async {
    if (!isAvailable || !isSignedIn) return;
    try {
      final safeData = Map<String, dynamic>.from(data);
      safeData.remove('password');
      safeData.remove('privateKey');
      await _dio.patch(
        '$_firestoreBaseUrl/users/$_userId/connections/$id',
        data: _toFirestoreDoc(safeData),
        options: Options(headers: _headers),
      );
    } catch (_) {}
  }

  /// Sync a setting
  Future<void> syncSetting(String key, dynamic value) async {
    if (!isAvailable || !isSignedIn) return;
    try {
      await _dio.patch(
        '$_firestoreBaseUrl/users/$_userId/settings/app_settings',
        data: _toFirestoreDoc({key: value}),
        options: Options(headers: _headers),
      );
    } catch (_) {}
  }

  /// Sync all monitors to cloud (bulk)
  Future<void> syncAllMonitors(List<WebsiteMonitor> monitors) async {
    if (!isAvailable || !isSignedIn) return;
    for (final monitor in monitors) {
      await syncMonitor(monitor);
    }
  }
}
