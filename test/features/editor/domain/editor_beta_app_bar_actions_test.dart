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
        EditorBetaAppBarAction.pageHistory,
        EditorBetaAppBarAction.setFont,
        EditorBetaAppBarAction.setReminder,
        EditorBetaAppBarAction.moveToTrash,
      };
      final authed = editorBetaAppBarActions(isAuthed: true).toSet();
      final anon = editorBetaAppBarActions(isAuthed: false).toSet();
      expect(authed.containsAll(alwaysOn), isTrue);
      expect(anon.containsAll(alwaysOn), isTrue);
    });

    test('returns actions in the stable AppBar order: '
        'pull → find → share → copyLink → copyUlid → copyPath → '
        'duplicate → reveal → rename → publishToggle → pageHistory → '
        'setFont → setReminder → moveToTrash', () {
      // Order matters so the rendered AppBar matches the post-D-fp14
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
        EditorBetaAppBarAction.pageHistory,
        EditorBetaAppBarAction.setFont,
        EditorBetaAppBarAction.setReminder,
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
        EditorBetaAppBarAction.pageHistory,
        EditorBetaAppBarAction.setFont,
        EditorBetaAppBarAction.setReminder,
        EditorBetaAppBarAction.moveToTrash,
      ]);
    });
  });

  // M1727 (D-fp13 kebab refactor slice 1): partition the actions
  // into the AppBar top-bar IconButtons + the kebab PopupMenuButton
  // entries. Tests are pure-Dart against the enum.
  group('isEditorBetaKebabAction', () {
    test('pullFromServer / findInPage / share / moveToTrash are top-bar', () {
      expect(
        isEditorBetaKebabAction(EditorBetaAppBarAction.pullFromServer),
        isFalse,
      );
      expect(
        isEditorBetaKebabAction(EditorBetaAppBarAction.findInPage),
        isFalse,
      );
      expect(
        isEditorBetaKebabAction(EditorBetaAppBarAction.share),
        isFalse,
      );
      expect(
        isEditorBetaKebabAction(EditorBetaAppBarAction.moveToTrash),
        isFalse,
      );
    });

    test('all secondary actions are kebab entries', () {
      const kebab = <EditorBetaAppBarAction>{
        EditorBetaAppBarAction.copyLink,
        EditorBetaAppBarAction.copyUlid,
        EditorBetaAppBarAction.copyPath,
        EditorBetaAppBarAction.duplicate,
        EditorBetaAppBarAction.reveal,
        EditorBetaAppBarAction.rename,
        EditorBetaAppBarAction.publishToggle,
        EditorBetaAppBarAction.pageHistory,
        EditorBetaAppBarAction.setFont,
        EditorBetaAppBarAction.setReminder,
      };
      for (final action in kebab) {
        expect(
          isEditorBetaKebabAction(action),
          isTrue,
          reason: '${action.name} should be in the kebab',
        );
      }
    });

    test('partition is exhaustive — every enum value is classified', () {
      for (final action in EditorBetaAppBarAction.values) {
        // Calling isEditorBetaKebabAction shouldn't throw or hit an
        // unreached switch arm; both branches return a concrete bool.
        final classified = isEditorBetaKebabAction(action);
        expect(classified, isA<bool>());
      }
    });
  });

  group('editorBetaTopBarActions / editorBetaKebabActions', () {
    test('together cover the full action set in stable order', () {
      final top = editorBetaTopBarActions(isAuthed: true).toList();
      final kebab = editorBetaKebabActions(isAuthed: true).toList();
      expect(
        {...top, ...kebab},
        EditorBetaAppBarAction.values.toSet(),
        reason: 'partition should cover every enum value',
      );
      // No overlap between the two sets.
      expect(top.toSet().intersection(kebab.toSet()), isEmpty);
    });

    test('top-bar drops pullFromServer in the unauthed sequence', () {
      expect(editorBetaTopBarActions(isAuthed: false).toList(), [
        EditorBetaAppBarAction.findInPage,
        EditorBetaAppBarAction.share,
        EditorBetaAppBarAction.moveToTrash,
      ]);
    });

    test('top-bar authed sequence is pull → find → share → moveToTrash', () {
      expect(editorBetaTopBarActions(isAuthed: true).toList(), [
        EditorBetaAppBarAction.pullFromServer,
        EditorBetaAppBarAction.findInPage,
        EditorBetaAppBarAction.share,
        EditorBetaAppBarAction.moveToTrash,
      ]);
    });

    test('kebab sequence preserves the original ordering', () {
      // The 8 secondary entries must appear in the same relative
      // order as in editorBetaAppBarActions so users see a consistent
      // sequence as actions move between the top-bar and the kebab.
      expect(editorBetaKebabActions(isAuthed: true).toList(), [
        EditorBetaAppBarAction.copyLink,
        EditorBetaAppBarAction.copyUlid,
        EditorBetaAppBarAction.copyPath,
        EditorBetaAppBarAction.duplicate,
        EditorBetaAppBarAction.reveal,
        EditorBetaAppBarAction.rename,
        EditorBetaAppBarAction.publishToggle,
        EditorBetaAppBarAction.pageHistory,
        EditorBetaAppBarAction.setFont,
        EditorBetaAppBarAction.setReminder,
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

      test('pageHistory tooltip reads the D-fp12 port label', () {
        expect(
          EditorBetaAppBarAction.pageHistory.tooltip,
          'Page history (git log)',
        );
      });

      test('setFont tooltip reads the D-fp14 port label', () {
        expect(EditorBetaAppBarAction.setFont.tooltip, 'Set page font');
      });

      test('setReminder tooltip reads the D-fp15 port label', () {
        expect(
          EditorBetaAppBarAction.setReminder.tooltip,
          'Set reminder…',
        );
      });
    });
  });
}
