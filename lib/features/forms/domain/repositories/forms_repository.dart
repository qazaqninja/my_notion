import '../entities/form_submission.dart';

/// Auth-gated owner-side view of form submissions. Mirrors the
/// backend's `GET /forms/owner/<ulid>/submissions` endpoint introduced
/// in E49. The unauthed `POST /forms/<ulid>/submit` is the visitor-
/// facing side and isn't exposed on the Flutter client — visitors hit
/// the URL directly from a browser.
///
/// Single-method today, but the interface stays abstract: future
/// slices add `getSubmission(token, id)` (for the row-detail dialog)
/// and `deleteSubmission(token, id)` (for spam cleanup), so promoting
/// to a function type would just need reverting later.
// ignore: one_member_abstracts
abstract class FormsRepository {
  /// List submissions for the page at [ulid]. The backend gates on
  /// ownership; this client surfaces ownership failures as
  /// [FormsNotOwnerException] (deliberately the same response shape
  /// as "page not found" — visitors can't enumerate ULIDs).
  ///
  /// Throws [FormsAuthException] on 401, [FormsNotOwnerException] on
  /// 403, [FormsNetworkException] on transport failures.
  Future<List<FormSubmission>> listSubmissions({
    required String token,
    required String ulid,
  });
}

class FormsException implements Exception {
  const FormsException(this.message);
  final String message;
  @override
  String toString() => 'FormsException: $message';
}

class FormsAuthException extends FormsException {
  const FormsAuthException([super.message = 'unauthorized']);
}

class FormsNotOwnerException extends FormsException {
  const FormsNotOwnerException([super.message = 'not_owner']);
}

class FormsNetworkException extends FormsException {
  const FormsNetworkException([super.message = 'network_error']);
}
