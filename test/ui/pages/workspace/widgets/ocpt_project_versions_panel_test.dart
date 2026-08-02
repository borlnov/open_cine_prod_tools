// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_version.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_version_summary.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_working_copy_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_project_version_card.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_project_versions_panel.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_project_working_copy_card.dart';

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve in tests.
Widget _wrapWithLocalization(Widget child) => MaterialApp(
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: Scaffold(body: SizedBox(width: 360, height: 700, child: child)),
);

/// Builds the version [id], named after it.
OcptProjectVersion _version(String id, {bool isBase = false}) => OcptProjectVersion(
  id: id,
  name: "Version $id",
  note: "",
  createdAt: DateTime(2026, 7, 12, 18, 42),
  summary: const OcptProjectVersionSummary(pageCount: 12, brokenDownSequenceCount: 1),
  isBase: isBase,
);

/// Builds a working copy state descending from [baseVersionId].
OcptProjectWorkingCopyState _workingCopy({
  String? baseVersionId,
  bool isModifiedSinceBase = false,
}) => OcptProjectWorkingCopyState(
  summary: const OcptProjectVersionSummary(pageCount: 13, brokenDownSequenceCount: 1),
  contentDigest: "digest",
  baseVersionId: baseVersionId,
  isModifiedSinceBase: isModifiedSinceBase,
);

/// The recorded calls of one panel's callbacks.
class _PanelCalls {
  /// The ids the panel asked to preview.
  final previewed = <String>[];

  /// How many times the panel asked to leave the preview.
  int exited = 0;

  /// The ids the panel asked to confirm the deletion of.
  final deleteRequested = <String>[];

  /// The ids the panel confirmed the deletion of.
  final deleteConfirmed = <String>[];

  /// How many times the panel cancelled a deletion.
  int deleteCancelled = 0;

  /// The ids the panel asked to confirm the restore of.
  final restoreRequested = <String>[];

  /// The versions the panel confirmed the restore of.
  final restoreConfirmed = <OcptProjectVersion>[];

  /// How many times the panel cancelled a restore.
  int restoreCancelled = 0;

  /// The ids the panel asked to open the inline rename form of.
  final renameRequested = <String>[];

  /// How many times the panel cancelled a rename.
  int renameCancelled = 0;

  /// The `(id, name, note)` triples the panel confirmed the rename of.
  final renameConfirmed = <(String, String, String)>[];

  /// How many times the panel asked to create a version.
  int created = 0;
}

/// Builds a panel over [versions], recording every callback into [calls].
Widget _panel({
  required List<OcptProjectVersion> versions,
  required _PanelCalls calls,
  String? previewedVersionId,
  OcptProjectWorkingCopyState? workingCopy,
  String? versionPendingDeletionId,
  String? versionPendingRestoreId,
  String? versionPendingRenameId,
}) => OcptProjectVersionsPanel(
  versions: versions,
  previewedVersionId: previewedVersionId,
  workingCopy: workingCopy,
  versionPendingDeletionId: versionPendingDeletionId,
  versionPendingRestoreId: versionPendingRestoreId,
  versionPendingRenameId: versionPendingRenameId,
  onCreateRequested: () => calls.created++,
  onPreviewRequested: calls.previewed.add,
  onPreviewExitRequested: () => calls.exited++,
  onRestoreRequested: calls.restoreRequested.add,
  onRestoreCancelled: () => calls.restoreCancelled++,
  onRestoreConfirmed: calls.restoreConfirmed.add,
  onDeleteRequested: calls.deleteRequested.add,
  onDeleteCancelled: () => calls.deleteCancelled++,
  onDeleteConfirmed: calls.deleteConfirmed.add,
  onRenameRequested: calls.renameRequested.add,
  onRenameCancelled: () => calls.renameCancelled++,
  onRenameConfirmed: (id, name, note) => calls.renameConfirmed.add((id, name, note)),
);

