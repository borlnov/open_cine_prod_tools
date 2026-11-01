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
import 'package:open_cine_prod_tools/models/ocpt_budget_allowance_form_fields.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste_seed.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_resource_form_fields.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_provision_entry.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_provision_outcome.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_totals.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_allowance_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_provision_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_group_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_status.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_financing_bloc.dart';
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

/// Run the tests of [OcptBudgetFinancingBloc].
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
    tempDir = await Directory.systemTemp.createTemp("ocpt_budget_financing_bloc_test_test_");
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

  /// Builds the mode bloc wired to the test project, seeded with [seed] (defaulting to [_smallSeed]).
  OcptBudgetBloc buildBloc({List<OcptBudgetPosteSeed> seed = _smallSeed}) => OcptBudgetBloc(
    seed: seed,
    projectsManager: projectsManager,
    propertiesManager: propertiesManager,
    routerManager: _RecordingRouterManager(),
    exportManager: OcptExportManager(fileSelectorManager: const FileSelectorManager()),
  );

  /// Builds the financing bloc of [modeBloc].
  OcptBudgetFinancingBloc buildFinancing(OcptBudgetBloc modeBloc) {
    final bloc = OcptBudgetFinancingBloc(modeBloc: modeBloc, projectsManager: projectsManager);
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

  group("creating a resource", () {
    test("writes every field and selects it", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final financingBloc = buildFinancing(bloc);
      await waitForState(bloc, (state) => !state.isLoading);

      financingBloc.add(
        const OcptBudgetResourceCreationConfirmedEvent(
          fields: OcptBudgetResourceFormFields(
            groupKind: OcptBudgetResourceGroupKind.inKind,
            personId: null,
            label: "Camera loan",
            amountCents: 250000,
            status: OcptBudgetResourceStatus.agreed,
            isReimbursable: false,
            notes: "Lent by the lab",
            posteId: null,
          ),
        ),
      );
      final state = await waitForState(bloc, (state) => state.selectedResourceId != null);

      expect(state.resources, hasLength(1));
      final resource = state.resources.single;
      expect(resource.groupKind, OcptBudgetResourceGroupKind.inKind);
      expect(resource.label, "Camera loan");
      expect(resource.amountCents, 250000);
      expect(resource.status, OcptBudgetResourceStatus.agreed);
      expect(resource.notes, "Lent by the lab");
      expect(state.selectedResourceId, resource.id);
    });
  });

  group("editing a resource", () {
    test("writes every field back", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final financingBloc = buildFinancing(bloc);
      await waitForState(bloc, (state) => !state.isLoading);
      final project = projectsManager.currentProject!;
      final resourceId = await projectsManager.budgetFinancingService.createResource(
        database: project.database,
        label: "Original",
      );
      expect(resourceId, isNotNull);

      bloc.add(const OcptBudgetProjectSettingsChangedEvent());
      await waitForState(bloc, (state) => state.resources.isNotEmpty);

      financingBloc.add(
        OcptBudgetResourceUpdateConfirmedEvent(
          resourceId: resourceId!,
          fields: const OcptBudgetResourceFormFields(
            groupKind: OcptBudgetResourceGroupKind.cash,
            personId: null,
            label: "Renamed",
            amountCents: 500,
            status: OcptBudgetResourceStatus.confirmed,
            isReimbursable: true,
            notes: "Repaid before the split",
            posteId: null,
          ),
        ),
      );
      final state = await waitForState(bloc, (state) => state.resources.single.label == "Renamed");

      final resource = state.resources.single;
      expect(resource.groupKind, OcptBudgetResourceGroupKind.cash);
      expect(resource.amountCents, 500);
      expect(resource.status, OcptBudgetResourceStatus.confirmed);
      expect(resource.isReimbursable, isTrue);
      expect(resource.notes, "Repaid before the split");
    });
  });

  group("deleting a resource", () {
    test("tombstones it, and clears the selection when it was selected", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final financingBloc = buildFinancing(bloc);
      await waitForState(bloc, (state) => !state.isLoading);
      final project = projectsManager.currentProject!;
      final resourceId = await projectsManager.budgetFinancingService.createResource(
        database: project.database,
        label: "To be deleted",
      );
      expect(resourceId, isNotNull);

      bloc.add(const OcptBudgetProjectSettingsChangedEvent());
      await waitForState(bloc, (state) => state.resources.isNotEmpty);
      bloc.add(OcptBudgetResourceSelectedEvent(resourceId: resourceId!));
      await waitForState(bloc, (state) => state.selectedResourceId == resourceId);

      financingBloc.add(OcptBudgetResourceDeletionConfirmedEvent(resourceId: resourceId));
      final state = await waitForState(bloc, (state) => state.resources.isEmpty);

      expect(state.resources, isEmpty);
      expect(state.selectedResourceId, isNull);
    });
  });

  group("an in-kind contribution's counterpart line", () {
    test("creating one mints exactly one line, at 0% VAT, valued at its figure", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final financingBloc = buildFinancing(bloc);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final posteId = loaded.postes.first.id;

      financingBloc.add(
        OcptBudgetResourceCreationConfirmedEvent(
          fields: OcptBudgetResourceFormFields(
            groupKind: OcptBudgetResourceGroupKind.inKind,
            personId: null,
            label: "Camera loan",
            amountCents: 250000,
            status: OcptBudgetResourceStatus.agreed,
            isReimbursable: false,
            notes: "Lent by the lab",
            posteId: posteId,
          ),
        ),
      );
      final state = await waitForState(bloc, (state) => state.selectedResourceId != null);
      final resourceId = state.selectedResourceId!;

      final poste = state.postes.singleWhere((poste) => poste.id == posteId);
      final counterpartLines = poste.lines.where((line) => line.inKindResourceId == resourceId);
      expect(counterpartLines, hasLength(1));
      final line = counterpartLines.single;
      expect(line.label, "Camera loan");
      expect(line.quantityMilli, 1000);
      expect(line.unitPrice.amountCents, 250000);
      expect(line.unitPrice.vatRateBasisPoints, 0);
    });

    test("revaluing the contribution updates the line's own amount", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final financingBloc = buildFinancing(bloc);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final posteId = loaded.postes.first.id;

      financingBloc.add(
        OcptBudgetResourceCreationConfirmedEvent(
          fields: OcptBudgetResourceFormFields(
            groupKind: OcptBudgetResourceGroupKind.inKind,
            personId: null,
            label: "Camera loan",
            amountCents: 250000,
            status: OcptBudgetResourceStatus.agreed,
            isReimbursable: false,
            notes: "",
            posteId: posteId,
          ),
        ),
      );
      final created = await waitForState(bloc, (state) => state.selectedResourceId != null);
      final resourceId = created.selectedResourceId!;

      financingBloc.add(
        OcptBudgetResourceUpdateConfirmedEvent(
          resourceId: resourceId,
          fields: OcptBudgetResourceFormFields(
            groupKind: OcptBudgetResourceGroupKind.inKind,
            personId: null,
            label: "Camera loan",
            amountCents: 400000,
            status: OcptBudgetResourceStatus.agreed,
            isReimbursable: false,
            notes: "",
            posteId: posteId,
          ),
        ),
      );
      final state = await waitForState(
        bloc,
        (state) =>
            ocptBudgetInKindCounterpartLineOf(state.postes, resourceId)?.unitPrice.amountCents ==
            400000,
      );

      final poste = state.postes.singleWhere((poste) => poste.id == posteId);
      expect(poste.lines.where((line) => line.inKindResourceId == resourceId), hasLength(1));
    });

    test("renaming the contribution updates the line's own label", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final financingBloc = buildFinancing(bloc);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final posteId = loaded.postes.first.id;

      financingBloc.add(
        OcptBudgetResourceCreationConfirmedEvent(
          fields: OcptBudgetResourceFormFields(
            groupKind: OcptBudgetResourceGroupKind.inKind,
            personId: null,
            label: "Camera loan",
            amountCents: 250000,
            status: OcptBudgetResourceStatus.agreed,
            isReimbursable: false,
            notes: "",
            posteId: posteId,
          ),
        ),
      );
      final created = await waitForState(bloc, (state) => state.selectedResourceId != null);
      final resourceId = created.selectedResourceId!;

      financingBloc.add(
        OcptBudgetResourceUpdateConfirmedEvent(
          resourceId: resourceId,
          fields: OcptBudgetResourceFormFields(
            groupKind: OcptBudgetResourceGroupKind.inKind,
            personId: null,
            label: "Zoom lens loan",
            amountCents: 250000,
            status: OcptBudgetResourceStatus.agreed,
            isReimbursable: false,
            notes: "",
            posteId: posteId,
          ),
        ),
      );
      final state = await waitForState(
        bloc,
        (state) =>
            ocptBudgetInKindCounterpartLineOf(state.postes, resourceId)?.label == "Zoom lens loan",
      );

      final poste = state.postes.singleWhere((poste) => poste.id == posteId);
      expect(poste.lines.where((line) => line.inKindResourceId == resourceId), hasLength(1));
    });

    test("changing the poste re-homes the line, still exactly one", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final financingBloc = buildFinancing(bloc);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final originalPosteId = loaded.postes[0].id;
      final newPosteId = loaded.postes[1].id;

      financingBloc.add(
        OcptBudgetResourceCreationConfirmedEvent(
          fields: OcptBudgetResourceFormFields(
            groupKind: OcptBudgetResourceGroupKind.inKind,
            personId: null,
            label: "Camera loan",
            amountCents: 250000,
            status: OcptBudgetResourceStatus.agreed,
            isReimbursable: false,
            notes: "",
            posteId: originalPosteId,
          ),
        ),
      );
      final created = await waitForState(bloc, (state) => state.selectedResourceId != null);
      final resourceId = created.selectedResourceId!;

      financingBloc.add(
        OcptBudgetResourceUpdateConfirmedEvent(
          resourceId: resourceId,
          fields: OcptBudgetResourceFormFields(
            groupKind: OcptBudgetResourceGroupKind.inKind,
            personId: null,
            label: "Camera loan",
            amountCents: 250000,
            status: OcptBudgetResourceStatus.agreed,
            isReimbursable: false,
            notes: "",
            posteId: newPosteId,
          ),
        ),
      );
      final state = await waitForState(
        bloc,
        (state) =>
            ocptBudgetInKindCounterpartLineOf(state.postes, resourceId)?.posteId == newPosteId,
      );

      final oldPoste = state.postes.singleWhere((poste) => poste.id == originalPosteId);
      final newPoste = state.postes.singleWhere((poste) => poste.id == newPosteId);
      expect(oldPoste.lines.where((line) => line.inKindResourceId == resourceId), isEmpty);
      expect(newPoste.lines.where((line) => line.inKindResourceId == resourceId), hasLength(1));
    });

    test("reclassifying in-kind to cash removes the line", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final financingBloc = buildFinancing(bloc);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final posteId = loaded.postes.first.id;

      financingBloc.add(
        OcptBudgetResourceCreationConfirmedEvent(
          fields: OcptBudgetResourceFormFields(
            groupKind: OcptBudgetResourceGroupKind.inKind,
            personId: null,
            label: "Camera loan",
            amountCents: 250000,
            status: OcptBudgetResourceStatus.agreed,
            isReimbursable: false,
            notes: "",
            posteId: posteId,
          ),
        ),
      );
      final created = await waitForState(bloc, (state) => state.selectedResourceId != null);
      final resourceId = created.selectedResourceId!;
      expect(ocptBudgetInKindCounterpartLineOf(created.postes, resourceId), isNotNull);

      financingBloc.add(
        OcptBudgetResourceUpdateConfirmedEvent(
          resourceId: resourceId,
          fields: const OcptBudgetResourceFormFields(
            groupKind: OcptBudgetResourceGroupKind.cash,
            personId: null,
            label: "Camera loan",
            amountCents: 250000,
            status: OcptBudgetResourceStatus.agreed,
            isReimbursable: false,
            notes: "",
            posteId: null,
          ),
        ),
      );
      final state = await waitForState(
        bloc,
        (state) => ocptBudgetInKindCounterpartLineOf(state.postes, resourceId) == null,
      );

      expect(
        state.resources.singleWhere((r) => r.id == resourceId).groupKind,
        OcptBudgetResourceGroupKind.cash,
      );
    });

    test("reclassifying cash to in-kind mints exactly one line", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final financingBloc = buildFinancing(bloc);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final posteId = loaded.postes.first.id;

      financingBloc.add(
        const OcptBudgetResourceCreationConfirmedEvent(
          fields: OcptBudgetResourceFormFields(
            groupKind: OcptBudgetResourceGroupKind.cash,
            personId: null,
            label: "Cash from Alice",
            amountCents: 5000,
            status: OcptBudgetResourceStatus.confirmed,
            isReimbursable: false,
            notes: "",
            posteId: null,
          ),
        ),
      );
      final created = await waitForState(bloc, (state) => state.selectedResourceId != null);
      final resourceId = created.selectedResourceId!;
      expect(ocptBudgetInKindCounterpartLineOf(created.postes, resourceId), isNull);

      financingBloc.add(
        OcptBudgetResourceUpdateConfirmedEvent(
          resourceId: resourceId,
          fields: OcptBudgetResourceFormFields(
            groupKind: OcptBudgetResourceGroupKind.inKind,
            personId: null,
            label: "Cash from Alice",
            amountCents: 5000,
            status: OcptBudgetResourceStatus.confirmed,
            isReimbursable: false,
            notes: "",
            posteId: posteId,
          ),
        ),
      );
      final state = await waitForState(
        bloc,
        (state) => ocptBudgetInKindCounterpartLineOf(state.postes, resourceId) != null,
      );

      final poste = state.postes.singleWhere((poste) => poste.id == posteId);
      expect(poste.lines.where((line) => line.inKindResourceId == resourceId), hasLength(1));
    });

    test("deleting the contribution tombstones its counterpart line", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final financingBloc = buildFinancing(bloc);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final posteId = loaded.postes.first.id;

      financingBloc.add(
        OcptBudgetResourceCreationConfirmedEvent(
          fields: OcptBudgetResourceFormFields(
            groupKind: OcptBudgetResourceGroupKind.inKind,
            personId: null,
            label: "Camera loan",
            amountCents: 250000,
            status: OcptBudgetResourceStatus.agreed,
            isReimbursable: false,
            notes: "",
            posteId: posteId,
          ),
        ),
      );
      final created = await waitForState(bloc, (state) => state.selectedResourceId != null);
      final resourceId = created.selectedResourceId!;
      final lineId = ocptBudgetInKindCounterpartLineOf(created.postes, resourceId)!.id;

      financingBloc.add(OcptBudgetResourceDeletionConfirmedEvent(resourceId: resourceId));
      final state = await waitForState(bloc, (state) => state.resources.isEmpty);

      final poste = state.postes.singleWhere((poste) => poste.id == posteId);
      expect(poste.lines.any((line) => line.id == lineId), isFalse);
    });
  });

  group("the events of the financing bloc", () {
    /// The name of each event of the financing hierarchy: the switch names every one, so an event
    /// added to the hierarchy does not compile until this list, and the test below, know it.
    String nameOf(OcptBudgetFinancingEvent event) => switch (event) {
      OcptBudgetResourceCreationConfirmedEvent() => "resource created",
      OcptBudgetResourceUpdateConfirmedEvent() => "resource updated",
      OcptBudgetResourceDeletionConfirmedEvent() => "resource deleted",
      OcptBudgetAllowanceCreationConfirmedEvent() => "allowance created",
      OcptBudgetAllowanceUpdateConfirmedEvent() => "allowance updated",
      OcptBudgetAllowanceDeletionConfirmedEvent() => "allowance deleted",
      OcptBudgetProvisionConfirmedEvent() => "provision confirmed",
    };

    test("every event of its hierarchy has a handler", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      final financingBloc = buildFinancing(bloc);
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final posteId = loaded.postes.first.id;

      final handled = <String>[];
      Future<void> proves(
        OcptBudgetFinancingEvent event,
        bool Function(OcptBudgetState) effect,
      ) async {
        financingBloc.add(event);
        await waitForState(bloc, effect);
        handled.add(nameOf(event));
      }

      OcptBudgetResourceFormFields resource(String label) => OcptBudgetResourceFormFields(
        groupKind: OcptBudgetResourceGroupKind.cash,
        personId: null,
        label: label,
        amountCents: 1000,
        status: OcptBudgetResourceStatus.agreed,
        isReimbursable: false,
        notes: "",
        posteId: null,
      );
      OcptBudgetAllowanceFormFields allowance(String label) => OcptBudgetAllowanceFormFields(
        personId: null,
        kind: OcptBudgetAllowanceKind.travel,
        label: label,
        date: DateTime(2026, 3),
        endDate: null,
        quantityMilli: 1000,
        unitAmountMilliCents: 100000,
        notes: "",
      );

      // An event nobody handles is ignored silently, so each is proven by its effect.
      await proves(
        OcptBudgetResourceCreationConfirmedEvent(fields: resource("First")),
        (state) => state.resources.length == 1,
      );
      final resourceId = bloc.state.resources.single.id;
      await proves(
        OcptBudgetResourceUpdateConfirmedEvent(resourceId: resourceId, fields: resource("Renamed")),
        (state) => state.resources.single.label == "Renamed",
      );
      await proves(
        OcptBudgetResourceDeletionConfirmedEvent(resourceId: resourceId),
        (state) => state.resources.isEmpty,
      );

      await proves(
        OcptBudgetAllowanceCreationConfirmedEvent(fields: allowance("First")),
        (state) => state.allowances.length == 1,
      );
      final allowanceId = bloc.state.allowances.single.id;
      await proves(
        OcptBudgetAllowanceUpdateConfirmedEvent(
          allowanceId: allowanceId,
          fields: allowance("Renamed"),
        ),
        (state) => state.allowances.single.label == "Renamed",
      );
      await proves(
        OcptBudgetAllowanceDeletionConfirmedEvent(allowanceId: allowanceId),
        (state) => state.allowances.isEmpty,
      );

      await proves(
        OcptBudgetProvisionConfirmedEvent(
          posteId: posteId,
          entries: const [
            OcptBudgetProvisionEntry(
              kind: OcptBudgetProvisionKind.meal,
              lineId: null,
              label: "Meals",
              quantityMilli: 4000,
              unitAmountCents: 1200,
              outcome: OcptBudgetProvisionOutcome.created,
            ),
          ],
        ),
        (state) => state.postes.first.lines.any((line) => line.label == "Meals"),
      );

      expect(handled.toSet(), hasLength(7), reason: "one proof per event of the hierarchy");
    });

    test("is registered with the mode as a flusher, without any widget having read it", () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      buildFinancing(bloc);
      await waitForState(bloc, (state) => !state.isLoading);

      expect(bloc.pendingWritesFlusherCount, 1);
    });
  });
}
