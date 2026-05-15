import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/theme/quill_tokens.dart';
import '../../../../shared/theme/tokens.dart';
import '../../../../shared/widgets/emoji_picker.dart';
import '../../../../shared/widgets/quill_icon.dart';
import '../../../vault/presentation/widgets/page_header.dart';
import '../../domain/entities/database_schema.dart';
import '../../domain/repositories/database_repository.dart';

/// Index of every database in the vault. Reached via /databases or the
/// mobile tab bar's Bases entry. Each row links to `/db/<id>`.
class DatabasesPage extends StatefulWidget {
  const DatabasesPage({super.key});

  @override
  State<DatabasesPage> createState() => _DatabasesPageState();
}

class _DatabasesPageState extends State<DatabasesPage> {
  late Future<List<DatabaseSchema>> _data;

  @override
  void initState() {
    super.initState();
    _data = _load();
  }

  Future<List<DatabaseSchema>> _load() =>
      context.read<DatabaseRepository>().listDatabases();

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    return Scaffold(
      backgroundColor: tokens.bg,
      body: Column(
        children: [
          const PageHeader(crumbs: ['Databases']),
          Expanded(
            child: FutureBuilder<List<DatabaseSchema>>(
              future: _data,
              builder: (context, snap) {
                if (snap.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          QuillIcon('warning',
                              size: 22,
                              strokeWidth: 1.4,
                              color: tokens.text3),
                          const SizedBox(height: 10),
                          Text('Could not list databases',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: tokens.text2,
                              )),
                          const SizedBox(height: 4),
                          Text(
                            '${snap.error}',
                            textAlign: TextAlign.center,
                            style:
                                mono(fontSize: 11, color: tokens.text3),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                if (!snap.hasData) {
                  return Center(
                    child: SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 1.5, color: tokens.text2),
                    ),
                  );
                }
                final items = snap.data!
                  ..sort((a, b) => a.name.compareTo(b.name));
                if (items.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          QuillIcon('database',
                              size: 24,
                              strokeWidth: 1.4,
                              color: tokens.text3),
                          const SizedBox(height: 10),
                          Text('No databases yet',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: tokens.text2,
                              )),
                          const SizedBox(height: 4),
                          Text(
                            'Drop a .database.yaml in any folder of the\n'
                            'vault to make Quill index it as a database.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: tokens.text3,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  itemCount: items.length,
                  itemBuilder: (_, i) => _Row(schema: items[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatefulWidget {
  const _Row({required this.schema});
  final DatabaseSchema schema;

  @override
  State<_Row> createState() => _RowState();
}

class _RowState extends State<_Row> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    final schema = widget.schema;
    final iconRaw = schema.icon.trim();
    final hasGlyphIcon = looksLikeEmoji(iconRaw);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () => context.go('/db/${schema.id}'),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          decoration: BoxDecoration(
            color: _hover ? tokens.surface2 : tokens.surface,
            border: Border.all(
                color: _hover ? tokens.accent : tokens.divider2, width: 0.5),
            borderRadius: const BorderRadius.all(Radius.circular(6)),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tokens.surface2,
                  borderRadius: const BorderRadius.all(Radius.circular(5)),
                ),
                child: hasGlyphIcon
                    ? Text(iconRaw,
                        style: TextStyle(fontSize: 16, color: tokens.text))
                    : QuillIcon('database',
                        size: 14,
                        strokeWidth: 1.7,
                        color: tokens.text3),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Tooltip(
                      message: schema.name,
                      waitDuration: const Duration(milliseconds: 600),
                      child: Text(
                        schema.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: tokens.text,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Tooltip(
                      message:
                          '${schema.folderPath}/.database.yaml\n${schema.columns.length} ${schema.columns.length == 1 ? "column" : "columns"} · ${schema.views.length} ${schema.views.length == 1 ? "view" : "views"}',
                      waitDuration: const Duration(milliseconds: 600),
                      child: Text(
                        '${schema.folderPath}  ·  '
                        '${schema.columns.length} ${schema.columns.length == 1 ? 'column' : 'columns'}  ·  '
                        '${schema.views.length} ${schema.views.length == 1 ? 'view' : 'views'}',
                        style: mono(fontSize: 11.5, color: tokens.text3),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 18, color: tokens.text3),
            ],
          ),
        ),
      ),
    );
  }
}
