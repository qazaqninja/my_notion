import 'package:flutter/material.dart' hide Page;

import '../../../../shared/theme/quill_tokens.dart';
import '../../../../shared/theme/tokens.dart';
import '../../../../shared/widgets/frontmatter_row.dart' as fr;
import '../../../../shared/widgets/quill_icon.dart';
import '../../../../shared/widgets/relation_chip.dart';
import '../../../../shared/widgets/segment.dart';
import '../../../vault/domain/entities/frontmatter.dart';
import '../../../vault/domain/entities/frontmatter_entry.dart' as fe;
import '../../../vault/domain/entities/page.dart';

enum PropertiesView { fields, yaml }

/// Right-side slide-in panel. Matches `overlays.jsx:127-216` —
/// header → Fields/YAML segment → body → relations → file actions.
class PropertiesPanel extends StatefulWidget {
  const PropertiesPanel({
    super.key,
    required this.page,
    required this.onClose,
  });

  final Page page;
  final VoidCallback onClose;

  @override
  State<PropertiesPanel> createState() => _PropertiesPanelState();
}

class _PropertiesPanelState extends State<PropertiesPanel> {
  PropertiesView _view = PropertiesView.fields;

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    return Container(
      width: 340,
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border(left: BorderSide(color: tokens.divider2, width: 0.5)),
        boxShadow: [
          BoxShadow(
            color: tokens.isDark
                ? Colors.black.withValues(alpha: 0.35)
                : Colors.black.withValues(alpha: 0.06),
            blurRadius: 28,
            offset: const Offset(-8, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: tokens.divider, width: 0.5)),
            ),
            child: Row(
              children: [
                QuillIcon('file-md', size: 14, strokeWidth: 1.7, color: tokens.text3),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.page.title,
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: tokens.text),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Text(
                          widget.page.relativePath,
                          style: mono(fontSize: 10.5, color: tokens.text3),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: widget.onClose,
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  icon: QuillIcon('x', size: 14, strokeWidth: 1.7, color: tokens.text3),
                ),
              ],
            ),
          ),
          // Fields/YAML segment + plus
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: tokens.divider, width: 0.5)),
            ),
            child: Row(
              children: [
                Segment<PropertiesView>(
                  size: SegmentSize.sm,
                  value: _view,
                  onChanged: (v) => setState(() => _view = v),
                  options: const [
                    SegmentOption(value: PropertiesView.fields, label: 'Fields'),
                    SegmentOption(value: PropertiesView.yaml, label: 'YAML', icon: 'code'),
                  ],
                ),
                const Spacer(),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () {},
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  icon: QuillIcon('plus', size: 14, strokeWidth: 1.7, color: tokens.text3),
                ),
              ],
            ),
          ),
          // Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_view == PropertiesView.fields)
                    _fieldsBody(tokens)
                  else
                    _yamlBody(tokens),
                  const SizedBox(height: 18),
                  // Relations rail
                  Text(
                    'RELATIONS',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.0,
                      color: tokens.text3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _relationsList(tokens),
                  const SizedBox(height: 18),
                  Container(height: 0.5, color: tokens.divider),
                  const SizedBox(height: 8),
                  _actionRow(tokens, 'reveal', 'Reveal in Finder', '⌘⇧R'),
                  _actionRow(tokens, 'link', 'Copy ULID link', '⌘L'),
                  _actionRow(tokens, 'export', 'Export .md', ''),
                  _actionRow(tokens, 'trash', 'Move to trash', '⌫'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fieldsBody(QuillTokens tokens) {
    final entries = widget.page.frontmatter.entries
        .where((e) => e.key != 'id')
        .toList();
    if (entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
          'No frontmatter on this page',
          style: TextStyle(fontSize: 13, color: tokens.text3),
        ),
      );
    }
    return Column(
      children: [
        for (final entry in entries)
          fr.FrontmatterRow(
            fieldKey: entry.key,
            type: _mapType(entry.type),
            value: entry.value ?? entry.rawScalar,
            dense: true,
          ),
      ],
    );
  }

  Widget _yamlBody(QuillTokens tokens) {
    final raw = widget.page.frontmatter.rawYaml ?? _regenerate(widget.page.frontmatter);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.bg,
        border: Border.all(color: tokens.divider2, width: 0.5),
        borderRadius: const BorderRadius.all(Radius.circular(5)),
      ),
      child: SelectableText(
        raw,
        style: mono(fontSize: 12.5, color: tokens.text2).copyWith(height: 1.6),
      ),
    );
  }

  String _regenerate(Frontmatter fm) {
    final buf = StringBuffer();
    for (final e in fm.entries) {
      buf.write(e.key);
      buf.write(': ');
      buf.write(e.rawScalar);
      buf.writeln();
    }
    return buf.toString();
  }

  Widget _relationsList(QuillTokens tokens) {
    final rels = <fe.FrontmatterEntry>[
      for (final e in widget.page.frontmatter.entries)
        if (e.type == fe.FrontmatterType.relation) e,
    ];
    if (rels.isEmpty) {
      return Text('—', style: TextStyle(fontSize: 12, color: tokens.text3));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final r in rels)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: RelationChip(
              label: '${r.value}',
              ulid: '${r.value}',
              icon: 'file-md',
              prefix: r.key,
            ),
          ),
      ],
    );
  }

  Widget _actionRow(QuillTokens tokens, String icon, String label, String hint) {
    return GestureDetector(
      onTap: () {},
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
          child: Row(
            children: [
              QuillIcon(icon, size: 13, strokeWidth: 1.7, color: tokens.text2),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 13, color: tokens.text2),
                ),
              ),
              if (hint.isNotEmpty)
                Text(hint, style: mono(fontSize: 11, color: tokens.text3)),
            ],
          ),
        ),
      ),
    );
  }

  fr.FrontmatterDisplayType _mapType(fe.FrontmatterType t) => switch (t) {
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
