// This page is a dev / lab showcase of design tokens; the strict
// `child:` ordering convention makes the side-by-side ComponentBox
// comparison harder to read.
// ignore_for_file: sort_child_properties_last

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../theme/accent.dart';
import '../theme/quill_tokens.dart';
import '../theme/tag_colors.dart';
import '../theme/theme_cubit.dart';
import '../theme/tokens.dart';
import 'frontmatter_row.dart';
import 'image_placeholder.dart';
import 'kbd.dart';
import 'quill_icon.dart';
import 'relation_chip.dart';
import 'segment.dart';
import 'side_item.dart';
import 'status_dot.dart';
import 'tag_chip.dart';

/// Visual contract for every primitive. Open at /lab. Ports
/// `component-sheet.jsx` shape-for-shape.
class ComponentSheetPage extends StatelessWidget {
  const ComponentSheetPage({super.key});

  // Demonstrates light + dark side-by-side regardless of the global theme.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101010),
      appBar: AppBar(
        title: const Text('quill / components'),
        backgroundColor: const Color(0xFF101010),
        foregroundColor: Colors.white,
        actions: [
          BlocBuilder<ThemeCubit, ThemeState>(
            builder: (context, state) {
              return TextButton(
                onPressed: () => context.read<ThemeCubit>().toggleAccent(),
                child: Text(
                  'accent: ${state.accent.label}',
                  style: const TextStyle(color: Colors.white70),
                ),
              );
            },
          ),
        ],
      ),
      body: BlocBuilder<ThemeCubit, ThemeState>(
        builder: (context, state) {
          return Row(
            children: [
              Expanded(
                child: _ComponentArtboard(
                  brightness: Brightness.light,
                  accent: state.accent,
                ),
              ),
              Container(width: 1, color: Colors.white12),
              Expanded(
                child: _ComponentArtboard(
                  brightness: Brightness.dark,
                  accent: state.accent,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ComponentArtboard extends StatelessWidget {
  const _ComponentArtboard({required this.brightness, required this.accent});

  final Brightness brightness;
  final AccentKey accent;

  @override
  Widget build(BuildContext context) {
    final theme = makeTheme(brightness, accent);
    return Theme(
      data: theme,
      child: Builder(
        builder: (innerContext) {
          final tokens = QuillTokens.of(innerContext);
          return Container(
            color: tokens.bg,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(40, 40, 48, 60),
              child: DefaultTextStyle(
                style: theme.textTheme.bodyMedium!.copyWith(color: tokens.text),
                child: const _SheetBody(),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SheetBody extends StatelessWidget {
  const _SheetBody();

  static const _northwindUlid = '01HX0V9R5N6E8L3P7Q8S9U2X4B';

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Text('quill / components',
            style: mono(fontSize: 11.5, color: tokens.text3, letterSpacing: 0.4)),
        const SizedBox(height: 6),
        Text(
          'Component sheet',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
            color: tokens.text,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 640,
          child: Text(
            'Atoms used across the eight screens. Restrained on purpose — chips are paper-coloured, dividers near-invisible, mono used only where it earns its place.',
            style: TextStyle(fontSize: 14, color: tokens.text3, height: 1.55),
          ),
        ),
        const SizedBox(height: 36),

        _SectionHeading('Color', tokens: tokens),
        Row(
          children: [
            _Swatch(color: const Color(0xFFF8F6F2), label: 'bg / light', sub: '#F8F6F2', tokens: tokens),
            const SizedBox(width: 12),
            _Swatch(color: const Color(0xFF1A1A1A), label: 'text / dark', sub: '#1A1A1A', tokens: tokens),
            const SizedBox(width: 12),
            _Swatch(color: tokens.accent, label: 'accent', sub: _toHex(tokens.accent), tokens: tokens),
            const SizedBox(width: 12),
            _Swatch(color: tokens.accentTint, label: 'tint', sub: 'accent · 10%', tokens: tokens),
            const SizedBox(width: 12),
            _Swatch(color: tokens.divider2, label: 'divider', sub: '≤ 8% opacity', tokens: tokens),
          ],
        ),
        const SizedBox(height: 36),

        _SectionHeading('Typography', tokens: tokens),
        Wrap(
          spacing: 24,
          runSpacing: 12,
          children: [
            _TypeSpec(
              label: 'Inter · 30 / 700',
              child: Text('H1 Northwind',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: -0.5, color: tokens.text)),
              tokens: tokens,
            ),
            _TypeSpec(
              label: 'Inter · 19 / 600',
              child: Text('H2 Status',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600, color: tokens.text)),
              tokens: tokens,
            ),
            _TypeSpec(
              label: 'Inter · 16 / 400 · 1.6',
              child: SizedBox(
                width: 320,
                child: Text(
                  'Body. 16/1.6 reads as paper. Long passages stay below 720px.',
                  style: TextStyle(fontSize: 16, color: tokens.text, height: 1.6),
                ),
              ),
              tokens: tokens,
            ),
            _TypeSpec(
              label: 'JetBrains Mono · 13',
              child: Text(_northwindUlid, style: mono(fontSize: 13, color: tokens.text)),
              tokens: tokens,
            ),
          ],
        ),
        const SizedBox(height: 36),

        _SectionHeading('Components', tokens: tokens),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 2.4,
          children: [
            _Spec(
              name: 'chip · relation',
              anno: 'ULID-resolved',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: const [
                  RelationChip(label: 'Northwind', ulid: _northwindUlid, icon: 'file-md'),
                  SizedBox(height: 6),
                  RelationChip(label: 'Northwind', ulid: _northwindUlid, showUlid: true, icon: 'file-md'),
                  SizedBox(height: 6),
                  RelationChip(label: '2026 Q1 QBR', icon: 'file-md'),
                ],
              ),
              tokens: tokens,
            ),
            _Spec(
              name: 'tag · select',
              anno: 'muted hues',
              child: Wrap(
                spacing: 5,
                runSpacing: 5,
                children: const [
                  TagChip(label: 'expanding', color: TagColor.green),
                  TagChip(label: 'pilot', color: TagColor.blue),
                  TagChip(label: 'churn-risk', color: TagColor.red),
                  TagChip(label: 'evaluation', color: TagColor.yellow),
                  TagChip(label: 'strategic', color: TagColor.purple),
                  TagChip(label: 'net-new', color: TagColor.orange),
                  TagChip(label: 'archive', color: TagColor.gray),
                  TagChip(label: 'ops', color: TagColor.pink),
                ],
              ),
              tokens: tokens,
            ),
            _Spec(
              name: 'status · dot',
              anno: 'health / sync',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final c in const [
                    StatusDotColor.green,
                    StatusDotColor.yellow,
                    StatusDotColor.red,
                    StatusDotColor.gray,
                  ])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 7),
                      child: Row(children: [
                        StatusDot(color: c),
                        const SizedBox(width: 8),
                        Text(c.name,
                            style: TextStyle(fontSize: 12.5, color: tokens.text2)),
                      ]),
                    ),
                ],
              ),
              tokens: tokens,
            ),
            _Spec(
              name: 'frontmatter row',
              anno: 'type-aware editor',
              child: Container(
                color: tokens.bg,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FrontmatterRow(fieldKey: 'stage', type: FrontmatterDisplayType.select, value: 'expanding', tagColor: TagColor.green),
                    FrontmatterRow(fieldKey: 'arr', type: FrontmatterDisplayType.number, value: r'$420,000'),
                    FrontmatterRow(fieldKey: 'tags', type: FrontmatterDisplayType.multi, value: ['logistics', 'enterprise']),
                  ],
                ),
              ),
              tokens: tokens,
            ),
            _Spec(
              name: 'segment · view switcher',
              anno: 'active = surface',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Segment<String>(
                    value: 'rendered',
                    onChanged: (_) {},
                    options: const [
                      SegmentOption(value: 'rendered', label: 'Rendered', icon: 'eye'),
                      SegmentOption(value: 'source', label: 'Source', icon: 'code'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Segment<String>(
                    value: 'table',
                    onChanged: (_) {},
                    options: const [
                      SegmentOption(value: 'table', label: 'Table', icon: 'table'),
                      SegmentOption(value: 'gallery', label: 'Gallery', icon: 'gallery'),
                      SegmentOption(value: 'board', label: 'Board', icon: 'board'),
                    ],
                  ),
                ],
              ),
              tokens: tokens,
            ),
            _Spec(
              name: 'sidebar item · states',
              anno: 'active / mute / nested',
              child: Container(
                color: tokens.sidebar,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SideItem(icon: 'file-md', label: 'Inbox.md'),
                    SideItem(icon: 'file-md', label: 'Northwind.md', active: true),
                    SideItem(icon: 'folder', label: 'Customers', chevron: SideChevron.open),
                    SideItem(icon: 'file-md', label: 'Acmeco.md', level: 1, mute: true),
                    SideItem(
                      glyph: SideItemGlyph(color: Color(0xFF6B8E7F), letter: 'C'),
                      label: 'Customers',
                      count: 48,
                    ),
                  ],
                ),
              ),
              tokens: tokens,
            ),
            _Spec(
              name: 'kbd · keycap',
              anno: 'mono · 11',
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  const Kbd('⌘'),
                  const Kbd('K'),
                  Text('or', style: TextStyle(fontSize: 12, color: tokens.text3)),
                  const Kbd('⌘'),
                  const Kbd('P'),
                  Text('or', style: TextStyle(fontSize: 12, color: tokens.text3)),
                  const Kbd('↵'),
                  const Kbd('j'),
                  const Kbd('k'),
                ],
              ),
              tokens: tokens,
            ),
            _Spec(
              name: 'placeholder · image',
              anno: 'striped, mono caption',
              child: const ImagePlaceholder(label: 'cover · northwind', height: 70),
              tokens: tokens,
            ),
          ],
        ),
        const SizedBox(height: 36),

