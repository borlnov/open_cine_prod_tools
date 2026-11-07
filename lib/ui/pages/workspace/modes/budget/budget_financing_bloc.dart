// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_global_manager/act_global_manager.dart';
import 'package:drift/drift.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_budget_allowances_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_budget_financing_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_budget_quote_service.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_selection.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_totals.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_reload_scope.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/abs_ocpt_view_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_financing_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_state.dart';

/// This is the bloc class for the budget mode's financing views: the financing plan (the
/// resources, and the counterpart quote line an in-kind contribution keeps in step) and the
/// logistics (the defrayals, and the provisioning of an account).
///
/// The resources and the defrayals are the mode's data, in `OcptBudgetState.snapshot`, and which
/// row is highlighted is the mode's too. This bloc owns every write these views trigger: the
/// service, then `await modeBloc.reload(…)`, then, for a resource it created, the mode's selection
/// of it. Nothing here is typed into a debounce, so it registers nothing to flush and reacts to
/// nothing the mode does.
class OcptBudgetFinancingBloc
    extends AbsOcptViewBloc<OcptBudgetFinancingState, OcptBudgetState, OcptBudgetBloc> {
  /// The manager used to access the project currently open.
  final OcptProjectsManager _projectsManager;

  /// The service used to read and write the financing plan: the `budget_resources` catalogue.
  final OcptBudgetFinancingService _budgetFinancingService;

  /// The service used to read and write the defrayals: the `budget_allowances` a production types
  /// for itself, which nothing here deduces from the schedule.
  final OcptBudgetAllowancesService _budgetAllowancesService;

  /// The service used to write the quote lines an in-kind contribution keeps in step with, and the
  /// provisioning of an account.
  final OcptBudgetQuoteService _budgetQuoteService;

  /// {@macro open_cine_prod_tools.viewBlocConstructor}
  OcptBudgetFinancingBloc({
    required super.modeBloc,
    OcptProjectsManager? projectsManager,
    OcptBudgetFinancingService? budgetFinancingService,
    OcptBudgetAllowancesService? budgetAllowancesService,
    OcptBudgetQuoteService? budgetQuoteService,
  }) : _projectsManager = projectsManager ?? globalGetIt().get<OcptProjectsManager>(),
       _budgetFinancingService =
           budgetFinancingService ??
           (projectsManager ?? globalGetIt().get<OcptProjectsManager>()).budgetFinancingService,
       _budgetAllowancesService =
           budgetAllowancesService ??
           (projectsManager ?? globalGetIt().get<OcptProjectsManager>()).budgetAllowancesService,
       _budgetQuoteService =
           budgetQuoteService ??
           (projectsManager ?? globalGetIt().get<OcptProjectsManager>()).budgetQuoteService,
       super(const OcptBudgetFinancingState.init());

  /// {@macro act_flutter_utility.BlocForMixin.registerMixinEvents}
  @override
  void registerMixinEvents() {
    super.registerMixinEvents();
    on<OcptBudgetResourceCreationConfirmedEvent>(_onResourceCreationConfirmed);
    on<OcptBudgetResourceUpdateConfirmedEvent>(_onResourceUpdateConfirmed);
    on<OcptBudgetResourceDeletionConfirmedEvent>(_onResourceDeletionConfirmed);
    on<OcptBudgetAllowanceCreationConfirmedEvent>(_onAllowanceCreationConfirmed);
    on<OcptBudgetAllowanceUpdateConfirmedEvent>(_onAllowanceUpdateConfirmed);
    on<OcptBudgetAllowanceDeletionConfirmedEvent>(_onAllowanceDeletionConfirmed);
    on<OcptBudgetProvisionConfirmedEvent>(_onProvisionConfirmed);
  }

  /// Create a new financing resource from `event.fields` and select it.
  ///
  /// [OcptBudgetFinancingService.createResourceWithFields] writes the row, its fields and the
  /// counterpart quote line of an in-kind contribution in one transaction, the same write
  /// [_onResourceUpdateConfirmed] uses for an edit. The snapshot is read again on a failure too, so
  /// the screen shows what the database holds.
  Future<void> _onResourceCreationConfirmed(
    OcptBudgetResourceCreationConfirmedEvent event,
    Emitter<OcptBudgetFinancingState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final fields = event.fields;
    final created = await _budgetFinancingService.createResourceWithFields(
      database: project.database,
      fields: fields,
    );
    if (created.isError) {
      await modeBloc.reload({OcptBudgetReloadScope.snapshot});
      return;
    }

    final resourceId = created.value;

    if (!await modeBloc.reload({OcptBudgetReloadScope.snapshot})) {
      return;
    }

    if (resourceId != null) {
      await addToModeAndWait(
        OcptBudgetSelectionCreatedEvent(
          selection: OcptBudgetResourceSelection(resourceId),
          opensInspector: false,
        ),
      );
    }
  }

  /// Write `event.fields` onto resource `event.resourceId`.
  Future<void> _onResourceUpdateConfirmed(
    OcptBudgetResourceUpdateConfirmedEvent event,
    Emitter<OcptBudgetFinancingState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final written = await _budgetFinancingService.writeResourceFields(
      database: project.database,
      resourceId: event.resourceId,
      fields: event.fields,
    );
    if (written.isError) {
      await modeBloc.reload({OcptBudgetReloadScope.snapshot});
      return;
    }

    await modeBloc.reload({OcptBudgetReloadScope.snapshot});
  }

  /// Delete financing resource `event.resourceId` for good, confirmed by the mode's own
  /// `OcptConfirmDialog` — and, alongside it, its own counterpart line if it had one, found in the
  /// live snapshot before the deletion rather than after: a resource just tombstoned names no
  /// account any more for [ocptBudgetInKindCounterpartLineOf] to find it by.
  Future<void> _onResourceDeletionConfirmed(
    OcptBudgetResourceDeletionConfirmedEvent event,
    Emitter<OcptBudgetFinancingState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final counterpartLine = ocptBudgetInKindCounterpartLineOf(
      modeBloc.state.accounts,
      event.resourceId,
    );

    final deleted = await _budgetFinancingService.deleteResource(
      database: project.database,
      resourceId: event.resourceId,
    );
    if (deleted.isError) {
      return;
    }

    if (counterpartLine != null) {
      final lineDeleted = await _budgetQuoteService.deleteLine(
        database: project.database,
        lineId: counterpartLine.id,
      );
      if (lineDeleted.isError) {
        return;
      }
    }

    await modeBloc.reload({OcptBudgetReloadScope.snapshot});
  }

  /// Create a defrayal from `event.fields`.
  ///
  /// **One insert, unlike a resource's own two**: `OcptBudgetAllowancesService.createAllowance`
  /// takes every field the dialog collected, because a defrayal is only ever minted from a form
  /// already filled in — there is no "create it empty and name it afterwards" gesture here.
  Future<void> _onAllowanceCreationConfirmed(
    OcptBudgetAllowanceCreationConfirmedEvent event,
    Emitter<OcptBudgetFinancingState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final fields = event.fields;
    final created = await _budgetAllowancesService.createAllowance(
      database: project.database,
      personId: fields.personId,
      kind: fields.kind,
      label: fields.label,
      date: fields.date,
      endDate: fields.endDate,
      quantityMilli: fields.quantityMilli,
      unitAmountMilliCents: fields.unitAmountMilliCents,
      notes: fields.notes,
    );
    if (created.isError) {
      return;
    }

    await modeBloc.reload({OcptBudgetReloadScope.snapshot});
  }

  /// Write `event.fields` onto defrayal `event.allowanceId`.
  Future<void> _onAllowanceUpdateConfirmed(
    OcptBudgetAllowanceUpdateConfirmedEvent event,
    Emitter<OcptBudgetFinancingState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final fields = event.fields;
    final updated = await _budgetAllowancesService.updateAllowance(
      database: project.database,
      allowanceId: event.allowanceId,
      personId: Value(fields.personId),
      kind: Value(fields.kind),
      label: Value(fields.label),
      date: Value(fields.date),
      endDate: Value(fields.endDate),
      quantityMilli: Value(fields.quantityMilli),
      unitAmountMilliCents: Value(fields.unitAmountMilliCents),
      notes: Value(fields.notes),
    );
    if (updated.isError) {
      return;
    }

    await modeBloc.reload({OcptBudgetReloadScope.snapshot});
  }

  /// Delete defrayal `event.allowanceId` for good, confirmed by the mode's own
  /// `OcptConfirmDialog`.
  Future<void> _onAllowanceDeletionConfirmed(
    OcptBudgetAllowanceDeletionConfirmedEvent event,
    Emitter<OcptBudgetFinancingState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final deleted = await _budgetAllowancesService.deleteAllowance(
      database: project.database,
      allowanceId: event.allowanceId,
    );
    if (deleted.isError) {
      return;
    }

    await modeBloc.reload({OcptBudgetReloadScope.snapshot});
  }

  /// Carry out `event.entries` against account `event.accountId`, confirmed by the mode's own
  /// `OcptConfirmDialog`.
  Future<void> _onProvisionConfirmed(
    OcptBudgetProvisionConfirmedEvent event,
    Emitter<OcptBudgetFinancingState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final provisioned = await _budgetQuoteService.applyProvision(
      database: project.database,
      accountId: event.accountId,
      entries: event.entries,
    );
    if (provisioned.isError) {
      return;
    }

    await modeBloc.reload({OcptBudgetReloadScope.snapshot});
  }
}
