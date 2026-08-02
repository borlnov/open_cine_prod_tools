// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_version.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_version_summary.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_project_version_card.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_project_versions_panel.dart';

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

  /// How many times the panel asked to create a version.
  int created = 0;
}

/// Builds a panel over [versions], recording every callback into [calls].
Widget _panel({
  required List<OcptProjectVersion> versions,
  required _PanelCalls calls,
  String? previewedVersionId,
  String? versionPendingDeletionId,
  String? versionPendingRestoreId,
  bool canCreate = true,
}) => OcptProjectVersionsPanel(
  versions: versions,
  previewedVersionId: previewedVersionId,
  versionPendingDeletionId: versionPendingDeletionId,
  versionPendingRestoreId: versionPendingRestoreId,
  onCreateRequested: canCreate ? () => calls.created++ : null,
  onPreviewRequested: calls.previewed.add,
  onPreviewExitRequested: () => calls.exited++,
  onRestoreRequested: calls.restoreRequested.add,
  onRestoreCancelled: () => calls.restoreCancelled++,
  onRestoreConfirmed: calls.restoreConfirmed.add,
  onDeleteRequested: calls.deleteRequested.add,
  onDeleteCancelled: () => calls.deleteCancelled++,
  onDeleteConfirmed: calls.deleteConfirmed.add,
);

void main() {
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

  testWidgets('creating a version is refused while one is being previewed', (tester) async {
    final calls = _PanelCalls();
    await tester.pumpWidget(
      _wrapWithLocalization(
        _panel(versions: [_version("a")], calls: calls, canCreate: false),
      ),
    );

    final context = tester.element(find.byType(OcptProjectVersionsPanel));
    final tr = Tr.of(context);

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, tr.projectVersionsCreateAction),
    );
    expect(button.onPressed, isNull);
    expect(calls.created, 0);
  });

  testWidgets('clicking a card previews it, and clicking the previewed one leaves the preview', (
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
    // The current version's card stays inert: it is what the working copy already shows.
    await tester.tap(find.text("Version b"));
    expect(calls.previewed, ["a"]);
  });

  testWidgets('deleting goes through the card that asked, and only that one', (tester) async {
    final calls = _PanelCalls();
    final versions = [_version("b", isBase: true), _version("a"), _version("c")];

    await tester.pumpWidget(_wrapWithLocalization(_panel(versions: versions, calls: calls)));

    final context = tester.element(find.byType(OcptProjectVersionsPanel));
    final tr = Tr.of(context);

    await tester.tap(find.text(tr.projectVersionDeleteAction).first);
    expect(calls.deleteRequested, ["a"]);

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

  testWidgets('restoring goes through the card that asked, and carries the version itself', (
    tester,
  ) async {
    final calls = _PanelCalls();
    final versions = [_version("b", isBase: true), _version("a")];

    await tester.pumpWidget(_wrapWithLocalization(_panel(versions: versions, calls: calls)));

    final context = tester.element(find.byType(OcptProjectVersionsPanel));
    final tr = Tr.of(context);

    // Only the versions the project could go back to offer it: the current one is what is already
    // on screen.
    expect(find.text(tr.projectVersionRestoreAction), findsOneWidget);

    await tester.tap(find.text(tr.projectVersionRestoreAction));
    expect(calls.restoreRequested, ["a"]);

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
}
