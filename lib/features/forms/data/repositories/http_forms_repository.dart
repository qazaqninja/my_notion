import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/entities/form_submission.dart';
import '../../domain/repositories/forms_repository.dart';

/// HTTP-backed implementation of [FormsRepository]. Talks to the v2
/// backend's `GET /forms/owner/<ulid>/submissions` endpoint. Mirrors
/// the wiring style of `HttpSyncRepository`: constructor-injected
/// `http.Client` for test seams, typed exception mapping per status
/// code, raw transport failures wrapped in [FormsNetworkException].
class HttpFormsRepository implements FormsRepository {
  HttpFormsRepository({required this.baseUrl, http.Client? client})
      : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  @override
  Future<List<FormSubmission>> listSubmissions({
    required String token,
    required String ulid,
  }) async {
    http.Response res;
    try {
      res = await _client.get(
        Uri.parse('$baseUrl/forms/owner/$ulid/submissions'),
        headers: {'authorization': 'Bearer $token'},
      );
    } catch (e) {
      throw FormsNetworkException(e.toString());
    }
    if (res.statusCode == 401) throw const FormsAuthException();
    if (res.statusCode == 403) throw const FormsNotOwnerException();
    if (res.statusCode == 503) {
      // F8: backend's dbExceptionToResponse middleware emits 503 on
      // a Postgres transport failure. Surface as a network error
      // with a distinct marker so the UI can render specific copy.
      throw const FormsNetworkException('backend_unhealthy_db');
    }
    if (res.statusCode != 200) {
      throw FormsException('list ${res.statusCode}: ${res.body}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final raw = (body['submissions'] as List).cast<Map<String, dynamic>>();
    return raw.map(FormSubmission.fromJson).toList();
  }
}
