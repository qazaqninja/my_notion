import 'package:flutter/material.dart';

import '../theme/quill_tokens.dart';
import '../theme/tokens.dart';
import 'quill_icon.dart';

class SideItemGlyph {
  const SideItemGlyph({required this.color, required this.letter});
  final Color color;
  final String letter;
}

enum SideDensity { comfy, compact }

enum SideChevron { none, closed, open }

/// Sidebar row — file/folder/database/generic. Matches `SideItem` from
/// `primitives.jsx:70-107`.
class SideItem extends StatelessWidget {
  const SideItem({
    super.key,
    this.density = SideDensity.comfy,
    this.icon,
    this.glyph,
    required this.label,
    this.count,
    this.chevron = SideChevron.none,
    this.active = false,
    this.mute = false,
    this.level = 0,
    this.onTap,
  });

  final SideDensity density;
  final String? icon;
  final SideItemGlyph? glyph;
  final String label;
  final int? count;
  final SideChevron chevron;
  final bool active;
  final bool mute;
  final int level;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    final padY = density == SideDensity.compact ? 3.0 : 5.0;
    final fs = density == SideDensity.compact ? 13.0 : 13.5;
    final color = active ? tokens.text : (mute ? tokens.text3 : tokens.text2);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        padding: EdgeInsets.fromLTRB(10 + level * 14, padY, 10, padY),
        decoration: BoxDecoration(
          color: active ? tokens.selected : Colors.transparent,
          borderRadius: const BorderRadius.all(Radius.circular(5)),
        ),
        child: Row(
          children: [
            if (chevron != SideChevron.none)
              SizedBox(
                width: 14,
                child: Transform.rotate(
                  angle: chevron == SideChevron.open ? 1.5708 : 0, // 90deg
                  child: QuillIcon('caret', size: 11, strokeWidth: 1.8, color: tokens.text3),
                ),
              )
            else
              const SizedBox(width: 14),
            if (glyph != null) ...[
              Container(
                width: 14,
                height: 14,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: glyph!.color,
                  borderRadius: const BorderRadius.all(Radius.circular(3.5)),
                ),
                child: Text(
                  glyph!.letter,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14 * 0.62,
                    height: 1,
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ] else if (icon != null) ...[
              QuillIcon(icon!, size: 14, strokeWidth: 1.7, color: tokens.text3),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: fs,
                  fontWeight: active ? FontWeight.w500 : FontWeight.w400,
                  height: 1.3,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                softWrap: false,
              ),
            ),
            if (count != null)
              Text('$count', style: mono(fontSize: 11, color: tokens.text3)),
          ],
        ),
      ),
    );
  }
}
