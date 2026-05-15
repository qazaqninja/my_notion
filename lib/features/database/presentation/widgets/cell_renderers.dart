import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/db/quill_database.dart' hide Page;
import '../../../../core/markdown/frontmatter_icon.dart';
import '../../../../core/markdown/yaml_scalar.dart';
import '../../../../core/platform/reveal.dart';
import '../../../../shared/theme/quill_tokens.dart';
import '../../../../shared/theme/tag_colors.dart';
import '../../../../shared/theme/tokens.dart';
import '../../../../shared/widgets/person_chip.dart';
import '../../../../shared/widgets/quill_overlays.dart';
import '../../../../shared/widgets/relation_chip.dart';
import '../../../../shared/widgets/status_dot.dart';
import '../../../../shared/widgets/tag_chip.dart';
import '../../../vault/presentation/bloc/vault_bloc.dart';
import '../../../vault/presentation/bloc/vault_state.dart';
import '../../domain/entities/database_schema.dart';

/// Render a single cell value. Each branch matches the design's
/// type-specific rendering in `database.jsx`.
class CellRenderer extends StatelessWidget {
  const CellRenderer({
    super.key,
    required this.column,
    required this.value,
    this.align = Alignment.centerLeft,
    this.wrap = false,
  });

  final ColumnDef column;
  final dynamic value;
  final Alignment align;

  /// When true, text-style cells use unlimited line count.
  final bool wrap;

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    final v = value;
    if (v == null || (v is String && v.isEmpty)) {
      return Align(
        alignment: align,
        child: Text('—', style: TextStyle(fontSize: 12, color: tokens.text3)),
      );
    }

