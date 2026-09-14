// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_removed_role_alert.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/ocpt_role_collision_alert.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_role_alert_banner.dart';

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

/// A minimal live role of [id] and [name], the merge-target chips are built from.
OcptRole _role(String id, String name) => OcptRole(
  id: id,
  name: name,
  personId: null,
  kind: OcptRoleKind.speaking,
  isFromScreenplay: true,
  orphanedName: null,
  castingNotes: "",
  number: 1,
  episodeIds: const [],
);

void main() {
  group("orphaned variant", () {
    const alert = OcptRemovedRoleAlert(roleId: "r1", characterName: "LE CLIENT");

    testWidgets("names the role and offers delete/keep, with no merge row when there is no target",
        (tester) async {
      var deleted = 0;
      var kept = 0;

      await tester.pumpWidget(
        _wrapInApp(
          OcptRoleAlertBanner.orphaned(
            alert: alert,
            mergeTargets: const [],
            onDeleteRequested: (_) => deleted++,
            onKeepRequested: (_) => kept++,
            onMergeRequested: (_, __) {},
          ),
        ),
      );

      final tr = Tr.of(tester.element(find.byType(OcptRoleAlertBanner)));
      expect(find.text(tr.roleAlertOrphanedMessage("LE CLIENT")), findsOneWidget);
      expect(find.text(tr.roleAlertOrphanedDeleteAction), findsOneWidget);
      expect(find.text(tr.roleAlertOrphanedKeepAction), findsOneWidget);
      expect(find.text(tr.roleAlertMergeWithLabel), findsNothing);

      await tester.tap(find.text(tr.roleAlertOrphanedDeleteAction));
      await tester.tap(find.text(tr.roleAlertOrphanedKeepAction));
      await tester.pump();

      expect(deleted, 1);
      expect(kept, 1);
    });

    testWidgets("offers one merge chip per target, reporting (alert's role, clicked target)", (
      tester,
    ) async {
      final merges = <(String, String)>[];

      await tester.pumpWidget(
        _wrapInApp(
          OcptRoleAlertBanner.orphaned(
            alert: alert,
            mergeTargets: [_role("r2", "La Voisine"), _role("r3", "Le Facteur")],
            onDeleteRequested: (_) {},
            onKeepRequested: (_) {},
            onMergeRequested: (sourceRoleId, targetRoleId) =>
                merges.add((sourceRoleId, targetRoleId)),
          ),
        ),
      );

      final tr = Tr.of(tester.element(find.byType(OcptRoleAlertBanner)));
      expect(find.text(tr.roleAlertMergeWithLabel), findsOneWidget);
      expect(find.text("La Voisine"), findsOneWidget);
      expect(find.text("Le Facteur"), findsOneWidget);

      await tester.tap(find.text("Le Facteur"));
      await tester.pump();

      expect(merges, [("r1", "r3")]);
    });

    testWidgets("isReadOnly keeps the message and withholds every action", (tester) async {
      await tester.pumpWidget(
        _wrapInApp(
          OcptRoleAlertBanner.orphaned(
            alert: alert,
            mergeTargets: [_role("r2", "La Voisine")],
            onDeleteRequested: (_) {},
            onKeepRequested: (_) {},
            onMergeRequested: (_, __) {},
            isReadOnly: true,
          ),
        ),
      );

      final tr = Tr.of(tester.element(find.byType(OcptRoleAlertBanner)));
      expect(find.text(tr.roleAlertOrphanedMessage("LE CLIENT")), findsOneWidget);
      expect(find.text(tr.roleAlertOrphanedDeleteAction), findsNothing);
      expect(find.text(tr.roleAlertOrphanedKeepAction), findsNothing);
      expect(find.text("La Voisine"), findsNothing);
    });
  });

  group("collision variant", () {
    const alert = OcptRoleCollisionAlert(
      name: "LE CLIENT",
      screenplayRoleId: "r-screenplay",
      handAddedRoleId: "r-hand",
    );

    testWidgets("is advisory: a single Merge action, no delete or keep", (tester) async {
      final merges = <(String, String)>[];

      await tester.pumpWidget(
        _wrapInApp(
          OcptRoleAlertBanner.collision(
            alert: alert,
            onMergeRequested: (sourceRoleId, targetRoleId) =>
                merges.add((sourceRoleId, targetRoleId)),
          ),
        ),
      );

      final tr = Tr.of(tester.element(find.byType(OcptRoleAlertBanner)));
      expect(find.text(tr.roleAlertCollisionMessage("LE CLIENT")), findsOneWidget);
      expect(find.text(tr.roleAlertOrphanedDeleteAction), findsNothing);
      expect(find.text(tr.roleAlertOrphanedKeepAction), findsNothing);

      await tester.tap(find.text(tr.roleAlertMergeAction));
      await tester.pump();

      // Anchored on the screenplay role (ADR 0030, decision 2): the hand-added one is always the
      // source, the screenplay one the target.
      expect(merges, [("r-hand", "r-screenplay")]);
    });

    testWidgets("isReadOnly keeps the message and withholds the merge action", (tester) async {
      await tester.pumpWidget(
        _wrapInApp(
          OcptRoleAlertBanner.collision(
            alert: alert,
            onMergeRequested: (_, __) {},
            isReadOnly: true,
          ),
        ),
      );

      final tr = Tr.of(tester.element(find.byType(OcptRoleAlertBanner)));
      expect(find.text(tr.roleAlertCollisionMessage("LE CLIENT")), findsOneWidget);
      expect(find.text(tr.roleAlertMergeAction), findsNothing);
    });
  });
}
