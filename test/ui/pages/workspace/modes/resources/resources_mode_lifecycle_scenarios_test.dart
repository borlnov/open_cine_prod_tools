// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_resources_list_panel.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_project_version_card.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_project_versions_panel.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_project_working_copy_card.dart';

import 'resources_mode_scenarios_test_doubles.dart';

/// How long a scenario waits, in real time, for the working copy capture throttle to let go.
const _captureThrottle = Duration(milliseconds: 2100);

void main() {
  final harness = ResourcesScenarioHarness();

  setUpAll(harness.setUpAll);
  setUp(harness.setUp);
  tearDown(harness.tearDown);

  /// Opens the export panel from the toolbar, leaving time for it to appear but not for the
  /// field-edit debounce to run out.
  Future<void> openExportPanel(WidgetTester tester) =>
      harness.tapOpening(tester, find.byTooltip(harness.trOf(tester).workspaceExportTooltip));

  /// Finds [target] inside the export panel dialog.
  Finder inPanel(Finder target) => find.descendant(of: find.byType(AlertDialog), matching: target);

  /// Taps the version card to preview it and waits for the read-only banner to show.
  Future<void> previewFirstVersion(WidgetTester tester) async {
    final tr = harness.trOf(tester);
    await tester.tapAt(
      tester.getTopLeft(find.byType(OcptProjectVersionCard)) + const Offset(24, 12),
    );
    await harness.pumpUntil(
      tester,
      () => harness.isShown(find.text(tr.workspaceReadOnlyBannerExitAction)),
    );
  }

  /// Leaves the preview and waits for the banner to go.
  Future<void> exitPreview(WidgetTester tester) async {
    final tr = harness.trOf(tester);
    await tester.tap(find.text(tr.workspaceReadOnlyBannerExitAction));
    await harness.pumpUntil(
      tester,
      () => !harness.isShown(find.text(tr.workspaceReadOnlyBannerExitAction)),
    );
  }

  testWidgets("the workbook export writes what was typed a moment ago, and says where the file "
      "went, or that it could not be written", (tester) async {
    await harness.seedPerson("Alice");
    await harness.mount(tester);
    final tr = harness.trOf(tester);
    await harness.tap(tester, find.text("Alice"));

    await harness.type(tester, harness.fieldHinted(tr.resourcesFirstNameHint), "Alicia");
    await openExportPanel(tester);
    await harness.tapQuickly(tester, inPanel(find.text(tr.resourcesExportXlsxTitle)));
    await tester.pumpAndSettle();

    final export = harness.exportManager.exports.single;
    expect(export.document, "xlsx");
    expect(export.projectName, "My Movie");
    expect(export.snapshot.people.single.firstName, "Alicia");
    expect(find.text(tr.resourcesExportXlsxSuccessMessage("/tmp/xlsx.out")), findsOneWidget);

    // A cancelled save dialog says nothing at all.
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    harness.exportManager.shouldCancel = true;
    await openExportPanel(tester);
    await harness.tap(tester, inPanel(find.text(tr.resourcesExportXlsxTitle)));
    expect(harness.exportManager.exports, hasLength(2));
    expect(find.byType(SnackBar), findsNothing);

    // A write that throws raises the error notice.
    harness.exportManager
      ..shouldCancel = false
      ..shouldFail = true;
    await openExportPanel(tester);
    await harness.tap(tester, inPanel(find.text(tr.resourcesExportXlsxTitle)));
    expect(harness.exportManager.exports, hasLength(3));
    expect(find.text(tr.resourcesExportXlsxError), findsOneWidget);
  });

  testWidgets("the contact list export asks for its page format first, hands the document the "
      "catalogue and reports the outcome", (tester) async {
    await harness.seedRole("Ghost");
    await harness.mount(tester);
    final tr = harness.trOf(tester);

    await openExportPanel(tester);
    await harness.tap(tester, inPanel(find.text(tr.resourcesExportContactListTitle)));
    expect(find.text(tr.resourcesExportContactListDialogTitle), findsOneWidget);

    // Cancelling the options dialog exports nothing.
    await harness.tap(tester, find.text(tr.editorPageSetupCancelAction));
    expect(harness.exportManager.exports, isEmpty);

    await openExportPanel(tester);
    await harness.tap(tester, inPanel(find.text(tr.resourcesExportContactListTitle)));
    await harness.tap(tester, inPanel(find.text(tr.editorExportPdfExportAction)));

    final export = harness.exportManager.exports.single;
    expect(export.document, "contactList");
    expect(export.pageSetup!.format, OcptPageFormat.usLetter);
    expect(export.snapshot.roles.map((role) => role.name), contains("Ghost"));
    expect(
      find.text(tr.resourcesExportContactListSuccessMessage("/tmp/contactList.out")),
      findsOneWidget,
    );

    harness.exportManager.shouldFail = true;
    await openExportPanel(tester);
    await harness.tap(tester, inPanel(find.text(tr.resourcesExportContactListTitle)));
    await harness.tap(tester, inPanel(find.text(tr.editorExportPdfExportAction)));
    expect(find.text(tr.resourcesExportContactListError), findsOneWidget);
  });

  testWidgets("the panel's project package card reaches the save dialog", (tester) async {
    await harness.seedPerson("Alice");
    await harness.mount(tester);
    final tr = harness.trOf(tester);

    await openExportPanel(tester);
    await harness.tap(tester, inPanel(find.text(tr.workspaceExportProjectPackageTitle)));
    await harness.pumpUntil(tester, () => harness.exportManager.saveDialog.askedCount > 0);

    expect(harness.exportManager.saveDialog.askedCount, 1);
    expect(harness.exportManager.exports, isEmpty);
  });

  testWidgets("coming back from the project settings with a change re-reads the catalogue and "
      "keeps the selection, while a plain return reads nothing", (tester) async {
    await harness.seedPerson("Alice");
    await harness.mount(tester);
    final tr = harness.trOf(tester);
    await harness.tap(tester, find.text("Alice"));

    await harness.seedPerson("Bob");
    harness.routerManager.pushAnswer = false;
    await harness.tap(tester, find.byTooltip(tr.workspaceProjectSettingsTooltip));
    expect(harness.routerManager.pushCount, 1);
    expect(harness.inList(find.text("Bob")), findsNothing);

    harness.routerManager.pushAnswer = true;
    await harness.tap(tester, find.byTooltip(tr.workspaceProjectSettingsTooltip));
    expect(harness.routerManager.pushCount, 2);
    expect(harness.inList(find.text("Bob")), findsOneWidget);
    expect(harness.fieldHinted(tr.resourcesFirstNameHint), findsOneWidget);
    expect(find.text(tr.resourcesStatsPeople(2)), findsOneWidget);
  });

  testWidgets("the right dock opens on Versions with the working copy card, follows a flushed "
      "edit, survives a tab change, and the left dock folds away", (tester) async {
    await harness.seedPerson("Alice");
    expect(await harness.projectsManager.createProjectVersion(name: "v1", note: ""), isNotNull);
    await harness.mount(tester);
    final tr = harness.trOf(tester);

    expect(find.byType(OcptProjectVersionsPanel), findsNothing);
    await harness.tap(tester, find.byTooltip(tr.workspaceToggleRightDockTooltip));
    expect(find.byType(OcptProjectVersionsPanel), findsOneWidget);
    expect(find.text(tr.projectWorkingCopyIdenticalHint("v1")), findsOneWidget);

    // A typed edit reaching the database makes the card read the new state.
    await tester.runAsync(() => Future<void>.delayed(_captureThrottle));
    await harness.tap(tester, find.text("Alice"));
    await harness.type(tester, harness.fieldHinted(tr.resourcesFirstNameHint), "Alicia");
    await tester.pump(const Duration(milliseconds: 2500));
    await harness.pumpUntil(
      tester,
      () => harness.isShown(find.text(tr.projectWorkingCopyModifiedHint("v1"))),
    );
    expect(find.byType(OcptProjectWorkingCopyCard), findsOneWidget);
    expect(find.text(tr.projectWorkingCopyModifiedHint("v1")), findsOneWidget);

    await harness.openTab(tester, tr.resourcesTabRoles);
    expect(find.byType(OcptProjectVersionsPanel), findsOneWidget);

    await harness.tap(tester, find.byTooltip(tr.resourcesRightDockCloseTooltip));
    expect(find.byType(OcptProjectVersionsPanel), findsNothing);

    await harness.tap(tester, find.byTooltip(tr.workspaceToggleLeftDockTooltip));
    expect(find.byType(OcptResourcesListPanel), findsNothing);
    await harness.tap(tester, find.byTooltip(tr.workspaceToggleLeftDockTooltip));
    expect(find.byType(OcptResourcesListPanel), findsOneWidget);
  });

  testWidgets("previewing a version reloads the whole catalogue and withholds every write, "
      "leaving it brings the working copy back", (tester) async {
    await harness.seedPerson("Alice");
    await harness.seedRole("Sam");
    final locationId = await harness.seedLocation("Cave");
    await harness.seedSet(locationId, "Back room");
    await harness.seedElement("Lamp");
    expect(await harness.projectsManager.createProjectVersion(name: "v1", note: ""), isNotNull);

    // Written after the version was captured, so the preview cannot show it.
    await harness.seedPerson("Bob");
    await harness.seedLocation("Harbour");

    await harness.mount(tester);
    final tr = harness.trOf(tester);
    final collision = tr.roleAlertCompactCollisionLine("SAM");
    expect(find.text(tr.resourcesStatsPeople(2)), findsOneWidget);
    expect(find.text(collision), findsWidgets);
    await harness.tap(tester, find.text("Alice"));
    expect(harness.editableFields(), findsWidgets);

    await harness.openVersions(tester);
    await previewFirstVersion(tester);

    // The version's own catalogue, with the selection dropped and the alerts withheld.
    expect(find.text(tr.workspaceReadOnlyBannerExitAction), findsOneWidget);
    expect(find.text(tr.resourcesStatsPeople(1)), findsOneWidget);
    expect(harness.inList(find.text("Bob")), findsNothing);
    expect(find.text(collision), findsNothing);
    expect(find.text(tr.resourcesNoPersonSelectedHint), findsOneWidget);

    // None of it writable: the add buttons are withheld, the sheets refuse typing, no delete.
    expect(find.text(tr.resourcesAddPersonAction), findsNothing);
    await harness.tap(tester, find.text("Alice"));
    expect(harness.editableFields(), findsNothing);
    expect(harness.readOnlyFields(), findsWidgets);
    expect(find.text(tr.resourcesDeletePersonAction), findsNothing);
    expect(find.byTooltip(tr.workspaceProjectSettingsTooltip), findsNothing);
    await harness.openTab(tester, tr.resourcesTabRoles);
    expect(find.text(tr.resourcesAddRoleAction), findsNothing);
    await harness.openTab(tester, tr.resourcesTabLocations);
    expect(find.text(tr.resourcesAddLocationAction), findsNothing);
    await harness.tap(tester, find.text("Cave"));
    expect(find.text(tr.resourcesAddSetAction), findsNothing);
    expect(find.text(tr.resourcesLocationDeleteAction), findsNothing);
    await harness.openTab(tester, tr.resourcesTabElements);
    expect(find.text(tr.resourcesAddElementAction), findsNothing);

    // Searching only reads, so the toggle stays.
    await harness.tap(tester, find.byTooltip(tr.resourcesToggleSearchTooltip));
    expect(find.text(tr.resourcesSearchHint), findsOneWidget);

    // The package export card says why it is unavailable.
    await harness.tap(tester, find.byTooltip(tr.workspaceExportTooltip));
    expect(inPanel(find.text(tr.workspaceExportProjectPackagePreviewReason)), findsOneWidget);
    await harness.tap(tester, find.text(tr.resourcesDeleteConfirmCancelAction).hitTestable().first);

    // Back to the working copy: everything written since is there again, and writable.
    await exitPreview(tester);
    await harness.openTab(tester, tr.resourcesTabPeople);
    expect(find.text(tr.resourcesStatsPeople(2)), findsOneWidget);
    expect(find.text(collision), findsWidgets);
    expect(find.text(tr.resourcesAddPersonAction), findsOneWidget);
    expect(harness.inList(find.text("Bob")), findsOneWidget);
  });

  testWidgets("a first name typed just before previewing a version is written first, the preview "
      "shows the version's own, and leaving it brings the name back", (tester) async {
    await harness.seedPerson("Alice");
    expect(await harness.projectsManager.createProjectVersion(name: "v1", note: ""), isNotNull);
    await harness.mount(tester);
    final tr = harness.trOf(tester);
    await harness.openVersions(tester);
    await harness.tap(tester, find.text("Alice"));

    await harness.type(tester, harness.fieldHinted(tr.resourcesFirstNameHint), "Alicia");
    await previewFirstVersion(tester);

    // The working copy file holds it already, though the debounce never ran out.
    final stored = await harness.projectsManager.peopleService.loadPeople(
      database: harness.projectsManager.currentProject!.fileDatabase,
    );
    expect(stored.single.firstName, "Alicia");

    // The preview shows the version, which never had it.
    expect(harness.inList(find.text("Alice")), findsOneWidget);
    expect(find.text("Alicia"), findsNothing);

    await exitPreview(tester);
    expect(harness.inList(find.text("Alicia")), findsOneWidget);
  });

  testWidgets("restoring a version puts the catalogue back to it and drops the selection", (
    tester,
  ) async {
    await harness.seedPerson("Alice");
    expect(await harness.projectsManager.createProjectVersion(name: "v1", note: ""), isNotNull);
    await harness.seedPerson("Bob");
    await harness.seedLocation("Harbour");
    await harness.mount(tester);
    final tr = harness.trOf(tester);
    await harness.tap(tester, find.text("Alice"));
    expect(find.text(tr.resourcesStatsPeople(2)), findsOneWidget);

    await harness.openVersions(tester);
    await harness.tap(tester, find.text(tr.projectVersionRestoreAction));
    await harness.tap(tester, find.text(tr.projectVersionRestoreConfirmAction));
    await harness.pumpUntil(tester, () => harness.isShown(find.text(tr.resourcesStatsPeople(1))));

    expect(find.text(tr.resourcesStatsPeople(1)), findsOneWidget);
    expect(find.text(tr.resourcesNoPersonSelectedHint), findsOneWidget);
    expect((await harness.readPeople()).map((person) => person.firstName), ["Alice"]);
    expect(await harness.readLocations(), isEmpty);
  });
}
