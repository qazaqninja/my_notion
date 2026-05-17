import 'package:flutter/material.dart' hide Page;
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:printing/printing.dart';

import '../../../../core/markdown/yaml_scalar.dart';
import '../../../../core/platform/reveal.dart';
import '../../../vault/data/pdf_exporter.dart';
import '../../../../shared/theme/quill_tokens.dart';
import '../../../../shared/theme/tokens.dart';
import '../../../../shared/widgets/quill_icon.dart';
import '../../../../shared/widgets/responsive_layout.dart';
import '../../../../shared/widgets/quill_overlays.dart';
import '../../../../shared/widgets/relation_chip.dart';
import '../../../../shared/widgets/segment.dart';
import '../../../vault/domain/entities/frontmatter.dart';
import '../../../vault/domain/entities/frontmatter_entry.dart' as fe;
import '../../../vault/domain/entities/page.dart';
import '../../../vault/presentation/bloc/vault_bloc.dart';
import '../../../vault/presentation/bloc/vault_state.dart';
import '../bloc/editor_bloc.dart';
import '../bloc/editor_event.dart';
import 'comments_dialog.dart';

enum PropertiesView { fields, yaml }

// ---------------------------------------------------------------------------
// M1682 — touch-tuned properties panel rows. Pure-Dart helpers picked
// between dense (desktop) and tall-touch (mobile) sizing. Same pattern
// as M1680's slash_menu_overlay helpers. Production reads them from
// `_EditableFrontmatterRow.build` via `isMobileWidth`.
// ---------------------------------------------------------------------------

/// Row container padding. Mobile bumps to 14 vertical so the resulting
/// row height clears the 44pt Material touch-target floor (14 + ~16
/// content + 14 = ~44). Desktop stays at the current dense 4.
EdgeInsets propertiesRowPaddingFor({required bool isMobile}) => isMobile
    ? const EdgeInsets.symmetric(vertical: 14)
    : const EdgeInsets.symmetric(vertical: 4);

/// Leading type-icon size. Mobile bumps to 16; desktop stays at 12.
double propertiesRowIconSizeFor({required bool isMobile}) =>
    isMobile ? 16 : 12;

