import 'package:flutter/material.dart';

import '../../../../shared/theme/quill_tokens.dart';
import '../../../../shared/theme/tokens.dart';
import '../../../../shared/widgets/quill_icon.dart';
import '../../domain/entities/database_query.dart';
import '../../domain/entities/database_schema.dart';

/// Result of the Group popover. The record encoding lets the parent
/// distinguish "user cancelled" (null result) from "user picked None"
/// (a non-null record with a null `value`).
typedef GroupPopoverResult = ({String? value, String? sub});

/// Shows a popover anchored to the toolbar. Returns whatever the popover
/// pops with, or null if dismissed via backdrop tap.
Future<T?> showQueryPopover<T>({
  required BuildContext context,
  required Widget child,
}) {
  return showDialog<T>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.18),
    builder: (ctx) => Align(
      alignment: Alignment.topRight,
      child: Padding(
        padding: const EdgeInsets.only(top: 110, right: 20),
        child: Material(
          color: Colors.transparent,
          child: child,
        ),
      ),
    ),
  );
}

/// Multi-filter editor. One row per active rule; "+ Add filter" appends.
class FilterPopover extends StatefulWidget {
  const FilterPopover({super.key, required this.schema, required this.initial});
  final DatabaseSchema schema;
  final List<FilterRule> initial;

  @override
  State<FilterPopover> createState() => _FilterPopoverState();
}

class _FilterPopoverState extends State<FilterPopover> {
  late List<FilterRule> _rules;

  @override
  void initState() {
    super.initState();
    _rules = [...widget.initial];
  }

  void _addRule() {
    final col = widget.schema.columns.firstWhere(
      (c) => c.key != 'id',
      orElse: () => widget.schema.columns.first,
    );
    setState(() => _rules.add(
          FilterRule(
              columnKey: col.key,
              op: filterOpsForType(col.type).first,
              value: ''),
        ));
  }

  void _removeRule(int i) {
    setState(() => _rules.removeAt(i));
  }

  void _setColumn(int i, String key) {
    final col = widget.schema.columns.firstWhere((c) => c.key == key);
    setState(() {
      _rules[i] = FilterRule(
        columnKey: key,
        op: filterOpsForType(col.type).first,
        value: _rules[i].value,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    return _PopoverShell(
      title: 'Filter',
      tokens: tokens,
      footer: Row(
        children: [
          GestureDetector(
            onTap: _addRule,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  QuillIcon('plus', size: 12, strokeWidth: 1.7, color: tokens.text3),
                  const SizedBox(width: 4),
                  Text('Add filter',
                      style: TextStyle(fontSize: 12.5, color: tokens.text2)),
                ],
              ),
            ),
          ),
          const Spacer(),
          if (_rules.isNotEmpty)
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () =>
                    Navigator.of(context).pop(const <FilterRule>[]),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  child: Text('Clear',
                      style: TextStyle(fontSize: 12, color: tokens.text2)),
                ),
              ),
            ),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(_rules),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: tokens.accent,
                  borderRadius:
                      const BorderRadius.all(Radius.circular(5)),
                ),
                child: const Text(
                  'Apply',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
      child: _rules.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'No filters. Click "Add filter" below.',
                style: TextStyle(fontSize: 12.5, color: tokens.text3),
                textAlign: TextAlign.center,
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < _rules.length; i++)
                  _FilterRow(
                    schema: widget.schema,
                    rule: _rules[i],
                    onColumnChanged: (k) => _setColumn(i, k),
                    onOpChanged: (op) => setState(() {
                      _rules[i] = FilterRule(
                          columnKey: _rules[i].columnKey,
                          op: op,
                          value: _rules[i].value);
                    }),
                    onValueChanged: (v) => setState(() {
                      _rules[i] = FilterRule(
                          columnKey: _rules[i].columnKey,
                          op: _rules[i].op,
                          value: v);
                    }),
                    onRemove: () => _removeRule(i),
                  ),
              ],
            ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.schema,
    required this.rule,
    required this.onColumnChanged,
    required this.onOpChanged,
    required this.onValueChanged,
    required this.onRemove,
  });

  final DatabaseSchema schema;
  final FilterRule rule;
  final void Function(String) onColumnChanged;
  final void Function(FilterOp) onOpChanged;
  final void Function(String) onValueChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    final col = schema.columns.firstWhere(
      (c) => c.key == rule.columnKey,
      orElse: () => schema.columns.first,
    );
    final ops = filterOpsForType(col.type);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          DropdownButton<String>(
            value: rule.columnKey,
            isDense: true,
            underline: const SizedBox.shrink(),
            style: mono(fontSize: 12, color: tokens.text2),
            items: [
              for (final c in schema.columns)
                if (c.key != 'id')
                  DropdownMenuItem(value: c.key, child: Text(c.key)),
            ],
            onChanged: (v) {
              if (v != null) onColumnChanged(v);
            },
          ),
          const SizedBox(width: 6),
          DropdownButton<FilterOp>(
            value: ops.contains(rule.op) ? rule.op : ops.first,
            isDense: true,
            underline: const SizedBox.shrink(),
            style: TextStyle(fontSize: 12, color: tokens.text2),
            items: [
              for (final op in ops)
                DropdownMenuItem(value: op, child: Text(filterOpLabel(op))),
            ],
            onChanged: (v) {
              if (v != null) onOpChanged(v);
            },
          ),
          const SizedBox(width: 6),
          if (rule.needsValue())
            Expanded(
              child: TextFormField(
                key: ValueKey('flt-${rule.columnKey}-${rule.op}'),
                initialValue: rule.value ?? '',
                onChanged: onValueChanged,
                style: TextStyle(fontSize: 12.5, color: tokens.text),
                decoration: const InputDecoration(
                  isCollapsed: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 6),
                  border: InputBorder.none,
                  hintText: 'value',
                ),
              ),
            )
          else
            const Spacer(),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(2),
            constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
            onPressed: onRemove,
            tooltip: 'Remove filter',
            icon: QuillIcon('x', size: 11, strokeWidth: 1.7, color: tokens.text3),
          ),
        ],
      ),
    );
  }
}

