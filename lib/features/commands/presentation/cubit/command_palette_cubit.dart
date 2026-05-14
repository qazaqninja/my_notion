import 'dart:convert';

import 'package:drift/drift.dart' show OrderingMode, OrderingTerm;
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/db/quill_database.dart' hide Page;
import '../../../database/domain/entities/database_schema.dart';
import '../../../database/domain/repositories/database_repository.dart';
import '../../../relations/domain/usecases/search_pages.dart';
import '../../domain/command_entry.dart';
import '../../domain/command_filter.dart';

class CommandPaletteState extends Equatable {
  const CommandPaletteState({
    required this.open,
    required this.query,
    required this.pages,
    required this.databases,
    required this.actions,
    required this.selectedIndex,
  });

  final bool open;
  final String query;
  final List<PageSearchResult> pages;
  final List<DatabaseSchema> databases;
  final List<CommandEntry> actions;
  final int selectedIndex;

  static const closed = CommandPaletteState(
    open: false,
    query: '',
    pages: [],
    databases: [],
    actions: [],
    selectedIndex: 0,
  );

  CommandPaletteState copyWith({
    bool? open,
    String? query,
    List<PageSearchResult>? pages,
    List<DatabaseSchema>? databases,
    List<CommandEntry>? actions,
    int? selectedIndex,
  }) {
    return CommandPaletteState(
      open: open ?? this.open,
      query: query ?? this.query,
      pages: pages ?? this.pages,
      databases: databases ?? this.databases,
      actions: actions ?? this.actions,
      selectedIndex: selectedIndex ?? this.selectedIndex,
    );
  }

  int get totalResults => pages.length + databases.length + actions.length;

  @override
  List<Object?> get props => [open, query, pages, databases, actions, selectedIndex];
}

class CommandPaletteCubit extends Cubit<CommandPaletteState> {
  CommandPaletteCubit({
    required SearchPages searchPages,
    required DatabaseRepository dbRepo,
    required QuillDatabase db,
  })  : _search = searchPages,
        _dbRepo = dbRepo,
        _db = db,
        super(CommandPaletteState.closed);

  final SearchPages _search;
  final DatabaseRepository _dbRepo;
  final QuillDatabase _db;

  Future<void> open() async {
    emit(state.copyWith(open: true, query: '', selectedIndex: 0));
    await _refresh('');
  }

  Future<void> setQuery(String q) async {
    if (!state.open) return;
    emit(state.copyWith(query: q, selectedIndex: 0));
    await _refresh(q);
  }

  Future<void> _refresh(String q) async {
    final filter = CommandFilter.parse(q);
    final term = filter.term;

    // Page results — varies by scope.
    var pages = const <PageSearchResult>[];
    switch (filter.scope) {
      case CommandFilterScope.none:
      case CommandFilterScope.tag:
        pages = await _search(term, limit: 24);
        break;
      case CommandFilterScope.path:
        // Walk all pages, filter by relativePath prefix. For empty
        // term, list all (cap at 24 by mtime).
        pages = await _pagesByPathPrefix(term, limit: 24);
        break;
      case CommandFilterScope.db:
        // Database-only scope; no page results.
        break;
    }

    // Tag scope: post-filter by frontmatter tags.
    if (filter.scope == CommandFilterScope.tag && term.isNotEmpty) {
      pages = await _filterByTag(pages, term);
    }

    // Cap pages to the usual 8 only when we didn't fan out for path/tag.
    if (filter.scope == CommandFilterScope.none) {
      pages = pages.take(8).toList();
    } else {
      pages = pages.take(12).toList();
    }

    // Database list — db scope filters by name; others show all but only
    // when the query is empty so the user sees them as a reference.
    final allDbs = await _dbRepo.listDatabases();
    final databases = switch (filter.scope) {
      CommandFilterScope.db => term.isEmpty
          ? allDbs
          : allDbs
              .where((d) => d.name.toLowerCase().contains(term.toLowerCase()))
              .toList(),
      CommandFilterScope.none => q.isEmpty
          ? allDbs
          : allDbs
              .where((d) => d.name.toLowerCase().contains(q.toLowerCase()))
              .toList(),
      _ => const <DatabaseSchema>[],
    };

    // Actions: only when not in a scoped query — scoped queries are
    // about navigation, not running commands.
    final actions = filter.scope == CommandFilterScope.none
        ? _filterActions(_baseActions, q)
        : const <CommandEntry>[];

    if (state.query == q) {
      emit(state.copyWith(pages: pages, databases: databases, actions: actions));
    }
  }

