// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:open_cine_prod_tools/constants/ocpt_localizations_delegates.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_removed_role_alert.dart';
import 'package:open_cine_prod_tools/models/ocpt_role_collision_alert.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_role_alert_compact_banner.dart';

/// Wraps [child] with the localization delegates so the banner's [Tr.of] lookups resolve.
Widget _wrapInApp(Widget child) => MaterialApp(
  localizationsDelegates: const [Tr.delegate, ...ocptDesignLocalizationsDelegates],
  supportedLocales: Tr.delegate.supportedLocales,
  home: Scaffold(body: child),
);

/// Run the tests of [OcptRoleAlertCompactBanner].
void main() {
  const orphaned = OcptRemovedRoleAlert(roleId: "r1", characterName: "LE CLIENT");
  const collision = OcptRoleCollisionAlert(
    name: "LA VOISINE",
    screenplayRoleId: "r-screenplay",
    handAddedRoleId: "r-hand",
  );

  testWidgets("renders nothing while no role needs attention", (tester) async {
    await tester.pumpWidget(
      _wrapInApp(
        OcptRoleAlertCompactBanner(
          orphanedAlerts: const [],
          collisionAlerts: const [],
          onRoleTapped: (_) {},
        ),
      ),
    );

    expect(find.byType(OcptRoleAlertCompactBanner), findsOneWidget);
    expect(tester.getSize(find.byType(OcptRoleAlertCompactBanner)), Size.zero);
  });

  testWidgets(
    "one line per orphaned role and two per collision, each tappable onto its own role id",
    (tester) async {
      final tapped = <String>[];

      await tester.pumpWidget(
        _wrapInApp(
          OcptRoleAlertCompactBanner(
            orphanedAlerts: const [orphaned],
            collisionAlerts: const [collision],
            onRoleTapped: tapped.add,
          ),
        ),
      );

      final tr = Tr.of(tester.element(find.byType(OcptRoleAlertCompactBanner)));
      await tester.tap(find.text(tr.roleAlertCompactSummary(3)));
      await tester.pump();
      expect(find.text(tr.roleAlertCompactOrphanedLine("LE CLIENT")), findsOneWidget);
      // The collision names one role each — the same line's text names the shared name twice,
      // once per role it names.
      expect(find.text(tr.roleAlertCompactCollisionLine("LA VOISINE")), findsNWidgets(2));

      await tester.tap(find.text(tr.roleAlertCompactOrphanedLine("LE CLIENT")));
      await tester.pump();
      expect(tapped, ["r1"]);

      await tester.tap(find.text(tr.roleAlertCompactCollisionLine("LA VOISINE")).first);
      await tester.pump();
      expect(tapped, ["r1", "r-screenplay"]);
    },
  );

  testWidgets("a single line is shown as is, with no summary to expand", (tester) async {
    await tester.pumpWidget(
      _wrapInApp(
        OcptRoleAlertCompactBanner(
          orphanedAlerts: const [orphaned],
          collisionAlerts: const [],
          onRoleTapped: (_) {},
        ),
      ),
    );

    final tr = Tr.of(tester.element(find.byType(OcptRoleAlertCompactBanner)));
    expect(find.text(tr.roleAlertCompactOrphanedLine("LE CLIENT")), findsOneWidget);
    expect(find.text(tr.roleAlertCompactSummary(1)), findsNothing);
  });

  testWidgets("several lines collapse behind a summary that expands and collapses them", (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrapInApp(
        OcptRoleAlertCompactBanner(
          orphanedAlerts: const [orphaned],
          collisionAlerts: const [collision],
          onRoleTapped: (_) {},
        ),
      ),
    );

    final tr = Tr.of(tester.element(find.byType(OcptRoleAlertCompactBanner)));
    final summary = find.text(tr.roleAlertCompactSummary(3));
    expect(summary, findsOneWidget);
    expect(find.text(tr.roleAlertCompactOrphanedLine("LE CLIENT")), findsNothing);

    await tester.tap(summary);
    await tester.pump();
    expect(find.text(tr.roleAlertCompactOrphanedLine("LE CLIENT")), findsOneWidget);

    await tester.tap(summary);
    await tester.pump();
    expect(find.text(tr.roleAlertCompactOrphanedLine("LE CLIENT")), findsNothing);
  });

  testWidgets("however many roles need attention, the expanded banner stays within its cap", (
    tester,
  ) async {
    final collisions = [
      for (var i = 0; i < 10; i++)
        OcptRoleCollisionAlert(name: "ROLE $i", screenplayRoleId: "s$i", handAddedRoleId: "h$i"),
    ];

    await tester.pumpWidget(
      _wrapInApp(
        Align(
          alignment: Alignment.topCenter,
          child: OcptRoleAlertCompactBanner(
            orphanedAlerts: const [],
            collisionAlerts: collisions,
            onRoleTapped: (_) {},
          ),
        ),
      ),
    );

    final tr = Tr.of(tester.element(find.byType(OcptRoleAlertCompactBanner)));
    final collapsedHeight = tester.getSize(find.byType(OcptRoleAlertCompactBanner)).height;

    await tester.tap(find.text(tr.roleAlertCompactSummary(20)));
    await tester.pump();

    final expandedHeight = tester.getSize(find.byType(OcptRoleAlertCompactBanner)).height;
    expect(expandedHeight, greaterThan(collapsedHeight));
    expect(
      expandedHeight,
      lessThanOrEqualTo(collapsedHeight + OcptRoleAlertCompactBanner.maxExpandedHeight),
    );
    expect(find.byType(Scrollable), findsOneWidget);
  });

  testWidgets("isReadOnly withholds the whole banner outright", (tester) async {
    await tester.pumpWidget(
      _wrapInApp(
        OcptRoleAlertCompactBanner(
          orphanedAlerts: const [orphaned],
          collisionAlerts: const [collision],
          onRoleTapped: (_) {},
          isReadOnly: true,
        ),
      ),
    );

    final tr = Tr.of(tester.element(find.byType(OcptRoleAlertCompactBanner)));
    expect(find.text(tr.roleAlertCompactOrphanedLine("LE CLIENT")), findsNothing);
    expect(find.text(tr.roleAlertCompactCollisionLine("LA VOISINE")), findsNothing);
  });
}
