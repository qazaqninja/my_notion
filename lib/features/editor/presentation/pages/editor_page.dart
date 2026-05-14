import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/db/quill_database.dart' hide Page;
import '../../../../shared/theme/quill_tokens.dart';
import '../../../../shared/theme/tokens.dart';
import '../../../../shared/widgets/emoji_picker.dart';
import '../../../../shared/widgets/page_icon.dart';
import '../../../../shared/widgets/quill_icon.dart';
import '../../../../shared/widgets/responsive_layout.dart';
import '../../../../shared/widgets/segment.dart';
import '../../../vault/data/indexer.dart';
import '../../../vault/domain/entities/frontmatter_entry.dart';
import '../../../vault/domain/repositories/vault_repository.dart';
// ignore: unused_import — Indexer used via context.read
import '../../../vault/presentation/bloc/vault_bloc.dart';
import '../../../vault/presentation/bloc/vault_state.dart';
import '../../../vault/presentation/widgets/page_header.dart';
import '../bloc/editor_bloc.dart';
import '../bloc/editor_event.dart';
import '../bloc/editor_state.dart';
import '../widgets/backlinks_rail.dart';
import '../widgets/frontmatter_card.dart';
import '../widgets/markdown_renderer.dart';
import '../widgets/outline_rail.dart';
import '../widgets/page_title_field.dart';
import '../widgets/properties_panel.dart';
import '../widgets/source_view.dart';

class EditorPage extends StatelessWidget {
  const EditorPage({super.key, required this.ulid});
  final String ulid;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<EditorBloc>(
      key: ValueKey(ulid),
      create: (context) {
        final bloc = EditorBloc(
          repo: context.read<VaultRepository>(),
          indexer: context.read<Indexer>(),
          db: context.read<QuillDatabase>(),
        );
        final vaultState = context.read<VaultBloc>().state;
        if (vaultState is VaultLoaded) {
          bloc.setVaultRoot(Directory(vaultState.rootPath));
        }
        bloc.add(OpenEditor(ulid));
        return bloc;
      },
      child: const _EditorBody(),
    );
  }
}

class _EditorBody extends StatefulWidget {
  const _EditorBody();

  @override
  State<_EditorBody> createState() => _EditorBodyState();
}

bool _isFullWidth(dynamic frontmatter) {
  final v = frontmatter.get('full_width');
  if (v == true) return true;
  return '${v ?? ''}'.toLowerCase() == 'true';
}

class _EditorBodyState extends State<_EditorBody> {
  bool _propertiesOpen = false;

  Future<void> _pickIcon(BuildContext context, EditorLoaded loaded) async {
    final bloc = context.read<EditorBloc>();
    final picked = await pickEmoji(context);
    if (picked == null) return; // dismissed without choosing
    final fm = loaded.page.frontmatter;
    final existing = fm.find('icon');
    if (picked.isEmpty) {
      // "Clear" — remove the icon entry entirely.
      if (existing != null) {
        bloc.add(const RemoveFrontmatterField('icon'));
      }
      return;
    }
    if (existing == null) {
      bloc.add(AddFrontmatterField(FrontmatterEntry(
        key: 'icon',
        rawScalar: picked,
        type: FrontmatterType.text,
        value: picked,
      )));
    } else {
      bloc.add(EditFrontmatterField(
        'icon',
        existing.copyWith(rawScalar: picked, value: picked),
      ));
    }
  }