        _SectionHeading('Icons', tokens: tokens),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final name in const [
              'caret-down', 'search', 'plus', 'x', 'file-md', 'folder',
              'database', 'table', 'gallery', 'board', 'timeline',
              'filter', 'sort', 'group', 'kebab-h', 'eye', 'code',
              'sync', 'cloud', 'git', 'tag', 'calendar', 'archive',
              'trash', 'users', 'hash', 'select', 'checksquare', 'gear',
              'home', 'inbox', 'export', 'reveal', 'link', 'sidebar', 'panel',
            ])
              SizedBox(
                width: 64,
                child: Column(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border.all(color: tokens.divider2, width: 0.5),
                        borderRadius: const BorderRadius.all(Radius.circular(4)),
                      ),
                      child: QuillIcon(name, size: 16, color: tokens.text2),
                    ),
                    const SizedBox(height: 4),
                    Text(name, style: mono(fontSize: 9.5, color: tokens.text3), textAlign: TextAlign.center),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }

  static String _toHex(Color c) {
    final r = (c.r * 255).round().toRadixString(16).padLeft(2, '0').toUpperCase();
    final g = (c.g * 255).round().toRadixString(16).padLeft(2, '0').toUpperCase();
    final b = (c.b * 255).round().toRadixString(16).padLeft(2, '0').toUpperCase();
    return '#$r$g$b';
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading(this.text, {required this.tokens});
  final String text;
  final QuillTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.0,
          color: tokens.text3,
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.color, required this.label, required this.sub, required this.tokens});
  final Color color;
  final String label;
  final String sub;
  final QuillTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 56,
            decoration: BoxDecoration(
              color: color,
              border: Border.all(color: tokens.divider2, width: 0.5),
              borderRadius: const BorderRadius.all(Radius.circular(5)),
            ),
          ),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(fontSize: 12, color: tokens.text, fontWeight: FontWeight.w500)),
          const SizedBox(height: 1),
          Text(sub, style: mono(fontSize: 11, color: tokens.text3)),
        ],
      ),
    );
  }
}

class _TypeSpec extends StatelessWidget {
  const _TypeSpec({required this.label, required this.child, required this.tokens});
  final String label;
  final Widget child;
  final QuillTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: mono(fontSize: 11, color: tokens.text3)),
        const SizedBox(height: 4),
        child,
      ],
    );
  }
}

class _Spec extends StatelessWidget {
  const _Spec({required this.name, required this.anno, required this.child, required this.tokens});
  final String name;
  final String anno;
  final Widget child;
  final QuillTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border.all(color: tokens.divider2, width: 0.5),
        borderRadius: const BorderRadius.all(Radius.circular(6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Text(name, style: mono(fontSize: 11.5, color: tokens.text2)),
                const Spacer(),
                Text(anno, style: TextStyle(fontSize: 11, color: tokens.text3)),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: tokens.divider, width: 0.5)),
            ),
            padding: const EdgeInsets.only(top: 10),
            child: child,
          ),
        ],
      ),
    );
  }
}
