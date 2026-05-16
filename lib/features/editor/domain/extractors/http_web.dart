// HTTP / web identifier extractors — pulled out of
// `source_line_ops.dart` at M1179 as the fifth step of the FS-02
// split. Each function preserves the
// `(String text, int start, int end) -> SortLinesResult` contract
// and is re-exported from `source_line_ops.dart` so callers
// (dispatch switch, slash entries, tests) need no import changes.
//
// Group rationale: HTTP status codes, HTTP method+path tokens, MIME
// types, and shields.io badge URLs all live in the "HTTP/REST API
// doc-audit" space. Inventorying these in OpenAPI specs, README
// files, and API postmortems is a common shared use case.

import '../source_line_ops.dart';

/// Extract every HTTP status code substring (1XX-5XX range)
/// from each selected line. Useful for log triage, API doc
/// audits, and "which errors does this incident report
/// mention?" surveys.
///
/// Recognition: `\b[1-5]\d{2}\b`
/// - First digit 1-5 (covers 1XX informational through 5XX
///   server-error families).
/// - Two more digits.
/// - Word boundaries on each end.
///
/// No semantic validation — `199` matches even though there's
/// no canonical HTTP 199 code. Acceptable for v1 since the
/// 3-digit shape in the 100-599 range is rare outside HTTP
/// status contexts. 4-digit numbers (`2024`) and 2-digit
/// numbers (`99`) are correctly skipped.
///
/// 70th member of the extraction family — round-number
/// milestone.
SortLinesResult extractHttpStatusCodesFromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(r'\b[1-5]\d{2}\b');
      final out = <String>[];
      for (final l in lines) {
        for (final m in re.allMatches(l)) {
          out.add(m.group(0)!);
        }
      }
      return out;
    });

/// Extract every HTTP method + path token from each selected
/// line (e.g. `GET /api/users`, `POST /v1/login`). Useful for
/// REST API doc audits, route inventory, and OpenAPI spec
/// authoring.
///
/// Recognition: `\b(?:GET|POST|PUT|PATCH|DELETE|HEAD|OPTIONS|TRACE|CONNECT)\s+/[^\s]+`
/// - Standard HTTP method (uppercase, all nine RFC 7231 +
///   RFC 5789 PATCH).
/// - Whitespace.
/// - Path starting with `/` (no spaces inside the path).
///
/// Lowercase methods (`get /path`) are NOT matched — HTTP
/// methods are conventionally uppercase in doc tables and
/// curl examples. Bare methods without paths are skipped.
///
/// 86th member of the extraction family.
SortLinesResult extractHttpMethodsFromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(
        r'\b(?:GET|POST|PUT|PATCH|DELETE|HEAD|OPTIONS|TRACE|CONNECT)'
        r'\s+/[^\s]+',
      );
      final out = <String>[];
      for (final l in lines) {
        for (final m in re.allMatches(l)) {
          out.add(m.group(0)!);
        }
      }
      return out;
    });

/// Extract every MIME type token from each selected line.
/// Useful for HTTP doc audits, Content-Type header harvests,
/// OpenAPI spec authoring, and accept-header inventory.
///
/// Recognition: `\b(application|audio|font|example|image|message|
/// model|multipart|text|video)/[A-Za-z0-9][A-Za-z0-9.\-+]*\b`
/// - Top-level type is one of the ten IANA-registered roots.
/// - Slash separator (required).
/// - Subtype starts with an alphanumeric and may contain `.`,
///   `-`, `+` afterward. Examples that match: `application/json`,
///   `application/vnd.api+json`, `text/html`, `image/png`,
///   `application/x-www-form-urlencoded`, `model/gltf+json`.
///
/// The parameter portion (`; charset=utf-8`) is NOT captured —
/// only the bare `type/subtype` token is returned, which is
/// almost always what doc audits want. Filter parameters
/// downstream with a separate pass if needed.
///
/// Top-level types are matched case-sensitively (lowercase per
/// IANA convention); subtypes allow mixed case to keep historical
/// names like `application/JSON` matchable.
///
/// 87th member of the extraction family.
SortLinesResult extractMimeTypesFromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(
        r'\b(?:application|audio|font|example|image|message|model|'
        r'multipart|text|video)/[A-Za-z0-9][A-Za-z0-9.\-+]*\b',
      );
      final out = <String>[];
      for (final l in lines) {
        for (final m in re.allMatches(l)) {
          out.add(m.group(0)!);
        }
      }
      return out;
    });

/// Extract every shields.io badge URL from each selected line.
/// Useful for README audits, repository status-badge inventory,
/// CI-pipeline reference scrapes, and dependency-badge harvests
/// in open-source project documentation.
///
/// Recognition: `https://img\.shields\.io/[^\s)\]>'"]+`
/// - Literal `https://img.shields.io/` scheme + host prefix.
/// - Path: any non-whitespace, non-bracket, non-quote chars.
///   The suffix is captured greedily up to the first delimiter
///   commonly used in markdown image-link syntax (`)`, `]`)
///   and prose quotes.
///
/// Matches:
/// - `https://img.shields.io/badge/dynamic-blue`
/// - `https://img.shields.io/github/v/release/owner/repo`
/// - `https://img.shields.io/github/actions/workflow/status/owner/repo/ci.yml`
/// - `https://img.shields.io/npm/v/some-package`
///
/// Other badge hosts (`badges.aleen42.com`, `badgen.net`) are
/// NOT matched — they're distinct surfaces with different URL
/// shapes. Add a dedicated extractor if those matter.
///
/// Bracket-bounded captures: in a typical
/// `[![Build](https://img.shields.io/...)](https://...)`
/// markdown link, the badge URL is cleanly extracted because
/// the path stops at the closing `)`.
///
/// 105th member of the extraction family.
SortLinesResult extractShieldsBadgesFromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(
        r'https://img\.shields\.io/[^\s)\]>"' "'" r']+',
      );
      final out = <String>[];
      for (final l in lines) {
        for (final m in re.allMatches(l)) {
          out.add(m.group(0)!);
        }
      }
      return out;
    });