  void _toggleLock(BuildContext context, EditorLoaded loaded) {
    final bloc = context.read<EditorBloc>();
    final wasLocked = EditorBloc.isLocked(loaded);
    final fm = loaded.page.frontmatter;
    final existing = fm.find('locked');
    final next = wasLocked ? 'false' : 'true';
    if (existing == null) {
      bloc.add(AddFrontmatterField(FrontmatterEntry(
        key: 'locked',
        rawScalar: next,
        type: FrontmatterType.checkbox,
        value: !wasLocked,
      )));
    } else {
      bloc.add(EditFrontmatterField(
        'locked',
        existing.copyWith(rawScalar: next, value: !wasLocked),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    return BlocBuilder<EditorBloc, EditorState>(
      builder: (context, state) {
        if (state is EditorLoading || state is EditorIdle) {
          return Center(
            child: SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 1.5, color: tokens.text2),
            ),
          );
        }
        if (state is EditorError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                state.message,
                style: TextStyle(color: tokens.text2, fontSize: 14),
              ),
            ),
          );
        }
        final loaded = state as EditorLoaded;
        final page = loaded.page;
        final crumbs = page.relativePath.split('/');
        final mobile = isMobileWidth(context);
        final locked = EditorBloc.isLocked(loaded);
        return Column(
          children: [
            PageHeader(
              crumbs: crumbs,
              extra: Segment<EditorMode>(
                value: loaded.mode,
                onChanged: (m) => context.read<EditorBloc>().add(ToggleEditorMode(m)),
                options: const [
                  SegmentOption(value: EditorMode.rendered, label: 'Rendered', icon: 'eye'),
                  SegmentOption(value: EditorMode.source, label: 'Source', icon: 'code'),
                ],
              ),
              actions: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (loaded.dirty)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        loaded.saving ? 'saving…' : 'unsaved',
                        style: mono(fontSize: 11, color: tokens.text3),
                      ),
                    ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _toggleLock(context, loaded),
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    tooltip: locked ? 'Unlock page' : 'Lock page',
                    icon: Icon(
                      locked ? Icons.lock_outline : Icons.lock_open,
                      size: 15,
                      color: locked ? tokens.accent : tokens.text3,
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => setState(() => _propertiesOpen = !_propertiesOpen),
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    icon: QuillIcon('panel', size: 16, strokeWidth: 1.7,
                        color: _propertiesOpen ? tokens.accent : tokens.text3),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () {},
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    icon: QuillIcon('kebab-h', size: 16, strokeWidth: 1.7, color: tokens.text3),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(horizontal: mobile ? 12 : 64),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: _isFullWidth(page.frontmatter)
                                ? double.infinity
                                : QuillSpacing.editorMax,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              PageCoverBand(
                                coverValue: page.frontmatter.get('cover') is String
                                    ? page.frontmatter.get('cover') as String
                                    : null,
                                vaultRoot: context.read<VaultBloc>().state is VaultLoaded
                                    ? (context.read<VaultBloc>().state as VaultLoaded).rootPath
                                    : null,
                              ),
                              if (locked)
                                Container(
                                  margin: const EdgeInsets.only(top: 16, bottom: 4),
                                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                                  decoration: BoxDecoration(
                                    color: tokens.accentTint,
                                    borderRadius:
                                        const BorderRadius.all(Radius.circular(4)),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.lock_outline,
                                          size: 13, color: tokens.accent),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Locked — click the lock to enable editing',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: tokens.accent,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  GestureDetector(
                                    onTap: locked
                                        ? null
                                        : () => _pickIcon(context, loaded),
                                    child: MouseRegion(
                                      cursor: locked
                                          ? SystemMouseCursors.basic
                                          : SystemMouseCursors.click,
                                      child: Padding(
                                        padding:
                                            const EdgeInsets.only(top: 22, right: 12),
                                        child: PageIcon(
                                          iconValue: page.frontmatter.get('icon') is String
                                              ? page.frontmatter.get('icon') as String
                                              : null,
                                          size: 28,
                                          vaultRoot: context.read<VaultBloc>().state is VaultLoaded
                                              ? (context.read<VaultBloc>().state as VaultLoaded).rootPath
                                              : null,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(child: PageTitleField(title: page.title)),
                                ],
                              ),
                              FrontmatterCard(frontmatter: page.frontmatter),
                              if (loaded.mode == EditorMode.rendered)
                                MarkdownRenderer(
                                  body: page.body,
                                  onBodyChange: locked
                                      ? null
                                      : (next) => context
                                          .read<EditorBloc>()
                                          .add(EditBody(next)),
                                )
                              else
                                SourceView(
                                  key: ValueKey('source-${page.ulid}'),
                                  initialText: page.body,
                                ),
                              if (mobile) ...[
                                const SizedBox(height: 24),
                                OutlineRail(body: page.body),
                                BacklinksRail(toUlid: page.ulid),
                              ],
                              const SizedBox(height: 20),
                              _PageFooter(body: page.body),
                              const SizedBox(height: 60),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_propertiesOpen)
                    PropertiesPanel(
                      page: page,
                      onClose: () => setState(() => _propertiesOpen = false),
                    )
                  else if (!mobile)
                    Container(
                      width: 248,
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                      decoration: BoxDecoration(
                        border: Border(left: BorderSide(color: tokens.divider, width: 0.5)),
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            OutlineRail(body: page.body),
                            BacklinksRail(toUlid: page.ulid),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Tiny dim row at the bottom of the editor: word count, character
/// count, reading-time estimate. Hidden if the body is empty so empty
/// pages don't show "0 words · 0 chars · 1 min".
class _PageFooter extends StatelessWidget {
  const _PageFooter({required this.body});

  final String body;

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    final stripped = body.replaceAll(RegExp(r'```[\s\S]*?```'), ' ');
    final words = stripped
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .length;
    if (words == 0) return const SizedBox.shrink();
    final chars = body.length;
    // 220wpm is a common silent-reading midpoint.
    final mins = (words / 220).ceil().clamp(1, 999);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Text('$words words',
              style: mono(fontSize: 11, color: tokens.text3)),
          Text('  ·  ', style: TextStyle(fontSize: 11, color: tokens.text3)),
          Text('$chars chars',
              style: mono(fontSize: 11, color: tokens.text3)),
          Text('  ·  ', style: TextStyle(fontSize: 11, color: tokens.text3)),
          Text('~$mins min read',
              style: mono(fontSize: 11, color: tokens.text3)),
        ],
      ),
    );
  }
}

