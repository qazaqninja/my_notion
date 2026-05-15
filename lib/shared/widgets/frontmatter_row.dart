import 'package:flutter/material.dart';

import '../theme/quill_tokens.dart';
import '../theme/tag_colors.dart';
import '../theme/tokens.dart';
import 'quill_icon.dart';
import 'relation_chip.dart';
import 'tag_chip.dart';

/// Visual frontmatter value type — used by both editor and properties panel.
/// (Distinct from the domain [FrontmatterType] in `features/vault/domain` —
/// this version only encodes how the value renders.)
enum FrontmatterDisplayType { ulid, text, number, date, select, multi, relation, formula, file, checkbox }

String _iconForType(FrontmatterDisplayType type) => switch (type) {
      FrontmatterDisplayType.ulid => 'hash',
      FrontmatterDisplayType.text => 'note',
      FrontmatterDisplayType.number => 'hash',
      FrontmatterDisplayType.date => 'calendar',
      FrontmatterDisplayType.select => 'select',
      FrontmatterDisplayType.multi => 'tag',
      FrontmatterDisplayType.relation => 'link',
      FrontmatterDisplayType.formula => 'code',
      FrontmatterDisplayType.file => 'file',
      FrontmatterDisplayType.checkbox => 'checksquare',
    };

String _labelForType(FrontmatterDisplayType type) => switch (type) {
      FrontmatterDisplayType.ulid => 'ULID',
      FrontmatterDisplayType.text => 'text',
      FrontmatterDisplayType.number => 'number',
      FrontmatterDisplayType.date => 'date',
      FrontmatterDisplayType.select => 'select',
      FrontmatterDisplayType.multi => 'multi-select',
      FrontmatterDisplayType.relation => 'relation',
      FrontmatterDisplayType.formula => 'formula',
      FrontmatterDisplayType.file => 'file',
      FrontmatterDisplayType.checkbox => 'checkbox',
    };

/// Single frontmatter field row — type-aware. Matches `FrontmatterRow` from
/// `primitives.jsx:174-198`.
class FrontmatterRow extends StatelessWidget {
  const FrontmatterRow({
    super.key,
    required this.fieldKey,
    required this.type,
    required this.value,
    this.tagColor,
    this.showUlid = false,
    this.dense = false,
    this.titleResolver,
  });

  final String fieldKey;
  final FrontmatterDisplayType type;
  final dynamic value;
  final TagColor? tagColor;
  final bool showUlid;
  final bool dense;
  final String Function(String ulid)? titleResolver;

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    final padY = dense ? 5.0 : 7.0;
    final labelW = dense ? 96.0 : 110.0;

    return Container(
      padding: EdgeInsets.symmetric(vertical: padY),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tokens.divider, width: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: labelW,
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                children: [
                  Tooltip(
                    message: _labelForType(type),
                    waitDuration: const Duration(milliseconds: 500),
                    child: QuillIcon(_iconForType(type),
                        size: 12, strokeWidth: 1.7, color: tokens.text3),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      fieldKey,
                      style: mono(fontSize: 12, color: tokens.text3),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: _renderValue(context, tokens)),
        ],
      ),
    );
  }

  Widget _renderValue(BuildContext context, QuillTokens tokens) {
    switch (type) {
      case FrontmatterDisplayType.ulid:
        return Text('$value', style: mono(fontSize: 12, color: tokens.text3));
      case FrontmatterDisplayType.number:
      case FrontmatterDisplayType.date:
        return Text('$value', style: mono(fontSize: 13, color: tokens.text));
      case FrontmatterDisplayType.select:
        return TagChip(label: '$value', color: tagColor ?? TagColor.gray);
      case FrontmatterDisplayType.multi:
        final values = (value is List) ? value : <dynamic>[];
        final palette = [
          TagColor.blue, TagColor.green, TagColor.orange,
          TagColor.purple, TagColor.pink, TagColor.yellow,
        ];
        return Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            for (var i = 0; i < values.length; i++)
              TagChip(label: '${values[i]}', color: palette[i % palette.length]),
          ],
        );
      case FrontmatterDisplayType.relation:
        final v = '$value';
        final title = titleResolver != null ? titleResolver!(v) : v;
        return RelationChip(label: title, ulid: v, showUlid: showUlid, icon: 'file-md');
      case FrontmatterDisplayType.text:
      case FrontmatterDisplayType.formula:
      case FrontmatterDisplayType.file:
      case FrontmatterDisplayType.checkbox:
        return Text(
          '$value',
          style: TextStyle(fontSize: 13, color: tokens.text, height: 1.5),
        );
    }
  }
}
