import 'package:flutter/material.dart';

// ────────────────────────────────────────────────────────────────────────────
// Tiny SVG-path-d parser. Supports M m L l H h V v C c S s Q q T t A a Z z.
// Sufficient for the icon set ported from `icons.jsx`.
// ────────────────────────────────────────────────────────────────────────────

Path _parseSvgPath(String d) {
  final path = Path();
  final tokens = _tokenise(d);
  double cx = 0, cy = 0;
  double startX = 0, startY = 0;
  double? lastCtrlX, lastCtrlY;
  String? last;

  int i = 0;
  while (i < tokens.length) {
    final tok = tokens[i];
    if (_isCmd(tok)) {
      last = tok;
      i++;
      continue;
    }
    if (last == null) {
      i++;
      continue;
    }
    final cmd = last;
    switch (cmd) {
      case 'M':
      case 'm':
        final x = double.parse(tokens[i++]);
        final y = double.parse(tokens[i++]);
        cx = cmd == 'M' ? x : cx + x;
        cy = cmd == 'M' ? y : cy + y;
        path.moveTo(cx, cy);
        startX = cx;
        startY = cy;
        last = cmd == 'M' ? 'L' : 'l';
        break;
      case 'L':
      case 'l':
        final x = double.parse(tokens[i++]);
        final y = double.parse(tokens[i++]);
        cx = cmd == 'L' ? x : cx + x;
        cy = cmd == 'L' ? y : cy + y;
        path.lineTo(cx, cy);
        break;
      case 'H':
      case 'h':
        final x = double.parse(tokens[i++]);
        cx = cmd == 'H' ? x : cx + x;
        path.lineTo(cx, cy);
        break;
      case 'V':
      case 'v':
        final y = double.parse(tokens[i++]);
        cy = cmd == 'V' ? y : cy + y;
        path.lineTo(cx, cy);
        break;
      case 'C':
      case 'c':
        final x1 = double.parse(tokens[i++]);
        final y1 = double.parse(tokens[i++]);
        final x2 = double.parse(tokens[i++]);
        final y2 = double.parse(tokens[i++]);
        final x = double.parse(tokens[i++]);
        final y = double.parse(tokens[i++]);
        final c1x = cmd == 'C' ? x1 : cx + x1;
        final c1y = cmd == 'C' ? y1 : cy + y1;
        final c2x = cmd == 'C' ? x2 : cx + x2;
        final c2y = cmd == 'C' ? y2 : cy + y2;
        final ex = cmd == 'C' ? x : cx + x;
        final ey = cmd == 'C' ? y : cy + y;
        path.cubicTo(c1x, c1y, c2x, c2y, ex, ey);
        lastCtrlX = c2x;
        lastCtrlY = c2y;
        cx = ex;
        cy = ey;
        break;
      case 'S':
      case 's':
        final x2 = double.parse(tokens[i++]);
        final y2 = double.parse(tokens[i++]);
        final x = double.parse(tokens[i++]);
        final y = double.parse(tokens[i++]);
        final reflectX = (lastCtrlX != null) ? 2 * cx - lastCtrlX : cx;
        final reflectY = (lastCtrlY != null) ? 2 * cy - lastCtrlY : cy;
        final c2x = cmd == 'S' ? x2 : cx + x2;
        final c2y = cmd == 'S' ? y2 : cy + y2;
        final ex = cmd == 'S' ? x : cx + x;
        final ey = cmd == 'S' ? y : cy + y;
        path.cubicTo(reflectX, reflectY, c2x, c2y, ex, ey);
        lastCtrlX = c2x;
        lastCtrlY = c2y;
        cx = ex;
        cy = ey;
        break;
      case 'Q':
      case 'q':
        final x1 = double.parse(tokens[i++]);
        final y1 = double.parse(tokens[i++]);
        final x = double.parse(tokens[i++]);
        final y = double.parse(tokens[i++]);
        final c1x = cmd == 'Q' ? x1 : cx + x1;
        final c1y = cmd == 'Q' ? y1 : cy + y1;
        final ex = cmd == 'Q' ? x : cx + x;
        final ey = cmd == 'Q' ? y : cy + y;
        path.quadraticBezierTo(c1x, c1y, ex, ey);
        lastCtrlX = c1x;
        lastCtrlY = c1y;
        cx = ex;
        cy = ey;
        break;
      case 'A':
      case 'a':
        final rx = double.parse(tokens[i++]);
        final ry = double.parse(tokens[i++]);
        final xRot = double.parse(tokens[i++]);
        final largeArc = double.parse(tokens[i++]) != 0;
        final sweep = double.parse(tokens[i++]) != 0;
        final x = double.parse(tokens[i++]);
        final y = double.parse(tokens[i++]);
        final ex = cmd == 'A' ? x : cx + x;
        final ey = cmd == 'A' ? y : cy + y;
        path.arcToPoint(
          Offset(ex, ey),
          radius: Radius.elliptical(rx, ry),
          rotation: xRot,
          largeArc: largeArc,
          clockwise: sweep,
        );
        cx = ex;
        cy = ey;
        break;
      case 'Z':
      case 'z':
        path.close();
        cx = startX;
        cy = startY;
        break;
      default:
        i++;
    }
  }
  return path;
}

