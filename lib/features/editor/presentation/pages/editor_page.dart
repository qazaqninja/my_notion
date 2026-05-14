import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/db/quill_database.dart' hide Page;
import '../../../../shared/theme/quill_tokens.dart';
import '../../../../shared/theme/tokens.dart';
import '../../../../shared/widgets/quill_icon.dart';
import '../../../../shared/widgets/responsive_layout.dart';
import '../../../../shared/widgets/segment.dart';
import '../../../vault/data/indexer.dart';
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

class _EditorBodyState extends State<_EditorBody> {
  bool _propertiesOpen = false;

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
                          constraints: const BoxConstraints(maxWidth: QuillSpacing.editorMax),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              PageTitleField(title: page.title),
                              FrontmatterCard(frontmatter: page.frontmatter),
                              if (loaded.mode == EditorMode.rendered)
                                MarkdownRenderer(body: page.body)
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
                              const SizedBox(height: 80),
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
