import 'package:equatable/equatable.dart';

/// Mirror of the backend `FormSubmission` (E48-E49). Returned by
/// `FormsRepository.listSubmissions` for the editor's "View form
/// submissions" surface. Equatable so the bloc that will own these can
/// dedup repeated list responses.
class FormSubmission extends Equatable {
  const FormSubmission({
    required this.id,
    required this.pageUlid,
    required this.fields,
    required this.createdAt,
    this.sourceIp,
  });

  factory FormSubmission.fromJson(Map<String, dynamic> json) {
    return FormSubmission(
      id: json['id'] as String,
      pageUlid: json['page_ulid'] as String,
      fields: Map<String, dynamic>.from(json['fields'] as Map),
      createdAt: DateTime.parse(json['created_at'] as String),
      sourceIp: json['source_ip'] as String?,
    );
  }

  /// Generated ULID for the submission (backend-side).
  final String id;

  /// The page ULID the form lives on. Echoed back so a list of mixed
  /// submissions across pages can be partitioned.
  final String pageUlid;

  /// One entry per text input on the form. Values are decoded from the
  /// backend's JSONB column; mixed-type values stay as `dynamic`
  /// because the schema validation slice (TBD) will narrow them.
  final Map<String, dynamic> fields;

  /// Server-side write time (DateTime.utc).
  final DateTime createdAt;

  /// Best-effort source IP captured at submit time. Null when the
  /// reverse-proxy header was absent and shelf couldn't derive one.
  final String? sourceIp;

  @override
  List<Object?> get props => [id, pageUlid, fields, createdAt, sourceIp];
}