/// Sort editor — one or more (column, direction) tuples in priority order.
class SortPopover extends StatefulWidget {
  const SortPopover({super.key, required this.schema, required this.initial});
  final DatabaseSchema schema;
  final List<SortRule> initial;

  @override
  State<SortPopover> createState() => _SortPopoverState();
}

class _SortPopoverState extends State<SortPopover> {
  late List<SortRule> _rules;

  @override
  void initState() {
    super.initState();
    _rules = [...widget.initial];
  }

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    return _PopoverShell(
      title: 'Sort',
      tokens: tokens,
      footer: Row(
        children: [
          GestureDetector(
            onTap: () {
              final col = widget.schema.columns.firstWhere(
                (c) => c.key != 'id',
                orElse: () => widget.schema.columns.first,
              );
              setState(() =>
                  _rules.add(SortRule(columnKey: col.key, ascending: true)));
            },
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  QuillIcon('plus', size: 12, strokeWidth: 1.7, color: tokens.text3),
                  const SizedBox(width: 4),
                  Text('Add sort',
                      style: TextStyle(fontSize: 12.5, color: tokens.text2)),
                ],
              ),
            ),
          ),
          const Spacer(),
          if (_rules.isNotEmpty)
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () =>
                    Navigator.of(context).pop(const <SortRule>[]),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  child: Text('Clear',
                      style: TextStyle(fontSize: 12, color: tokens.text2)),
                ),
              ),
            ),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(_rules),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: tokens.accent,
                  borderRadius:
                      const BorderRadius.all(Radius.circular(5)),
                ),
                child: const Text(
                  'Apply',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
      child: _rules.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'No sorts. Default order is by title.',
                style: TextStyle(fontSize: 12.5, color: tokens.text3),
                textAlign: TextAlign.center,
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < _rules.length; i++)
                  _SortRow(
                    schema: widget.schema,
                    rule: _rules[i],
                    onColumnChanged: (k) => setState(
                        () => _rules[i] = SortRule(columnKey: k, ascending: _rules[i].ascending)),
                    onDirChanged: (asc) => setState(() => _rules[i] = SortRule(
                        columnKey: _rules[i].columnKey, ascending: asc)),
                    onRemove: () => setState(() => _rules.removeAt(i)),
                  ),
              ],
            ),
    );
  }
}

