import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../database/domain/entities/database_schema.dart';
import '../../../database/domain/repositories/database_repository.dart';
import '../../../relations/domain/usecases/search_pages.dart';
import '../../domain/command_entry.dart';

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
  CommandPaletteCubit({required SearchPages searchPages, required DatabaseRepository dbRepo})
      : _search = searchPages,
        _dbRepo = dbRepo,
        super(CommandPaletteState.closed);

  final SearchPages _search;
  final DatabaseRepository _dbRepo;

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
    final pages = await _search(q, limit: 8);
    final allDbs = await _dbRepo.listDatabases();
    final databases = q.isEmpty
        ? allDbs
        : allDbs
            .where((d) => d.name.toLowerCase().contains(q.toLowerCase()))
            .toList();
    final actions = _filterActions(_baseActions, q);
    if (state.query == q) {
      emit(state.copyWith(pages: pages, databases: databases, actions: actions));
    }
  }

  static const _baseActions = <CommandEntry>[
    CommandEntry(group: CommandGroup.actions, icon: 'reveal', label: 'Reveal vault in Finder', hint: '⌘⇧R'),
    CommandEntry(group: CommandGroup.actions, icon: 'export', label: 'Export vault to folder', hint: ''),
    CommandEntry(group: CommandGroup.actions, icon: 'sync', label: 'Reindex vault', hint: '⌘R'),
    CommandEntry(group: CommandGroup.actions, icon: 'eye', label: 'Toggle theme', hint: ''),
    CommandEntry(group: CommandGroup.actions, icon: 'eye', label: 'Toggle compact mode', hint: ''),
    CommandEntry(group: CommandGroup.actions, icon: 'trash', label: 'Show trash', hint: ''),
    CommandEntry(group: CommandGroup.actions, icon: 'table', label: 'Import CSV as database', hint: ''),
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
