// AWS-specific identifier extractors — pulled out of
// `source_line_ops.dart` at M1178 as the fourth step of the FS-02
// split (geographic / bibliographic / crypto_hash already done).
// Each function preserves the
// `(String text, int start, int end) -> SortLinesResult` contract
// and is re-exported from `source_line_ops.dart` so callers
// (dispatch switch, slash entries, tests) need no import changes.
//
// Group rationale: AWS ARNs, S3 URIs, and region codes all live in
// the AWS-cloud namespace and share doc-audit use cases (IAM policy
// authoring, multi-region failover, cross-account inventory).

import '../source_line_ops.dart';

/// Extract every AWS ARN substring (`arn:PARTITION:SERVICE:REGION:ACCOUNT:RESOURCE`)
/// from each selected line. Useful for infrastructure docs,
/// IAM policy audits, and cross-account resource inventory.
///
/// Recognition: `\barn:[\w\-]+:[\w\-]+:[\w\-]*:\d{0,12}:[\w/\-:.,*]+`
/// - `arn:` literal namespace marker.
/// - Partition (`aws`, `aws-cn`, `aws-us-gov`, etc.): alphanumeric
///   + hyphen.
/// - Service (`s3`, `iam`, `lambda`, etc.): alphanumeric + hyphen.
/// - Region (`us-east-1`, optional empty for global services):
///   alphanumeric + hyphen, can be empty.
/// - Account-id: 0-12 digits (empty allowed for global / public
///   resources).
/// - Resource: alphanumeric plus `/`, `-`, `:`, `.`, `,`, `*`.
///
/// 65th member of the extraction family.
SortLinesResult extractAwsArnsFromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(
        r'\barn:[\w\-]+:[\w\-]+:[\w\-]*:\d{0,12}:[\w/\-:.,*]+',
      );
      final out = <String>[];
      for (final l in lines) {
        for (final m in re.allMatches(l)) {
          out.add(m.group(0)!);
        }
      }
      return out;
    });

/// Extract every AWS S3 URI (`s3://bucket[/key]`) from each
/// selected line. Useful for cloud-storage doc audits, IAM
/// policy authoring, and bucket inventory inside runbooks.
///
/// Recognition: `\bs3://[a-z0-9][a-z0-9.\-]*[a-z0-9](?:/\S*)?`
/// - Literal `s3://` scheme prefix (canonical lowercase).
/// - Bucket name: starts and ends with lowercase alphanumeric;
///   middle characters may be lowercase letters, digits, dots,
///   or hyphens. (Minimum 2 chars per the regex; AWS's real
///   3-char minimum is not enforced here — out-of-band invalid
///   names are an edge case that doesn't appear in prose docs.)
/// - Optional key path: `/` followed by any non-whitespace
///   characters. The path is included in the captured token.
///
/// Examples that match:
/// - `s3://my-bucket`
/// - `s3://my-bucket/path/to/key.txt`
/// - `s3://example.com/index.html` (dotted bucket)
///
/// Uppercase bucket names (`S3://Foo`) and HTTPS S3 endpoints
/// (`https://s3.amazonaws.com/...`) are NOT matched — those are
/// distinct surfaces. Filter HTTPS via a URL extractor; the
/// canonical `s3://` URI scheme is the doc-audit target here.
///
/// 90th member of the extraction family — round-number
/// milestone.
SortLinesResult extractS3UrisFromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(r'\bs3://[a-z0-9][a-z0-9.\-]*[a-z0-9]'
          r'(?:/\S*)?',);
      final out = <String>[];
      for (final l in lines) {
        for (final m in re.allMatches(l)) {
          out.add(m.group(0)!);
        }
      }
      return out;
    });

/// Extract every AWS region code from each selected line.
/// Useful for cloud-resource doc audits, IAM scope inventories,
/// multi-region failover plan triage, and disaster-recovery
/// runbook scrapes.
///
/// Recognition: a continent / partition prefix (`us`, `eu`, `ap`,
/// `sa`, `ca`, `af`, `me`, `cn`, `il`), a hyphen, a directional
/// component (`east`, `west`, `north`, `south`, `central`,
/// `northeast`, `northwest`, `southeast`, `southwest`), a hyphen,
/// and a 1-digit availability index.
///
/// Matches:
/// - `us-east-1`        — N. Virginia
/// - `us-west-2`        — Oregon
/// - `eu-central-1`     — Frankfurt
/// - `ap-southeast-2`   — Sydney
/// - `sa-east-1`        — São Paulo
/// - `ap-northeast-3`   — Osaka
/// - `cn-northwest-1`   — China Ningxia
/// - `il-central-1`     — Israel Tel Aviv
///
/// AWS GovCloud regions (`us-gov-east-1`, `us-gov-west-1`) use a
/// `us-gov-...` triple-prefix not covered by the directional
/// alternation; those are intentionally not matched. Add a
/// dedicated GovCloud extractor if that surface matters.
///
/// 96th member of the extraction family.
SortLinesResult extractAwsRegionsFromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(
        r'\b(?:us|eu|ap|sa|ca|af|me|cn|il)-'
        r'(?:east|west|north|south|central|northeast|northwest|'
        r'southeast|southwest)-\d\b',
      );
      final out = <String>[];
      for (final l in lines) {
        for (final m in re.allMatches(l)) {
          out.add(m.group(0)!);
        }
      }
      return out;
    });
