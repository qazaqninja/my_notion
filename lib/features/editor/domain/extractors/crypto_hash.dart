// Crypto / hash identifier extractors — pulled out of
// `source_line_ops.dart` at M1177 as the third step of the FS-02
// split (geographic at M1175, bibliographic at M1176). Each function
// preserves the `(String text, int start, int end) -> SortLinesResult`
// contract and is re-exported from `source_line_ops.dart` so callers
// (dispatch switch, slash entries, tests) need no import changes.
//
// Group rationale: Bitcoin / Ethereum addresses and content-addressing
// hashes (SHA-256) all live in the "cryptographic identifier" space —
// each maps a binary key to a printable form via a different base
// (base58 / hex). Doc-audit use cases (wallet inventory, supply-chain
// verification, web3 reference scraping) overlap.

import '../source_line_ops.dart';

/// Extract every Bitcoin address substring from each selected
/// line. Covers the three dominant address formats:
/// - Legacy P2PKH: `1` + 25-34 base58 chars
/// - P2SH: `3` + 25-34 base58 chars
/// - Bech32 (SegWit): `bc1` + 39-59 lowercase chars
///
/// Useful for crypto-transaction docs, wallet inventory, and
/// "is there a public address leaked here?" sweeps.
///
/// Recognition:
///   `\b(?:[13][1-9A-HJ-NP-Za-km-z]{25,34}|bc1[a-z0-9]{39,59})\b`
/// - Word boundaries on each end.
/// - Legacy / P2SH: base58 character class (no `0`, `O`, `I`,
///   `l` — Bitcoin's confusable-char exclusion).
/// - Bech32: lowercase alphanumeric (the full spec is more
///   restrictive but `[a-z0-9]` covers the practical space
///   without false-positive risk in non-bech32 text).
///
/// 79th member of the extraction family.
SortLinesResult extractBitcoinAddressesFromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(
        r'\b(?:[13][1-9A-HJ-NP-Za-km-z]{25,34}|bc1[a-z0-9]{39,59})\b',
      );
      final out = <String>[];
      for (final l in lines) {
        for (final m in re.allMatches(l)) {
          out.add(m.group(0)!);
        }
      }
      return out;
    });

/// Extract every Ethereum address (`0x` + 40 hex chars) from
/// each selected line. Useful for web3 doc audits, smart-contract
/// reviews, NFT-collection inventories, and on-chain reference
/// harvests in postmortem notes.
///
/// Recognition: `\b0x[0-9a-fA-F]{40}\b`
/// - Literal `0x` prefix (the canonical Ethereum / EVM scheme).
/// - Exactly 40 hexadecimal characters (160-bit address).
/// - Mixed case allowed: Ethereum uses EIP-55 checksum casing
///   so addresses commonly contain both upper- and lower-case
///   letters. The regex preserves whatever casing appears.
///
/// 41 hex chars (too long) and 39 hex chars (too short) are
/// rejected by the word boundary plus exact `{40}` quantifier.
///
/// Distinct from [extractBitcoinAddressesFromLinesIn] (base58
/// P2PKH / P2SH / bech32 shapes). Ethereum's hex format is its
/// own surface.
///
/// 93rd member of the extraction family.
SortLinesResult extractEthereumAddressesFromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(r'\b0x[0-9a-fA-F]{40}\b');
      final out = <String>[];
      for (final l in lines) {
        for (final m in re.allMatches(l)) {
          out.add(m.group(0)!);
        }
      }
      return out;
    });

/// Extract every SHA-256 hash (64 hex chars) from each
/// selected line. Useful for content-addressing audits,
/// file-integrity reference inventories, container-image
/// digest harvests (`@sha256:...`), and supply-chain
/// verification trails.
///
/// Recognition: `\b[0-9a-fA-F]{64}\b` — exactly 64
/// hexadecimal characters, surrounded by word boundaries.
/// Mixed case allowed (canonical is lowercase but some tools
/// emit uppercase).
///
/// Matches:
/// - `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`
///   (SHA-256 of empty string)
/// - Bare container image digests after the `sha256:` prefix
///   in `image@sha256:<digest>` form (the prefix itself is
///   not captured).
///
/// Distinct from `extractGitShasFromLinesIn` (M1063 — 7-40
/// hex chars for git SHA-1) and
/// [extractEthereumAddressesFromLinesIn] (M1157 — `0x`-prefixed
/// 40 hex). The exact 64-char length disambiguates from those
/// neighbouring surfaces.
///
/// 104th member of the extraction family.
SortLinesResult extractSha256FromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(r'\b[0-9a-fA-F]{64}\b');
      final out = <String>[];
      for (final l in lines) {
        for (final m in re.allMatches(l)) {
          out.add(m.group(0)!);
        }
      }
      return out;
    });

/// Extract every MD5 hash (32 hex chars) from each selected
/// line. Useful for file-integrity audits, password-hash
/// inventories (where MD5 is unfortunately still used), and
/// content-id harvests from older systems.
///
/// Recognition: `\b[0-9a-fA-F]{32}\b` — exactly 32 hex chars
/// surrounded by word boundaries. Mixed case allowed.
///
/// Matches:
/// - `d41d8cd98f00b204e9800998ecf8427e`  (MD5 of empty string)
/// - Hyphenless UUIDs technically match this shape — `123e4567`
///   `e89b12d3a456426614174000` (an 8-4-4-4-12 UUID with hyphens
///   stripped). For audits where the distinction matters, use
///   the UUID extractor first to pull canonical-form UUIDs and
///   then this extractor for the hyphenless residue.
///
/// Distinct from SHA-1 / git refs (M1063 — 7-40 hex) and SHA-256
/// (M1168 — exactly 64 hex). The fixed 32-char length pins down
/// MD5 specifically.
///
/// MD5 is cryptographically broken (RFC 6151) and should not be
/// used for security purposes. This extractor exists for
/// inventory / audit needs only.
///
/// 110th member of the extraction family — round milestone.
SortLinesResult extractMd5FromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(r'\b[0-9a-fA-F]{32}\b');
      final out = <String>[];
      for (final l in lines) {
        for (final m in re.allMatches(l)) {
          out.add(m.group(0)!);
        }
      }
      return out;
    });
