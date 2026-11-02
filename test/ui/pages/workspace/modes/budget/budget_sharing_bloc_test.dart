// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste_seed.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_revenue_form_fields.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_share_form_fields.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_revenue_status.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_sharing_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_state.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// A router manager that only records the call: these bloc tests never navigate for real.
class _RecordingRouterManager extends OcptRouterManager {
  /// Ignore the pop: this double navigates nowhere.
  @override
  void pop<Y extends Object?>([Y? result]) {}
}

/// A minimal, three-entry seed used by every test that isn't about the seeding path itself, so
/// their own assertions aren't drowned in ten postes.
const _smallSeed = [
  OcptBudgetPosteSeed(id: "seed-1", code: "1", label: "Poste one", simpleLabel: "P1"),
  OcptBudgetPosteSeed(id: "seed-2", code: "2", label: "Poste two", simpleLabel: "P2"),
  OcptBudgetPosteSeed(id: "seed-3", code: "3", label: "Poste three", simpleLabel: "P3"),
];

/// Run the tests of [OcptBudgetSharingBloc].
void main() {
  late OcptPropertiesManager propertiesManager;
  late OcptProjectsManager projectsManager;
  late Directory tempDir;

  setUpAll(() async {
    OcptGlobalManager.instance;

    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    propertiesManager = OcptPropertiesManager();
    await propertiesManager.initLifeCycle();
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp("ocpt_budget_sharing_bloc_test_test_");
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

  /// Builds the mode bloc wired to the test project, seeded with [seed] (defaulting to
  /// [_smallSeed]).
  OcptBudgetBloc buildBloc({List<OcptBudgetPosteSeed> seed = _smallSeed}) => OcptBudgetBloc(
    seed: seed,
    projectsManager: projectsManager,
    propertiesManager: propertiesManager,
    routerManager: _RecordingRouterManager(),
    exportManager: OcptExportManager(fileSelectorManager: const FileSelectorManager()),
  );

  /// Builds the sharing bloc of [modeBloc].
  OcptBudgetSharingBloc buildSharing(OcptBudgetBloc modeBloc) {
    final bloc = OcptBudgetSharingBloc(modeBloc: modeBloc, projectsManager: projectsManager);
    addTearDown(bloc.close);
    return bloc;
  }

  /// Waits for the first state of [bloc] matching [predicate] (the current one included).
  Future<S> waitForState<S>(BlocBase<S> bloc, bool Function(S state) predicate) async {
    if (predicate(bloc.state)) {
      return bloc.state;
    }

    return bloc.stream.firstWhere(predicate).timeout(const Duration(seconds: 5));
  }

  group("creating a revenue", () {
    test("writes every field and selects it", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final sharingBloc = buildSharing(bloc);
      await waitForState(bloc, (state) => !state.isLoading);

      sharingBloc.add(
        OcptBudgetRevenueCreationConfirmedEvent(
          fields: OcptBudgetRevenueFormFields(
            date: DateTime(2026, 3),
            label: "Festival prize",
            amountCents: 250000,
            status: OcptBudgetRevenueStatus.confirmed,
            notes: "Announced at the closing ceremony",
          ),
        ),
      );
      final state = await waitForState(bloc, (state) => state.selectedRevenueId != null);

      expect(state.revenues, hasLength(1));
      final revenue = state.revenues.single;
      expect(revenue.label, "Festival prize");
      expect(revenue.amountCents, 250000);
      expect(revenue.status, OcptBudgetRevenueStatus.confirmed);
      expect(revenue.notes, "Announced at the closing ceremony");
      expect(state.selectedRevenueId, revenue.id);
    });
  });

  group("editing a revenue", () {
    test("writes every field back", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final sharingBloc = buildSharing(bloc);
      await waitForState(bloc, (state) => !state.isLoading);
      final project = projectsManager.currentProject!;
      final revenueId = await projectsManager.budgetSharingService.createRevenue(
        database: project.database,
        date: DateTime(2026, 3),
        label: "Original",
      );
      expect(revenueId, isNotNull);

      bloc.add(const OcptBudgetProjectSettingsChangedEvent());
      await waitForState(bloc, (state) => state.revenues.isNotEmpty);

      sharingBloc.add(
        OcptBudgetRevenueUpdateConfirmedEvent(
          revenueId: revenueId!,
          fields: OcptBudgetRevenueFormFields(
            date: DateTime(2026, 4),
            label: "Renamed",
            amountCents: 500,
            status: OcptBudgetRevenueStatus.invoiced,
            notes: "Billed",
          ),
        ),
      );
      final state = await waitForState(bloc, (state) => state.revenues.single.label == "Renamed");

      final revenue = state.revenues.single;
      expect(revenue.amountCents, 500);
      expect(revenue.status, OcptBudgetRevenueStatus.invoiced);
      expect(revenue.notes, "Billed");
    });
  });

  group("reordering a revenue", () {
    test("moves it to the new position", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final sharingBloc = buildSharing(bloc);
      await waitForState(bloc, (state) => !state.isLoading);
      final project = projectsManager.currentProject!;
      final firstId = await projectsManager.budgetSharingService.createRevenue(
        database: project.database,
        date: DateTime(2026, 3),
        label: "First",
      );
      await projectsManager.budgetSharingService.createRevenue(
        database: project.database,
        date: DateTime(2026, 3),
        label: "Second",
      );
      expect(firstId, isNotNull);

      bloc.add(const OcptBudgetProjectSettingsChangedEvent());
      await waitForState(bloc, (state) => state.revenues.length == 2);

      sharingBloc.add(OcptBudgetRevenueReorderedEvent(revenueId: firstId!, newPosition: 1));
      final state = await waitForState(bloc, (state) => state.revenues.last.id == firstId);

      expect(state.revenues.last.id, firstId);
    });
  });

  group("deleting a revenue", () {
    test("tombstones it, and clears the selection when it was selected", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final sharingBloc = buildSharing(bloc);
      await waitForState(bloc, (state) => !state.isLoading);
      final project = projectsManager.currentProject!;
      final revenueId = await projectsManager.budgetSharingService.createRevenue(
        database: project.database,
        date: DateTime(2026, 3),
        label: "To be deleted",
      );
      expect(revenueId, isNotNull);

      bloc.add(const OcptBudgetProjectSettingsChangedEvent());
      await waitForState(bloc, (state) => state.revenues.isNotEmpty);
      bloc.add(OcptBudgetRevenueSelectedEvent(revenueId: revenueId!));
      await waitForState(bloc, (state) => state.selectedRevenueId == revenueId);

      sharingBloc.add(OcptBudgetRevenueDeletionConfirmedEvent(revenueId: revenueId));
      final state = await waitForState(bloc, (state) => state.revenues.isEmpty);

      expect(state.revenues, isEmpty);
      expect(state.selectedRevenueId, isNull);
    });
  });

  group("creating a share", () {
    test("writes every field and selects it", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final sharingBloc = buildSharing(bloc);
      await waitForState(bloc, (state) => !state.isLoading);

      sharingBloc.add(
        const OcptBudgetShareCreationConfirmedEvent(
          fields: OcptBudgetShareFormFields(
            personId: null,
            label: "Director",
            sharePermille: 300,
            reinvestPermille: 100,
            notes: "Agreed by contract",
          ),
        ),
      );
      final state = await waitForState(bloc, (state) => state.selectedShareId != null);

      expect(state.shares, hasLength(1));
      final share = state.shares.single;
      expect(share.label, "Director");
      expect(share.sharePermille, 300);
      expect(share.reinvestPermille, 100);
      expect(share.notes, "Agreed by contract");
      expect(state.selectedShareId, share.id);
    });
  });

  group("editing a share", () {
    test("writes every field back", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final sharingBloc = buildSharing(bloc);
      await waitForState(bloc, (state) => !state.isLoading);
      final project = projectsManager.currentProject!;
      final shareId = await projectsManager.budgetSharingService.createShare(
        database: project.database,
        label: "Original",
      );
      expect(shareId, isNotNull);

      bloc.add(const OcptBudgetProjectSettingsChangedEvent());
      await waitForState(bloc, (state) => state.shares.isNotEmpty);

      sharingBloc.add(
        OcptBudgetShareUpdateConfirmedEvent(
          shareId: shareId!,
          fields: const OcptBudgetShareFormFields(
            personId: null,
            label: "Renamed",
            sharePermille: 600,
            reinvestPermille: 500,
            notes: "Renegotiated",
          ),
        ),
      );
      final state = await waitForState(bloc, (state) => state.shares.single.label == "Renamed");

      final share = state.shares.single;
      expect(share.sharePermille, 600);
      expect(share.reinvestPermille, 500);
      expect(share.notes, "Renegotiated");
    });
  });

  group("reordering a share", () {
    test("moves it to the new position", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final sharingBloc = buildSharing(bloc);
      await waitForState(bloc, (state) => !state.isLoading);
      final project = projectsManager.currentProject!;
      final firstId = await projectsManager.budgetSharingService.createShare(
        database: project.database,
        label: "First",
      );
      await projectsManager.budgetSharingService.createShare(
        database: project.database,
        label: "Second",
      );
      expect(firstId, isNotNull);

      bloc.add(const OcptBudgetProjectSettingsChangedEvent());
      await waitForState(bloc, (state) => state.shares.length == 2);

      sharingBloc.add(OcptBudgetShareReorderedEvent(shareId: firstId!, newPosition: 1));
      final state = await waitForState(bloc, (state) => state.shares.last.id == firstId);

      expect(state.shares.last.id, firstId);
    });
  });

  group("deleting a share", () {
    test("tombstones it, and clears the selection when it was selected", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final sharingBloc = buildSharing(bloc);
      await waitForState(bloc, (state) => !state.isLoading);
      final project = projectsManager.currentProject!;
      final shareId = await projectsManager.budgetSharingService.createShare(
        database: project.database,
        label: "To be deleted",
      );
      expect(shareId, isNotNull);

      bloc.add(const OcptBudgetProjectSettingsChangedEvent());
      await waitForState(bloc, (state) => state.shares.isNotEmpty);
      bloc.add(OcptBudgetShareSelectedEvent(shareId: shareId!));
      await waitForState(bloc, (state) => state.selectedShareId == shareId);

      sharingBloc.add(OcptBudgetShareDeletionConfirmedEvent(shareId: shareId));
      final state = await waitForState(bloc, (state) => state.shares.isEmpty);

      expect(state.shares, isEmpty);
      expect(state.selectedShareId, isNull);
    });
  });

  group("the events of the sharing bloc", () {
    /// The name of each event of the sharing hierarchy: the switch names every one, so an event
    /// added to the hierarchy does not compile until this list, and the test below, know it.
    String nameOf(OcptBudgetSharingEvent event) => switch (event) {
      OcptBudgetRevenueCreationConfirmedEvent() => "revenue created",
      OcptBudgetRevenueUpdateConfirmedEvent() => "revenue updated",
      OcptBudgetRevenueReorderedEvent() => "revenue reordered",
      OcptBudgetRevenueDeletionConfirmedEvent() => "revenue deleted",
      OcptBudgetShareCreationConfirmedEvent() => "share created",
      OcptBudgetShareUpdateConfirmedEvent() => "share updated",
      OcptBudgetShareReorderedEvent() => "share reordered",
      OcptBudgetShareDeletionConfirmedEvent() => "share deleted",
    };

    test("every event of its hierarchy has a handler", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final sharingBloc = buildSharing(bloc);
      await waitForState(bloc, (state) => !state.isLoading);

      final handled = <String>[];
      Future<void> proves(
        OcptBudgetSharingEvent event,
        bool Function(OcptBudgetState) effect,
      ) async {
        sharingBloc.add(event);
        await waitForState(bloc, effect);
        handled.add(nameOf(event));
      }

      OcptBudgetRevenueFormFields revenue(String label) => OcptBudgetRevenueFormFields(
        date: DateTime(2026, 3),
        label: label,
        amountCents: 100,
        status: OcptBudgetRevenueStatus.confirmed,
        notes: "",
      );
      OcptBudgetShareFormFields share(String label) => OcptBudgetShareFormFields(
        personId: null,
        label: label,
        sharePermille: 100,
        reinvestPermille: 0,
        notes: "",
      );

      // An event nobody handles is ignored silently, so each is proven by its effect.
      await proves(
        OcptBudgetRevenueCreationConfirmedEvent(fields: revenue("First")),
        (state) => state.revenues.length == 1,
      );
      await proves(
        OcptBudgetRevenueCreationConfirmedEvent(fields: revenue("Second")),
        (state) => state.revenues.length == 2,
      );
      final firstRevenueId = bloc.state.revenues.first.id;
      await proves(
        OcptBudgetRevenueUpdateConfirmedEvent(
          revenueId: firstRevenueId,
          fields: revenue("Renamed"),
        ),
        (state) => state.revenues.any((revenue) => revenue.label == "Renamed"),
      );
      await proves(
        OcptBudgetRevenueReorderedEvent(revenueId: firstRevenueId, newPosition: 1),
        (state) => state.revenues.last.id == firstRevenueId,
      );
      await proves(
        OcptBudgetRevenueDeletionConfirmedEvent(revenueId: firstRevenueId),
        (state) => state.revenues.length == 1,
      );

      await proves(
        OcptBudgetShareCreationConfirmedEvent(fields: share("First")),
        (state) => state.shares.length == 1,
      );
      await proves(
        OcptBudgetShareCreationConfirmedEvent(fields: share("Second")),
        (state) => state.shares.length == 2,
      );
      final firstShareId = bloc.state.shares.first.id;
      await proves(
        OcptBudgetShareUpdateConfirmedEvent(shareId: firstShareId, fields: share("Renamed")),
        (state) => state.shares.any((share) => share.label == "Renamed"),
      );
      await proves(
        OcptBudgetShareReorderedEvent(shareId: firstShareId, newPosition: 1),
        (state) => state.shares.last.id == firstShareId,
      );
      await proves(
        OcptBudgetShareDeletionConfirmedEvent(shareId: firstShareId),
        (state) => state.shares.length == 1,
      );

      expect(handled.toSet(), hasLength(8), reason: "one proof per event of the hierarchy");
    });

    test("is registered with the mode as a flusher, without any widget having read it", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      buildSharing(bloc);
      await waitForState(bloc, (state) => !state.isLoading);

      expect(bloc.pendingWritesFlusherCount, 1);
    });
  });

  test("a taking created while a share is highlighted leaves the share highlighted", () async {
    final bloc = buildBloc();
    addTearDown(bloc.close);
    final sharingBloc = buildSharing(bloc);
    await waitForState(bloc, (state) => !state.isLoading);

    sharingBloc.add(
      const OcptBudgetShareCreationConfirmedEvent(
        fields: OcptBudgetShareFormFields(
          personId: null,
          label: "Director",
          sharePermille: 300,
          reinvestPermille: 100,
          notes: "",
        ),
      ),
    );
    final withShare = await waitForState(bloc, (state) => state.selectedShareId != null);

    sharingBloc.add(
      OcptBudgetRevenueCreationConfirmedEvent(
        fields: OcptBudgetRevenueFormFields(
          date: DateTime(2026, 3),
          label: "Prize",
          amountCents: 100,
          status: OcptBudgetRevenueStatus.confirmed,
          notes: "",
        ),
      ),
    );
    final withRevenue = await waitForState(bloc, (state) => state.selectedRevenueId != null);

    // The taking is the selection, drawn as a plain highlight: the right dock is not opened.
    expect(withRevenue.selectedShareId, withShare.selectedShareId);
    expect(withRevenue.rightDockTab, isNull);
  });
}
