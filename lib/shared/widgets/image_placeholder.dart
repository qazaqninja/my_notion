import 'package:flutter/material.dart';

import '../theme/quill_tokens.dart';
import '../theme/tokens.dart';

/// Striped placeholder with a mono caption. Matches `ImagePlaceholder` from
/// `primitives.jsx:233-244`. Diagonal 8-px stripes via [CustomPainter].
class ImagePlaceholder extends StatelessWidget {
  const ImagePlaceholder({super.key, required this.label, this.height = 120});

  final String label;
  final double height;

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _StripesPainter(
          // Inverse-of-bg stripe wash — same evaluation as the
          // black/white toggle pattern.
          stripe: tokens.text.withValues(alpha: 0.025),
          border: tokens.divider2,
        ),
        child: Center(
          child: Text(label, style: mono(fontSize: 11, color: tokens.text3)),
        ),
      ),
    );
  }
}

class _StripesPainter extends CustomPainter {
  _StripesPainter({required this.stripe, required this.border});

  final Color stripe;
  final Color border;

  @override
  void paint(Canvas canvas, Size size) {
    final r = const Radius.circular(4);
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, r);

    canvas.save();
    canvas.clipRRect(rrect);
    final stripePaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = stripe
      ..strokeWidth = 8;
    const step = 16.0;
    final diag = size.width + size.height;
    for (double x = -diag; x < diag; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), stripePaint);
    }
    canvas.restore();

    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = border
      ..strokeWidth = 0.5;
    // Dashed border — simulate with dashes via PathMetrics.
    final path = Path()..addRRect(rrect);
    _drawDashed(canvas, path, borderPaint, dash: 4, gap: 3);
  }

  void _drawDashed(Canvas canvas, Path src, Paint paint, {required double dash, required double gap}) {
    for (final metric in src.computeMetrics()) {
      double dist = 0;
      while (dist < metric.length) {
        final next = (dist + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(dist, next), paint);
        dist = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_StripesPainter old) => old.stripe != stripe || old.border != border;
}