bool _isCmd(String s) {
  if (s.length != 1) return false;
  final c = s.codeUnitAt(0);
  return (c >= 65 && c <= 90) || (c >= 97 && c <= 122);
}

List<String> _tokenise(String d) {
  final tokens = <String>[];
  final buf = StringBuffer();
  void flush() {
    if (buf.isNotEmpty) {
      tokens.add(buf.toString());
      buf.clear();
    }
  }

  for (int i = 0; i < d.length; i++) {
    final ch = d[i];
    final code = d.codeUnitAt(i);
    final isAlpha = (code >= 65 && code <= 90) || (code >= 97 && code <= 122);
    if (isAlpha) {
      flush();
      tokens.add(ch);
    } else if (ch == ' ' || ch == ',' || ch == '\t' || ch == '\n') {
      flush();
    } else if (ch == '-') {
      // '-' starts a new number unless it follows 'e'/'E' (exponent sign).
      final s = buf.toString();
      if (s.isNotEmpty && !s.endsWith('e') && !s.endsWith('E')) {
        flush();
      }
      buf.write(ch);
    } else if (ch == '.' && buf.toString().contains('.')) {
      // A second '.' starts a new decimal number (handles `.06.06` shorthand).
      flush();
      buf.write(ch);
    } else {
      buf.write(ch);
    }
  }
  flush();
  return tokens;
}

// ────────────────────────────────────────────────────────────────────────────
// Shape sealed hierarchy. One icon = one [_Glyph] = list of [_Shape]s drawn
// in order at a 24×24 viewBox.
// ────────────────────────────────────────────────────────────────────────────

sealed class _Shape {
  const _Shape({this.fill = false});
  final bool fill;
}

class _PathShape extends _Shape {
  const _PathShape(this.d);
  final String d;
}

class _RectShape extends _Shape {
  const _RectShape({required this.x, required this.y, required this.w, required this.h, this.rx = 0});
  final double x, y, w, h, rx;
}

class _CircleShape extends _Shape {
  const _CircleShape({required this.cx, required this.cy, required this.r, super.fill});
  final double cx, cy, r;
}

class _EllipseShape extends _Shape {
  const _EllipseShape({required this.cx, required this.cy, required this.rx, required this.ry});
  final double cx, cy, rx, ry;
}

class _Glyph {
  const _Glyph(this.shapes);
  final List<_Shape> shapes;
}

