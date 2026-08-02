// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_version_summary.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_working_copy_state.dart';
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
  home: Scaffold(body: child),
);

/// Builds a working copy state with the given counters and comparison to its base.
OcptProjectWorkingCopyState _workingCopy({
  String? baseVersionId,
  bool isModifiedSinceBase = false,
  int pageCount = 42,
  int brokenDownSequenceCount = 3,
}) => OcptProjectWorkingCopyState(
  summary: OcptProjectVersionSummary(
    pageCount: pageCount,
    brokenDownSequenceCount: brokenDownSequenceCount,
  ),
  contentDigest: "digest",
  baseVersionId: baseVersionId,
  isModifiedSinceBase: isModifiedSinceBase,
);

void main() {
  testWidgets('shows the title and the counters of the working copy', (tester) async {
    var created = 0;
    await tester.pumpWidget(
      _wrapWithLocalization(
        OcptProjectWorkingCopyCard(
          workingCopy: _workingCopy(baseVersionId: "v1"),
          baseVersionName: "v1",
          onCreateRequested: () => created++,
        ),
      ),
    );

    final context = tester.element(find.byType(OcptProjectWorkingCopyCard));
    final tr = Tr.of(context);

    expect(find.text(tr.projectWorkingCopyTitle), findsOneWidget);
    expect(find.textContaining(tr.editorStatsPages(42)), findsOneWidget);
    expect(find.textContaining(tr.projectVersionSequencesBrokenDown(3)), findsOneWidget);
  });

  testWidgets('says it is identical to its base when the content digests match', (tester) async {
    await tester.pumpWidget(
      _wrapWithLocalization(
        OcptProjectWorkingCopyCard(
          workingCopy: _workingCopy(baseVersionId: "v1"),
          baseVersionName: "v1",
          onCreateRequested: () {},
        ),
      ),
    );

    final context = tester.element(find.byType(OcptProjectWorkingCopyCard));
    final tr = Tr.of(context);

    expect(find.text(tr.projectWorkingCopyIdenticalHint("v1")), findsOneWidget);
  });

  testWidgets('says it was modified since its base when the content digests differ', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrapWithLocalization(
        OcptProjectWorkingCopyCard(
          workingCopy: _workingCopy(baseVersionId: "v1", isModifiedSinceBase: true),
          baseVersionName: "v1",
          onCreateRequested: () {},
        ),
      ),
    );

    final context = tester.element(find.byType(OcptProjectWorkingCopyCard));
    final tr = Tr.of(context);

    expect(find.text(tr.projectWorkingCopyModifiedHint("v1")), findsOneWidget);
  });

  testWidgets('says it is based on no version when it has none', (tester) async {
    await tester.pumpWidget(
      _wrapWithLocalization(
        OcptProjectWorkingCopyCard(
          workingCopy: _workingCopy(),
          baseVersionName: null,
          onCreateRequested: () {},
        ),
      ),
    );

    final context = tester.element(find.byType(OcptProjectWorkingCopyCard));
    final tr = Tr.of(context);

    expect(find.text(tr.projectWorkingCopyNoBaseHint), findsOneWidget);
  });

  testWidgets('reports Create a version when its button is clicked', (tester) async {
    var created = 0;
    await tester.pumpWidget(
      _wrapWithLocalization(
        OcptProjectWorkingCopyCard(
          workingCopy: _workingCopy(),
          baseVersionName: null,
          onCreateRequested: () => created++,
        ),
      ),
    );

    final context = tester.element(find.byType(OcptProjectWorkingCopyCard));
    final tr = Tr.of(context);

    await tester.tap(find.text(tr.projectVersionsCreateAction));
    expect(created, 1);
  });
}
