import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/entities/sync_file.dart';
import '../../domain/repositories/sync_repository.dart';

/// HTTP-backed implementation of [SyncRepository] that talks to the
/// Phase E backend's `/auth/*` and `/sync/*` endpoints. The `client`
/// argument lets tests inject a `MockClient` from `package:http/testing`.
class HttpSyncRepository implements SyncRepository {
  HttpSyncRepository({required this.baseUrl, http.Client? client})
      : _client = client ?? http.Client();

  /// Backend root URL, e.g. `http://localhost:8080`. No trailing slash.
  final String baseUrl;
  final http.Client _client;

  @override
  Future<String> signup({
    required String email,
    required String password,
  }) async {
    final res = await _post('/auth/signup', {'email': email, 'password': password});
    if (res.statusCode == 409) {
      throw const SyncEmailTakenException();
    }
    return _readToken(res);
  }

  @override
  Future<String> login({
    required String email,
    required String password,
  }) async {
    final res = await _post('/auth/login', {'email': email, 'password': password});
    if (res.statusCode == 401) {
      throw const SyncAuthException('invalid_credentials');
    }
    return _readToken(res);
  }

  @override
  Future<List<SyncFileSummary>> list({required String token}) async {
    final res = await _get('/sync/list', token: token);
    final list = jsonDecode(res.body) as List;
    return [
      for (final raw in list)
        SyncFileSummary.fromJson(raw as Map<String, dynamic>),
    ];
  }

  @override
  Future<SyncFileBody?> get({
    required String token,
    required String relpath,
  }) async {
    final res = await _get('/sync/get/$relpath', token: token);
    if (res.statusCode == 404) return null;
    return SyncFileBody.fromJson(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
  }

  @override
  Future<SyncPutOutcome> put({
    required String token,
    required String relpath,
    required String body,
    String? ifMatch,
  }) async {
    final headers = <String, String>{
      'authorization': 'Bearer $token',
      if (ifMatch != null) 'if-match': ifMatch,
    };
    http.Response res;
    try {
      res = await _client.put(
        Uri.parse('$baseUrl/sync/put/$relpath'),
        headers: headers,
        body: body,
      );
    } catch (e) {
      throw SyncNetworkException(e.toString());
    }
    if (res.statusCode == 409) {
      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      return SyncPutConflict(
        SyncFileSummary.fromJson(decoded['current'] as Map<String, dynamic>),
      );
    }
    if (res.statusCode == 401) throw const SyncAuthException();
    if (res.statusCode != 200) {
      throw SyncException('put ${res.statusCode}: ${res.body}');
    }
    return SyncPutSuccess(
      SyncFileSummary.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>,
      ),
    );
  }

  @override
  Future<bool> delete({
    required String token,
    required String relpath,
  }) async {
    http.Response res;
    try {
      res = await _client.delete(
        Uri.parse('$baseUrl/sync/del/$relpath'),
        headers: {'authorization': 'Bearer $token'},
      );
    } catch (e) {
      throw SyncNetworkException(e.toString());
    }
    if (res.statusCode == 204) return true;
    if (res.statusCode == 404) return false;
    if (res.statusCode == 401) throw const SyncAuthException();
    throw SyncException('delete ${res.statusCode}: ${res.body}');
  }

  // ── helpers ──────────────────────────────────────────────────────────

  Future<http.Response> _post(String path, Map<String, dynamic> body) async {
    try {
      return await _client.post(
        Uri.parse('$baseUrl$path'),
        headers: const {'content-type': 'application/json'},
        body: jsonEncode(body),
      );
    } catch (e) {
      throw SyncNetworkException(e.toString());
    }
  }

  Future<http.Response> _get(String path, {required String token}) async {
    http.Response res;
    try {
      res = await _client.get(
        Uri.parse('$baseUrl$path'),
        headers: {'authorization': 'Bearer $token'},
      );
    } catch (e) {
      throw SyncNetworkException(e.toString());
    }
    if (res.statusCode == 401) throw const SyncAuthException();
    return res;
  }

  String _readToken(http.Response res) {
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw SyncException('auth ${res.statusCode}: ${res.body}');
    }
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    return decoded['token'] as String;
  }
}
