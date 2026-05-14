import 'package:equatable/equatable.dart';

import 'editor_state.dart';

sealed class EditorEvent extends Equatable {
  const EditorEvent();
  @override
  List<Object?> get props => [];
}

class OpenEditor extends EditorEvent {
  const OpenEditor(this.ulid);
  final String ulid;
  @override
  List<Object?> get props => [ulid];
}

class EditBody extends EditorEvent {
  const EditBody(this.body);
  final String body;
  @override
  List<Object?> get props => [body];
}

class ToggleEditorMode extends EditorEvent {
  const ToggleEditorMode(this.mode);
  final EditorMode mode;
  @override
  List<Object?> get props => [mode];
}

class SaveNow extends EditorEvent {
  const SaveNow();
}
