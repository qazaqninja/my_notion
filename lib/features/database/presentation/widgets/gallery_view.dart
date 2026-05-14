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
  });

  final DatabaseSchema schema;
  final List<DatabasePageRow> rows;

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
                onChanged: (next) => _setSize(next),
                options: const [
                  SegmentOption(
                      value: GalleryCardSize.small,
                      label: 'S',
                      icon: 'gallery'),
                  SegmentOption(
                      value: GalleryCardSize.medium,
                      label: 'M',
                      icon: 'gallery'),
                  SegmentOption(
                      value: GalleryCardSize.large,
                      label: 'L',
                      icon: 'gallery'),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
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
            ),
          ),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.row,
    required this.schema,
    required this.metrics,
  });
  final DatabasePageRow row;
  final DatabaseSchema schema;
  final _CardMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    final stage = '${row.cells['stage'] ?? ''}';
    final health = '${row.cells['health'] ?? ''}';
    final arr = '${row.cells['arr'] ?? ''}';
    final owner = '${row.cells['owner'] ?? ''}';
    final last = '${row.cells['updated'] ?? ''}';

    return GestureDetector(
      onTap: () => context.go('/editor/${row.ulid}'),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          decoration: BoxDecoration(
            color: tokens.surface,
            border: Border.all(color: tokens.divider2, width: 0.5),
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
                        child: Text(
                          row.title,
                          style: TextStyle(
                            fontSize: metrics.titleSize,
                            fontWeight: FontWeight.w600,
                            color: tokens.text,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      if (health.isNotEmpty) StatusDot(color: _dotColor(health)),
                    ]),
                    const SizedBox(height: 8),
                    Row(children: [
                      if (stage.isNotEmpty) TagChip(label: stage, color: _stageColor(stage)),
                      const SizedBox(width: 6),
                      if (arr.isNotEmpty && arr != '0')
                        Text(_kFmt(arr), style: mono(fontSize: 11.5, color: tokens.text3)),
                    ]),
                    const SizedBox(height: 8),
                    Row(children: [
                      Text(
                        owner,
                        style: TextStyle(fontSize: 11.5, color: tokens.text3),
                      ),
                      const Spacer(),
                      Text(last, style: mono(fontSize: 11, color: tokens.text3)),
                    ]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Cover image strip for a card. Reads the row's `cover:` frontmatter
  /// — http(s) URL or vault-relative path — and renders [height]px
  /// cover-fit. Falls back to the existing labelled placeholder.
  Widget _coverFor(BuildContext context, DatabasePageRow row, double height) {
    final raw = '${row.cells['cover'] ?? ''}'.trim();
    if (raw.isEmpty) {
      return ImagePlaceholder(
          label: 'cover · ${row.title.toLowerCase()}', height: height);
    }
    final placeholder = ImagePlaceholder(
        label: 'cover · ${row.title.toLowerCase()}', height: height);
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return Image.network(raw,
          height: height,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => placeholder);
    }
    final state = context.read<VaultBloc>().state;
    if (state is! VaultLoaded) return placeholder;
    final resolved = raw.startsWith('/') ? raw : '${state.rootPath}/$raw';
    return Image.file(File(resolved),
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder);
  }

  Widget _rowIcon(DatabasePageRow row, QuillTokens tokens) {
    final raw = '${row.cells['icon'] ?? ''}'.trim();
    if (raw.isNotEmpty && raw.length <= 4 && !raw.contains('/')) {
      return SizedBox(
        width: 14,
        child: Text(raw,
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
