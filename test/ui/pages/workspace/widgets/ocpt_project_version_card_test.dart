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

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve in tests.
Widget _wrapWithLocalization(Widget child) => MaterialApp(
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: Scaffold(body: child),
);

/// Builds a version named [name], with [note], [isBase] and the given counters.
OcptProjectVersion _version({
  String id = "version-1",
  String name = "v3 — Before the seq. 1 rewrite",
  String note = "",
  bool isBase = false,
  int pageCount = 41,
  int brokenDownSequenceCount = 3,
}) => OcptProjectVersion(
  id: id,
  name: name,
  note: note,
  createdAt: DateTime(2026, 7, 12, 18, 42),
  summary: OcptProjectVersionSummary(
    pageCount: pageCount,
    brokenDownSequenceCount: brokenDownSequenceCount,
  ),
  isBase: isBase,
);

/// Builds a card over [version], with every callback a no-op unless overridden, and every inline
/// mode closed unless [isConfirmingDeletion], [isConfirmingRestore] or [isConfirmingRename] says
/// otherwise.
Widget _card({
  required OcptProjectVersion version,
  bool isPreviewed = false,
  bool isConfirmingDeletion = false,
  bool isConfirmingRestore = false,
  bool isConfirmingRename = false,
  VoidCallback? onTap,
  VoidCallback? onRestoreRequested,
  VoidCallback? onRestoreConfirmed,
  VoidCallback? onRestoreCancelled,
  VoidCallback? onDeleteRequested,
  VoidCallback? onDeleteConfirmed,
  VoidCallback? onDeleteCancelled,
  VoidCallback? onRenameRequested,
  void Function(String name, String note)? onRenameConfirmed,
  VoidCallback? onRenameCancelled,
}) => OcptProjectVersionCard(
  version: version,
  isPreviewed: isPreviewed,
  isConfirmingDeletion: isConfirmingDeletion,
  isConfirmingRestore: isConfirmingRestore,
  isConfirmingRename: isConfirmingRename,
  onTap: onTap ?? () {},
  onRestoreRequested: onRestoreRequested ?? () {},
  onRestoreConfirmed: onRestoreConfirmed ?? () {},
  onRestoreCancelled: onRestoreCancelled ?? () {},
  onDeleteRequested: onDeleteRequested,
  onDeleteConfirmed: onDeleteConfirmed ?? () {},
  onDeleteCancelled: onDeleteCancelled ?? () {},
  onRenameRequested: onRenameRequested ?? () {},
  onRenameConfirmed: onRenameConfirmed ?? (name, note) {},
  onRenameCancelled: onRenameCancelled ?? () {},
);

