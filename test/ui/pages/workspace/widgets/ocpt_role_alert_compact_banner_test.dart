// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_removed_role_alert.dart';
import 'package:open_cine_prod_tools/models/ocpt_role_collision_alert.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_role_alert_compact_banner.dart';

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
