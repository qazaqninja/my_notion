import 'package:equatable/equatable.dart';

import '../../../vault/domain/entities/page.dart';

enum EditorMode { rendered, source }

sealed class EditorState extends Equatable {
  const EditorState();
  @override
  List<Object?> get props => [];
}

class EditorIdle extends EditorState {
  const EditorIdle();
}

class EditorLoading extends EditorState {
  const EditorLoading(this.ulid);
  final String ulid;
  @override
  List<Object?> get props => [ulid];
}

class EditorLoaded extends EditorState {
  const EditorLoaded({
    required this.page,
    required this.mode,
    required this.dirty,
    required this.saving,
  });

  final Page page;
  final EditorMode mode;
  final bool dirty;
  final bool saving;

  EditorLoaded copyWith({Page? page, EditorMode? mode, bool? dirty, bool? saving}) {
    return EditorLoaded(
      page: page ?? this.page,
      mode: mode ?? this.mode,
      dirty: dirty ?? this.dirty,
      saving: saving ?? this.saving,
    );
  }

  @override
  List<Object?> get props => [page.ulid, page.body, mode, dirty, saving];
}

class EditorError extends EditorState {
  const EditorError(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}