class _SortRow extends StatelessWidget {
  const _SortRow({
    required this.schema,
    required this.rule,
    required this.onColumnChanged,
    required this.onDirChanged,
    required this.onRemove,
  });
  final DatabaseSchema schema;
  final SortRule rule;
  final void Function(String) onColumnChanged;
  final void Function(bool ascending) onDirChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: DropdownButton<String>(
              value: rule.columnKey,
              isDense: true,
              underline: const SizedBox.shrink(),
              style: mono(fontSize: 12, color: tokens.text2),
              items: [
                for (final c in schema.columns)
                  if (c.key != 'id')
                    DropdownMenuItem(value: c.key, child: Text(c.key)),
              ],
              onChanged: (v) {
                if (v != null) onColumnChanged(v);
              },
            ),
          ),
          GestureDetector(
            onTap: () => onDirChanged(!rule.ascending),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: tokens.divider2, width: 0.5),
                  borderRadius: const BorderRadius.all(Radius.circular(4)),
                ),
                child: Text(rule.ascending ? '↑ asc' : '↓ desc',
                    style:
                        TextStyle(fontSize: 11.5, color: tokens.text2)),
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(2),
            constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
            onPressed: onRemove,
            tooltip: 'Remove sort',
            icon: QuillIcon('x', size: 11, strokeWidth: 1.7, color: tokens.text3),
          ),
        ],
      ),
    );
  }
}

/// Group selector — primary + optional secondary sub-group column.
class GroupPopover extends StatefulWidget {
  const GroupPopover({
    super.key,
    required this.schema,
    required this.initial,
    this.initialSub,
  });
  final DatabaseSchema schema;
  final String? initial;
  final String? initialSub;

  @override
  State<GroupPopover> createState() => _GroupPopoverState();
}

class _GroupPopoverState extends State<GroupPopover> {
  String? _selected;
  String? _sub;

  @override
  void initState() {
    super.initState();
    _selected = widget.initial;
    _sub = widget.initialSub;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    return _PopoverShell(
      title: 'Group by',
      tokens: tokens,
      footer: Row(
        children: [
          const Spacer(),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () =>
                  Navigator.of(context).pop((value: null, sub: null)),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                child: Text('None',
                    style: TextStyle(fontSize: 12, color: tokens.text2)),
              ),
            ),
          ),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => Navigator.of(context)
                  .pop((value: _selected, sub: _sub)),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: tokens.accent,
                  borderRadius:
                      const BorderRadius.all(Radius.circular(5)),
                ),
                child: const Text(
                  'Apply',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text('PRIMARY',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
                  color: tokens.text3,
                )),
          ),
          for (final c in widget.schema.columns)
            if (c.key != 'id')
              _GroupRow(
                label: c.key,
                selected: _selected == c.key,
                onTap: () => setState(() => _selected =
                    _selected == c.key ? null : c.key),
              ),
          if (_selected != null) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 4),
              child: Text('SUB-GROUP',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.0,
                    color: tokens.text3,
                  )),
            ),
            for (final c in widget.schema.columns)
              if (c.key != 'id' && c.key != _selected)
                _GroupRow(
                  label: c.key,
                  selected: _sub == c.key,
                  onTap: () =>
                      setState(() => _sub = _sub == c.key ? null : c.key),
                ),
          ],
        ],
      ),
    );
  }
}

class _GroupRow extends StatelessWidget {
  const _GroupRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? tokens.accentTint : Colors.transparent,
            border: selected
                ? Border(left: BorderSide(color: tokens.accent, width: 2))
                : const Border(
                    left: BorderSide(color: Colors.transparent, width: 2)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(label,
                    style: mono(
                        fontSize: 12.5,
                        color: selected ? tokens.accent : tokens.text2)),
              ),
              if (selected)
                Icon(Icons.check, size: 13, color: tokens.accent),
            ],
          ),
        ),
      ),
    );
  }
}