/// Key-column font size (the frontmatter field name in `mono`). Mobile
/// bumps to 15 (touch-comfortable body); desktop stays at the dense 12.
double propertiesRowKeyFontSizeFor({required bool isMobile}) =>
    isMobile ? 15 : 12;

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
  bool _addingField = false;

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
            color: Theme.of(context)
                .colorScheme
                .shadow
                .withValues(alpha: tokens.isDark ? 0.35 : 0.06),
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
                  tooltip: 'Close properties panel',
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
                    SegmentOption(
                        value: PropertiesView.fields,
                        label: 'Fields',
                        tooltip: 'Edit each frontmatter field with a typed input'),
                    SegmentOption(
                        value: PropertiesView.yaml,
                        label: 'YAML',
                        icon: 'code',
                        tooltip: 'Edit the raw YAML frontmatter block'),
                  ],
                ),
                const Spacer(),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: _view == PropertiesView.fields
                      ? () => setState(() => _addingField = true)
                      : null,
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  tooltip: _view == PropertiesView.fields
                      ? 'Add field'
                      : 'Switch to Fields view to add',
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
                  Tooltip(
                    message:
                        'Frontmatter fields of type relation — values are [[ULID]] links to other pages.',
                    waitDuration: const Duration(milliseconds: 500),
                    child: Text(
                      'RELATIONS',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.0,
                        color: tokens.text3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _relationsList(tokens),
                  const SizedBox(height: 18),
                  Container(height: 0.5, color: tokens.divider),
                  const SizedBox(height: 8),
                  _actionRow(
                    tokens, 'reveal', 'Reveal in Finder', '⌘⌥R',
                    onTap: () => _revealPage(context),
                  ),
                  _actionRow(
                    tokens, 'link', 'Copy ULID link', '',
                    onTap: () => _copyUlid(context),
                  ),
                  _actionRow(
                    tokens, 'note', 'Comments', '',
                    onTap: () => _openComments(context),
                  ),
                  _actionRow(
                    tokens, 'export', 'Print…', '',
                    onTap: () => _printPage(context),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// True when the page's frontmatter marks it `locked: true` or
  /// `permissions: read_only` (mirrors EditorBloc.isLocked but operates
  /// on a raw Frontmatter so we don't need to pass EditorLoaded around).
  bool _isLocked() {
    final fm = widget.page.frontmatter;
    final v = fm.get('locked');
    if (v == true || '$v'.toLowerCase() == 'true') return true;
    final p = fm.get('permissions');
    final ps = '$p'.trim().toLowerCase();
    return ps == 'read_only' ||
        ps == 'read-only' ||
        ps == 'readonly' ||
        ps == 'locked';
  }

  bool _guardUnlocked() {
    if (!_isLocked()) return true;
    context.toastInfo('Page is locked',
        sub: 'Unlock the page (⌘⇧L) to edit properties');
    return false;
  }

  Widget _fieldsBody(QuillTokens tokens) {
    final entries = widget.page.frontmatter.entries
        .where((e) => e.key != 'id')
        .toList();
    return Column(
      children: [
        if (entries.isEmpty && !_addingField)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                QuillIcon('hash',
                    size: 22, strokeWidth: 1.4, color: tokens.text3),
                const SizedBox(height: 10),
                Text(
                  'No properties yet',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: tokens.text2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Click + above to add a field.',
                  style: TextStyle(fontSize: 12, color: tokens.text3),
                ),
              ],
            ),
          ),
        for (final entry in entries)
          _EditableFrontmatterRow(
            key: ValueKey('fm-${entry.key}'),
            entry: entry,
            onChange: (next) {
              if (!_guardUnlocked()) return;
              context
                  .read<EditorBloc>()
                  .add(EditFrontmatterField(entry.key, next));
            },
            onRemove: () {
              if (!_guardUnlocked()) return;
              context
                  .read<EditorBloc>()
                  .add(RemoveFrontmatterField(entry.key));
            },
          ),
        if (_addingField)
          _AddFieldForm(
            existingKeys: widget.page.frontmatter.keys.toSet(),
            onCancel: () => setState(() => _addingField = false),
            onAdd: (newEntry) {
              if (!_guardUnlocked()) {
                setState(() => _addingField = false);
                return;
              }
              context
                  .read<EditorBloc>()
                  .add(AddFrontmatterField(newEntry));
              setState(() => _addingField = false);
            },
          ),
      ],
    );
  }

  Widget _yamlBody(QuillTokens tokens) {
    final raw = widget.page.frontmatter.rawYaml ?? _regenerate(widget.page.frontmatter);
    return _YamlEditor(
      key: ValueKey('yaml-${widget.page.ulid}-${raw.hashCode}'),
      initial: raw,
      onSave: (text) {
        // EditorBloc.ReplaceFrontmatterYaml silently swallows on
        // locked pages (editor_bloc.dart:330). Without the guard the
        // user would click Apply, see nothing happen, and have no
        // idea why — same fix M681 applied to the field-edit path.
        if (!_guardUnlocked()) return;
        context
            .read<EditorBloc>()
            .add(ReplaceFrontmatterYaml(text));
      },
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

  Future<void> _revealPage(BuildContext context) async {
    final vault = context.read<VaultBloc>().state;
    if (vault is! VaultLoaded) return;
    final abs = '${vault.rootPath}/${widget.page.relativePath}';
    final ok = await Reveal.show(abs);
    if (!ok && context.mounted) {
      context.toastError('Could not reveal', sub: abs, subMono: true);
    }
  }

  Future<void> _copyUlid(BuildContext context) async {
    // Label says "Copy ULID link" — that's the wikilink form, not the
    // bare ULID. (Bare ULID lives in the kebab menu's "Copy ULID".)
    final link = '[[${widget.page.ulid}]]';
    await ClipboardSetter.set(link);
    if (context.mounted) context.toastSuccess('Copied $link', subMono: true);
  }

  Future<void> _printPage(BuildContext context) async {
    final page = widget.page;
    try {
      final bytes = await const PdfExporter().exportSingle(
        title: page.title,
        body: page.body,
      );
      await Printing.layoutPdf(
        name: page.title,
        onLayout: (_) async => Uint8List.fromList(bytes),
      );
    } catch (e) {
      if (context.mounted) context.toastError('Print failed', sub: '$e');
    }
  }

  Future<void> _openComments(BuildContext context) async {
    final vault = context.read<VaultBloc>().state;
    if (vault is! VaultLoaded) return;
    await showQuillModal<void>(
      context,
      builder: (_) => CommentsDialog(
        vaultRoot: vault.rootPath,
        pageUlid: widget.page.ulid,
        defaultAuthor: vault.workspace.currentUserName ?? 'You',
      ),
    );
  }

  Widget _actionRow(
    QuillTokens tokens,
    String icon,
    String label,
    String hint, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap ?? () {},
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

}

String _iconForType(fe.FrontmatterType t) => switch (t) {
      fe.FrontmatterType.ulid => 'hash',
      fe.FrontmatterType.text => 'note',
      fe.FrontmatterType.number => 'hash',
      fe.FrontmatterType.date => 'calendar',
      fe.FrontmatterType.select => 'select',
      fe.FrontmatterType.multi => 'tag',
      fe.FrontmatterType.relation => 'link',
      fe.FrontmatterType.checkbox => 'checksquare',
      fe.FrontmatterType.formula => 'code',
      fe.FrontmatterType.file => 'file',
    };

String _labelForType(fe.FrontmatterType t) => switch (t) {
      fe.FrontmatterType.ulid => 'ULID',
      fe.FrontmatterType.text => 'Text',
      fe.FrontmatterType.number => 'Number',
      fe.FrontmatterType.date => 'Date',
      fe.FrontmatterType.select => 'Select',
      fe.FrontmatterType.multi => 'Multi',
      fe.FrontmatterType.relation => 'Relation',
      fe.FrontmatterType.checkbox => 'Checkbox',
      fe.FrontmatterType.formula => 'Formula',
      fe.FrontmatterType.file => 'File',
    };

/// Inline editor row used in the Fields view. Defers to a type-specific
/// control: TextField for text/number, calendar-shaped TextField for date,
/// chip-toggle for checkbox, comma-split for multi.
class _EditableFrontmatterRow extends StatefulWidget {
  const _EditableFrontmatterRow({
    super.key,
    required this.entry,
    required this.onChange,
    required this.onRemove,
  });

  final fe.FrontmatterEntry entry;
  final void Function(fe.FrontmatterEntry next) onChange;
  final VoidCallback onRemove;

  @override
  State<_EditableFrontmatterRow> createState() => _EditableFrontmatterRowState();
}

class _EditableFrontmatterRowState extends State<_EditableFrontmatterRow> {
  late final TextEditingController _controller;
  late final FocusNode _focus;
  bool _hover = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _initialText());
    _focus = FocusNode();
    _focus.addListener(_onFocusLost);
  }

  @override
  void didUpdateWidget(_EditableFrontmatterRow old) {
    super.didUpdateWidget(old);
    // External update (e.g. YAML edit replaced this entry) — sync the field
    // unless the user is mid-edit.
    if (!_focus.hasFocus && _controller.text != _initialText()) {
      _controller.text = _initialText();
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusLost);
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  String _initialText() {
    final v = widget.entry.value;
    if (v is List) return v.join(', ');
    if (v == null) return widget.entry.rawScalar;
    return '$v';
  }

  void _onFocusLost() {
    if (_focus.hasFocus) return;
    _commit(_controller.text);
  }

  void _commit(String text) {
    final next = _buildNextEntry(text);
    if (next == widget.entry &&
        '${next.value}' == '${widget.entry.value}' &&
        next.rawScalar == widget.entry.rawScalar) {
      return;
    }
    widget.onChange(next);
  }

  fe.FrontmatterEntry _buildNextEntry(String text) {
    final type = widget.entry.type;
    switch (type) {
      case fe.FrontmatterType.number:
        final n = num.tryParse(text.trim());
        return widget.entry.copyWith(
          rawScalar: n?.toString() ?? text.trim(),
          value: n ?? text.trim(),
        );
      case fe.FrontmatterType.multi:
        // Quote-aware split (M783) — `"a, b", c` yields two items
        // not three.
        final parts = parseMultiValueInput(text);
        return widget.entry.copyWith(
          rawScalar: '[${parts.map(yamlFlowItem).join(', ')}]',
          value: parts,
        );
      case fe.FrontmatterType.checkbox:
        final b = text.trim().toLowerCase() == 'true';
        return widget.entry.copyWith(
          rawScalar: b ? 'true' : 'false',
          value: b,
        );
      case fe.FrontmatterType.text:
      case fe.FrontmatterType.date:
      case fe.FrontmatterType.select:
      case fe.FrontmatterType.ulid:
      case fe.FrontmatterType.relation:
      case fe.FrontmatterType.formula:
      case fe.FrontmatterType.file:
        return widget.entry
            .copyWith(rawScalar: yamlSafeScalar(text), value: text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    final type = widget.entry.type;
    // M1682: per-row touch tuning — bump padding + icon + key font on
    // narrow widths so each row clears the 44pt touch-target floor.
    final isMobile = isMobileWidth(context);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Container(
        padding: propertiesRowPaddingFor(isMobile: isMobile),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: tokens.divider, width: 0.5)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 96,
              child: Row(
                children: [
                  Tooltip(
                    message: _labelForType(type),
                    waitDuration: const Duration(milliseconds: 500),
                    child: QuillIcon(_iconForType(type),
                        size: propertiesRowIconSizeFor(isMobile: isMobile),
                        strokeWidth: 1.7,
                        color: tokens.text3),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Tooltip(
                      message: widget.entry.key,
                      waitDuration: const Duration(milliseconds: 600),
                      child: Text(
                        widget.entry.key,
                        style: mono(
                          fontSize: propertiesRowKeyFontSizeFor(
                            isMobile: isMobile,
                          ),
                          color: tokens.text3,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: _input(tokens)),
            Visibility(
              visible: _hover,
              maintainSize: true,
              maintainState: true,
              maintainAnimation: true,
              child: IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: widget.onRemove,
                padding: const EdgeInsets.all(2),
                constraints:
                    const BoxConstraints(minWidth: 22, minHeight: 22),
                icon: QuillIcon('x',
                    size: 11, strokeWidth: 1.7, color: tokens.text3),
                tooltip: 'Remove field',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _input(QuillTokens tokens) {
    if (widget.entry.type == fe.FrontmatterType.checkbox) {
      final on = widget.entry.value == true ||
          widget.entry.rawScalar.toLowerCase() == 'true';
      return Align(
        alignment: Alignment.centerLeft,
        child: GestureDetector(
          onTap: () => widget.onChange(widget.entry.copyWith(
            rawScalar: on ? 'false' : 'true',
            value: !on,
          )),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: on ? tokens.accent : Colors.transparent,
                border: Border.all(color: on ? tokens.accent : tokens.divider2, width: 1),
                borderRadius: const BorderRadius.all(Radius.circular(3)),
              ),
              child: on
                  ? Center(
                      child: Icon(Icons.check,
                          size: 12,
                          color: Theme.of(context).colorScheme.onPrimary),
                    )
                  : null,
            ),
          ),
        ),
      );
    }
    final isMono = widget.entry.type == fe.FrontmatterType.number ||
        widget.entry.type == fe.FrontmatterType.date ||
        widget.entry.type == fe.FrontmatterType.ulid;
    return TextField(
      controller: _controller,
      focusNode: _focus,
      onSubmitted: _commit,
      style: isMono
          ? mono(fontSize: 13, color: tokens.text)
          : TextStyle(fontSize: 13, color: tokens.text, height: 1.5),
      decoration: InputDecoration(
        isCollapsed: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 4),
        border: InputBorder.none,
        hintText: switch (widget.entry.type) {
          fe.FrontmatterType.date => 'YYYY-MM-DD',
          fe.FrontmatterType.multi => 'comma-separated',
          _ => '',
        },
        hintStyle: TextStyle(fontSize: 12, color: tokens.text3),
      ),
    );
  }
}

/// Inline form for the "+" button. Picks a key, a type, and an optional
/// initial value, then dispatches `AddFrontmatterField`.
class _AddFieldForm extends StatefulWidget {
  const _AddFieldForm({
    required this.existingKeys,
    required this.onAdd,
    required this.onCancel,
  });

  final Set<String> existingKeys;
  final void Function(fe.FrontmatterEntry entry) onAdd;
  final VoidCallback onCancel;

  @override
  State<_AddFieldForm> createState() => _AddFieldFormState();
}

class _AddFieldFormState extends State<_AddFieldForm> {
  final _keyCtl = TextEditingController();
  final _valCtl = TextEditingController();
  fe.FrontmatterType _type = fe.FrontmatterType.text;

  @override
  void dispose() {
    _keyCtl.dispose();
    _valCtl.dispose();
    super.dispose();
  }

  void _submit() {
    final key = _keyCtl.text.trim();
    if (key.isEmpty || widget.existingKeys.contains(key)) return;
    final text = _valCtl.text;
    final entry = switch (_type) {
      fe.FrontmatterType.number => fe.FrontmatterEntry(
          key: key,
          rawScalar: text,
          type: _type,
          value: num.tryParse(text.trim()) ?? text.trim(),
        ),
      fe.FrontmatterType.checkbox => fe.FrontmatterEntry(
          key: key,
          rawScalar: text.trim().toLowerCase() == 'true' ? 'true' : 'false',
          type: _type,
          value: text.trim().toLowerCase() == 'true',
        ),
      fe.FrontmatterType.multi => () {
          // Quote-aware split (M783).
          final items = parseMultiValueInput(text);
          return fe.FrontmatterEntry(
            key: key,
            rawScalar: '[${items.map(yamlFlowItem).join(', ')}]',
            type: _type,
            value: items,
          );
        }(),
      _ => fe.FrontmatterEntry(
          key: key, rawScalar: yamlSafeScalar(text), type: _type, value: text),
    };
    widget.onAdd(entry);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    final duplicate = widget.existingKeys.contains(_keyCtl.text.trim());
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: tokens.surface2,
        border: Border.all(color: tokens.divider2, width: 0.5),
        borderRadius: const BorderRadius.all(Radius.circular(6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _keyCtl,
                  autofocus: true,
                  onChanged: (_) => setState(() {}),
                  style: mono(fontSize: 12.5, color: tokens.text),
                  decoration: const InputDecoration(
                    isCollapsed: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 6),
                    border: InputBorder.none,
                    hintText: 'field key',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _TypeDropdown(
                value: _type,
                onChanged: (t) => setState(() => _type = t),
              ),
            ],
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _valCtl,
            onSubmitted: (_) => _submit(),
            style: TextStyle(fontSize: 13, color: tokens.text),
            decoration: InputDecoration(
              isCollapsed: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 6),
              border: InputBorder.none,
              hintText: switch (_type) {
                fe.FrontmatterType.date => 'YYYY-MM-DD',
                fe.FrontmatterType.checkbox => 'true / false',
                fe.FrontmatterType.multi => 'a, b, c',
                _ => 'value',
              },
              hintStyle: TextStyle(fontSize: 12, color: tokens.text3),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (duplicate)
                Text('key exists',
                    style: TextStyle(fontSize: 11.5, color: tokens.text3)),
              const Spacer(),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: widget.onCancel,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    child: Text('Cancel',
                        style: TextStyle(
                            fontSize: 12.5, color: tokens.text2)),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              MouseRegion(
                cursor: _keyCtl.text.trim().isEmpty || duplicate
                    ? SystemMouseCursors.basic
                    : SystemMouseCursors.click,
                child: Tooltip(
                  message: _keyCtl.text.trim().isEmpty
                      ? 'Type a field key to add'
                      : duplicate
                          ? 'A field with this key already exists'
                          : 'Add field to frontmatter',
                  waitDuration: const Duration(milliseconds: 500),
                  child: GestureDetector(
                    onTap: _keyCtl.text.trim().isEmpty || duplicate
                        ? null
                        : _submit,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: _keyCtl.text.trim().isEmpty || duplicate
                            ? tokens.surface
                            : tokens.accent,
                        borderRadius:
                            const BorderRadius.all(Radius.circular(5)),
                      ),
                      child: Text(
                        'Add',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: _keyCtl.text.trim().isEmpty || duplicate
                              ? tokens.text3
                              : Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TypeDropdown extends StatelessWidget {
  const _TypeDropdown({required this.value, required this.onChanged});
  final fe.FrontmatterType value;
  final void Function(fe.FrontmatterType) onChanged;

  static const List<fe.FrontmatterType> _editableTypes = [
    fe.FrontmatterType.text,
    fe.FrontmatterType.number,
    fe.FrontmatterType.date,
    fe.FrontmatterType.select,
    fe.FrontmatterType.multi,
    fe.FrontmatterType.checkbox,
  ];

  @override
  Widget build(BuildContext context) {
    return QuillSelect<fe.FrontmatterType>(
      value: value,
      onChanged: onChanged,
      dense: true,
      mono: true,
      width: 120,
      options: [
        for (final t in _editableTypes)
          QuillSelectOption(value: t, label: _labelForType(t)),
      ],
    );
  }
}

/// Editable raw-YAML textarea with Save / Revert.
class _YamlEditor extends StatefulWidget {
  const _YamlEditor({super.key, required this.initial, required this.onSave});
  final String initial;
  final void Function(String text) onSave;

  @override
  State<_YamlEditor> createState() => _YamlEditorState();
}

class _YamlEditorState extends State<_YamlEditor> {
  late final TextEditingController _ctl;

  @override
  void initState() {
    super.initState();
    _ctl = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    final dirty = _ctl.text != widget.initial;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: tokens.bg,
        border: Border.all(color: tokens.divider2, width: 0.5),
        borderRadius: const BorderRadius.all(Radius.circular(5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _ctl,
              maxLines: null,
              minLines: 4,
              onChanged: (_) => setState(() {}),
              style: mono(fontSize: 12.5, color: tokens.text2).copyWith(height: 1.6),
              decoration: const InputDecoration.collapsed(hintText: ''),
            ),
          ),
          if (dirty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: tokens.divider, width: 0.5)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () => setState(() => _ctl.text = widget.initial),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        child: Text('Revert',
                            style: TextStyle(
                                fontSize: 12, color: tokens.text2)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () => widget.onSave(_ctl.text),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: tokens.accent,
                          borderRadius:
                              const BorderRadius.all(Radius.circular(5)),
                        ),
                        child: Text(
                          'Apply',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color:
                                  Theme.of(context).colorScheme.onPrimary),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Wrapper around `flutter/services` clipboard. Lives here to keep the
/// import out of the main panel body.
class ClipboardSetter {
  static Future<void> set(String text) async {
    // We deliberately import services only here to avoid pulling it into
    // every consumer of this file.
    // ignore: depend_on_referenced_packages
    await _platformSet(text);
  }

  static Future<void> _platformSet(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
  }
}
