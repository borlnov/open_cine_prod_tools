// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/ui/pages/project_settings/widgets/ocpt_project_settings_file_section.dart';

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve in tests.
Widget _wrapWithLocalization(Widget child) => MaterialApp(
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

/// Pumps [OcptProjectSettingsFileSection], recording every callback into a value a test reads
/// back.
Future<void> _pumpSection(
  WidgetTester tester, {
  required String filePath,
  VoidCallback? onShowInFolderRequested,
  VoidCallback? onMoveRequested,
  String? moveWithheldHint,
}) async {
  await tester.pumpWidget(
    _wrapWithLocalization(
      OcptProjectSettingsFileSection(
        filePath: filePath,
        onShowInFolderRequested: onShowInFolderRequested,
        onMoveRequested: onMoveRequested,
        moveWithheldHint: moveWithheldHint,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets("shows the project's file path as selectable text", (tester) async {
    await _pumpSection(
      tester,
      filePath: "/home/ben/Films/My short.ocpt",
      onShowInFolderRequested: () {},
      onMoveRequested: () {},
    );

    expect(find.text("/home/ben/Films/My short.ocpt"), findsOneWidget);
    expect(find.byType(SelectableText), findsOneWidget);
  });

  testWidgets("both actions call back when offered", (tester) async {
    var showInFolderCalled = false;
    var moveCalled = false;

    await _pumpSection(
      tester,
      filePath: "/home/ben/Films/My short.ocpt",
      onShowInFolderRequested: () => showInFolderCalled = true,
      onMoveRequested: () => moveCalled = true,
    );

    final context = tester.element(find.byType(OcptProjectSettingsFileSection));
    final tr = Tr.of(context);

    await tester.tap(find.text(tr.projectSettingsShowInFolderAction));
    expect(showInFolderCalled, isTrue);

    await tester.tap(find.text(tr.projectSettingsMoveAction));
    expect(moveCalled, isTrue);
  });

  testWidgets("Move is withheld (no button at all) when its callback is null", (tester) async {
    await _pumpSection(
      tester,
      filePath: "/home/ben/Films/My short.ocpt",
      onShowInFolderRequested: () {},
    );

    final context = tester.element(find.byType(OcptProjectSettingsFileSection));
    final tr = Tr.of(context);

    expect(find.text(tr.projectSettingsMoveAction), findsNothing);
    expect(find.text(tr.projectSettingsShowInFolderAction), findsOneWidget);
  });

  testWidgets("Show in folder is withheld too when its callback is null (mobile)", (tester) async {
    await _pumpSection(tester, filePath: "/home/ben/Films/My short.ocpt");

    final context = tester.element(find.byType(OcptProjectSettingsFileSection));
    final tr = Tr.of(context);

    expect(find.text(tr.projectSettingsShowInFolderAction), findsNothing);
    expect(find.text(tr.projectSettingsMoveAction), findsNothing);
  });

  testWidgets("shows the hint explaining why Move is withheld, when one is given", (tester) async {
    await _pumpSection(
      tester,
      filePath: "/home/ben/Films/My short.ocpt",
      onShowInFolderRequested: () {},
      moveWithheldHint: "Stop hosting this project to move it.",
    );

    expect(find.text("Stop hosting this project to move it."), findsOneWidget);
  });

  testWidgets("shows no hint when Move is offered", (tester) async {
    await _pumpSection(
      tester,
      filePath: "/home/ben/Films/My short.ocpt",
      onShowInFolderRequested: () {},
      onMoveRequested: () {},
    );

    final context = tester.element(find.byType(OcptProjectSettingsFileSection));
    final tr = Tr.of(context);
    expect(find.text(tr.projectSettingsMoveWithheldByHostingHint), findsNothing);
  });
}
