// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_budget_sharing_service.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_selection.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_reload_scope.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/abs_ocpt_view_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_sharing_form_writes.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_sharing_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_state.dart';

/// This is the bloc class for the budget mode's revenue sharing view: the takings and the shares
/// that split what they bring in.
///
/// The takings and the shares are the mode's data, in `OcptBudgetState.snapshot`, and which row is
/// highlighted is the mode's too. This bloc owns every write the view triggers: the service, then
/// `await modeBloc.reload(…)`, then, for a taking or a share it created, the mode's selection of
/// it. Nothing here is typed into a debounce, so it registers nothing to flush and reacts to
/// nothing the mode does.
class OcptBudgetSharingBloc
    extends AbsOcptViewBloc<OcptBudgetSharingState, OcptBudgetState, OcptBudgetBloc> {
  /// The manager used to access the project currently open.
  final OcptProjectsManager _projectsManager;

  /// The service used to read and write the revenue sharing: the `budget_revenues` takings and the
  /// `budget_shares` splitting what they bring in.
  final OcptBudgetSharingService _budgetSharingService;

  /// Class constructor
  ///
  /// Every dependency but [modeBloc] can be overridden, which is what the tests do; in the app they
  /// all resolve through [globalGetIt].
  OcptBudgetSharingBloc({
    required super.modeBloc,
    OcptProjectsManager? projectsManager,
    OcptBudgetSharingService? budgetSharingService,
  }) : _projectsManager = projectsManager ?? globalGetIt().get<OcptProjectsManager>(),
       _budgetSharingService =
           budgetSharingService ??
           (projectsManager ?? globalGetIt().get<OcptProjectsManager>()).budgetSharingService,
       super(const OcptBudgetSharingState.init());

  /// {@macro act_flutter_utility.BlocForMixin.registerMixinEvents}
  @override
  void registerMixinEvents() {
    super.registerMixinEvents();
    on<OcptBudgetRevenueCreationConfirmedEvent>(_onRevenueCreationConfirmed);
    on<OcptBudgetRevenueUpdateConfirmedEvent>(_onRevenueUpdateConfirmed);
    on<OcptBudgetRevenueReorderedEvent>(_onRevenueReordered);
    on<OcptBudgetRevenueDeletionConfirmedEvent>(_onRevenueDeletionConfirmed);
    on<OcptBudgetShareCreationConfirmedEvent>(_onShareCreationConfirmed);
    on<OcptBudgetShareUpdateConfirmedEvent>(_onShareUpdateConfirmed);
    on<OcptBudgetShareReorderedEvent>(_onShareReordered);
    on<OcptBudgetShareDeletionConfirmedEvent>(_onShareDeletionConfirmed);
  }

  /// Create a new taking from `event.fields` and select it, without opening the right dock —
  /// mirrors the creation of a financing resource: `OcptBudgetSharingService.createRevenue` mints
  /// the row from a date and a label alone, every other field written straight after through
  /// `OcptBudgetSharingFormWrites.writeRevenueFields`, the very same call
  /// [_onRevenueUpdateConfirmed] itself uses.
  Future<void> _onRevenueCreationConfirmed(
    OcptBudgetRevenueCreationConfirmedEvent event,
    Emitter<OcptBudgetSharingState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final fields = event.fields;
    final revenueId = await _budgetSharingService.createRevenueWithFields(
      database: project.database,
      fields: fields,
    );

    if (!await modeBloc.reload({OcptBudgetReloadScope.snapshot})) {
      return;
    }

    if (revenueId != null) {
      await addToModeAndWait(
        OcptBudgetSelectionCreatedEvent(
          selection: OcptBudgetRevenueSelection(revenueId),
          opensInspector: false,
        ),
      );
    }
  }

  /// Write `event.fields` onto revenue `event.revenueId`.
  Future<void> _onRevenueUpdateConfirmed(
    OcptBudgetRevenueUpdateConfirmedEvent event,
    Emitter<OcptBudgetSharingState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    await _budgetSharingService.writeRevenueFields(
      database: project.database,
      revenueId: event.revenueId,
      fields: event.fields,
    );
    await modeBloc.reload({OcptBudgetReloadScope.snapshot});
  }

  /// Move revenue `event.revenueId` to `event.newPosition` within the sharing view's own flat
  /// order — mirrors `OcptBudgetAccountReorderedEvent`'s own handler.
  Future<void> _onRevenueReordered(
    OcptBudgetRevenueReorderedEvent event,
    Emitter<OcptBudgetSharingState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    await _budgetSharingService.reorderRevenue(
      database: project.database,
      revenueId: event.revenueId,
      newPosition: event.newPosition,
    );
    await modeBloc.reload({OcptBudgetReloadScope.snapshot});
  }

  /// Delete taking `event.revenueId` for good, confirmed by the mode's own `OcptConfirmDialog` —
  /// mirrors the deletion of a financing resource.
  Future<void> _onRevenueDeletionConfirmed(
    OcptBudgetRevenueDeletionConfirmedEvent event,
    Emitter<OcptBudgetSharingState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    await _budgetSharingService.deleteRevenue(
      database: project.database,
      revenueId: event.revenueId,
    );
    await modeBloc.reload({OcptBudgetReloadScope.snapshot});
  }

  /// Create a new share from `event.fields` and select it — mirrors
  /// [_onRevenueCreationConfirmed].
  Future<void> _onShareCreationConfirmed(
    OcptBudgetShareCreationConfirmedEvent event,
    Emitter<OcptBudgetSharingState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final fields = event.fields;
    final shareId = await _budgetSharingService.createShareWithFields(
      database: project.database,
      fields: fields,
    );

    if (!await modeBloc.reload({OcptBudgetReloadScope.snapshot})) {
      return;
    }

    if (shareId != null) {
      await addToModeAndWait(OcptBudgetShareCreatedEvent(shareId: shareId));
    }
  }

  /// Write `event.fields` onto share `event.shareId`.
  Future<void> _onShareUpdateConfirmed(
    OcptBudgetShareUpdateConfirmedEvent event,
    Emitter<OcptBudgetSharingState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    await _budgetSharingService.writeShareFields(
      database: project.database,
      shareId: event.shareId,
      fields: event.fields,
    );
    await modeBloc.reload({OcptBudgetReloadScope.snapshot});
  }

  /// Move share `event.shareId` to `event.newPosition` within the sharing view's own flat order —
  /// mirrors [_onRevenueReordered].
  Future<void> _onShareReordered(
    OcptBudgetShareReorderedEvent event,
    Emitter<OcptBudgetSharingState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    await _budgetSharingService.reorderShare(
      database: project.database,
      shareId: event.shareId,
      newPosition: event.newPosition,
    );
    await modeBloc.reload({OcptBudgetReloadScope.snapshot});
  }

  /// Delete share `event.shareId` for good, confirmed by the mode's own `OcptConfirmDialog` —
  /// mirrors [_onRevenueDeletionConfirmed].
  Future<void> _onShareDeletionConfirmed(
    OcptBudgetShareDeletionConfirmedEvent event,
    Emitter<OcptBudgetSharingState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    await _budgetSharingService.deleteShare(database: project.database, shareId: event.shareId);
    await modeBloc.reload({OcptBudgetReloadScope.snapshot});
  }
}