const Map<String, _Glyph> _glyphs = {
  'caret': _Glyph([_PathShape('M9 6l6 6-6 6')]),
  'caret-down': _Glyph([_PathShape('M6 9l6 6 6-6')]),
  'caret-up': _Glyph([_PathShape('M6 15l6-6 6 6')]),
  'search': _Glyph([
    _CircleShape(cx: 11, cy: 11, r: 6),
    _PathShape('M20 20 l-3.5 -3.5'),
  ]),
  'plus': _Glyph([_PathShape('M12 5v14M5 12h14')]),
  'check': _Glyph([_PathShape('M5 12.5l4.5 4.5L19 7')]),
  'x': _Glyph([_PathShape('M6 6l12 12M18 6l-12 12')]),
  'sidebar': _Glyph([
    _RectShape(x: 3, y: 4, w: 18, h: 16, rx: 2),
    _PathShape('M9 4v16'),
  ]),
  'panel': _Glyph([
    _RectShape(x: 3, y: 4, w: 18, h: 16, rx: 2),
    _PathShape('M15 4v16'),
  ]),
  'folder': _Glyph([
    _PathShape('M3 7a2 2 0 0 1 2-2h4l2 2h8a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z'),
  ]),
  'file': _Glyph([
    _PathShape('M14 3H6a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V9z'),
    _PathShape('M14 3v6h6'),
  ]),
  'file-md': _Glyph([
    _PathShape('M14 3H6a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V9z'),
    _PathShape('M14 3v6h6'),
    _PathShape('M7 14v3M7 14l1.4 2.2L9.8 14v3M12.5 14v3M11.6 16l.9 1 .9-1'),
  ]),
  'database': _Glyph([
    _EllipseShape(cx: 12, cy: 5, rx: 8, ry: 2.5),
    _PathShape('M4 5v6c0 1.4 3.6 2.5 8 2.5s8-1.1 8-2.5V5'),
    _PathShape('M4 11v6c0 1.4 3.6 2.5 8 2.5s8-1.1 8-2.5v-6'),
  ]),
  'table': _Glyph([
    _RectShape(x: 3, y: 4, w: 18, h: 16, rx: 1.5),
    _PathShape('M3 9h18M3 14.5h18M9 4v16'),
  ]),
  'gallery': _Glyph([
    _RectShape(x: 3, y: 4, w: 8, h: 7, rx: 1),
    _RectShape(x: 13, y: 4, w: 8, h: 7, rx: 1),
    _RectShape(x: 3, y: 13, w: 8, h: 7, rx: 1),
    _RectShape(x: 13, y: 13, w: 8, h: 7, rx: 1),
  ]),
  'board': _Glyph([
    _RectShape(x: 3, y: 4, w: 5.5, h: 16, rx: 1.5),
    _RectShape(x: 9.5, y: 4, w: 5, h: 10, rx: 1.5),
    _RectShape(x: 15.5, y: 4, w: 5.5, h: 13, rx: 1.5),
  ]),
  'timeline': _Glyph([_PathShape('M3 7h7M7 12h10M11 17h7')]),
  'list': _Glyph([_PathShape('M5 6h14M5 12h14M5 18h14')]),
  'filter': _Glyph([_PathShape('M3 5h18l-7 9v6l-4-2v-4z')]),
  'sort': _Glyph([_PathShape('M7 4v16M3 16l4 4 4-4M17 20V4M13 8l4-4 4 4')]),
  'group': _Glyph([
    _RectShape(x: 3, y: 4, w: 18, h: 6, rx: 1),
    _RectShape(x: 3, y: 14, w: 11, h: 6, rx: 1),
  ]),
  'kebab': _Glyph([
    _CircleShape(cx: 12, cy: 6, r: 1.2, fill: true),
    _CircleShape(cx: 12, cy: 12, r: 1.2, fill: true),
    _CircleShape(cx: 12, cy: 18, r: 1.2, fill: true),
  ]),
  'kebab-h': _Glyph([
    _CircleShape(cx: 5, cy: 12, r: 1.2, fill: true),
    _CircleShape(cx: 12, cy: 12, r: 1.2, fill: true),
    _CircleShape(cx: 19, cy: 12, r: 1.2, fill: true),
  ]),
  'pin': _Glyph([_PathShape('M12 2v6l3 4v3H9v-3l3-4V2zM12 15v6')]),
  'clock': _Glyph([
    _CircleShape(cx: 12, cy: 12, r: 8),
    _PathShape('M12 8v4l3 2'),
  ]),
  'link': _Glyph([
    _PathShape('M10 13a4 4 0 0 0 5.7 0l3-3a4 4 0 1 0-5.7-5.7L11 6'),
    _PathShape('M14 11a4 4 0 0 0-5.7 0l-3 3a4 4 0 1 0 5.7 5.7l2-2'),
  ]),
  'arrow-right': _Glyph([_PathShape('M5 12h14M13 6l6 6-6 6')]),
  'arrow-up-right': _Glyph([_PathShape('M7 17 L17 7 M9 7h8v8')]),
  'eye': _Glyph([
    _PathShape('M2 12s4-7 10-7 10 7 10 7-4 7-10 7S2 12 2 12z'),
    _CircleShape(cx: 12, cy: 12, r: 3),
  ]),
  'code': _Glyph([_PathShape('M8 18l-6-6 6-6M16 6l6 6-6 6')]),
  'edit': _Glyph([
    _PathShape('M12 20h9'),
    _PathShape('M16.5 3.5a2.1 2.1 0 1 1 3 3L7 19l-4 1 1-4z'),
  ]),
  'gear': _Glyph([
    _CircleShape(cx: 12, cy: 12, r: 3),
    _PathShape(
      'M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 1 1 2.83-2.83l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z',
    ),
  ]),
  'sync': _Glyph([
    _PathShape('M20 11A8 8 0 0 0 6.3 5.3L4 8M4 4v4h4M4 13a8 8 0 0 0 13.7 5.7L20 16M20 20v-4h-4'),
  ]),
  'lock': _Glyph([
    _RectShape(x: 4, y: 11, w: 16, h: 10, rx: 2),
    _PathShape('M8 11V7a4 4 0 0 1 8 0v4'),
  ]),
  'cloud': _Glyph([
    _PathShape('M17 18a4 4 0 0 0 0-8 6 6 0 0 0-11.7 1.5A4 4 0 0 0 6 18z'),
  ]),
  'home': _Glyph([
    _PathShape('M3 11l9-7 9 7v9a2 2 0 0 1-2 2h-4v-7h-6v7H5a2 2 0 0 1-2-2z'),
  ]),
  'inbox': _Glyph([
    _PathShape('M3 13h5l2 3h4l2-3h5'),
    _PathShape('M5 5h14l2 8v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-6z'),
  ]),
  'tag': _Glyph([
    _PathShape('M20 12L12 20a2 2 0 0 1-2.8 0L3 13.8a2 2 0 0 1 0-2.8L11 3l9 1z'),
    _CircleShape(cx: 15.5, cy: 8.5, r: 1.2, fill: true),
  ]),
  'briefcase': _Glyph([
    _RectShape(x: 3, y: 7, w: 18, h: 13, rx: 2),
    _PathShape('M8 7V5a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2M3 13h18'),
  ]),
  'users': _Glyph([
    _CircleShape(cx: 9, cy: 8, r: 3.5),
    _PathShape('M2 21a7 7 0 0 1 14 0M17 11a3 3 0 1 0 0-6M22 21a7 7 0 0 0-5-6.7'),
  ]),
  'calendar': _Glyph([
    _RectShape(x: 3, y: 5, w: 18, h: 16, rx: 2),
    _PathShape('M3 10h18M8 3v4M16 3v4'),
  ]),
  'archive': _Glyph([_PathShape('M3 5h18v4H3zM5 9v10h14V9M10 13h4')]),
  'trash': _Glyph([_PathShape('M4 7h16M9 7V4h6v3M6 7l1 14h10l1-14')]),
  'git': _Glyph([
    _CircleShape(cx: 6, cy: 6, r: 2),
    _CircleShape(cx: 18, cy: 6, r: 2),
    _CircleShape(cx: 12, cy: 18, r: 2),
    _PathShape('M6 8v4a2 2 0 0 0 2 2h8a2 2 0 0 0 2-2V8'),
  ]),
  'note': _Glyph([
    _PathShape('M5 4h10l4 4v12a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V5a1 1 0 0 1 1-1z'),
    _PathShape('M14 4v5h5'),
  ]),
  'square': _Glyph([_RectShape(x: 4, y: 4, w: 16, h: 16, rx: 2)]),
  'checksquare': _Glyph([
    _RectShape(x: 4, y: 4, w: 16, h: 16, rx: 2),
    _PathShape('M8 12l3 3 5-6'),
  ]),
  'dollar': _Glyph([
    _PathShape('M12 3v18M16 7H9.5a2.5 2.5 0 0 0 0 5h5a2.5 2.5 0 0 1 0 5H7'),
  ]),
  'hash': _Glyph([_PathShape('M5 9h14M5 15h14M10 4l-2 16M16 4l-2 16')]),
  'select': _Glyph([
    _PathShape('M5 8l3 3 3-3M5 16l3-3 3 3M14 8h5M14 12h5M14 16h5'),
  ]),
  'reveal': _Glyph([
    _PathShape('M3 7a2 2 0 0 1 2-2h4l2 2h8a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z'),
    _PathShape('M16 12l-3-3M16 12l-3 3M9 12h7'),
  ]),
  'export': _Glyph([_PathShape('M12 3v12M7 8l5-5 5 5M5 21h14')]),
};