/// Internal — shared chrome (header bar + body padding + footer).
class _PopoverShell extends StatelessWidget {
  const _PopoverShell({
    required this.title,
    required this.tokens,
    required this.child,
    required this.footer,
  });
  final String title;
  final QuillTokens tokens;
  final Widget child;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 460,
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border.all(color: tokens.divider2, width: 0.5),
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        boxShadow: [
          BoxShadow(
            color: tokens.isDark
                ? Colors.black.withValues(alpha: 0.45)
                : Colors.black.withValues(alpha: 0.10),
            blurRadius: 36,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: tokens.divider, width: 0.5)),
            ),
            child: Row(
              children: [
                Text(title.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.0,
                      color: tokens.text3,
                    )),
                const Spacer(),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(2),
                  constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Close',
                  icon: QuillIcon('x', size: 12, strokeWidth: 1.7, color: tokens.text3),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
            child: child,
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 8, 10, 10),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: tokens.divider, width: 0.5)),
            ),
            child: footer,
          ),
        ],
      ),
    );
  }
}

/// Toggle column visibility per-view. Title is always shown (not in
/// the list). The popover pops a `Set<String>?` of visible column keys
/// or null if the user picks "Show all" → equivalent to no override.
class PropertiesPopover extends StatefulWidget {
  const PropertiesPopover({
    super.key,
    required this.schema,
    required this.initial,
  });

  final DatabaseSchema schema;
  final Set<String>? initial;

  @override
  State<PropertiesPopover> createState() => _PropertiesPopoverState();
}

class _PropertiesPopoverState extends State<PropertiesPopover> {
  late Set<String> _visible;

  @override
  void initState() {
    super.initState();
    _visible = widget.initial != null
        ? {...widget.initial!}
        : {
            for (final c in widget.schema.columns)
              if (c.key != 'id') c.key,
          };
  }

  void _toggle(String key) {
    setState(() {
      if (_visible.contains(key)) {
        _visible.remove(key);
      } else {
        _visible.add(key);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    final togglable = [
      for (final c in widget.schema.columns)
        if (c.key != 'id' && c.key != 'title') c,
    ];
    return _PopoverShell(
      title: 'Properties',
      tokens: tokens,
      footer: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop((visible: null)),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Text('Show all',
                    style: TextStyle(fontSize: 12, color: tokens.text2)),
              ),
            ),
          ),
          const Spacer(),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop((visible: _visible)),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: tokens.accent,
                  borderRadius:
                      const BorderRadius.all(Radius.circular(5)),
                ),
                child: const Text(
                  'Apply',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PropertyRow(
            label: 'title',
            visible: true,
            locked: true,
            onTap: () {},
          ),
          for (final c in togglable)
            _PropertyRow(
              label: c.key,
              visible: _visible.contains(c.key),
              locked: false,
              onTap: () => _toggle(c.key),
            ),
        ],
      ),
    );
  }
}

typedef PropertiesPopoverResult = ({Set<String>? visible});

class _PropertyRow extends StatefulWidget {
  const _PropertyRow({
    required this.label,
    required this.visible,
    required this.locked,
    required this.onTap,
  });

  final String label;
  final bool visible;
  final bool locked;
  final VoidCallback onTap;

  @override
  State<_PropertyRow> createState() => _PropertyRowState();
}

class _PropertyRowState extends State<_PropertyRow> {
  bool _hover = false;

  String get label => widget.label;
  bool get visible => widget.visible;
  bool get locked => widget.locked;

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    return MouseRegion(
      cursor: locked ? SystemMouseCursors.basic : SystemMouseCursors.click,
      onEnter: locked ? null : (_) => setState(() => _hover = true),
      onExit: locked ? null : (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: locked ? null : widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
          decoration: BoxDecoration(
            color: _hover ? tokens.hover : null,
            borderRadius: const BorderRadius.all(Radius.circular(4)),
          ),
          child: Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: visible ? tokens.accent : Colors.transparent,
                  border: Border.all(
                      color:
                          visible ? tokens.accent : tokens.divider2,
                      width: 1),
                  borderRadius: const BorderRadius.all(Radius.circular(3)),
                ),
                child: visible
                    ? const Center(
                        child:
                            Icon(Icons.check, size: 11, color: Colors.white),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: mono(
                    fontSize: 12.5,
                    color: locked ? tokens.text3 : tokens.text2,
                  ),
                ),
              ),
              if (locked)
                Text('always shown',
                    style: TextStyle(fontSize: 11, color: tokens.text3)),
            ],
          ),
        ),
      ),
    );
  }
}