    switch (column.type) {
      case ColumnType.text:
        final s = '$v';
        // Auto-link URLs and email addresses so a text-typed cell that
        // happens to hold one becomes clickable. Matches Notion-style
        // smart cells.
        final url = _autoLink(s);
        if (url != null) {
          return Align(
            alignment: align,
            child: _LinkCell(label: s, target: url, wrap: wrap),
          );
        }
        return Align(
          alignment: align,
          child: Text(
            s,
            style: TextStyle(fontSize: 13, color: tokens.text, height: 1.4),
            overflow: wrap ? TextOverflow.visible : TextOverflow.ellipsis,
            maxLines: wrap ? null : 1,
          ),
        );
      case ColumnType.number:
        return Align(
          alignment: align,
          child: Text(_fmtNumber('$v'), style: mono(fontSize: 13, color: tokens.text)),
        );
      case ColumnType.date:
        final s = '$v';
        // Date range: YYYY-MM-DD..YYYY-MM-DD renders with an arrow.
        if (s.contains('..')) {
          final parts = s.split('..');
          if (parts.length == 2) {
            final from = DateTime.tryParse(parts[0].trim());
            final to = DateTime.tryParse(parts[1].trim());
            final days = (from != null && to != null)
                ? to.difference(from).inDays
                : null;
            return Align(
              alignment: align,
              child: Tooltip(
                message: days == null
                    ? s
                    : days == 0
                        ? '$s (same day)'
                        : days.abs() == 1
                            ? '$s (1 day)'
                            : '$s (${days.abs()} days)',
                waitDuration: const Duration(milliseconds: 500),
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(
                        text: _fmtDate(parts[0].trim()),
                        style: mono(fontSize: 12.5, color: tokens.text2)),
                    TextSpan(
                        text: '  →  ',
                        style: TextStyle(fontSize: 12, color: tokens.text3)),
                    TextSpan(
                        text: _fmtDate(parts[1].trim()),
                        style: mono(fontSize: 12.5, color: tokens.text2)),
                  ]),
                ),
              ),
            );
          }
        }
        return Align(
          alignment: align,
          child: Text(_fmtDate(s),
              style: mono(fontSize: 12.5, color: tokens.text2)),
        );
      case ColumnType.select:
        return Align(alignment: align, child: TagChip(label: '$v', color: _tagFor('$v')));
      case ColumnType.multi:
        final values = _parseList(v);
        if (values.isEmpty) {
          return Align(
            alignment: align,
            child: Text('—', style: TextStyle(fontSize: 12, color: tokens.text3)),
          );
        }
        final palette = [
          TagColor.blue, TagColor.green, TagColor.orange,
          TagColor.purple, TagColor.pink, TagColor.yellow,
        ];
        return Align(
          alignment: align,
          child: Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (int i = 0; i < values.length; i++)
                TagChip(label: values[i], color: palette[i % palette.length]),
            ],
          ),
        );
      case ColumnType.relation:
        return Align(alignment: align, child: _Relation(ulid: '$v'));
      case ColumnType.checkbox:
        final on = '$v'.toLowerCase() == 'true';
        return Align(
          alignment: align,
          child: Icon(
            on ? Icons.check_box_outlined : Icons.check_box_outline_blank,
            size: 14,
            color: tokens.text3,
          ),
        );
      case ColumnType.formula:
        return Align(
          alignment: align,
          child: Text('$v', style: mono(fontSize: 12, color: tokens.text2)),
        );
      case ColumnType.file:
        final paths = _parseList(v);
        return Align(
          alignment: align,
          child: Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final path in paths) _FileChip(value: path),
            ],
          ),
        );
      case ColumnType.createdTime:
      case ColumnType.lastEditedTime:
        final ts = _timestampDetail(v);
        return Align(
          alignment: align,
          child: Tooltip(
            message: ts ?? _formatTimestamp(v),
            waitDuration: const Duration(milliseconds: 500),
            child: Text(
              _formatTimestamp(v),
              style: mono(fontSize: 12, color: tokens.text3),
            ),
          ),
        );
      case ColumnType.person:
        // A person column carries either a single name string or a
        // comma-separated list (or YAML list). Render each as a person
        // chip — small initial-circle + name. The colour is derived
        // from the name so the same person reads the same way across
        // the vault.
        final names = _parseList(v);
        return Align(
          alignment: align,
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final n in names)
                if (n.isNotEmpty) PersonChip(name: n),
            ],
          ),
        );
      case ColumnType.rollup:
        // Pre-computed by RollupCompute before the table is rendered.
        // Numbers get the standard right-aligned mono formatting; lists
        // (RollupAgg.list) come in as comma-joined strings.
        if (v is num) {
          final isInt = v == v.truncate();
          return Align(
            alignment: align,
            child: Text(
              isInt ? '${v.toInt()}' : v.toStringAsFixed(2),
              style: mono(fontSize: 12, color: tokens.text2),
            ),
          );
        }
        return Align(
          alignment: align,
          child: Tooltip(
            message: '$v',
            waitDuration: const Duration(milliseconds: 600),
            child: Text('$v',
                style: mono(fontSize: 12, color: tokens.text2),
                overflow: TextOverflow.ellipsis,
                maxLines: wrap ? null : 1),
          ),
        );
    }
  }

  static String _formatTimestamp(dynamic v) {
    if (v == null) return '—';
    // Numeric (millis since epoch).
    if (v is num) {
      final dt = DateTime.fromMillisecondsSinceEpoch(v.toInt()).toLocal();
      return _yyyymmdd(dt);
    }
    // ISO string (frontmatter `created_at:` etc).
    final dt = DateTime.tryParse('$v'.trim());
    if (dt != null) return _yyyymmdd(dt);
    return '$v';
  }

  static String _yyyymmdd(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  /// Pretty timestamp for the createdTime/lastEditedTime tooltip — full
  /// `YYYY-MM-DD HH:MM` so users can confirm the actual save instant
  /// instead of just the day. Returns null when [v] doesn't parse so
  /// the caller can fall back to the day-only label.
  static String? _timestampDetail(dynamic v) {
    DateTime? dt;
    if (v is num) {
      dt = DateTime.fromMillisecondsSinceEpoch(v.toInt()).toLocal();
    } else if (v != null) {
      dt = DateTime.tryParse('$v'.trim())?.toLocal();
    }
    if (dt == null) return null;
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '${_yyyymmdd(dt)} $hh:$mm';
  }

  static List<String> _parseList(dynamic v) {
    if (v is List) return v.map((e) => '$e').toList();
    // Route through parseYamlFlowList so quoted commas inside an item
    // (e.g. `[draft, "high, priority"]`) don't split. The old inline
    // splitter naively split on every `,`, silently shredding any
    // multi-value entry that contained a quoted comma into bogus
    // individual chips.
    return parseYamlFlowList('$v');
  }

  static TagColor _tagFor(String value) {
    final v = value.toLowerCase();
    if (v.contains('won') || v.contains('expand') || v == 'green') return TagColor.green;
    if (v.contains('churn') || v == 'red') return TagColor.red;
    if (v.contains('pilot') || v == 'blue') return TagColor.blue;
    if (v.contains('eval') || v == 'yellow') return TagColor.yellow;
    if (v.contains('negot') || v == 'orange') return TagColor.orange;
    if (v == 'ent' || v == 'enterprise') return TagColor.purple;
    if (v == 'mid' || v == 'mid-market') return TagColor.gray;
    if (v == 'small') return TagColor.gray;
    return TagColor.gray;
  }

  /// Detect a URL, email, or tel: target in a plain text cell. Returns
  /// the canonical href when matched; null otherwise.
  static String? _autoLink(String s) {
    final t = s.trim();
    if (t.isEmpty) return null;
    if (t.startsWith('http://') || t.startsWith('https://')) return t;
    if (RegExp(r'^[\w\.\-]+@[\w\.\-]+\.[a-zA-Z]{2,}$').hasMatch(t)) {
      return 'mailto:$t';
    }
    if (RegExp(r'^\+?[\d\s\-\(\)]{7,}$').hasMatch(t) &&
        RegExp(r'\d').allMatches(t).length >= 7) {
      return 'tel:${t.replaceAll(RegExp(r'\s'), '')}';
    }
    return null;
  }

  /// Pretty date / datetime formatter. Accepts:
  ///   YYYY-MM-DD                       → "YYYY-MM-DD"
  ///   YYYY-MM-DDTHH:MM[:SS][Z|±HH:MM]  → "YYYY-MM-DD · HH:MM[tz]"
  /// Anything that doesn't parse falls back to the raw string.
  static String _fmtDate(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return s;
    // Bare date.
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(s)) return s;
    // Date + time, optional Z / ±offset.
    final m = RegExp(
            r'^(\d{4}-\d{2}-\d{2})[T ](\d{2}:\d{2})(?::\d{2})?(Z|[+\-]\d{2}:?\d{2})?$')
        .firstMatch(s);
    if (m != null) {
      final date = m.group(1)!;
      final time = m.group(2)!;
      final tz = m.group(3);
      final tzSuffix = tz == null
          ? ''
          : (tz == 'Z' ? ' UTC' : ' $tz');
      return '$date · $time$tzSuffix';
    }
    return s;
  }

  static String _fmtNumber(String raw) {
    final s = raw.replaceAll(',', '');
    final n = num.tryParse(s);
    if (n == null) return raw;
    // Format with thousands separator for large numbers; prepend $ for amounts.
    final isMoney = n >= 1000;
    final formatted = _withSeparators(n);
    return isMoney && !raw.contains('\$') ? '\$$formatted' : formatted;
  }

  static String _withSeparators(num n) {
    final s = n.toString();
    final idx = s.indexOf('.');
    final intPart = idx == -1 ? s : s.substring(0, idx);
    final frac = idx == -1 ? '' : s.substring(idx);
    final buf = StringBuffer();
    for (int i = 0; i < intPart.length; i++) {
      if (i > 0 && (intPart.length - i) % 3 == 0) buf.write(',');
      buf.write(intPart[i]);
    }
    return '$buf$frac';
  }
}

