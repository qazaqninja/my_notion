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
      // viewFormSubmissions + copyFormLink are page-conditional rather
      // than session-conditional, so they live outside this
      // "always-on" set — see the dedicated isFormBearing tests below.
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
        EditorBetaAppBarAction.setGoal,
        EditorBetaAppBarAction.exportMarkdown,
        EditorBetaAppBarAction.exportHtml,
        EditorBetaAppBarAction.printPage,
        EditorBetaAppBarAction.setReminder,
        EditorBetaAppBarAction.snoozeReminder,
        EditorBetaAppBarAction.clearReminder,
        EditorBetaAppBarAction.copyBody,
        EditorBetaAppBarAction.copyPlain,
        EditorBetaAppBarAction.copyJson,
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
        'setFont → setGoal → exportMarkdown → exportHtml → '
        'printPage → setReminder → snoozeReminder → clearReminder → '
        'copyBody → copyPlain → copyJson → copyFormLink? → '
        'viewFormSubmissions? → moveToTrash', () {
      // Order matters so the rendered AppBar matches the post-D-fp23
      // layout users have already learned. setGoal slots between
      // setFont and setReminder (D-fp21 / M1745); exportMarkdown +
      // exportHtml slot between setGoal and setReminder (D-fp22 /
      // M1747); printPage closes the export trio immediately after
      // exportHtml (D-fp23 / M1749). The three copy-* entries group
      // together; copyFormLink + viewFormSubmissions (when present)
      // form the form-bearing pair immediately before moveToTrash.
      expect(
          editorBetaAppBarActions(isAuthed: true, isFormBearing: true).toList(),
          [
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
            EditorBetaAppBarAction.setGoal,
            EditorBetaAppBarAction.exportMarkdown,
            EditorBetaAppBarAction.exportHtml,
            EditorBetaAppBarAction.printPage,
            EditorBetaAppBarAction.setReminder,
            EditorBetaAppBarAction.snoozeReminder,
            EditorBetaAppBarAction.clearReminder,
            EditorBetaAppBarAction.copyBody,
            EditorBetaAppBarAction.copyPlain,
            EditorBetaAppBarAction.copyJson,
            EditorBetaAppBarAction.copyFormLink,
            EditorBetaAppBarAction.viewFormSubmissions,
            EditorBetaAppBarAction.moveToTrash,
          ]);
    });

    test('drops only pullFromServer in the unauthed sequence', () {
      expect(
          editorBetaAppBarActions(isAuthed: false, isFormBearing: true)
              .toList(),
          [
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
            EditorBetaAppBarAction.setGoal,
            EditorBetaAppBarAction.exportMarkdown,
            EditorBetaAppBarAction.exportHtml,
            EditorBetaAppBarAction.printPage,
            EditorBetaAppBarAction.setReminder,
            EditorBetaAppBarAction.snoozeReminder,
            EditorBetaAppBarAction.clearReminder,
            EditorBetaAppBarAction.copyBody,
            EditorBetaAppBarAction.copyPlain,
            EditorBetaAppBarAction.copyJson,
            EditorBetaAppBarAction.copyFormLink,
            EditorBetaAppBarAction.viewFormSubmissions,
            EditorBetaAppBarAction.moveToTrash,
          ]);
    });

    test('drops viewFormSubmissions when isFormBearing is false (M1741)', () {
      // D-fp19 / M1741: the kebab "View form submissions →" entry is
      // page-conditional, not session-conditional. A non-form-bearing
      // page should not see the option at all — matches the legacy
      // editor's `if (_hasForms(loaded)) ...[ … ]` gate.
      final actions = editorBetaAppBarActions(isAuthed: true).toList();
      expect(actions, isNot(contains(
        EditorBetaAppBarAction.viewFormSubmissions,
      )));
    });

    test('drops copyFormLink when isFormBearing is false (M1743)', () {
      // D-fp20 / M1743: pairs with viewFormSubmissions — same
      // form-bearing gate, same legacy `if (_hasForms(loaded))`
      // wrap that hides both entries when the page lacks a `forms:`
      // field.
      final actions = editorBetaAppBarActions(isAuthed: true).toList();
      expect(actions, isNot(contains(EditorBetaAppBarAction.copyFormLink)));
    });

    test('includes viewFormSubmissions when isFormBearing is true', () {
      final actions = editorBetaAppBarActions(
        isAuthed: true,
        isFormBearing: true,
      ).toList();
      expect(actions, contains(EditorBetaAppBarAction.viewFormSubmissions));
    });

    test('includes copyFormLink when isFormBearing is true', () {
      final actions = editorBetaAppBarActions(
        isAuthed: true,
        isFormBearing: true,
      ).toList();
      expect(actions, contains(EditorBetaAppBarAction.copyFormLink));
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
        EditorBetaAppBarAction.setGoal,
        EditorBetaAppBarAction.exportMarkdown,
        EditorBetaAppBarAction.exportHtml,
        EditorBetaAppBarAction.printPage,
        EditorBetaAppBarAction.setReminder,
        EditorBetaAppBarAction.snoozeReminder,
        EditorBetaAppBarAction.clearReminder,
        EditorBetaAppBarAction.copyBody,
        EditorBetaAppBarAction.copyPlain,
        EditorBetaAppBarAction.copyJson,
        EditorBetaAppBarAction.copyFormLink,
        EditorBetaAppBarAction.viewFormSubmissions,
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
      final top = editorBetaTopBarActions(
        isAuthed: true,
        isFormBearing: true,
      ).toList();
      final kebab = editorBetaKebabActions(
        isAuthed: true,
        isFormBearing: true,
      ).toList();
      expect(
        {...top, ...kebab},
        EditorBetaAppBarAction.values.toSet(),
        reason: 'partition should cover every enum value when '
            'isFormBearing is true',
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
      // The secondary entries must appear in the same relative
      // order as in editorBetaAppBarActions so users see a consistent
      // sequence as actions move between the top-bar and the kebab.
      // copyFormLink + viewFormSubmissions only enter when
      // isFormBearing is true; the non-form sequence keeps its
      // existing 15-row layout.
      expect(
          editorBetaKebabActions(isAuthed: true, isFormBearing: true).toList(),
          [
            EditorBetaAppBarAction.copyLink,
            EditorBetaAppBarAction.copyUlid,
            EditorBetaAppBarAction.copyPath,
            EditorBetaAppBarAction.duplicate,
            EditorBetaAppBarAction.reveal,
            EditorBetaAppBarAction.rename,
            EditorBetaAppBarAction.publishToggle,
            EditorBetaAppBarAction.pageHistory,
            EditorBetaAppBarAction.setFont,
            EditorBetaAppBarAction.setGoal,
            EditorBetaAppBarAction.exportMarkdown,
            EditorBetaAppBarAction.exportHtml,
            EditorBetaAppBarAction.printPage,
            EditorBetaAppBarAction.setReminder,
            EditorBetaAppBarAction.snoozeReminder,
            EditorBetaAppBarAction.clearReminder,
            EditorBetaAppBarAction.copyBody,
            EditorBetaAppBarAction.copyPlain,
            EditorBetaAppBarAction.copyJson,
            EditorBetaAppBarAction.copyFormLink,
            EditorBetaAppBarAction.viewFormSubmissions,
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

      test('setGoal tooltip reads the D-fp21 port label', () {
        expect(
          EditorBetaAppBarAction.setGoal.tooltip,
          'Set word count goal…',
        );
      });

      test('exportMarkdown tooltip reads the D-fp22 port label', () {
        expect(
          EditorBetaAppBarAction.exportMarkdown.tooltip,
          'Export as .md…',
        );
      });

      test('exportHtml tooltip reads the D-fp22 port label', () {
        expect(
          EditorBetaAppBarAction.exportHtml.tooltip,
          'Export as .html…',
        );
      });

      test('printPage tooltip reads the D-fp23 port label', () {
        expect(
          EditorBetaAppBarAction.printPage.tooltip,
          'Print / Save as PDF…',
        );
      });

      test('setReminder tooltip reads the D-fp15 port label', () {
        expect(
          EditorBetaAppBarAction.setReminder.tooltip,
          'Set reminder…',
        );
      });

      test('snoozeReminder tooltip reads the D-fp16 port label', () {
        expect(
          EditorBetaAppBarAction.snoozeReminder.tooltip,
          'Snooze reminder…',
        );
      });

      test('clearReminder tooltip reads the D-fp16 port label', () {
        expect(
          EditorBetaAppBarAction.clearReminder.tooltip,
          'Clear reminder',
        );
      });

      test('copyBody tooltip reads the D-fp17 port label', () {
        expect(EditorBetaAppBarAction.copyBody.tooltip, 'Copy body text');
      });

      test('copyPlain tooltip reads the D-fp18 port label', () {
        expect(
          EditorBetaAppBarAction.copyPlain.tooltip,
          'Copy body as plain text',
        );
      });

      test('copyJson tooltip reads the D-fp18 port label', () {
        expect(
          EditorBetaAppBarAction.copyJson.tooltip,
          'Copy page as JSON',
        );
      });

      test('viewFormSubmissions tooltip reads the D-fp19 port label', () {
        expect(
          EditorBetaAppBarAction.viewFormSubmissions.tooltip,
          'View form submissions →',
        );
      });

      test('copyFormLink tooltip reads the D-fp20 port label', () {
        expect(
          EditorBetaAppBarAction.copyFormLink.tooltip,
          'Copy form link',
        );
      });
    });
  });
}
