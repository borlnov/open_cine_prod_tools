// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';
import 'dart:ui';

import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_contact_list_export_options.dart';
import 'package:open_cine_prod_tools/models/ocpt_contact_list_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_resources_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_resources_xlsx_labels.dart';
import 'package:open_cine_prod_tools/types/ocpt_export_outcome.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/types/ocpt_person_editable_field.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_export_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_export_state.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// The seven weekday names an availability window's summary cell is built from, keyed by their
/// `DateTime.monday`…`DateTime.sunday` numbers — the locale's own names in the app, plain English
/// ones here.
const Map<int, String> _weekdayLabels = {
  DateTime.monday: "Mon",
  DateTime.tuesday: "Tue",
  DateTime.wednesday: "Wed",
  DateTime.thursday: "Thu",
  DateTime.friday: "Fri",
  DateTime.saturday: "Sat",
  DateTime.sunday: "Sun",
};

/// An export manager whose [exportResourcesXlsx] is stubbed and whose calls are recorded, so the
/// bloc's export path can be exercised without any real native dialog or workbook write. Mirrors
/// `shot_list_bloc_test.dart`'s own `_FakeExportManager`.
class _FakeExportManager extends OcptExportManager {
  /// Class constructor
  _FakeExportManager({this.exportResult, this.fails = false})
    : super(fileSelectorManager: const FileSelectorManager());

  /// The path [exportResourcesXlsx] returns, or null to simulate a cancelled save dialog.
  final String? exportResult;

  /// Whether [exportResourcesXlsx] throws, to exercise the bloc's export failure path.
  final bool fails;

  /// The snapshot of the last [exportResourcesXlsx] call.
  OcptResourcesSnapshot? lastExportedSnapshot;

  /// The labels of the last [exportResourcesXlsx] call.
  OcptResourcesXlsxLabels? lastExportedLabels;

  /// The project name of the last [exportResourcesXlsx] call.
  String? lastExportedProjectName;

  /// The file type label of the last [exportResourcesXlsx] call.
  String? lastExportedFileTypeLabel;

  @override
  Future<OcptExportOutcome?> exportResourcesXlsx({
    required OcptResourcesSnapshot snapshot,
    required OcptResourcesXlsxLabels labels,
    required String projectName,
    required String fileTypeLabel,
    Rect? shareAnchor,
  }) async {
    lastExportedSnapshot = snapshot;
    lastExportedLabels = labels;
    lastExportedProjectName = projectName;
    lastExportedFileTypeLabel = fileTypeLabel;

    if (fails) {
      throw StateError("resources export intentionally failed for the test");
    }

    final result = exportResult;
    return result == null ? null : OcptExportSaved(result);
  }

  /// The snapshot of the last [exportContactList] call.
  OcptResourcesSnapshot? lastExportedContactListSnapshot;

  /// The page setup of the last [exportContactList] call.
  OcptPageSetup? lastExportedContactListPageSetup;

  /// The labels of the last [exportContactList] call.
  OcptContactListLabels? lastExportedContactListLabels;

  /// The project name of the last [exportContactList] call.
  String? lastExportedContactListProjectName;

  /// The file type label of the last [exportContactList] call.
  String? lastExportedContactListFileTypeLabel;

  @override
  Future<OcptExportOutcome?> exportContactList({
    required OcptResourcesSnapshot snapshot,
    required OcptPageSetup pageSetup,
    required OcptContactListLabels labels,
    required String projectName,
    required String fileTypeLabel,
    DateTime? exportDate,
    Rect? shareAnchor,
  }) async {
    lastExportedContactListSnapshot = snapshot;
    lastExportedContactListPageSetup = pageSetup;
    lastExportedContactListLabels = labels;
    lastExportedContactListProjectName = projectName;
    lastExportedContactListFileTypeLabel = fileTypeLabel;

    if (fails) {
      throw StateError("contact list export intentionally failed for the test");
    }

    final result = exportResult;
    return result == null ? null : OcptExportSaved(result);
  }
}

