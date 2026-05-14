import 'dart:io';

import 'package:flutter/material.dart';

import '../theme/quill_tokens.dart';
import 'quill_icon.dart';

/// Renders a page's icon. Supported encodings (read from frontmatter `icon:`):
///
/// - A short string (≤4 chars / single emoji): rendered as text.
/// - A path starting with `assets/` or `Assets/`: rendered as Image.asset.
/// - An absolute path or http/https URL: rendered via `FileImage` /
///   `NetworkImage`.
/// - Anything else: falls back to the QuillIcon named by [fallback].
class PageIcon extends StatelessWidget {
  const PageIcon({
    super.key,
    required this.iconValue,
    this.size = 18,
    this.fallback = 'file-md',
    this.vaultRoot,
  });

  /// Raw value from frontmatter. Null/empty → fallback icon.
  final String? iconValue;
  final double size;
  final String fallback;

  /// When provided, relative `icon:` paths are resolved against this root.
  final String? vaultRoot;

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    final value = iconValue?.trim();
    if (value == null || value.isEmpty) {
      return QuillIcon(fallback, size: size, strokeWidth: 1.7, color: tokens.text3);
    }
    // Short text → emoji or initials.
    if (value.length <= 4 && !value.contains('/')) {
      return SizedBox(
        width: size,
        height: size,
        child: Center(
          child: Text(
            value,
            style: TextStyle(fontSize: size * 0.85, height: 1, color: tokens.text),
          ),
        ),
      );
    }
    // URL.
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return SizedBox(
        width: size,
        height: size,
        child: ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(3)),
          child: Image.network(value, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  QuillIcon(fallback, size: size, color: tokens.text3)),
        ),
      );
    }
    // Bundled asset.
    if (value.startsWith('assets/') || value.startsWith('Assets/')) {
      return SizedBox(
        width: size,
        height: size,
        child: ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(3)),
          child: Image.asset(value, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  QuillIcon(fallback, size: size, color: tokens.text3)),
        ),
      );
    }
    // Vault-relative or absolute filesystem path.
    final resolved = value.startsWith('/') || vaultRoot == null
        ? value
        : '$vaultRoot/$value';
    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(3)),
        child: Image.file(File(resolved), fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                QuillIcon(fallback, size: size, color: tokens.text3)),
      ),
    );
  }
}

/// Hero band shown at the top of a page, sourced from frontmatter `cover:`.
/// Returns SizedBox.shrink if no cover.
class PageCoverBand extends StatelessWidget {
  const PageCoverBand({
    super.key,
    required this.coverValue,
    this.vaultRoot,
    this.height = 180,
  });

  final String? coverValue;
  final String? vaultRoot;
  final double height;

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    final v = coverValue?.trim();
    if (v == null || v.isEmpty) return const SizedBox.shrink();
    final ImageProvider provider;
    if (v.startsWith('http://') || v.startsWith('https://')) {
      provider = NetworkImage(v);
    } else if (v.startsWith('assets/') || v.startsWith('Assets/')) {
      provider = AssetImage(v);
    } else {
      final resolved = v.startsWith('/') || vaultRoot == null
          ? v
          : '$vaultRoot/$v';
      provider = FileImage(File(resolved));
    }
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: tokens.surface2,
        image: DecorationImage(image: provider, fit: BoxFit.cover),
      ),
    );
  }
}
