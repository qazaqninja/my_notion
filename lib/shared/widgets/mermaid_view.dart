import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../theme/tokens.dart';

/// Renders a mermaid diagram source string. On supported platforms
/// (iOS / Android / macOS) it loads the vendored `mermaid.min.js`
/// (`assets/mermaid/mermaid.min.js`, declared in pubspec) inside a
/// `WebView` and injects the source via JavaScript. On unsupported
/// platforms (Linux / Windows / test environment) it falls back to a
/// styled placeholder card with the source text — matching the M200
/// behaviour that shipped before C1.
///
/// Why a WebView rather than a Dart-side renderer?
/// - Mermaid is a 700KB JS library with complex layout / Bezier curve
///   logic; no production-grade Dart port exists.
/// - WebView's bundle size is negligible (we already need it for future
///   bookmark-card previews) and `mermaid.min.js` runs entirely offline
///   from the vendored asset — no `fonts.gstatic.com`-style network
///   dependency the macOS sandbox blocks.
class MermaidView extends StatefulWidget {
  const MermaidView({
    super.key,
    required this.source,
    this.height = 240,
    this.forceFallback = false,
  });

  /// Raw mermaid diagram source (after the fenced ```` ```mermaid ```` line
  /// and before the closing ` ``` `).
  final String source;

  /// Card-band height. The actual diagram may be shorter; the WebView is
  /// configured to report its `getBoundingClientRect()` so future slices
  /// can shrink-to-fit.
  final double height;

  /// Test-only escape hatch: skip the WebView and render the fallback
  /// regardless of the runtime platform. Used to exercise the styled-card
  /// branch in unit tests.
  final bool forceFallback;

  @override
  State<MermaidView> createState() => _MermaidViewState();
}

class _MermaidViewState extends State<MermaidView> {
  // Nullable on purpose: Linux/Windows/test environments never init it.
  // ignore: use_late_for_private_fields_and_variables
  WebViewController? _controller;

  bool get _isSupportedPlatform {
    if (widget.forceFallback) return false;
    if (kIsWeb) return false; // web app doesn't bundle the WebView plugin
    return Platform.isIOS || Platform.isAndroid || Platform.isMacOS;
  }

  @override
  void initState() {
    super.initState();
    if (_isSupportedPlatform) {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0x00000000))
        ..loadHtmlString(_htmlFor(widget.source));
    }
  }

  /// Build the HTML scaffold injected into the WebView. The body contains a
  /// single `<div id="d">…</div>` whose text is the diagram source. The
  /// vendored `mermaid.min.js` (slice 2 lands the asset) runs
  /// `mermaid.initialize` + `mermaid.run` on DOMContentLoaded, replacing
  /// the div's contents with rendered SVG.
  String _htmlFor(String source) {
    final escaped = source
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
    return '''
<!doctype html>
<html><head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width,initial-scale=1" />
  <style>
    body { margin: 0; padding: 8px; font-family: -apple-system, system-ui, sans-serif; }
    .mermaid { background: transparent; }
  </style>
</head>
<body>
  <div class="mermaid">$escaped</div>
  <script src="mermaid.min.js"></script>
  <script>
    if (window.mermaid) {
      mermaid.initialize({ startOnLoad: true, securityLevel: 'loose' });
    } else {
      document.body.innerHTML += '<p style="color:#c00;font-size:12px">mermaid.min.js not vendored yet (C1 slice 2)</p>';
    }
  </script>
</body></html>
''';
  }

  @override
  Widget build(BuildContext context) {
    if (!_isSupportedPlatform) {
      return _fallbackCard(context);
    }
    return SizedBox(
      height: widget.height,
      child: WebViewWidget(controller: _controller!),
    );
  }

  /// Uses Material's ColorScheme so the fallback renders even outside a
  /// QuillApp-wrapped tree (e.g. in unit tests).
  Widget _fallbackCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        border: Border.all(color: cs.outlineVariant, width: 0.5),
        borderRadius: const BorderRadius.all(Radius.circular(6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'mermaid (rendering not supported on this platform)',
            style: mono(fontSize: 10, color: cs.outline),
          ),
          const SizedBox(height: 6),
          SelectableText(widget.source, style: mono(fontSize: 12)),
        ],
      ),
    );
  }
}
