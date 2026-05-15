import 'package:flutter/material.dart';

import '../theme/quill_tokens.dart';
import 'quill_icon.dart';

/// Centered empty-state card with dashed border + glyph tile + title + body
/// + action row. Ports `EmptyBlock` from `feedback.jsx:120-144`.
class QuillEmptyBlock extends StatelessWidget {
  const QuillEmptyBlock({
    super.key,
    required this.glyph,
    required this.title,
    required this.body,
    this.actions,
    this.maxWidth = 460,
  });

  final String glyph;
  final String title;
  final String body;
  final List<Widget>? actions;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Container(
        padding: const EdgeInsets.fromLTRB(28, 36, 28, 32),
        decoration: ShapeDecoration(
          color: tokens.surface,
          shape: _DashedRoundedRectangleBorder(
            color: tokens.divider2,
            radius: 8,
            dashWidth: 4,
            dashGap: 3,
            strokeWidth: 0.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: tokens.bg,
                border: Border.all(color: tokens.divider2, width: 0.5),
                borderRadius: const BorderRadius.all(Radius.circular(8)),
              ),
              alignment: Alignment.center,
              child: QuillIcon(glyph,
                  size: 18, strokeWidth: 1.6, color: tokens.text3),
            ),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w600,
                color: tokens.text,
              ),
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Text(
                body,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: tokens.text3,
                  height: 1.55,
                ),
              ),
            ),
            if (actions != null && actions!.isNotEmpty) ...[
              const SizedBox(height: 14),
              Wrap(spacing: 8, runSpacing: 8, children: actions!),
            ],
          ],
        ),
      ),
    );
  }
}

/// Painter-based dashed border. Flutter doesn't ship one for rounded rects;
/// this draws a dashed `RRect` path with [dashWidth] on/[dashGap] off.
class _DashedRoundedRectangleBorder extends OutlinedBorder {
  const _DashedRoundedRectangleBorder({
    required this.color,
    required this.radius,
    required this.dashWidth,
    required this.dashGap,
    required this.strokeWidth,
  }) : super(side: BorderSide.none);

  final Color color;
  final double radius;
  final double dashWidth;
  final double dashGap;
  final double strokeWidth;

  @override
  ShapeBorder scale(double t) => _DashedRoundedRectangleBorder(
        color: color,
        radius: radius * t,
        dashWidth: dashWidth * t,
        dashGap: dashGap * t,
        strokeWidth: strokeWidth * t,
      );

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(strokeWidth);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path()
      ..addRRect(RRect.fromRectAndRadius(
        rect.deflate(strokeWidth),
        Radius.circular(radius),
      ));
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    return Path()
      ..addRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(radius)),
      );
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    final metrics = path.computeMetrics();
    for (final m in metrics) {
      double distance = 0;
      while (distance < m.length) {
        final next = distance + dashWidth;
        canvas.drawPath(
          m.extractPath(distance, next.clamp(0, m.length)),
          paint,
        );
        distance = next + dashGap;
      }
    }
  }

  @override
  OutlinedBorder copyWith({BorderSide? side}) => this;
}
