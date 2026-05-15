import 'package:flutter/material.dart';

import '../../../../shared/theme/quill_tokens.dart';
import '../../../../shared/theme/tokens.dart';
import '../../../../shared/widgets/frontmatter_row.dart' as fr;
import '../../../../shared/widgets/quill_icon.dart';
import '../../../vault/domain/entities/frontmatter.dart';
import '../../../vault/domain/entities/frontmatter_entry.dart' as fe;

/// Collapsible card showing the page's YAML frontmatter as a type-aware
/// list of rows. Read-only in v1 — editing frontmatter happens in the
/// Properties panel (M10).
class FrontmatterCard extends StatefulWidget {
  const FrontmatterCard({super.key, required this.frontmatter, this.showUlid = false});

  final Frontmatter frontmatter;
  final bool showUlid;

  @override
  State<FrontmatterCard> createState() => _FrontmatterCardState();
}

class _FrontmatterCardState extends State<FrontmatterCard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    if (widget.frontmatter.isEmpty) return const SizedBox.shrink();

    final visibleEntries = widget.frontmatter.entries
        .where((e) => widget.showUlid || e.key != 'id')
        .toList();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border.all(color: tokens.divider2, width: 0.5),
        borderRadius: const BorderRadius.all(Radius.circular(6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Tooltip(
                message: _expanded ? 'Collapse frontmatter' : 'Expand frontmatter',
                waitDuration: const Duration(milliseconds: 600),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    // Inverse-of-bg wash so the chrome reads as a band
                    // against the surface; `tokens.text` is dark on
                    // light + light on dark, evaluating identically.
                    color: tokens.text
                        .withValues(alpha: tokens.isDark ? 0.02 : 0.015),
                    border: _expanded
                        ? Border(bottom: BorderSide(color: tokens.divider, width: 0.5))
                        : null,
                  ),
                  child: Row(
                    children: [
                      AnimatedRotation(
                        turns: _expanded ? 0 : -0.25,
                        duration: const Duration(milliseconds: 120),
                        child: QuillIcon('caret-down',
                            size: 11,
                            strokeWidth: 1.8,
                            color: tokens.text3),
                      ),
                      const SizedBox(width: 8),
                      Text('frontmatter', style: mono(fontSize: 12, color: tokens.text3)),
                      const Spacer(),
                      Text(
                        '${widget.frontmatter.entries.length} ${widget.frontmatter.entries.length == 1 ? 'field' : 'fields'}',
                        style: mono(fontSize: 11, color: tokens.text3.withValues(alpha: 0.7)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Column(
                children: [
                  for (final entry in visibleEntries) _row(entry),
                ],
              ),
            ),
        ],
      ),
    );
  }

  fr.FrontmatterRow _row(fe.FrontmatterEntry entry) {
    return fr.FrontmatterRow(
      fieldKey: entry.key,
      type: _mapType(entry.type),
      value: entry.value ?? entry.rawScalar,
      showUlid: widget.showUlid,
    );
  }

  fr.FrontmatterDisplayType _mapType(fe.FrontmatterType t) {
    return switch (t) {
      fe.FrontmatterType.ulid => fr.FrontmatterDisplayType.ulid,
      fe.FrontmatterType.text => fr.FrontmatterDisplayType.text,
      fe.FrontmatterType.number => fr.FrontmatterDisplayType.number,
      fe.FrontmatterType.date => fr.FrontmatterDisplayType.date,
      fe.FrontmatterType.select => fr.FrontmatterDisplayType.select,
      fe.FrontmatterType.multi => fr.FrontmatterDisplayType.multi,
      fe.FrontmatterType.relation => fr.FrontmatterDisplayType.relation,
      fe.FrontmatterType.checkbox => fr.FrontmatterDisplayType.checkbox,
      fe.FrontmatterType.formula => fr.FrontmatterDisplayType.formula,
      fe.FrontmatterType.file => fr.FrontmatterDisplayType.file,
    };
  }
}
