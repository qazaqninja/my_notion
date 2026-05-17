import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_notion/features/forms/domain/entities/form_bearing_page.dart';
import 'package:my_notion/features/forms/domain/repositories/form_bearing_pages_repository.dart';

/// E58b-ii — state shape for the Settings → Forms pane. Standard
/// {initial, loading, success, failure} status enum matching the
/// project convention (M1340 introduced the same shape on the
/// SyncBloc). `pages` carries the last-known list across status
/// flips so the UI can keep rendering rows while a refresh is in
/// flight.
enum FormBearingPagesStatus { initial, loading, success, failure }

class FormBearingPagesState extends Equatable {
  const FormBearingPagesState({
    this.status = FormBearingPagesStatus.initial,
    this.pages = const [],
    this.lastError,
  });

  factory FormBearingPagesState.initial() => const FormBearingPagesState();

  final FormBearingPagesStatus status;
  final List<FormBearingPage> pages;
  final String? lastError;

  FormBearingPagesState copyWith({
    FormBearingPagesStatus? status,
    List<FormBearingPage>? pages,
    String? lastError,
    bool clearError = false,
  }) {
    return FormBearingPagesState(
      status: status ?? this.status,
      pages: pages ?? this.pages,
      lastError: clearError ? null : (lastError ?? this.lastError),
    );
  }

  @override
  List<Object?> get props => [status, pages, lastError];
}

/// Loads form-bearing pages out of [FormBearingPagesRepository] for
/// the Settings → Forms pane. Single async action ([load]) drives
/// the {initial → loading → success | failure} transition. The
/// pane wires a retry button straight to [load] so the user can
/// re-attempt after a transient repo failure.
class FormBearingPagesCubit extends Cubit<FormBearingPagesState> {
  FormBearingPagesCubit({required FormBearingPagesRepository repo})
      : _repo = repo,
        super(FormBearingPagesState.initial());

  final FormBearingPagesRepository _repo;

  /// Re-fetch the form-bearing page list. Clears any prior error
  /// on entry so the UI's stale "load failed" copy disappears
  /// during the new attempt.
  Future<void> load() async {
    emit(state.copyWith(
      status: FormBearingPagesStatus.loading,
      clearError: true,
    ));
    try {
      final pages = await _repo.loadAll();
      emit(state.copyWith(
        status: FormBearingPagesStatus.success,
        pages: pages,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: FormBearingPagesStatus.failure,
        lastError: e is FormBearingPagesLoadException ? e.message : e.toString(),
      ));
    }
  }
}
