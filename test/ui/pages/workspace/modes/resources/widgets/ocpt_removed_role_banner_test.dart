// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_removed_role_alert.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_removed_role_banner.dart';

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve.
Widget _wrapInApp(Widget child) => MaterialApp(
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: Scaffold(body: SizedBox(width: 400, child: child)),
);

const _alert = OcptRemovedRoleAlert(roleId: "r1", characterName: "Le Client");

void main() {
  testWidgets("names the character and offers both ways out", (tester) async {
    await tester.pumpWidget(
      _wrapInApp(
        OcptRemovedRoleBanner(alert: _alert, onDeleteRequested: () {}, onKeepRequested: () {}),
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptRemovedRoleBanner)));
    expect(find.text(tr.resourcesRemovedRoleBanner("Le Client")), findsOneWidget);
    expect(find.text(tr.resourcesRemovedRoleDeleteAction), findsOneWidget);
    expect(find.text(tr.resourcesRemovedRoleKeepAction), findsOneWidget);
  });

  testWidgets("Delete this role dispatches onDeleteRequested", (tester) async {
    var deleted = false;

    await tester.pumpWidget(
      _wrapInApp(
        OcptRemovedRoleBanner(
          alert: _alert,
          onDeleteRequested: () => deleted = true,
          onKeepRequested: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptRemovedRoleBanner)));
    await tester.tap(find.text(tr.resourcesRemovedRoleDeleteAction));
    await tester.pumpAndSettle();

    expect(deleted, isTrue);
  });

  testWidgets("Keep as a silent role dispatches onKeepRequested", (tester) async {
    var kept = false;

    await tester.pumpWidget(
      _wrapInApp(
        OcptRemovedRoleBanner(
          alert: _alert,
          onDeleteRequested: () {},
          onKeepRequested: () => kept = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptRemovedRoleBanner)));
    await tester.tap(find.text(tr.resourcesRemovedRoleKeepAction));
    await tester.pumpAndSettle();

    expect(kept, isTrue);
  });

  testWidgets("read-only keeps the report and drops both ways out", (tester) async {
    await tester.pumpWidget(
      _wrapInApp(
        OcptRemovedRoleBanner(
          alert: _alert,
          isReadOnly: true,
          onDeleteRequested: () {},
          onKeepRequested: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptRemovedRoleBanner)));
    expect(find.text(tr.resourcesRemovedRoleBanner("Le Client")), findsOneWidget);
    expect(find.text(tr.resourcesRemovedRoleDeleteAction), findsNothing);
    expect(find.text(tr.resourcesRemovedRoleKeepAction), findsNothing);
  });
}
