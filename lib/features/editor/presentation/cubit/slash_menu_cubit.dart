import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/slash_entries.dart';

class SlashMenuState extends Equatable {
  const SlashMenuState({
    required this.open,
    required this.query,
    required this.results,
    required this.selectedIndex,
    this.anchorRect,
    this.triggerOffset = 0,
  });

  /// Whether the popover is currently shown.
  final bool open;

  /// Chars typed after the leading `/`.
  final String query;

  final List<SlashEntry> results;

  /// Highlighted row.
  final int selectedIndex;

  /// Screen-space rect of the trigger; used to position the overlay.
  final Rect? anchorRect;

  /// Character offset of the leading `/` in source text, so the inserter
  /// knows where to splice and what to strip when picking.
  final int triggerOffset;

  static const closed = SlashMenuState(
    open: false,
    query: '',
    results: kSlashEntries,
    selectedIndex: 0,
  );

  SlashMenuState copyWith({
    bool? open,
    String? query,
    List<SlashEntry>? results,
    int? selectedIndex,
    Rect? anchorRect,
    int? triggerOffset,
  }) {
    return SlashMenuState(
      open: open ?? this.open,
      query: query ?? this.query,
      results: results ?? this.results,
      selectedIndex: selectedIndex ?? this.selectedIndex,
      anchorRect: anchorRect ?? this.anchorRect,
      triggerOffset: triggerOffset ?? this.triggerOffset,
    );
  }

  SlashEntry? get selected =>
      (selectedIndex >= 0 && selectedIndex < results.length)
          ? results[selectedIndex]
          : null;

  @override
  List<Object?> get props =>
      [open, query, results, selectedIndex, anchorRect, triggerOffset];
}

class SlashMenuCubit extends Cubit<SlashMenuState> {
  SlashMenuCubit() : super(SlashMenuState.closed);

  void openAt({required Rect anchor, required int triggerOffset}) {
    emit(state.copyWith(
      open: true,
      anchorRect: anchor,
      triggerOffset: triggerOffset,
      query: '',
      results: kSlashEntries,
      selectedIndex: 0,
    ));
  }

  void setQuery(String q) {
    if (!state.open) return;
    final results = filterSlashEntries(q);
    final next = results.isEmpty ? 0 : state.selectedIndex.clamp(0, results.length - 1);
    emit(state.copyWith(query: q, results: results, selectedIndex: next));
  }

  void move(int delta) {
    if (!state.open || state.results.isEmpty) return;
    final next = (state.selectedIndex + delta).clamp(0, state.results.length - 1);
    emit(state.copyWith(selectedIndex: next));
  }

  void setSelection(int index) {
    if (!state.open || state.results.isEmpty) return;
    if (index < 0 || index >= state.results.length) return;
    if (state.selectedIndex == index) return;
    emit(state.copyWith(selectedIndex: index));
  }

  void dismiss() => emit(SlashMenuState.closed);
}
