import 'dart:convert';

/// Serialise a page's identity + frontmatter + body as a JSON string,
/// matching the legacy `editor_page.dart:555` "Copy as JSON" payload
/// shape exactly:
///
///     { "ulid": …, "relativePath": …, "frontmatter": {…}, "body": … }
///
/// Key order is preserved so tooling that diffs the payload across the
/// legacy + beta editors sees identical output for identical input.
/// `frontmatter` is the caller's flattened entry map — usually built
/// by walking `page.frontmatter.entries` and assigning each
/// `e.value` under `e.key`.
String pageAsJsonPayload({
  required String ulid,
  required String relativePath,
  required Map<String, Object?> frontmatter,
  required String body,
}) {
  return jsonEncode({
    'ulid': ulid,
    'relativePath': relativePath,
    'frontmatter': frontmatter,
    'body': body,
  });
}
