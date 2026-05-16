// Network identifier extractors — pulled out of
// `source_line_ops.dart` at M1182 as the sixth step of the FS-02
// split. Each function preserves the
// `(String text, int start, int end) -> SortLinesResult` contract
// and is re-exported from `source_line_ops.dart` so callers
// (dispatch switch, slash entries, tests) need no import changes.
//
// Group rationale: IPv4 dotted-quad addresses, IPv6 colon-separated
// addresses, and TCP/UDP port references all live in the
// "network address / endpoint" space. Doc-audit use cases (firewall
// rules, log triage, dual-stack rollout, IANA service inventory)
// overlap.
//
// The MAC-address family (standard + Cisco-dot form), MAC OUI
// extractor, and CIDR notation are still in `source_line_ops.dart`
// because they touch `extractMacAddressesFromLinesIn`'s internal
// backref pattern (see comment there) and are a tighter group; a
// later tick can pull those into `extractors/mac.dart` or merge
// them in.

import '../source_line_ops.dart';

/// Extract every IPv4 dotted-quad address from each selected line
/// (`a.b.c.d` where each octet is 0..255). Useful for triaging log
/// paste-ins or surveying which hosts appear in a debug dump.
///
/// Recognition validates each octet's numeric range, so `999.0.0.0`
/// is REJECTED even though it has the right shape. The `\b`
/// boundary on either end prevents matches inside longer dotted
/// runs like a version string `1.2.3.4.5`.
SortLinesResult extractIpv4FromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      // Each octet alternation explicit: 0-9 / 10-99 / 100-199 /
      // 200-249 / 250-255. Ugly but exact.
      const octet =
          r'(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)';
      final re = RegExp(r'\b' + octet + r'(?:\.' + octet + r'){3}\b');
      final out = <String>[];
      for (final l in lines) {
        for (final m in re.allMatches(l)) {
          out.add(m.group(0)!);
        }
      }
      return out;
    });

/// Extract every IPv6 address from each selected line. Useful
/// for network doc audits, firewall rule inventories,
/// distributed-system trace harvests, and dual-stack rollout
/// runbook scrapes.
///
/// Recognition: a three-arm alternation covering:
/// - Full eight-group form: `2001:0db8:85a3:0000:0000:8a2e:`
///   `0370:7334`
/// - Compressed form with `::`: `2001:db8::1`, `fe80::1`,
///   `::ffff:a:b`
/// - Leading-`::` and standalone `::`: `::1` (loopback), `::`
///   (unspecified)
///
/// Each group is 1-4 hexadecimal characters; case is
/// preserved as written (lowercase is canonical per RFC 5952
/// but uppercase appears in older docs).
///
/// Boundary lookarounds `(?<![\w:.])` and `(?![\w:.])` prevent
/// the regex from slicing inside longer non-IPv6 tokens that
/// share the colon character.
///
/// Time-of-day strings like `12:34:56` are NOT matched because
/// they have only 2 colons; the full-form arm requires 7
/// colons and the compressed arm requires `::` somewhere in
/// the match. IPv4 dotted-quad `127.0.0.1` is also not matched
/// because the format has dots, not just colons.
///
/// IPv6-mapped IPv4 addresses (`::ffff:192.0.2.1`) are NOT
/// matched — the trailing dotted-quad section breaks the
/// purely-colonised group structure. A separate extractor
/// could target this hybrid form if needed.
///
/// Zone identifiers (`fe80::1%eth0`) capture only the address
/// portion; the `%zone` suffix is dropped at the boundary
/// lookahead.
///
/// 100th member of the extraction family — milestone.
SortLinesResult extractIpv6FromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(
        r'(?<![\w:.])'
        r'(?:'
        r'(?:[0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}'
        r'|(?:[0-9a-fA-F]{1,4}:){1,7}:[0-9a-fA-F]{0,4}'
        r'|::(?:[0-9a-fA-F]{1,4}(?::[0-9a-fA-F]{1,4}){0,6})?'
        r')'
        r'(?![\w:.])',
      );
      final out = <String>[];
      for (final l in lines) {
        for (final m in re.allMatches(l)) {
          out.add(m.group(0)!);
        }
      }
      return out;
    });

/// Extract every transport-protocol + port reference (e.g.
/// `tcp/443`, `udp/53`, `sctp/2904`) from each selected line.
/// Useful for firewall-rule audits, port-inventory scrapes,
/// IANA service-port doc reviews, and security-group spec
/// authoring.
///
/// Recognition: `\b(?:tcp|udp|sctp)/\d{1,5}\b`
/// - Protocol prefix: one of `tcp`, `udp`, `sctp` (lowercase
///   per IANA convention).
/// - Literal `/` separator.
/// - 1-5 digit port number. Real ports are 1-65535; the regex
///   doesn't bound-check the numeric value (so `tcp/99999`
///   would also match) but documented limit allows downstream
///   range checks if precision matters.
///
/// Matches:
/// - `tcp/443`     — HTTPS
/// - `tcp/22`      — SSH
/// - `udp/53`      — DNS
/// - `udp/123`     — NTP
/// - `sctp/2904`   — M3UA / Signalling
///
/// Uppercase prefixes (`TCP/443`) and bare port numbers
/// (`:443`) are NOT matched. Use the proto-prefix form when
/// authoring firewall rules so this extractor can find them.
///
/// 111th member of the extraction family.
SortLinesResult extractTcpUdpPortsFromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(r'\b(?:tcp|udp|sctp)/\d{1,5}\b');
      final out = <String>[];
      for (final l in lines) {
        for (final m in re.allMatches(l)) {
          out.add(m.group(0)!);
        }
      }
      return out;
    });