/// Calm, minimal stroked icons. 24×24 viewBox, stroke 1.6–1.8 depending on
/// context. Falls back to an outline circle for unknown names.
class QuillIcon extends StatelessWidget {
  const QuillIcon(this.name, {super.key, this.size = 14, this.strokeWidth = 1.7, this.color});

  final String name;
  final double size;
  final double strokeWidth;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? DefaultTextStyle.of(context).style.color ?? Colors.black;
    return CustomPaint(
      size: Size.square(size),
      painter: _IconPainter(name: name, strokeWidth: strokeWidth, color: c),
    );
  }
}

class _IconPainter extends CustomPainter {
  _IconPainter({required this.name, required this.strokeWidth, required this.color});

  final String name;
  final double strokeWidth;
  final Color color;

  static const double _viewBox = 24;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / _viewBox;
    canvas.save();
    canvas.scale(scale);

    final stroke = strokeWidth / scale;
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = color
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = color;

    final glyph = _glyphs[name];
    if (glyph == null) {
      canvas.drawCircle(const Offset(12, 12), 9, strokePaint);
      canvas.restore();
      return;
    }

    for (final shape in glyph.shapes) {
      switch (shape) {
        case _PathShape(:final d):
          canvas.drawPath(_parseSvgPath(d), strokePaint);
        case _RectShape(:final x, :final y, :final w, :final h, :final rx):
          final rrect = RRect.fromRectAndRadius(
            Rect.fromLTWH(x, y, w, h),
            Radius.circular(rx),
          );
          canvas.drawRRect(rrect, shape.fill ? fillPaint : strokePaint);
        case _CircleShape(:final cx, :final cy, :final r):
          canvas.drawCircle(Offset(cx, cy), r, shape.fill ? fillPaint : strokePaint);
        case _EllipseShape(:final cx, :final cy, :final rx, :final ry):
          canvas.drawOval(
            Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2),
            shape.fill ? fillPaint : strokePaint,
          );
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_IconPainter old) =>
      old.name != name || old.strokeWidth != strokeWidth || old.color != color;
}

/// Database glyph — small coloured square with a single capital letter.
/// Matches `DBGlyph` from `icons.jsx:73-82`.
class DBGlyph extends StatelessWidget {
  const DBGlyph({super.key, required this.letter, required this.color, this.size = 16});

  final String letter;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.all(Radius.circular(3.5)),
      ),
      child: Text(
        letter,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.62,
          fontWeight: FontWeight.w600,
          height: 1,
          letterSpacing: 0,
        ),
      ),
    );
  }
}
