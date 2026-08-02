// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_version.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_version_summary.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_read_only_banner.dart';

/// Wraps [child] with the localization delegates so the banner's [Tr.of] lookups resolve.
Widget _wrapInApp(Widget child) => MaterialApp(
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: Scaffold(body: child),
);

/// The version the banner is built from, with [note] overridable since it is the one field that
/// changes what the headline reads.
OcptProjectVersion _version({String note = "Before the seq. 1 rewrite"}) => OcptProjectVersion(
  id: "version-1",
  name: "v3",
  note: note,
  createdAt: DateTime(2026, 3, 12, 18, 42),
  summary: const OcptProjectVersionSummary(pageCount: 41, brokenDownSequenceCount: 3),
  isCurrent: false,
);

void main() {
  testWidgets("the headline names the version and quotes the user's note", (tester) async {
    await tester.pumpWidget(
      _wrapInApp(
        OcptWorkspaceReadOnlyBanner(version: _version(), onExitPreview: () {}),
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptWorkspaceReadOnlyBanner)));

    expect(
      find.text("${tr.workspaceReadOnlyBannerTitle("v3")} — Before the seq. 1 rewrite"),
      findsOneWidget,
    );
  });

  testWidgets("a version with no note shows the headline alone, with no dangling separator", (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrapInApp(
        OcptWorkspaceReadOnlyBanner(version: _version(note: ""), onExitPreview: () {}),
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptWorkspaceReadOnlyBanner)));

    expect(find.text(tr.workspaceReadOnlyBannerTitle("v3")), findsOneWidget);
  });

  testWidgets("the summary line repeats the counters measured when the version was created", (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrapInApp(
        OcptWorkspaceReadOnlyBanner(version: _version(), onExitPreview: () {}),
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptWorkspaceReadOnlyBanner)));

    expect(
      find.textContaining(
        "${tr.editorStatsPages(41)} · ${tr.projectVersionSequencesBrokenDown(3)}",
      ),
      findsOneWidget,
    );
  });

  testWidgets("the exit action fires onExitPreview when clicked", (tester) async {
    var exitCount = 0;

    await tester.pumpWidget(
      _wrapInApp(
        OcptWorkspaceReadOnlyBanner(version: _version(), onExitPreview: () => exitCount++),
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptWorkspaceReadOnlyBanner)));
    await tester.tap(find.text(tr.workspaceReadOnlyBannerExitAction));
    await tester.pumpAndSettle();

    expect(exitCount, 1);
  });
}