class _Relation extends StatelessWidget {
  const _Relation({required this.ulid});

  /// Raw cell value as written in YAML. May be `01HX…`, `[[01HX…]]`,
  /// `"01HX…"`, or — when the user round-trips through Obsidian — a
  /// quoted wikilink form. The Drift lookup needs the bare ULID, so
  /// normalise before querying.
  final String ulid;

  /// Strip surrounding `[[…]]` wikilink wrapping and YAML quotes so
  /// the Drift lookup sees the bare 26-char ULID. Returns null when
  /// the result doesn't look like a ULID — the chip then renders as
  /// broken with the original raw text in the tooltip.
  static String? _normalise(String raw) {
    var s = raw.trim();
    if (s.length >= 2) {
      if ((s.startsWith('"') && s.endsWith('"')) ||
          (s.startsWith("'") && s.endsWith("'"))) {
        s = s.substring(1, s.length - 1).trim();
      }
    }
    if (s.startsWith('[[') && s.endsWith(']]') && s.length >= 4) {
      s = s.substring(2, s.length - 2).trim();
    }
    if (RegExp(r'^[0-9A-Z]{26}$').hasMatch(s)) return s;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final db = context.read<QuillDatabase>();
    final normalised = _normalise(ulid);
    if (normalised == null) {
      // Not a ULID-shaped value — render as broken without hitting the DB.
      return RelationChip(
        label: '⚠ $ulid',
        ulid: ulid,
        icon: 'trash',
        emojiIcon: null,
        tooltip:
            'Broken relation — value is not a ULID (`$ulid`).',
      );
    }
    return FutureBuilder(
      future: (db.select(db.pages)
            ..where((p) => p.ulid.equals(normalised)))
          .getSingleOrNull(),
      builder: (context, snap) {
        final title = snap.data?.title ??
            '…${normalised.substring(normalised.length - 6)}';
        final emoji = snap.data == null
            ? null
            : emojiFromFrontmatterJson(snap.data!.frontmatterJson);
        // Mirrors M335 in the inline `_ResolvedChip`: when the lookup
        // settles with no row, render the chip as broken.
        final isBroken = snap.connectionState == ConnectionState.done &&
            snap.data == null;
        return RelationChip(
          label: isBroken ? '⚠ $title' : title,
          ulid: normalised,
          icon: isBroken ? 'trash' : 'file-md',
          emojiIcon: emoji,
          tooltip: isBroken
              ? 'Broken relation — target page is no longer in the vault.\n[[$normalised]]'
              : null,
        );
      },
    );
  }
}