/// The labels the export tests dispatch, standing in for what `ocptResourcesXlsxLabelsOf` builds
/// from a real `Tr`: the bloc only carries them through to the manager.
const _exportLabels = OcptResourcesXlsxLabels(
  fileNameSuffix: "resources",
  peopleSheetName: "People",
  rolesSheetName: "Roles",
  locationsSheetName: "Locations",
  elementsSheetName: "Elements",
  peopleColumnHeaders: {},
  rolesColumnHeaders: {},
  locationsColumnHeaders: {},
  elementsColumnHeaders: {},
  crewPositionLabels: {},
  roleKindLabels: {},
  imageRightsStatusLabels: {},
  permitStatusLabels: {},
  elementCategoryLabels: {},
  elementSourceKindLabels: {},
  dayPartSlotLabels: {},
  availabilityKindLabels: {},
  elementTrackingToSecureLabel: "To secure",
  elementTrackingSecuredLabel: "Secured",
  elementTrackingReadyLabel: "Ready",
  elementTrackingReturnedLabel: "Returned",
  everyDayLabel: "Every day",
  weekdayLabels: _weekdayLabels,
  sceneLabels: {},
);

/// The labels the contact list export tests dispatch, standing in for what
/// `ocptContactListLabelsOf` builds from a real `Tr`: the bloc only carries them through to the
/// manager.
const _contactListLabels = OcptContactListLabels(
  fileNameSuffix: "contacts",
  documentTitle: "Contact list",
  versionLabel: "Version",
  crewSectionTitle: "Crew",
  castSectionTitle: "Cast",
  nameHeader: "Name",
  positionHeader: "Position",
  phoneHeader: "Phone",
  emailHeader: "Email",
  crewDepartmentLabels: {},
  crewPositionLabels: {},
  unassignedDepartmentLabel: "Unassigned",
  emptyDocumentNote: "Nothing to print.",
);

/// The options the contact list export tests dispatch, standing in for what
/// `OcptContactListExportDialog` returns.
const _contactListOptions = OcptContactListExportOptions(
  format: OcptPageFormat.usLetter,
  margins: FountainPageMargins.standard(),
);

/// A router manager whose [pop] only records that it was called: these bloc tests don't build a
/// real GoRouter for it to operate on.
class _RecordingRouterManager extends OcptRouterManager {
  /// Records the call instead of delegating to the (never initialized) GoRouter.
  @override
  void pop<Y extends Object?>([Y? result]) {}
}