void main() {
  testWidgets('shows the name, the counters and the note of the version', (tester) async {
    await tester.pumpWidget(
      _wrapWithLocalization(_card(version: _version(note: "Everything before the rewrite"))),
    );

    final context = tester.element(find.byType(OcptProjectVersionCard));
    final tr = Tr.of(context);

    expect(find.text("v3 — Before the seq. 1 rewrite"), findsOneWidget);
    expect(find.text("Everything before the rewrite"), findsOneWidget);
    expect(find.textContaining(tr.editorStatsPages(41)), findsOneWidget);
    expect(find.textContaining(tr.projectVersionSequencesBrokenDown(3)), findsOneWidget);
  });

  testWidgets('the base version wears its badge and offers preview, restore and delete', (
    tester,
  ) async {
    var previewed = 0;
    var restoreRequested = 0;
    var deleteRequested = 0;
    await tester.pumpWidget(
      _wrapWithLocalization(
        _card(
          version: _version(isBase: true),
          onTap: () => previewed++,
          onRestoreRequested: () => restoreRequested++,
          onDeleteRequested: () => deleteRequested++,
        ),
      ),
    );

    final context = tester.element(find.byType(OcptProjectVersionCard));
    final tr = Tr.of(context);

    expect(find.text(tr.projectVersionBaseBadge), findsOneWidget);
    expect(find.text(tr.projectVersionBaseHint), findsOneWidget);

    await tester.tap(find.byType(OcptProjectVersionCard));
    expect(previewed, 1);

    await tester.tap(find.text(tr.projectVersionRestoreAction));
    expect(restoreRequested, 1);

    await tester.tap(find.text(tr.projectVersionDeleteAction));
    expect(deleteRequested, 1);
  });

  testWidgets('the previewed version wears the preview badge and offers going back', (
    tester,
  ) async {
    var exited = 0;
    await tester.pumpWidget(
      _wrapWithLocalization(
        _card(version: _version(), isPreviewed: true, onTap: () => exited++),
      ),
    );

    final context = tester.element(find.byType(OcptProjectVersionCard));
    final tr = Tr.of(context);

    expect(find.text(tr.projectVersionPreviewBadge), findsOneWidget);
    expect(find.text(tr.projectVersionPreviewedHint), findsOneWidget);
    // The preview reads from a database hydrated out of this very row: deleting it is refused.
    expect(find.text(tr.projectVersionDeleteAction), findsNothing);

    await tester.tap(find.byType(OcptProjectVersionCard));
    expect(exited, 1);
  });

  testWidgets('clicking any other card asks for its preview', (tester) async {
    var previewed = 0;
    await tester.pumpWidget(
      _wrapWithLocalization(_card(version: _version(), onTap: () => previewed++)),
    );

    final context = tester.element(find.byType(OcptProjectVersionCard));
    final tr = Tr.of(context);

    expect(find.text(tr.projectVersionPreviewHint), findsOneWidget);

    await tester.tap(find.text(tr.projectVersionPreviewHint));
    expect(previewed, 1);
  });

  testWidgets('the delete confirmation is inline, and answers back both ways', (tester) async {
    var confirmed = 0;
    var cancelled = 0;
    await tester.pumpWidget(
      _wrapWithLocalization(
        _card(
          version: _version(),
          isConfirmingDeletion: true,
          onDeleteConfirmed: () => confirmed++,
          onDeleteCancelled: () => cancelled++,
        ),
      ),
    );

    final context = tester.element(find.byType(OcptProjectVersionCard));
    final tr = Tr.of(context);

    // The confirmation replaces the footer: neither the hint nor the `Delete` action is left to
    // click while the question is on screen.
    expect(find.text(tr.projectVersionDeleteConfirmMessage), findsOneWidget);
    expect(find.text(tr.projectVersionPreviewHint), findsNothing);

    await tester.tap(find.text(tr.projectVersionDeleteCancelAction));
    expect(cancelled, 1);

    await tester.tap(find.text(tr.projectVersionDeleteConfirmAction));
    expect(confirmed, 1);
  });

  testWidgets('the restore confirmation is inline, and answers back both ways', (tester) async {
    var confirmed = 0;
    var cancelled = 0;
    await tester.pumpWidget(
      _wrapWithLocalization(
        _card(
          version: _version(),
          isConfirmingRestore: true,
          onRestoreConfirmed: () => confirmed++,
          onRestoreCancelled: () => cancelled++,
        ),
      ),
    );

    final context = tester.element(find.byType(OcptProjectVersionCard));
    final tr = Tr.of(context);

    // The question replaces the footer, and it is the one that says what a restore costs: the page
    // setup comes back with the state, and the state being replaced is kept.
    expect(find.text(tr.projectVersionRestoreConfirmMessage), findsOneWidget);
    expect(find.text(tr.projectVersionPreviewHint), findsNothing);
    expect(find.text(tr.projectVersionRestoreAction), findsNothing);

    await tester.tap(find.text(tr.projectVersionRestoreCancelAction));
    expect(cancelled, 1);

    await tester.tap(find.text(tr.projectVersionRestoreConfirmAction));
    expect(confirmed, 1);
  });

  testWidgets('clicking Rename asks to open the inline rename form', (tester) async {
    var requested = 0;
    await tester.pumpWidget(
      _wrapWithLocalization(_card(version: _version(), onRenameRequested: () => requested++)),
    );

    final context = tester.element(find.byType(OcptProjectVersionCard));
    final tr = Tr.of(context);

    await tester.tap(find.text(tr.projectVersionRenameAction));
    expect(requested, 1);
  });

  testWidgets('the inline rename form is pre-filled from the version', (tester) async {
    await tester.pumpWidget(
      _wrapWithLocalization(
        _card(version: _version(note: "Everything kept"), isConfirmingRename: true),
      ),
    );

    final context = tester.element(find.byType(OcptProjectVersionCard));
    final tr = Tr.of(context);

    expect(_fieldText(tester, tr.projectVersionRenameNameLabel), "v3 — Before the seq. 1 rewrite");
    expect(_fieldText(tester, tr.projectVersionRenameNoteLabel), "Everything kept");
  });

  testWidgets('Save is disabled once the name field is emptied', (tester) async {
    await tester.pumpWidget(
      _wrapWithLocalization(_card(version: _version(), isConfirmingRename: true)),
    );

    final context = tester.element(find.byType(OcptProjectVersionCard));
    final tr = Tr.of(context);

    expect(_saveButton(tester, tr).onPressed, isNotNull);

    await tester.enterText(
      find.widgetWithText(TextFormField, tr.projectVersionRenameNameLabel),
      "",
    );
    await tester.pump();

    expect(_saveButton(tester, tr).onPressed, isNull);
  });

  testWidgets('Save reports the trimmed name and note, Cancel reports nothing', (tester) async {
    (String, String)? saved;
    var cancelled = 0;
    await tester.pumpWidget(
      _wrapWithLocalization(
        _card(
          version: _version(),
          isConfirmingRename: true,
          onRenameConfirmed: (name, note) => saved = (name, note),
          onRenameCancelled: () => cancelled++,
        ),
      ),
    );

    final context = tester.element(find.byType(OcptProjectVersionCard));
    final tr = Tr.of(context);

    await tester.enterText(
      find.widgetWithText(TextFormField, tr.projectVersionRenameNameLabel),
      "  Renamed  ",
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, tr.projectVersionRenameNoteLabel),
      "  A note  ",
    );
    await tester.pump();

    await tester.tap(find.text(tr.projectVersionRenameConfirmAction));
    expect(saved, ("Renamed", "A note"));

    await tester.tap(find.text(tr.projectVersionRenameCancelAction));
    expect(cancelled, 1);
  });
}

/// The current text of the [TextFormField] labelled [label].
String? _fieldText(WidgetTester tester, String label) =>
    tester.widget<TextFormField>(find.widgetWithText(TextFormField, label)).controller?.text;

/// The `Save` button of the inline rename form.
FilledButton _saveButton(WidgetTester tester, Tr tr) =>
    tester.widget<FilledButton>(find.widgetWithText(FilledButton, tr.projectVersionRenameConfirmAction));