/// Health-style status dot — exposed separately because the design's "health"
/// column uses a dot + colour name, not a Tag chip.
class HealthCell extends StatelessWidget {
  const HealthCell({super.key, required this.value});
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    final color = switch (value.toLowerCase()) {
      'green' => StatusDotColor.green,
      'yellow' => StatusDotColor.yellow,
      'red' => StatusDotColor.red,
      _ => StatusDotColor.gray,
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        StatusDot(color: color),
        const SizedBox(width: 6),
        Text(value, style: TextStyle(fontSize: 12, color: tokens.text2)),
      ],
    );
  }
}

/// Underlined accent text that opens the link on tap. Used by text
/// cells whose value smells like a URL / email / phone (M122).
class _LinkCell extends StatelessWidget {
  const _LinkCell({
    required this.label,
    required this.target,
    required this.wrap,
  });
  final String label;
  final String target;
  final bool wrap;

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    return Tooltip(
      message: target == label ? target : '$label\n$target',
      waitDuration: const Duration(milliseconds: 500),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Builder(builder: (innerCtx) {
          return GestureDetector(
            onTap: () async {
              final ok = await Reveal.openUrl(target);
              if (!ok && innerCtx.mounted) {
                innerCtx.toastError('Could not open', sub: target, subMono: true);
              }
            },
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: tokens.accent,
                decoration: TextDecoration.underline,
                decorationColor: tokens.accent.withValues(alpha: 0.5),
              ),
              overflow: wrap ? TextOverflow.visible : TextOverflow.ellipsis,
              maxLines: wrap ? null : 1,
            ),
          );
        }),
      ),
    );
  }
}

/// Clickable chip for a file/media cell value. URLs open externally,
/// vault-relative paths shell out to Reveal.show. Image extensions
/// (png/jpg/etc.) render a 22px-square thumbnail instead of the
/// icon-and-text chip so a `files` column ends up looking like a
/// micro-gallery row.
class _FileChip extends StatelessWidget {
  const _FileChip({required this.value});
  final String value;

  bool get _isUrl =>
      value.startsWith('http://') || value.startsWith('https://');

  bool get _isImage {
    final lower = value.toLowerCase().split(RegExp(r'[?#]')).first;
    return lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.bmp');
  }

  String get _label {
    if (_isUrl) {
      return Uri.tryParse(value)?.host ?? value;
    }
    final slash = value.lastIndexOf('/');
    return slash < 0 ? value : value.substring(slash + 1);
  }

  Future<void> _open(BuildContext context) async {
    if (_isUrl) {
      try {
        if (Platform.isMacOS) {
          await Process.run('open', [value]);
        } else if (Platform.isLinux) {
          await Process.run('xdg-open', [value]);
        } else if (Platform.isWindows) {
          await Process.run('cmd', ['/c', 'start', '', value]);
        }
      } catch (_) {}
      return;
    }
    final state = context.read<VaultBloc>().state;
    if (state is! VaultLoaded) return;
    final resolved = value.startsWith('/') ? value : '${state.rootPath}/$value';
    final ok = await Reveal.show(resolved);
    if (!ok && context.mounted) {
      context.toastError('Could not open', sub: resolved, subMono: true);
    }
  }

  Widget _thumb(BuildContext context, QuillTokens tokens) {
    final fallback = Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tokens.surface2,
        borderRadius: const BorderRadius.all(Radius.circular(3)),
      ),
      child: Icon(Icons.image_outlined, size: 12, color: tokens.text3),
    );
    if (_isUrl) {
      return ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(3)),
        child: Image.network(value,
            width: 22,
            height: 22,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => fallback),
      );
    }
    final state = context.read<VaultBloc>().state;
    if (state is! VaultLoaded) return fallback;
    final resolved = value.startsWith('/') ? value : '${state.rootPath}/$value';
    return ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(3)),
      child: Image.file(File(resolved),
          width: 22,
          height: 22,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => fallback),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    if (_isImage) {
      return Tooltip(
        message: value,
        waitDuration: const Duration(milliseconds: 500),
        child: GestureDetector(
          onTap: () => _open(context),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: _thumb(context, tokens),
          ),
        ),
      );
    }
    return Tooltip(
      message: value,
      waitDuration: const Duration(milliseconds: 500),
      child: GestureDetector(
        onTap: () => _open(context),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: tokens.surface2,
              border: Border.all(color: tokens.divider2, width: 0.5),
              borderRadius: const BorderRadius.all(Radius.circular(3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isUrl ? Icons.link : Icons.attach_file,
                  size: 11,
                  color: tokens.text3,
                ),
                const SizedBox(width: 4),
                Text(
                  _label,
                  style: TextStyle(fontSize: 11.5, color: tokens.text2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
