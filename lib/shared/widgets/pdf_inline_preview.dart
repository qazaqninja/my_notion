import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

/// Inline PDF first-page preview surfaced inside `_FileAttachment`'s M201
/// PDF card. Renders only the first page (small, fixed-height) as a quick
/// visual confirmation — full multi-page navigation happens in the external
/// OS reader via the surrounding card's `_open()` tap handler.
///
/// Why a thumbnail instead of `PdfView`?
/// - PdfView is built for full-screen reading: it manages a Pageable
///   controller, swipe gestures, zoom, and scroll physics. Inside a 220-px
///   card it would over-render and steal the parent's gesture surface.
/// - A first-page raster fits the M201 visual contract (banded coloured
///   thumbnail) and keeps tap-to-open semantics intact for the rest of the
///   card.
///
/// Lifecycle:
/// 1. `initState` calls `PdfDocument.openFile(path)`.
/// 2. While the future is pending, render a fixed-height placeholder with a
///    `CircularProgressIndicator`.
/// 3. On resolve, `document.getPage(1)` → `page.render(width, height)` → an
///    `Image.memory(bytes)` is built and shown.
/// 4. On error, an error placeholder appears; the surrounding card's
///    "tap to open externally" still works.
/// 5. `dispose` closes the document and any in-flight page.
class PdfInlinePreview extends StatefulWidget {
  const PdfInlinePreview({
    super.key,
    required this.filePath,
    this.height = 220,
  });

  /// Absolute file path. Vault-relative paths must be resolved before
  /// construction.
  final String filePath;

  /// Card-band height. Defaults to 220 to match M201 PDF card's vertical
  /// rhythm.
  final double height;

  @override
  State<PdfInlinePreview> createState() => _PdfInlinePreviewState();
}

class _PdfInlinePreviewState extends State<PdfInlinePreview> {
  PdfDocument? _doc;
  PdfPageImage? _pageImage;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final doc = await PdfDocument.openFile(widget.filePath);
      if (!mounted) {
        await doc.close();
        return;
      }
      _doc = doc;
      final page = await doc.getPage(1);
      try {
        final image = await page.render(
          width: page.width * 1.5,
          height: page.height * 1.5,
          format: PdfPageImageFormat.png,
        );
        if (!mounted) return;
        setState(() => _pageImage = image);
      } finally {
        await page.close();
      }
    } catch (err) {
      if (mounted) setState(() => _error = err);
    }
  }

  @override
  void dispose() {
    _doc?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return SizedBox(
        height: widget.height,
        child: Center(
          child: Text(
            'PDF preview unavailable',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ),
      );
    }
    if (_pageImage == null) {
      return SizedBox(
        height: widget.height,
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: Image.memory(
        _pageImage!.bytes,
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
      ),
    );
  }
}
