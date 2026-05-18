import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/editor/domain/editor_beta_app_bar_actions.dart';

void main() {
  group('editorBetaAppBarActions', () {
    test('includes pullFromServer when authed', () {
      final actions = editorBetaAppBarActions(isAuthed: true).toList();
      expect(actions, contains(EditorBetaAppBarAction.pullFromServer));
    });

    test('omits pullFromServer when not authed', () {
      final actions = editorBetaAppBarActions(isAuthed: false).toList();
      expect(actions, isNot(contains(EditorBetaAppBarAction.pullFromServer)));
    });

    test('always includes the always-on actions regardless of auth', () {
      final alwaysOn = <EditorBetaAppBarAction>{
        EditorBetaAppBarAction.findInPage,
        EditorBetaAppBarAction.share,
        EditorBetaAppBarAction.copyLink,
        EditorBetaAppBarAction.copyUlid,
        EditorBetaAppBarAction.copyPath,
        EditorBetaAppBarAction.duplicate,
        EditorBetaAppBarAction.reveal,
        EditorBetaAppBarAction.rename,
        EditorBetaAppBarAction.publishToggle,
        EditorBetaAppBarAction.moveToTrash,
      };
      final authed = editorBetaAppBarActions(isAuthed: true).toSet();
      final anon = editorBetaAppBarActions(isAuthed: false).toSet();
      expect(authed.containsAll(alwaysOn), isTrue);
      expect(anon.containsAll(alwaysOn), isTrue);
    });

    test('returns actions in the stable AppBar order: '
        'pull → find → share → copyLink → copyUlid → copyPath → '
        'duplicate → reveal → rename → publishToggle → moveToTrash', () {
      // Order matters so the rendered AppBar matches the post-D-fp11
      // layout users have already learned. Future kebab refactor will
      // map this directly to PopupMenuItem rows.
      expect(editorBetaAppBarActions(isAuthed: true).toList(), [
        EditorBetaAppBarAction.pullFromServer,
        EditorBetaAppBarAction.findInPage,
        EditorBetaAppBarAction.share,
        EditorBetaAppBarAction.copyLink,
        EditorBetaAppBarAction.copyUlid,
        EditorBetaAppBarAction.copyPath,
        EditorBetaAppBarAction.duplicate,
        EditorBetaAppBarAction.reveal,
        EditorBetaAppBarAction.rename,
        EditorBetaAppBarAction.publishToggle,
        EditorBetaAppBarAction.moveToTrash,
      ]);
    });

    test('drops only pullFromServer in the unauthed sequence', () {
      expect(editorBetaAppBarActions(isAuthed: false).toList(), [
        EditorBetaAppBarAction.findInPage,
        EditorBetaAppBarAction.share,
        EditorBetaAppBarAction.copyLink,
        EditorBetaAppBarAction.copyUlid,
        EditorBetaAppBarAction.copyPath,
        EditorBetaAppBarAction.duplicate,
        EditorBetaAppBarAction.reveal,
        EditorBetaAppBarAction.rename,
        EditorBetaAppBarAction.publishToggle,
        EditorBetaAppBarAction.moveToTrash,
      ]);
    });
  });

  // M1701 (TS-04 fix-forward on M1700 audit): tooltip tests live inside
  // the enum-named outer group with `.tooltip getter` as the sub-group,
  // since the property is the unit under test rather than a method.
  group('EditorBetaAppBarAction', () {
    group('.tooltip getter', () {
      test('each enum carries a non-empty user-visible tooltip', () {
        for (final action in EditorBetaAppBarAction.values) {
          expect(action.tooltip.isNotEmpty, isTrue,
              reason: '${action.name} should have a tooltip');
        }
      });

      test('copyUlid tooltip reads "Copy ULID" (D-fp6 port label)', () {
        expect(EditorBetaAppBarAction.copyUlid.tooltip, 'Copy ULID');
      });

      test('copyLink tooltip reads the M1696-shipped label', () {
        expect(
          EditorBetaAppBarAction.copyLink.tooltip,
          'Copy [[link]] to this page',
        );
      });

      test('copyPath tooltip reads "Copy file path" (D-fp7 port label)', () {
        expect(EditorBetaAppBarAction.copyPath.tooltip, 'Copy file path');
      });

      test('duplicate tooltip reads "Duplicate page" (D-fp8 port label)',
          () {
        expect(EditorBetaAppBarAction.duplicate.tooltip, 'Duplicate page');
      });

      test('reveal tooltip reads the D-fp9 port label', () {
        expect(
          EditorBetaAppBarAction.reveal.tooltip,
          'Reveal in OS file browser',
        );
      });

      test('rename tooltip reads the D-fp10 port label', () {
        expect(EditorBetaAppBarAction.rename.tooltip, 'Rename file…');
      });

      test('publishToggle tooltip reads the D-fp11 port label', () {
        expect(
          EditorBetaAppBarAction.publishToggle.tooltip,
          'Publish / unpublish',
        );
      });
    });
  });
}
