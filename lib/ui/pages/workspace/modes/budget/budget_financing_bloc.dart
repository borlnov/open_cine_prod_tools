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
import 'package:open_cine_prod_tools/models/ocpt_budget_resource_form_fields.dart';
import 'package:open_cine_prod_tools/models/ocpt_open_project_model.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_totals.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_reload_scope.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_group_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_selection.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/abs_ocpt_view_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_financing_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_form_writes.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_state.dart';

/// This is the bloc class for the budget mode's financing views: the financing plan (the
/// resources, and the counterpart quote line an in-kind contribution keeps in step) and the
/// logistics (the defrayals, and the provisioning of a poste).
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
  /// provisioning of a poste.
  final OcptBudgetQuoteService _budgetQuoteService;

  /// Class constructor
  ///
  /// Every dependency but [modeBloc] can be overridden, which is what the tests do; in the app they
  /// all resolve through [globalGetIt].
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
  /// [OcptBudgetFinancingService.createResource] mints the row from a label alone (mirroring
  /// `OcptBudgetQuoteService.createPoste`'s own shape, unlike `createCommitment`'s single insert):
  /// every other field `event.fields` collected is written straight after, in the very same
  /// [OcptBudgetFinancingService.updateResource] call [_onResourceUpdateConfirmed] itself uses, so
  /// there is exactly one place that turns a whole [OcptBudgetResourceFormFields] into a write.
  Future<void> _onResourceCreationConfirmed(
    OcptBudgetResourceCreationConfirmedEvent event,
    Emitter<OcptBudgetFinancingState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final fields = event.fields;
    final resourceId = await _budgetFinancingService.createResourceWithFields(
      database: project.database,
      fields: fields,
    );
    if (resourceId != null) {
      await _reconcileInKindCounterpartLine(project, resourceId, fields);
    }

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

    await _budgetFinancingService.writeResourceFields(
      database: project.database,
      resourceId: event.resourceId,
      fields: event.fields,
    );
    await _reconcileInKindCounterpartLine(project, event.resourceId, event.fields);
    await modeBloc.reload({OcptBudgetReloadScope.snapshot});
  }

  /// Delete financing resource `event.resourceId` for good, confirmed by the mode's own
  /// `OcptConfirmDialog` — and, alongside it, its own counterpart line if it had one, found in the
  /// live snapshot before the deletion rather than after: a resource just tombstoned names no poste
  /// any more for [ocptBudgetInKindCounterpartLineOf] to find it by.
  Future<void> _onResourceDeletionConfirmed(
    OcptBudgetResourceDeletionConfirmedEvent event,
    Emitter<OcptBudgetFinancingState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final counterpartLine = ocptBudgetInKindCounterpartLineOf(
      modeBloc.state.postes,
      event.resourceId,
    );

    await _budgetFinancingService.deleteResource(
      database: project.database,
      resourceId: event.resourceId,
    );
    if (counterpartLine != null) {
      await _budgetQuoteService.deleteLine(database: project.database, lineId: counterpartLine.id);
    }
    await modeBloc.reload({OcptBudgetReloadScope.snapshot});
  }

  /// Keep in-kind contribution `resourceId`'s own counterpart quote line in step with `fields`,
  /// called right after `OcptBudgetFinancingFormWrites.writeResourceFields` writes the contribution
  /// itself, from both [_onResourceCreationConfirmed] and [_onResourceUpdateConfirmed] — the
  /// resource and its counterpart line are two rows kept in step by one caller, the same "one
  /// write, two rows" shape [OcptBudgetLinePaidDirectlyEvent] already uses to create a commitment
  /// and its entry together (`docs/architecture/budget.md`, "A quote line is paid directly, the
  /// commitment made for it").
  ///
  /// **Exactly one counterpart line exists whenever `fields` describes an in-kind contribution,
  /// and none does otherwise** — the invariant `docs/architecture/budget.md`'s "A balanced in-kind
  /// contribution" argues for:
  /// - not in kind any more (or never was): the existing line, if any, is tombstoned — a
  ///   reclassification away from in-kind offsets no poste any more.
  /// - in kind, no line yet: one is minted, quantity 1 (`quantityMilli` 1000), tax-inclusive,
  ///   frozen at 0 % VAT (a valuation, not an invoice — "The link, and where the single truth
  ///   lives"), the figure and label read straight off `fields`.
  /// - in kind, a line already exists, same poste: an ordinary field update — the label and the
  ///   amount follow the contribution; the quantity and the 0 % rate are never touched again.
  /// - in kind, a line already exists, a **different** poste: deleted and re-minted in the new one,
  ///   never moved in place. `budget_lines.sortKey` is fractional **within its own `posteId`**
  ///   (`OcptBudgetPostesTable` orders flat; `budget_lines` orders "like a shot within a scene"),
  ///   so re-poste-ing a line is really a second operation — its position among a different poste's
  ///   own lines — wearing the name of a field write (`docs/architecture/budget.md`, "A
  ///   commitment's poste is editable, a quote line's is not").
  ///
  /// `OcptBudgetResourceDialog`'s own poste picker already blocks confirming an in-kind
  /// contribution with no poste chosen, so `fields.posteId == null` here should not occur; this
  /// writes nothing rather than mint an orphaned line if it somehow does.
  Future<void> _reconcileInKindCounterpartLine(
    OcptOpenProjectModel project,
    String resourceId,
    OcptBudgetResourceFormFields fields,
  ) async {
    final existing = ocptBudgetInKindCounterpartLineOf(modeBloc.state.postes, resourceId);

    if (fields.groupKind != OcptBudgetResourceGroupKind.inKind) {
      if (existing != null) {
        await _budgetQuoteService.deleteLine(database: project.database, lineId: existing.id);
      }
      return;
    }

    final desiredPosteId = fields.posteId;
    if (desiredPosteId == null) {
      return;
    }

    if (existing != null && existing.posteId == desiredPosteId) {
      await _budgetQuoteService.updateLine(
        database: project.database,
        lineId: existing.id,
        label: Value(fields.label),
        unitAmountCents: Value(fields.amountCents),
      );
      return;
    }

    if (existing != null) {
      await _budgetQuoteService.deleteLine(database: project.database, lineId: existing.id);
    }

    await _budgetQuoteService.createLine(
      database: project.database,
      posteId: desiredPosteId,
      label: fields.label,
      quantityMilli: const Value(1000),
      unitAmountCents: Value(fields.amountCents),
      isTaxInclusive: const Value(true),
      vatRateBasisPoints: const Value(0),
      inKindResourceId: Value(resourceId),
    );
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
    await _budgetAllowancesService.createAllowance(
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
    await _budgetAllowancesService.updateAllowance(
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

    await _budgetAllowancesService.deleteAllowance(
      database: project.database,
      allowanceId: event.allowanceId,
    );
    await modeBloc.reload({OcptBudgetReloadScope.snapshot});
  }

  /// Carry out `event.entries` against poste `event.posteId`, confirmed by the mode's own
  /// `OcptConfirmDialog`.
  Future<void> _onProvisionConfirmed(
    OcptBudgetProvisionConfirmedEvent event,
    Emitter<OcptBudgetFinancingState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    await _budgetQuoteService.applyProvision(
      database: project.database,
      posteId: event.posteId,
      entries: event.entries,
    );
    await modeBloc.reload({OcptBudgetReloadScope.snapshot});
  }
}
