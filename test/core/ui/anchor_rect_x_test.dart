import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/core/ui/anchor_rect_x.dart';

void main() {
  group('anchorRectFromRect', () {
    test('maps left/top/right/bottom verbatim', () {
      const r = Rect.fromLTWH(10, 20, 300, 40);
      final a = anchorRectFromRect(r);
      expect(a.left, 10);
      expect(a.top, 20);
      expect(a.right, 310);
      expect(a.bottom, 60);
    });

    test('zero rect maps to zero anchor', () {
      final a = anchorRectFromRect(Rect.zero);
      expect(a.left, 0);
      expect(a.top, 0);
      expect(a.right, 0);
      expect(a.bottom, 0);
    });

    test('width/height getters round-trip the source rect', () {
      const r = Rect.fromLTWH(5, 7, 100, 25);
      final a = anchorRectFromRect(r);
      expect(a.width, 100);
      expect(a.height, 25);
    });

    test('negative offsets are preserved', () {
      // Off-screen anchors are still valid; caller decides what to clamp.
      const r = Rect.fromLTWH(-50, -10, 200, 20);
      final a = anchorRectFromRect(r);
      expect(a.left, -50);
      expect(a.top, -10);
    });
  });

  group('RectAnchor extension', () {
    test('.toAnchor() returns the same AnchorRect as the free function', () {
      const r = Rect.fromLTWH(8, 16, 240, 32);
      expect(r.toAnchor(), anchorRectFromRect(r));
    });
  });
}
