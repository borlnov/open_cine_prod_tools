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

void main() {
  testWidgets('shows the name, the counters and the note of the version', (tester) async {
    await tester.pumpWidget(
      _wrapWithLocalization(
        OcptProjectVersionCard(
          version: _version(note: "Everything before the rewrite"),
          isPreviewed: false,
          isConfirmingDeletion: false,
          isConfirmingRestore: false,
          onTap: () {},
          onRestoreRequested: () {},
          onRestoreConfirmed: () {},
          onRestoreCancelled: () {},
          onDeleteRequested: () {},
          onDeleteConfirmed: () {},
          onDeleteCancelled: () {},
        ),
      ),
    );

    final context = tester.element(find.byType(OcptProjectVersionCard));
    final tr = Tr.of(context);

    expect(find.text("v3 — Before the seq. 1 rewrite"), findsOneWidget);
    expect(find.text("Everything before the rewrite"), findsOneWidget);
    expect(find.textContaining(tr.editorStatsPages(41)), findsOneWidget);
    expect(find.textContaining(tr.projectVersionSequencesBrokenDown(3)), findsOneWidget);
  });

  testWidgets('the current version wears its badge and offers neither preview nor delete', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrapWithLocalization(
        OcptProjectVersionCard(
          version: _version(isBase: true),
          isPreviewed: false,
          isConfirmingDeletion: false,
          isConfirmingRestore: false,
          onTap: null,
          onRestoreRequested: null,
          onRestoreConfirmed: () {},
          onRestoreCancelled: () {},
          onDeleteRequested: null,
          onDeleteConfirmed: () {},
          onDeleteCancelled: () {},
        ),
      ),
    );

    final context = tester.element(find.byType(OcptProjectVersionCard));
    final tr = Tr.of(context);

    expect(find.text(tr.projectVersionCurrentBadge), findsOneWidget);
    expect(find.text(tr.projectVersionCurrentHint), findsOneWidget);
    expect(find.text(tr.projectVersionDeleteAction), findsNothing);
  });

  testWidgets('the previewed version wears the preview badge and offers going back', (
    tester,
  ) async {
    var exited = 0;
    await tester.pumpWidget(
      _wrapWithLocalization(
        OcptProjectVersionCard(
          version: _version(),
          isPreviewed: true,
          isConfirmingDeletion: false,
          isConfirmingRestore: false,
          onTap: () => exited++,
          onRestoreRequested: () {},
          onRestoreConfirmed: () {},
          onRestoreCancelled: () {},
          onDeleteRequested: null,
          onDeleteConfirmed: () {},
          onDeleteCancelled: () {},
        ),
      ),
    );

    final context = tester.element(find.byType(OcptProjectVersionCard));
    final tr = Tr.of(context);

    expect(find.text(tr.projectVersionPreviewBadge), findsOneWidget);
    expect(find.text(tr.projectVersionPreviewedHint), findsOneWidget);

    await tester.tap(find.byType(OcptProjectVersionCard));
    expect(exited, 1);
  });

  testWidgets('clicking any other card asks for its preview', (tester) async {
    var previewed = 0;
    await tester.pumpWidget(
      _wrapWithLocalization(
        OcptProjectVersionCard(
          version: _version(),
          isPreviewed: false,
          isConfirmingDeletion: false,
          isConfirmingRestore: false,
          onTap: () => previewed++,
          onRestoreRequested: () {},
          onRestoreConfirmed: () {},
          onRestoreCancelled: () {},
          onDeleteRequested: () {},
          onDeleteConfirmed: () {},
          onDeleteCancelled: () {},
        ),
      ),
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
        OcptProjectVersionCard(
          version: _version(),
          isPreviewed: false,
          isConfirmingDeletion: true,
          isConfirmingRestore: false,
          onTap: () {},
          onRestoreRequested: () {},
          onRestoreConfirmed: () {},
          onRestoreCancelled: () {},
          onDeleteRequested: () {},
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
        OcptProjectVersionCard(
          version: _version(),
          isPreviewed: false,
          isConfirmingDeletion: false,
          isConfirmingRestore: true,
          onTap: () {},
          onRestoreRequested: () {},
          onRestoreConfirmed: () => confirmed++,
          onRestoreCancelled: () => cancelled++,
          onDeleteRequested: () {},
          onDeleteConfirmed: () {},
          onDeleteCancelled: () {},
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

  testWidgets('a card with nothing to restore from shows no restore action', (tester) async {
    await tester.pumpWidget(
      _wrapWithLocalization(
        OcptProjectVersionCard(
          version: _version(isBase: true),
          isPreviewed: false,
          isConfirmingDeletion: false,
          isConfirmingRestore: false,
          onTap: null,
          onRestoreRequested: null,
          onRestoreConfirmed: () {},
          onRestoreCancelled: () {},
          onDeleteRequested: null,
          onDeleteConfirmed: () {},
          onDeleteCancelled: () {},
        ),
      ),
    );

    final context = tester.element(find.byType(OcptProjectVersionCard));

    expect(find.text(Tr.of(context).projectVersionRestoreAction), findsNothing);
  });
}
