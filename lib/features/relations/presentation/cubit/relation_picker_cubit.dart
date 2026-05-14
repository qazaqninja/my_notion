import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/search_pages.dart';

class RelationPickerState extends Equatable {
  const RelationPickerState({
    required this.open,
    required this.query,
    required this.results,
    required this.selectedIndex,
    this.anchorRect,
    this.anchorStartOffset = 0,
  });

  /// Whether the overlay is currently shown.
  final bool open;

  /// Current query text (the chars typed AFTER the `[[`).
  final String query;

  final List<PageSearchResult> results;

  /// Highlighted result row.
  final int selectedIndex;

  /// Screen-space rect of the `[[` trigger — used to position the overlay.
  final Rect? anchorRect;

  /// Character offset of the opening `[[` in the source text. Used when
  /// the user picks a result so we know where to splice the ULID.
  final int anchorStartOffset;

  static const closed = RelationPickerState(
    open: false,
    query: '',
    results: [],
    selectedIndex: 0,
  );

  RelationPickerState copyWith({
    bool? open,
    String? query,
    List<PageSearchResult>? results,
    int? selectedIndex,
    Rect? anchorRect,
    int? anchorStartOffset,
  }) {
    return RelationPickerState(
      open: open ?? this.open,
      query: query ?? this.query,
      results: results ?? this.results,
      selectedIndex: selectedIndex ?? this.selectedIndex,
      anchorRect: anchorRect ?? this.anchorRect,
      anchorStartOffset: anchorStartOffset ?? this.anchorStartOffset,
    );
  }

  PageSearchResult? get selectedResult =>
      (selectedIndex >= 0 && selectedIndex < results.length) ? results[selectedIndex] : null;

  @override
  List<Object?> get props => [open, query, results, selectedIndex, anchorRect, anchorStartOffset];
}

class RelationPickerCubit extends Cubit<RelationPickerState> {
  RelationPickerCubit(this._search) : super(RelationPickerState.closed);

  final SearchPages _search;

  Future<void> openAt({required Rect anchor, required int sourceOffset}) async {
    emit(state.copyWith(
      open: true,
      anchorRect: anchor,
      anchorStartOffset: sourceOffset,
      query: '',
      selectedIndex: 0,
    ));
    final results = await _search('');
    emit(state.copyWith(results: results));
  }

  Future<void> setQuery(String q) async {
    if (!state.open) return;
    emit(state.copyWith(query: q, selectedIndex: 0));
    final results = await _search(q);
    if (state.query == q) {
      emit(state.copyWith(results: results));
    }
  }

  void move(int delta) {
    if (!state.open || state.results.isEmpty) return;
    final next = (state.selectedIndex + delta).clamp(0, state.results.length - 1);
    emit(state.copyWith(selectedIndex: next));
  }

  void dismiss() => emit(RelationPickerState.closed);
}
