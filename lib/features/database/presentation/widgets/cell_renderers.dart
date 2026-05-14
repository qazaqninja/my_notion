import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/db/quill_database.dart' hide Page;
import '../../../../core/platform/reveal.dart';
import '../../../../shared/theme/quill_tokens.dart';
import '../../../../shared/theme/tag_colors.dart';
import '../../../../shared/theme/tokens.dart';
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
        return Align(
          alignment: align,
          child: Text(
            '$v',
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
            return Align(
              alignment: align,
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(
                      text: parts[0].trim(),
                      style: mono(fontSize: 12.5, color: tokens.text2)),
                  TextSpan(
                      text: '  →  ',
                      style: TextStyle(fontSize: 12, color: tokens.text3)),
                  TextSpan(
                      text: parts[1].trim(),
                      style: mono(fontSize: 12.5, color: tokens.text2)),
                ]),
              ),
            );
          }
        }
        return Align(
          alignment: align,
          child: Text(s, style: mono(fontSize: 12.5, color: tokens.text2)),
        );
      case ColumnType.select:
        return Align(alignment: align, child: TagChip(label: '$v', color: _tagFor('$v')));
      case ColumnType.multi:
        final values = _parseList(v);
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
        return Align(
          alignment: align,
          child: Text(
            _formatTimestamp(v),
            style: mono(fontSize: 12, color: tokens.text3),
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

  static List<String> _parseList(dynamic v) {
    if (v is List) return v.map((e) => '$e').toList();
    final s = '$v'.trim();
    if (s.startsWith('[') && s.endsWith(']')) {
      return s
          .substring(1, s.length - 1)
          .split(',')
          .map((part) => _stripQuotes(part.trim()))
          .where((part) => part.isNotEmpty)
          .toList();
    }
    return [s];
  }

  static String _stripQuotes(String s) {
    if (s.length < 2) return s;
    final first = s[0];
    final last = s[s.length - 1];
    if ((first == '"' || first == "'") && first == last) {
      return s.substring(1, s.length - 1);
    }
    return s;
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
  final String ulid;

  @override
  Widget build(BuildContext context) {
    final db = context.read<QuillDatabase>();
    return FutureBuilder(
      future: (db.select(db.pages)..where((p) => p.ulid.equals(ulid))).getSingleOrNull(),
      builder: (context, snap) {
        final title = snap.data?.title ?? '…${ulid.length >= 6 ? ulid.substring(ulid.length - 6) : ulid}';
        return RelationChip(label: title, ulid: ulid, icon: 'file-md');
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

/// Clickable chip for a file/media cell value. URLs open externally,
/// vault-relative paths shell out to Reveal.show.
class _FileChip extends StatelessWidget {
  const _FileChip({required this.value});
  final String value;

  bool get _isUrl =>
      value.startsWith('http://') || value.startsWith('https://');

  String get _label {
    if (_isUrl) {
      return Uri.tryParse(value)?.host ?? value;
    }
    // For paths, show the basename.
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
    // Vault-relative path. Resolve via the vault root from VaultBloc.
    final state = context.read<VaultBloc>().state;
    if (state is! VaultLoaded) return;
    final resolved = value.startsWith('/') ? value : '${state.rootPath}/$value';
    await Reveal.show(resolved);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    return GestureDetector(
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
    );
  }
}