void main() {
  late OcptPropertiesManager propertiesManager;
  late OcptProjectsManager projectsManager;
  late Directory tempDir;

  setUpAll(() async {
    // Creating the global manager makes appLogger() (used by the bloc's write error path)
    // resolvable; the bloc's dependencies themselves are passed to it explicitly below.
    OcptGlobalManager.instance;

    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    propertiesManager = OcptPropertiesManager();
    await propertiesManager.initLifeCycle();
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp("ocpt_resources_export_bloc_test_");
    projectsManager = OcptProjectsManager(
      propertiesManager: propertiesManager,
      appLanguageCode: () => "en",
    );
    await projectsManager.initLifeCycle();

    final result = await projectsManager.createProject(
      name: "My Movie",
      filePath: p.join(tempDir.path, "movie.ocpt"),
    );
    expect(result.status.isSuccess, isTrue);
  });

  tearDown(() async {
    await projectsManager.disposeLifeCycle();
    await tempDir.delete(recursive: true);
  });

  /// Builds the mode bloc wired to the test project. [fieldEditDebounce] defaults to a duration no
  /// test waits out, so a typed edit stays pending until an export flushes it.
  OcptResourcesBloc buildBloc({Duration fieldEditDebounce = const Duration(days: 1)}) =>
      OcptResourcesBloc(
        projectsManager: projectsManager,
        propertiesManager: propertiesManager,
        routerManager: _RecordingRouterManager(),
        exportManager: OcptExportManager(fileSelectorManager: const FileSelectorManager()),
        fieldEditDebounce: fieldEditDebounce,
      );

  /// Builds the export bloc of [modeBloc], exporting through [exportManager] (a cancelled save
  /// dialog by default, so no test ever reaches a native one).
  OcptResourcesExportBloc buildExportBloc(
    OcptResourcesBloc modeBloc, {
    OcptExportManager? exportManager,
  }) => OcptResourcesExportBloc(
    modeBloc: modeBloc,
    projectsManager: projectsManager,
    exportManager: exportManager ?? _FakeExportManager(),
  );

  /// Waits for the first state of [bloc] matching [predicate] (the current one included).
  Future<S> waitForState<S>(BlocBase<S> bloc, bool Function(S state) predicate) async {
    if (predicate(bloc.state)) {
      return bloc.state;
    }

    return bloc.stream.firstWhere(predicate).timeout(const Duration(seconds: 5));
  }

  /// Creates a person through [modeBloc] and types [firstName] into their sheet without letting the
  /// debounce write it.
  Future<String> createPersonWithPendingName(OcptResourcesBloc modeBloc, String firstName) async {
    modeBloc.add(const OcptResourcesPersonCreationRequestedEvent());
    final created = await waitForState(modeBloc, (state) => state.peopleCount == 1);
    final personId = created.selectedPersonId!;

    modeBloc.add(
      OcptResourcesPersonFieldChangedEvent(
        personId: personId,
        field: OcptPersonField.firstName,
        rawValue: firstName,
      ),
    );
    await waitForState(modeBloc, (state) => state.pendingFieldEdits.isNotEmpty);

    return personId;
  }

  group("the workbook export", () {
    test("hands the snapshot to the export manager", () async {
      final exportManager = _FakeExportManager(exportResult: "/tmp/My Movie - resources.xlsx");
      final modeBloc = buildBloc();
      final exportBloc = buildExportBloc(modeBloc, exportManager: exportManager);
      await waitForState(modeBloc, (state) => !state.isLoading);

      modeBloc.add(const OcptResourcesPersonCreationRequestedEvent());
      await waitForState(modeBloc, (state) => state.peopleCount == 1);

      exportBloc.add(
        const OcptResourcesXlsxExportRequestedEvent(
          labels: _exportLabels,
          fileTypeLabel: "Excel workbook",
        ),
      );
      final state = await waitForState(exportBloc, (state) => state.ioNotice != null);

      expect(state.ioNotice!.kind, OcptResourcesIoNoticeKind.xlsxExportSucceeded);
      expect(state.ioNotice!.path, "/tmp/My Movie - resources.xlsx");
      expect(exportManager.lastExportedProjectName, "My Movie");
      expect(exportManager.lastExportedFileTypeLabel, "Excel workbook");
      expect(exportManager.lastExportedLabels, _exportLabels);
      expect(exportManager.lastExportedSnapshot!.peopleCount, 1);

      exportBloc.add(const OcptResourcesIoNoticeDismissedEvent());
      await waitForState(exportBloc, (state) => state.ioNotice == null);
      expect(modeBloc.state.hasWriteError, isFalse);

      await exportBloc.close();
      await modeBloc.close();
    });

    test("flushes a pending field edit first, so the workbook holds it", () async {
      final exportManager = _FakeExportManager(exportResult: "/tmp/My Movie - resources.xlsx");
      final modeBloc = buildBloc();
      final exportBloc = buildExportBloc(modeBloc, exportManager: exportManager);
      await waitForState(modeBloc, (state) => !state.isLoading);
      final personId = await createPersonWithPendingName(modeBloc, "Léa");

      exportBloc.add(
        const OcptResourcesXlsxExportRequestedEvent(
          labels: _exportLabels,
          fileTypeLabel: "Excel workbook",
        ),
      );
      await waitForState(exportBloc, (state) => state.ioNotice != null);

      expect(modeBloc.state.pendingFieldEdits, isEmpty);
      final exportedPerson = exportManager.lastExportedSnapshot!.people.firstWhere(
        (person) => person.id == personId,
      );
      expect(exportedPerson.firstName, "Léa");

      await exportBloc.close();
      await modeBloc.close();
    });

    test("leaves no notice at all when the save dialog is cancelled", () async {
      final modeBloc = buildBloc();
      final exportBloc = buildExportBloc(modeBloc, exportManager: _FakeExportManager());
      await waitForState(modeBloc, (state) => !state.isLoading);

      exportBloc.add(
        const OcptResourcesXlsxExportRequestedEvent(
          labels: _exportLabels,
          fileTypeLabel: "Excel workbook",
        ),
      );
      // Nothing to wait for: a cancellation emits no state of its own, so the assertion is that the
      // bloc settles back with no notice once the export has had time to resolve.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(exportBloc.state.ioNotice, isNull);

      await exportBloc.close();
      await modeBloc.close();
    });

    test("raises the transient export failure notice when the export fails", () async {
      final modeBloc = buildBloc();
      final exportBloc = buildExportBloc(modeBloc, exportManager: _FakeExportManager(fails: true));
      await waitForState(modeBloc, (state) => !state.isLoading);

      exportBloc.add(
        const OcptResourcesXlsxExportRequestedEvent(
          labels: _exportLabels,
          fileTypeLabel: "Excel workbook",
        ),
      );
      final state = await waitForState(exportBloc, (state) => state.ioNotice != null);

      expect(state.ioNotice!.kind, OcptResourcesIoNoticeKind.xlsxExportFailed);
      expect(state.ioNotice!.path, isNull);

      await exportBloc.close();
      await modeBloc.close();
    });
  });

  group("the contact list export", () {
    test("hands the snapshot and the options to the export manager", () async {
      final exportManager = _FakeExportManager(exportResult: "/tmp/My Movie - contacts.pdf");
      final modeBloc = buildBloc();
      final exportBloc = buildExportBloc(modeBloc, exportManager: exportManager);
      await waitForState(modeBloc, (state) => !state.isLoading);

      modeBloc.add(const OcptResourcesPersonCreationRequestedEvent());
      final created = await waitForState(modeBloc, (state) => state.peopleCount == 1);

      modeBloc.add(
        OcptResourcesPositionAddedEvent(
          personId: created.selectedPersonId!,
          positionId: "director",
          customLabel: "",
        ),
      );
      await waitForState(modeBloc, (state) => state.positionCount == 1);

      exportBloc.add(
        const OcptResourcesContactListExportRequestedEvent(
          options: _contactListOptions,
          labels: _contactListLabels,
          fileTypeLabel: "PDF document",
        ),
      );
      final state = await waitForState(exportBloc, (state) => state.ioNotice != null);

      expect(state.ioNotice!.kind, OcptResourcesIoNoticeKind.contactListExportSucceeded);
      expect(state.ioNotice!.path, "/tmp/My Movie - contacts.pdf");
      expect(exportManager.lastExportedContactListProjectName, "My Movie");
      expect(exportManager.lastExportedContactListFileTypeLabel, "PDF document");
      expect(exportManager.lastExportedContactListLabels, _contactListLabels);
      expect(
        exportManager.lastExportedContactListPageSetup,
        const OcptPageSetup(
          format: OcptPageFormat.usLetter,
          margins: FountainPageMargins.standard(),
        ),
      );
      expect(exportManager.lastExportedContactListSnapshot!.positionCount, 1);

      exportBloc.add(const OcptResourcesIoNoticeDismissedEvent());
      await waitForState(exportBloc, (state) => state.ioNotice == null);
      expect(modeBloc.state.hasWriteError, isFalse);

      await exportBloc.close();
      await modeBloc.close();
    });

    test("flushes a pending field edit first, so the document holds it", () async {
      final exportManager = _FakeExportManager(exportResult: "/tmp/My Movie - contacts.pdf");
      final modeBloc = buildBloc();
      final exportBloc = buildExportBloc(modeBloc, exportManager: exportManager);
      await waitForState(modeBloc, (state) => !state.isLoading);
      final personId = await createPersonWithPendingName(modeBloc, "Léa");

      exportBloc.add(
        const OcptResourcesContactListExportRequestedEvent(
          options: _contactListOptions,
          labels: _contactListLabels,
          fileTypeLabel: "PDF document",
        ),
      );
      await waitForState(exportBloc, (state) => state.ioNotice != null);

      expect(modeBloc.state.pendingFieldEdits, isEmpty);
      final exportedPerson = exportManager.lastExportedContactListSnapshot!.people.firstWhere(
        (person) => person.id == personId,
      );
      expect(exportedPerson.firstName, "Léa");

      await exportBloc.close();
      await modeBloc.close();
    });

    test("leaves no notice at all when the save dialog is cancelled", () async {
      final modeBloc = buildBloc();
      final exportBloc = buildExportBloc(modeBloc, exportManager: _FakeExportManager());
      await waitForState(modeBloc, (state) => !state.isLoading);

      exportBloc.add(
        const OcptResourcesContactListExportRequestedEvent(
          options: _contactListOptions,
          labels: _contactListLabels,
          fileTypeLabel: "PDF document",
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(exportBloc.state.ioNotice, isNull);

      await exportBloc.close();
      await modeBloc.close();
    });

    test("raises the transient export failure notice when the export fails", () async {
      final modeBloc = buildBloc();
      final exportBloc = buildExportBloc(modeBloc, exportManager: _FakeExportManager(fails: true));
      await waitForState(modeBloc, (state) => !state.isLoading);

      exportBloc.add(
        const OcptResourcesContactListExportRequestedEvent(
          options: _contactListOptions,
          labels: _contactListLabels,
          fileTypeLabel: "PDF document",
        ),
      );
      final state = await waitForState(exportBloc, (state) => state.ioNotice != null);

      expect(state.ioNotice!.kind, OcptResourcesIoNoticeKind.contactListExportFailed);
      expect(state.ioNotice!.path, isNull);

      await exportBloc.close();
      await modeBloc.close();
    });
  });

  group("the events of the export bloc", () {
    test("every event of its hierarchy has a handler", () async {
      final exportManager = _FakeExportManager(exportResult: "/tmp/export");
      final modeBloc = buildBloc();
      final exportBloc = buildExportBloc(modeBloc, exportManager: exportManager);
      await waitForState(modeBloc, (state) => !state.isLoading);
      modeBloc.add(const OcptResourcesPersonCreationRequestedEvent());
      await waitForState(modeBloc, (state) => state.peopleCount == 1);

      String nameOf(OcptResourcesExportEvent event) => switch (event) {
        OcptResourcesXlsxExportRequestedEvent() => "workbook",
        OcptResourcesContactListExportRequestedEvent() => "contact list",
        OcptResourcesIoNoticeDismissedEvent() => "dismiss",
      };
      const events = <OcptResourcesExportEvent>[
        OcptResourcesXlsxExportRequestedEvent(
          labels: _exportLabels,
          fileTypeLabel: "Excel workbook",
        ),
        OcptResourcesContactListExportRequestedEvent(
          options: _contactListOptions,
          labels: _contactListLabels,
          fileTypeLabel: "PDF document",
        ),
        OcptResourcesIoNoticeDismissedEvent(),
      ];
      expect(
        events.map(nameOf).toSet(),
        hasLength(3),
        reason: 'one event per name of the hierarchy',
      );

      // An event nobody handles is ignored silently, so each is proven by its effect: an export
      // leaves a notice, and the dismissal takes it away again.
      exportBloc.add(events[0]);
      await waitForState(exportBloc, (state) => state.ioNotice != null);
      exportBloc.add(events[2]);
      await waitForState(exportBloc, (state) => state.ioNotice == null);

      exportBloc.add(events[1]);
      final contactList = await waitForState(exportBloc, (state) => state.ioNotice != null);
      expect(contactList.ioNotice!.kind, OcptResourcesIoNoticeKind.contactListExportSucceeded);

      await exportBloc.close();
      await modeBloc.close();
    });
  });
}
