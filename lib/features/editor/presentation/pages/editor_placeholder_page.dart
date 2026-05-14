import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/db/quill_database.dart' hide Page;
import '../../../../shared/theme/quill_tokens.dart';
import '../../../../shared/theme/tokens.dart';
import '../../../../shared/widgets/quill_icon.dart';
import '../../../vault/presentation/widgets/page_header.dart';

/// Temporary editor route until the real editor lands in M5. Loads the page
/// row from drift and shows the markdown body as plain text.
class EditorPlaceholderPage extends StatelessWidget {
  const EditorPlaceholderPage({super.key, required this.ulid});
  final String ulid;

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    final db = context.read<QuillDatabase>();

    return FutureBuilder(
      future: (db.select(db.pages)..where((p) => p.ulid.equals(ulid))).getSingleOrNull(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return Center(
            child: SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 1.5, color: tokens.text2),
            ),
          );
        }
        final page = snap.data;
        if (page == null) {
          return Column(
            children: [
              PageHeader(crumbs: ['…', ulid]),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      QuillIcon('file-md', size: 28, color: tokens.text3),
                      const SizedBox(height: 8),
                      Text('Page not found', style: TextStyle(color: tokens.text2)),
                      const SizedBox(height: 4),
                      Text(ulid, style: mono(fontSize: 11, color: tokens.text3)),
                    ],
                  ),
                ),
              ),
            ],
          );
        }
        final crumbs = page.relativePath.split('/');
        return Column(
          children: [
            PageHeader(crumbs: crumbs),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(64, 32, 64, 120),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: QuillSpacing.editorMax),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          page.title,
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                            color: tokens.text,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SelectableText(
                          page.bodyText,
                          style: TextStyle(fontSize: 16, color: tokens.text, height: 1.6),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Editor with WYSIWYG/source toggle lands in M5.',
                          style: mono(fontSize: 11, color: tokens.text3),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
