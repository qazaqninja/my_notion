import 'package:equatable/equatable.dart';

import '../../../vault/domain/entities/frontmatter_entry.dart';
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

/// Replace a single frontmatter entry by key (preserves position).
class EditFrontmatterField extends EditorEvent {
  const EditFrontmatterField(this.key, this.newEntry);
  final String key;
  final FrontmatterEntry newEntry;
  @override
  List<Object?> get props => [key, newEntry];
}

/// Append a new entry. No-op if [key] already exists.
class AddFrontmatterField extends EditorEvent {
  const AddFrontmatterField(this.entry);
  final FrontmatterEntry entry;
  @override
  List<Object?> get props => [entry];
}

/// Remove the entry with [key]. No-op if absent. The `id` field is protected
/// (silently ignored) — it's the page identifier and must remain stable.
class RemoveFrontmatterField extends EditorEvent {
  const RemoveFrontmatterField(this.key);
  final String key;
  @override
  List<Object?> get props => [key];
}

/// Replace the entire YAML block. Parses [rawYaml], rebuilds entries, and
/// merges back into the page. Emits an EditorError if the YAML is invalid.
class ReplaceFrontmatterYaml extends EditorEvent {
  const ReplaceFrontmatterYaml(this.rawYaml);
  final String rawYaml;
  @override
  List<Object?> get props => [rawYaml];
}

/// Pop the most recent edit off the undo stack and restore the page
/// to that state. No-op when the stack is empty.
class UndoEdit extends EditorEvent {
  const UndoEdit();
}

/// Re-apply the most recent undone edit. No-op when there's nothing to
/// redo (i.e. `_redo` is empty, or the user made a fresh edit after an
/// undo — that clears the redo stack to prevent branching history).
class RedoEdit extends EditorEvent {
  const RedoEdit();
}
