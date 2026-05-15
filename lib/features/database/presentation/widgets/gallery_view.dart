import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../shared/theme/quill_tokens.dart';
import '../../../../shared/theme/tag_colors.dart';
import '../../../../shared/theme/tokens.dart';
import '../../../../shared/widgets/image_placeholder.dart';
import '../../../../shared/widgets/quill_icon.dart';
import '../../../../shared/widgets/segment.dart';
import '../../../../shared/widgets/status_dot.dart';
import '../../../../shared/widgets/tag_chip.dart';
import '../../../vault/presentation/bloc/vault_bloc.dart';
import '../../../vault/presentation/bloc/vault_state.dart';
import '../../domain/entities/database_schema.dart';
import '../../domain/repositories/database_repository.dart';
import '../../domain/row_display.dart';

enum GalleryCardSize { small, medium, large }

class _CardMetrics {
  const _CardMetrics({
    required this.cardWidth,
    required this.cardHeight,
    required this.coverHeight,
    required this.titleSize,
  });
  final double cardWidth;
  final double cardHeight;
  final double coverHeight;
  final double titleSize;

  static const _small = _CardMetrics(
    cardWidth: 180,
    cardHeight: 150,
    coverHeight: 60,
    titleSize: 12.5,
  );
  static const _medium = _CardMetrics(
    cardWidth: 260,
    cardHeight: 220,
    coverHeight: 92,
    titleSize: 13.5,
  );
  static const _large = _CardMetrics(
    cardWidth: 340,
    cardHeight: 300,
    coverHeight: 140,
    titleSize: 14.5,
  );

  static _CardMetrics forSize(GalleryCardSize s) => switch (s) {
        GalleryCardSize.small => _small,
        GalleryCardSize.medium => _medium,
        GalleryCardSize.large => _large,
      };
}

/// Card-grid view of a database. Matches `altviews.jsx:46-95`.
class GalleryView extends StatefulWidget {
  const GalleryView({
    super.key,
    required this.schema,
    required this.rows,
    this.cardFields,
    this.subGroupBy,
  });

  final DatabaseSchema schema;
  final List<DatabasePageRow> rows;

  /// Column keys to surface on the card body, in order. When null, the
  /// view falls back to its legacy stage/arr/owner/updated layout so
  /// existing schemas keep working without an opt-in change.
  final List<String>? cardFields;

  /// When non-null, cards are partitioned into sections by this column's
  /// value. Each section gets a full-width header band; the cards within
  /// flow as a Wrap. Empty values land in a `—` section. Mirrors the
  /// TableView (M177) and BoardView (M86) sub-group behaviour.
  final String? subGroupBy;

  @override
  State<GalleryView> createState() => _GalleryViewState();
}

class _GalleryViewState extends State<GalleryView> {
  GalleryCardSize _size = GalleryCardSize.medium;

  String get _prefsKey => 'gallery.cardSize.${widget.schema.id}';

  @override
  void initState() {
    super.initState();
    _hydrate();
  }

  Future<void> _hydrate() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (!mounted) return;
    setState(() {
      _size = switch (raw) {
        'small' => GalleryCardSize.small,
        'large' => GalleryCardSize.large,
        _ => GalleryCardSize.medium,
      };
    });
  }

  Future<void> _setSize(GalleryCardSize next) async {
    setState(() => _size = next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, next.name);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    final m = _CardMetrics.forSize(_size);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: Row(
            children: [
              const Spacer(),
              Text('Card size',
                  style: TextStyle(fontSize: 11, color: tokens.text3)),
              const SizedBox(width: 8),
              Segment<GalleryCardSize>(
                value: _size,
                onChanged: _setSize,
                options: const [
                  SegmentOption(
                      value: GalleryCardSize.small,
                      label: 'S',
                      icon: 'gallery',
                      tooltip: 'Small cards'),
                  SegmentOption(
                      value: GalleryCardSize.medium,
                      label: 'M',
                      icon: 'gallery',
                      tooltip: 'Medium cards'),
                  SegmentOption(
                      value: GalleryCardSize.large,
                      label: 'L',
                      icon: 'gallery',
                      tooltip: 'Large cards'),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: widget.rows.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        QuillIcon('gallery',
                            size: 24,
                            strokeWidth: 1.4,
                            color: tokens.text3),
                        const SizedBox(height: 10),
                        Text('No cards yet',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: tokens.text2,
                            )),
                        const SizedBox(height: 2),
                        Text(
                          'Pages in this database will appear as cards here.',
                          style:
                              TextStyle(fontSize: 12, color: tokens.text3),
                        ),
                      ],
                    ),
                  ),
                )
              : widget.subGroupBy == null
              ? GridView.builder(
                  padding: const EdgeInsets.all(24),
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: m.cardWidth,
                    mainAxisExtent: m.cardHeight,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                  ),
                  itemCount: widget.rows.length,
                  itemBuilder: (context, i) => _Card(
                    row: widget.rows[i],
                    schema: widget.schema,
                    metrics: m,
                    cardFields: widget.cardFields,
                  ),
                )
              : _SubGroupedGallery(
                  rows: widget.rows,
                  schema: widget.schema,
                  metrics: m,
                  cardFields: widget.cardFields,
                  subGroupBy: widget.subGroupBy!,
                ),
        ),
      ],
    );
  }
}