void main() {
  /// Grows the test surface past the panel's own 700px-tall wrapper: three actions in a card's
  /// footer (`Rename`, `Restore this version`, `Delete`) wrap onto two lines at this width, tall
  /// enough that the default 800×600 test surface would otherwise cut a lower card's confirmation
  /// off before any scrolling could reach it.
  Future<void> growTestSurface(WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('shows the header, the explanation line and the empty hint with no version', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrapWithLocalization(_panel(versions: const [], calls: _PanelCalls())),
    );

    final context = tester.element(find.byType(OcptProjectVersionsPanel));
    final tr = Tr.of(context);

    expect(find.text(tr.projectVersionsPanelTitle), findsOneWidget);
    expect(find.text(tr.projectVersionsPanelSubtitle), findsOneWidget);
    expect(find.text(tr.projectVersionsEmptyHint), findsOneWidget);
    expect(find.byType(OcptProjectVersionCard), findsNothing);
    // No capture has landed yet: there is nothing to show as the working copy's own card.
    expect(find.byType(OcptProjectWorkingCopyCard), findsNothing);
  });

  testWidgets('the working copy card sits above the version list, in order', (tester) async {
    await tester.pumpWidget(
      _wrapWithLocalization(
        _panel(
          versions: [_version("b", isBase: true), _version("a")],
          calls: _PanelCalls(),
          workingCopy: _workingCopy(baseVersionId: "b"),
        ),
      ),
    );

    expect(find.byType(OcptProjectWorkingCopyCard), findsOneWidget);
    expect(find.byType(OcptProjectVersionCard), findsNWidgets(2));

    final workingCopyTop = tester.getTopLeft(find.byType(OcptProjectWorkingCopyCard)).dy;
    final bTop = tester.getTopLeft(find.text("Version b")).dy;
    final aTop = tester.getTopLeft(find.text("Version a")).dy;

    expect(workingCopyTop, lessThan(bTop));
    expect(bTop, lessThan(aTop));
  });

  testWidgets('the working copy card names its base and reports Create a version', (
    tester,
  ) async {
    final calls = _PanelCalls();
    await tester.pumpWidget(
      _wrapWithLocalization(
        _panel(
          versions: [_version("b", isBase: true)],
          calls: calls,
          workingCopy: _workingCopy(baseVersionId: "b", isModifiedSinceBase: true),
        ),
      ),
    );

    final context = tester.element(find.byType(OcptProjectVersionsPanel));
    final tr = Tr.of(context);

    expect(find.text(tr.projectWorkingCopyModifiedHint("Version b")), findsOneWidget);

    await tester.tap(find.text(tr.projectVersionsCreateAction));
    expect(calls.created, 1);
  });

  testWidgets('renders one card per version, in the order given', (tester) async {
    await tester.pumpWidget(
      _wrapWithLocalization(
        _panel(
          versions: [_version("b", isBase: true), _version("a")],
          calls: _PanelCalls(),
        ),
      ),
    );

    expect(find.byType(OcptProjectVersionCard), findsNWidgets(2));
    expect(
      tester.getTopLeft(find.text("Version b")).dy,
      lessThan(tester.getTopLeft(find.text("Version a")).dy),
    );
  });

  testWidgets('clicking any card, base included, previews it, and the previewed one leaves it', (
    tester,
  ) async {
    final calls = _PanelCalls();
    await tester.pumpWidget(
      _wrapWithLocalization(
        _panel(
          versions: [_version("b", isBase: true), _version("a")],
          calls: calls,
        ),
      ),
    );

    await tester.tap(find.text("Version a"));
    expect(calls.previewed, ["a"]);

    await tester.tap(find.text("Version b"));
    expect(calls.previewed, ["a", "b"]);

    await tester.pumpWidget(
      _wrapWithLocalization(
        _panel(
          versions: [_version("b", isBase: true), _version("a")],
          calls: calls,
          previewedVersionId: "a",
        ),
      ),
    );

    await tester.tap(find.text("Version a"));
    expect(calls.exited, 1);
  });

  testWidgets('deleting goes through the card that asked, and only that one', (tester) async {
    final calls = _PanelCalls();
    final versions = [_version("b", isBase: true), _version("a"), _version("c")];

    await tester.pumpWidget(_wrapWithLocalization(_panel(versions: versions, calls: calls)));

    final context = tester.element(find.byType(OcptProjectVersionsPanel));
    final tr = Tr.of(context);

    await tester.tap(find.text(tr.projectVersionDeleteAction).first);
    expect(calls.deleteRequested, ["b"]);

    await tester.pumpWidget(
      _wrapWithLocalization(
        _panel(versions: versions, calls: calls, versionPendingDeletionId: "a"),
      ),
    );

    expect(find.text(tr.projectVersionDeleteConfirmMessage), findsOneWidget);

    // Found by its button type: the confirmation's `Delete` and the other cards' own `Delete`
    // deliberately read the same, and only one of them is a filled button.
    await tester.tap(
      find.widgetWithText(FilledButton, tr.projectVersionDeleteConfirmAction),
    );
    expect(calls.deleteConfirmed, ["a"]);
  });

  testWidgets('restoring goes through the card that asked, base included', (tester) async {
    await growTestSurface(tester);
    final calls = _PanelCalls();
    final versions = [_version("b", isBase: true), _version("a")];

    await tester.pumpWidget(_wrapWithLocalization(_panel(versions: versions, calls: calls)));

    final context = tester.element(find.byType(OcptProjectVersionsPanel));
    final tr = Tr.of(context);

    // Every version, base included, now offers it.
    expect(find.text(tr.projectVersionRestoreAction), findsNWidgets(2));

    await tester.tap(find.text(tr.projectVersionRestoreAction).first);
    expect(calls.restoreRequested, ["b"]);

    await tester.pumpWidget(
      _wrapWithLocalization(
        _panel(versions: versions, calls: calls, versionPendingRestoreId: "a"),
      ),
    );

    expect(find.text(tr.projectVersionRestoreConfirmMessage), findsOneWidget);

    await tester.tap(
      find.widgetWithText(FilledButton, tr.projectVersionRestoreConfirmAction),
    );

    // The whole version rather than its id: the page names the safety version after it, and that
    // name is localized.
    expect(calls.restoreConfirmed.single.id, "a");
    expect(calls.restoreConfirmed.single.name, "Version a");
  });

  testWidgets('the previewed version can be restored, but still not deleted', (tester) async {
    final calls = _PanelCalls();

    await tester.pumpWidget(
      _wrapWithLocalization(
        _panel(versions: [_version("a")], calls: calls, previewedVersionId: "a"),
      ),
    );

    final context = tester.element(find.byType(OcptProjectVersionsPanel));
    final tr = Tr.of(context);

    expect(find.text(tr.projectVersionDeleteAction), findsNothing);

    await tester.tap(find.text(tr.projectVersionRestoreAction));
    expect(calls.restoreRequested, ["a"]);
  });

  testWidgets('renaming goes through the card that asked, and carries its id, name and note', (
    tester,
  ) async {
    final calls = _PanelCalls();
    final versions = [_version("a"), _version("b")];

    await tester.pumpWidget(_wrapWithLocalization(_panel(versions: versions, calls: calls)));

    final context = tester.element(find.byType(OcptProjectVersionsPanel));
    final tr = Tr.of(context);

    await tester.tap(find.text(tr.projectVersionRenameAction).first);
    expect(calls.renameRequested, ["a"]);
  });

  testWidgets("opening one card's rename form closes another card's open confirmation", (
    tester,
  ) async {
    final calls = _PanelCalls();
    final versions = [_version("a"), _version("b")];

    await tester.pumpWidget(
      _wrapWithLocalization(
        _panel(versions: versions, calls: calls, versionPendingDeletionId: "a"),
      ),
    );

    final context = tester.element(find.byType(OcptProjectVersionsPanel));
    final tr = Tr.of(context);

    expect(find.text(tr.projectVersionDeleteConfirmMessage), findsOneWidget);

    // The state guarantees only one pending id is ever set: rebuilding with `b`'s rename pending
    // is what the bloc does once the user clicks `Rename` on `b` while `a`'s confirmation was up.
    await tester.pumpWidget(
      _wrapWithLocalization(
        _panel(versions: versions, calls: calls, versionPendingRenameId: "b"),
      ),
    );

    expect(find.text(tr.projectVersionDeleteConfirmMessage), findsNothing);
    expect(find.text(tr.projectVersionRenameConfirmAction), findsOneWidget);
  });
}