  Future<List<PageSearchResult>> _pagesByPathPrefix(
      String prefix, {required int limit}) async {
    final query = _db.select(_db.pages)
      ..orderBy([
        (p) => OrderingTerm(expression: p.mtimeMs, mode: OrderingMode.desc),
      ])
      ..limit(limit);
    final rows = await query.get();
    final lp = prefix.toLowerCase();
    return [
      for (final r in rows)
        if (prefix.isEmpty || r.relativePath.toLowerCase().startsWith(lp))
          PageSearchResult(
            ulid: r.ulid,
            title: r.title,
            relativePath: r.relativePath,
            snippet: '',
          ),
    ];
  }

  Future<List<PageSearchResult>> _filterByTag(
      List<PageSearchResult> pages, String tag) async {
    if (pages.isEmpty) return pages;
    final t = tag.toLowerCase();
    final out = <PageSearchResult>[];
    for (final p in pages) {
      final row = await (_db.select(_db.pages)
            ..where((x) => x.ulid.equals(p.ulid))
            ..limit(1))
          .getSingleOrNull();
      if (row == null) continue;
      final tags = _readTags(row.frontmatterJson);
      if (tags.any((s) => s.toLowerCase() == t)) out.add(p);
    }
    return out;
  }

  static List<String> _readTags(String json) {
    if (json.isEmpty) return const [];
    try {
      final m = jsonDecode(json);
      if (m is! Map) return const [];
      final raw = m['tags'];
      if (raw is List) {
        return [for (final t in raw) '$t'];
      }
      if (raw is String) return [raw];
    } catch (_) {/* fall through */}
    return const [];
  }

  static const _baseActions = <CommandEntry>[
    CommandEntry(group: CommandGroup.actions, icon: 'reveal', label: 'Reveal vault in Finder', hint: '⌘⇧R'),
    CommandEntry(group: CommandGroup.actions, icon: 'export', label: 'Export vault to folder', hint: ''),
    CommandEntry(group: CommandGroup.actions, icon: 'sync', label: 'Reindex vault', hint: '⌘R'),
    CommandEntry(group: CommandGroup.actions, icon: 'eye', label: 'Toggle theme', hint: ''),
    CommandEntry(group: CommandGroup.actions, icon: 'eye', label: 'Toggle compact mode', hint: ''),
    CommandEntry(group: CommandGroup.actions, icon: 'trash', label: 'Show trash', hint: ''),
    CommandEntry(group: CommandGroup.actions, icon: 'table', label: 'Import CSV as database', hint: ''),
    CommandEntry(group: CommandGroup.actions, icon: 'note', label: 'Import HTML file as page', hint: ''),
    CommandEntry(group: CommandGroup.actions, icon: 'note', label: 'Import text file as page', hint: ''),
    CommandEntry(group: CommandGroup.actions, icon: 'note', label: 'Import Markdown file as page', hint: ''),
    CommandEntry(group: CommandGroup.actions, icon: 'note', label: 'Import OPML outline as page', hint: ''),
    CommandEntry(group: CommandGroup.actions, icon: 'note', label: 'Import Roam JSON export', hint: ''),
    CommandEntry(group: CommandGroup.actions, icon: 'export', label: 'Export vault as HTML', hint: ''),
    CommandEntry(group: CommandGroup.actions, icon: 'export', label: 'Export vault as PDF', hint: ''),
    CommandEntry(group: CommandGroup.actions, icon: 'plus', label: 'New page from template…', hint: ''),
    CommandEntry(group: CommandGroup.actions, icon: 'hash', label: 'Vault stats', hint: ''),
    CommandEntry(group: CommandGroup.actions, icon: 'plus', label: 'Install built-in templates', hint: ''),
    CommandEntry(group: CommandGroup.actions, icon: 'database', label: 'Browse all databases', hint: ''),
    CommandEntry(group: CommandGroup.actions, icon: 'plus', label: 'New database…', hint: ''),
    CommandEntry(group: CommandGroup.actions, icon: 'tag', label: 'Browse tags', hint: ''),
  ];

  static List<CommandEntry> _filterActions(List<CommandEntry> all, String q) {
    if (q.isEmpty) return all;
    final lower = q.toLowerCase();
    return [
      for (final a in all)
        if (a.label.toLowerCase().contains(lower)) a,
    ];
  }

  void moveSelection(int delta) {
    if (!state.open || state.totalResults == 0) return;
    final next = (state.selectedIndex + delta).clamp(0, state.totalResults - 1);
    emit(state.copyWith(selectedIndex: next));
  }

  /// Resolve [selectedIndex] back into a typed entry (page/db/action).
  /// Returns null if nothing focused.
  Object? selectedItem() {
    int i = state.selectedIndex;
    if (i < state.pages.length) return state.pages[i];
    i -= state.pages.length;
    if (i < state.databases.length) return state.databases[i];
    i -= state.databases.length;
    if (i < state.actions.length) return state.actions[i];
    return null;
  }

  void dismiss() => emit(CommandPaletteState.closed);
}