/// Partitions the gallery rows by [subGroupBy] and renders one section
/// per value: a full-width header band followed by a Wrap of cards.
/// Order of sections follows first-occurrence in the input; empty
/// values bucket under `—`.
class _SubGroupedGallery extends StatelessWidget {
  const _SubGroupedGallery({
    required this.rows,
    required this.schema,
    required this.metrics,
    required this.subGroupBy,
    this.cardFields,
  });

  final List<DatabasePageRow> rows;
  final DatabaseSchema schema;
  final _CardMetrics metrics;
  final String subGroupBy;
  final List<String>? cardFields;

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    final partitions = <String, List<DatabasePageRow>>{};
    for (final r in rows) {
      final raw = '${r.cells[subGroupBy] ?? ''}'.trim();
      final key = raw.isEmpty ? '—' : raw;
      (partitions[key] ??= []).add(r);
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final entry in partitions.entries) ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: tokens.divider2, width: 0.5),
                ),
              ),
              child: Row(
                children: [
                  Tooltip(
                    message: 'Sub-group: ${entry.key}',
                    waitDuration: const Duration(milliseconds: 600),
                    child: Text(
                      entry.key,
                      style: mono(
                        fontSize: 11,
                        color: tokens.text2,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: entry.value.length == 1
                        ? '1 card in ${entry.key}'
                        : '${entry.value.length} cards in ${entry.key}',
                    waitDuration: const Duration(milliseconds: 500),
                    child: Text(
                      '${entry.value.length}',
                      style: mono(fontSize: 11, color: tokens.text3),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                for (final row in entry.value)
                  SizedBox(
                    width: metrics.cardWidth,
                    height: metrics.cardHeight,
                    child: _Card(
                      row: row,
                      schema: schema,
                      metrics: metrics,
                      cardFields: cardFields,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 22),
          ],
        ],
      ),
    );
  }
}

class _Card extends StatefulWidget {
  const _Card({
    required this.row,
    required this.schema,
    required this.metrics,
    this.cardFields,
  });
  final DatabasePageRow row;
  final DatabaseSchema schema;
  final _CardMetrics metrics;
  final List<String>? cardFields;

  @override
  State<_Card> createState() => _CardState();
}

class _CardState extends State<_Card> {
  bool _hover = false;

  DatabasePageRow get row => widget.row;
  DatabaseSchema get schema => widget.schema;
  _CardMetrics get metrics => widget.metrics;
  List<String>? get cardFields => widget.cardFields;

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    final health = '${row.cells['health'] ?? ''}';

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () => context.go('/editor/${row.ulid}'),
        child: Container(
          decoration: BoxDecoration(
            color: _hover ? tokens.surface2 : tokens.surface,
            border: Border.all(
                color: _hover ? tokens.accent : tokens.divider2, width: 0.5),
            borderRadius: const BorderRadius.all(Radius.circular(6)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                child: _coverFor(context, row, metrics.coverHeight),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      _rowIcon(row, tokens),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Tooltip(
                          message:
                              row.title.isEmpty ? 'Untitled page' : row.title,
                          waitDuration: const Duration(milliseconds: 600),
                          child: Text(
                            row.title.isEmpty ? 'Untitled' : row.title,
                            style: TextStyle(
                              fontSize: metrics.titleSize,
                              fontWeight: FontWeight.w600,
                              color: row.title.isEmpty
                                  ? tokens.text3
                                  : tokens.text,
                              fontStyle: row.title.isEmpty
                                  ? FontStyle.italic
                                  : FontStyle.normal,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ),
                      if (health.isNotEmpty)
                        StatusDot(color: _dotColor(health), tooltip: health),
                    ]),
                    const SizedBox(height: 8),
                    ..._cardBodyRows(tokens),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build the body rows for the card. If [cardFields] is provided, walk
  /// the list in order and render each value via [_renderCell]; otherwise
  /// fall back to the legacy stage/arr/owner/updated two-row layout for
  /// schemas that haven't opted into custom fields.
  List<Widget> _cardBodyRows(QuillTokens tokens) {
    final fields = cardFields;
    if (fields != null) {
      final widgets = <Widget>[];
      for (final key in fields) {
        if (key == 'title' || key == 'health') continue;
        final raw = '${row.cells[key] ?? ''}'.trim();
        if (raw.isEmpty) continue;
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(children: [
            SizedBox(
              width: 56,
              child: Tooltip(
                message: key,
                waitDuration: const Duration(milliseconds: 600),
                child: Text(key,
                    style: mono(fontSize: 10.5, color: tokens.text3),
                    overflow: TextOverflow.ellipsis),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(child: _renderCell(key, raw, tokens)),
          ]),
        ));
      }
      return widgets;
    }
    // Legacy layout.
    final stage = '${row.cells['stage'] ?? ''}';
    final arr = '${row.cells['arr'] ?? ''}';
    final owner = '${row.cells['owner'] ?? ''}';
    final last = '${row.cells['updated'] ?? ''}';
    return [
      Row(children: [
        if (stage.isNotEmpty)
          TagChip(label: stage, color: _stageColor(stage)),
        const SizedBox(width: 6),
        if (arr.isNotEmpty && arr != '0')
          Text(_kFmt(arr), style: mono(fontSize: 11.5, color: tokens.text3)),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        Text(owner,
            style: TextStyle(fontSize: 11.5, color: tokens.text3)),
        const Spacer(),
        Text(last, style: mono(fontSize: 11, color: tokens.text3)),
      ]),
    ];
  }

  /// Render a single field on the card. Recognises a handful of
  /// "special" keys (stage / status / arr / date-shaped) and falls back
  /// to plain text for everything else.
  Widget _renderCell(String key, String raw, QuillTokens tokens) {
    final lower = key.toLowerCase();
    if (lower == 'stage' || lower == 'status' || lower == 'priority') {
      return Align(
        alignment: Alignment.centerLeft,
        child: TagChip(label: raw, color: _stageColor(raw)),
      );
    }
    if (lower == 'arr' || lower == 'mrr' || lower == 'revenue') {
      return Text(_kFmt(raw),
          style: mono(fontSize: 11.5, color: tokens.text3));
    }
    if (RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(raw)) {
      return Text(raw, style: mono(fontSize: 11, color: tokens.text3));
    }
    return Tooltip(
      message: raw,
      waitDuration: const Duration(milliseconds: 600),
      child: Text(raw,
          style: TextStyle(fontSize: 11.5, color: tokens.text2),
          overflow: TextOverflow.ellipsis,
          maxLines: 1),
    );
  }

  /// Cover image strip for a card. Reads the row's `cover:` frontmatter
  /// — http(s) URL or vault-relative path — and renders [height]px
  /// cover-fit. Falls back to the existing labelled placeholder.
  Widget _coverFor(BuildContext context, DatabasePageRow row, double height) {
    final raw = '${row.cells['cover'] ?? ''}'.trim();
    if (raw.isEmpty) {
      return ImagePlaceholder(
          label: 'no cover · ${row.title.toLowerCase()}', height: height);
    }
    final brokenPlaceholder = ImagePlaceholder(
        label: 'cover not found · ${row.title.toLowerCase()}',
        height: height);
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return Image.network(raw,
          height: height,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => brokenPlaceholder);
    }
    final state = context.read<VaultBloc>().state;
    if (state is! VaultLoaded) return brokenPlaceholder;
    final resolved = raw.startsWith('/') ? raw : '${state.rootPath}/$raw';
    return Image.file(File(resolved),
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => brokenPlaceholder);
  }

  Widget _rowIcon(DatabasePageRow row, QuillTokens tokens) {
    final emoji = rowIconString(row);
    if (emoji != null) {
      return SizedBox(
        width: 14,
        child: Text(emoji,
            style: TextStyle(fontSize: 12, color: tokens.text),
            textAlign: TextAlign.center),
      );
    }
    return QuillIcon('file-md',
        size: 12, strokeWidth: 1.7, color: tokens.text3);
  }

  static StatusDotColor _dotColor(String h) => switch (h.toLowerCase()) {
        'green' => StatusDotColor.green,
        'yellow' => StatusDotColor.yellow,
        'red' => StatusDotColor.red,
        _ => StatusDotColor.gray,
      };

  static TagColor _stageColor(String s) {
    final v = s.toLowerCase();
    if (v.contains('won') || v.contains('expand')) return TagColor.green;
    if (v.contains('churn')) return TagColor.red;
    if (v.contains('pilot')) return TagColor.blue;
    if (v.contains('eval')) return TagColor.yellow;
    return TagColor.gray;
  }

  static String _kFmt(String raw) {
    final n = num.tryParse(raw.replaceAll(',', ''));
    if (n == null) return raw;
    if (n >= 1000) return '\$${(n / 1000).toStringAsFixed(0)}k';
    return raw;
  }
}
