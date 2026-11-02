// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/models/ocpt_budget_mileage_rate.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_element.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_default_provision_account.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_right_dock_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_selection.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_selection_cause.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_tax_basis.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_tools_view.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_view.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_state.dart';

/// The named copies of an `OcptBudgetState`: each one is a change the bloc makes, spelled out with
/// every field the change affects.
extension OcptBudgetStateCopiesExtension on OcptBudgetState {
  /// Copy this state with the selection and the selected share cleared, moving the selection
  /// with the cause [OcptBudgetSelectionCause.cleared].
  OcptBudgetState copyWithSelectionCleared() => copyWith(
    forceSelectionValue: true,
    forceSelectedShareIdValue: true,
    selectionEpoch: selectionEpoch + 1,
    selectionCause: OcptBudgetSelectionCause.cleared,
  );

  /// Copy this state as loaded when no project is open: the right dock preferences restored, no
  /// version previewed, the selection cleared and the data emptied.
  OcptBudgetState copyToLoadedWithoutProject({
    required double rightDockFraction,
    required OcptBudgetRightDockTab lastRightDockTab,
  }) => copyWith(
    isLoading: false,
    rightDockFraction: rightDockFraction,
    lastRightDockTab: lastRightDockTab,
    forcePreviewedVersionIdValue: true,
    forceSelectionValue: true,
    forceSelectedShareIdValue: true,
    roles: const [],
    people: const [],
    elements: const [],
    logisticsDecorNameByDayId: const {},
    selectionEpoch: selectionEpoch + 1,
    selectionCause: OcptBudgetSelectionCause.load,
  );

  /// Copy this state as loaded from the open project: the budget and everything read beside it
  /// replaced, the selection and the selected share cleared and the selection moved with the cause
  /// [OcptBudgetSelectionCause.load].
  ///
  /// No version is previewed when [previewedVersionId] is null, and the provision account goes back
  /// to the default one of [snapshot].
  OcptBudgetState copyToLoaded({
    required String title,
    required String? previewedVersionId,
    required OcptBudgetSnapshot snapshot,
    required List<OcptRole> roles,
    required List<OcptPerson> people,
    required List<OcptElement> elements,
    required List<OcptBudgetMileageRate> mileageRates,
    required Map<String, String> logisticsDecorNameByDayId,
    required double rightDockFraction,
    required OcptBudgetRightDockTab lastRightDockTab,
    required OcptPageSetup pageSetup,
  }) => copyWith(
    isLoading: false,
    title: title,
    previewedVersionId: previewedVersionId,
    forcePreviewedVersionIdValue: previewedVersionId == null,
    snapshot: snapshot,
    currencyCode: snapshot.currencyCode,
    forceSelectionValue: true,
    forceSelectedShareIdValue: true,
    roles: roles,
    people: people,
    elements: elements,
    mileageRates: mileageRates,
    provisionAccountId: ocptBudgetDefaultProvisionAccountIdOf(snapshot.accounts),
    logisticsDecorNameByDayId: logisticsDecorNameByDayId,
    rightDockFraction: rightDockFraction,
    lastRightDockTab: lastRightDockTab,
    pageSetup: pageSetup,
    selectionEpoch: selectionEpoch + 1,
    selectionCause: OcptBudgetSelectionCause.load,
  );

  /// Copy this state with the budget [snapshot] and everything read beside it replaced.
  ///
  /// What the new [snapshot] no longer holds is dropped in the same copy, and moves the selection
  /// with the cause [OcptBudgetSelectionCause.reconciled]: the selection when it is not
  /// [selectionStillExists], the account filter when it is not [filterStillExists] and the selected
  /// share when it is not [shareStillExists]. The provision account stays unless [snapshot] no
  /// longer holds it, and then goes back to the default one.
  OcptBudgetState copyWithReconciledSnapshot({
    required OcptBudgetSnapshot snapshot,
    required List<OcptRole> roles,
    required List<OcptPerson> people,
    required List<OcptElement> elements,
    required List<OcptBudgetMileageRate> mileageRates,
    required Map<String, String> logisticsDecorNameByDayId,
    required bool selectionStillExists,
    required bool filterStillExists,
    required bool shareStillExists,
  }) {
    final hasDroppedSelection = !selectionStillExists || !filterStillExists || !shareStillExists;
    return copyWith(
      snapshot: snapshot,
      currencyCode: snapshot.currencyCode,
      roles: roles,
      people: people,
      elements: elements,
      mileageRates: mileageRates,
      provisionAccountId:
          provisionAccountId != null &&
              snapshot.accounts.any((account) => account.id == provisionAccountId)
          ? provisionAccountId
          : ocptBudgetDefaultProvisionAccountIdOf(snapshot.accounts),
      logisticsDecorNameByDayId: logisticsDecorNameByDayId,
      forceSelectionValue: !selectionStillExists,
      forceFilterAccountIdValue: !filterStillExists,
      forceSelectedShareIdValue: !shareStillExists,
      selectionEpoch: hasDroppedSelection ? selectionEpoch + 1 : null,
      selectionCause: hasDroppedSelection ? OcptBudgetSelectionCause.reconciled : null,
    );
  }

  /// Copy this state with the right dock tab [tab] shown and remembered, or the dock closed when
  /// [isAlreadyActive].
  OcptBudgetState copyWithToggledRightDockTab({
    required OcptBudgetRightDockTab tab,
    required bool isAlreadyActive,
  }) => copyWith(
    rightDockTab: isAlreadyActive ? null : tab,
    forceRightDockTabValue: isAlreadyActive,
    lastRightDockTab: tab,
  );

  /// Copy this state with the right dock closed.
  OcptBudgetState copyWithRightDockClosed() => copyWith(forceRightDockTabValue: true);

  /// Copy this state with the right dock reopened on the last tab it showed.
  OcptBudgetState copyWithRightDockReopened() => copyWith(rightDockTab: lastRightDockTab);

  /// Copy this state with [fraction] as the width of the right dock.
  OcptBudgetState copyWithRightDockFraction({required double fraction}) =>
      copyWith(rightDockFraction: fraction);

  /// Copy this state with [view] as the centre view.
  ///
  /// The selection is cleared, moving it with the cause [OcptBudgetSelectionCause.viewChanged],
  /// when [clearSelection].
  OcptBudgetState copyWithView({required OcptBudgetView view, required bool clearSelection}) =>
      copyWith(
        view: view,
        forceSelectionValue: clearSelection,
        selectionEpoch: clearSelection ? selectionEpoch + 1 : null,
        selectionCause: clearSelection ? OcptBudgetSelectionCause.viewChanged : null,
      );

  /// Copy this state with [toolsView] as the tools view.
  ///
  /// The selection is cleared, moving it with the cause [OcptBudgetSelectionCause.viewChanged],
  /// when [clearSelection].
  OcptBudgetState copyWithToolsView({
    required OcptBudgetToolsView toolsView,
    required bool clearSelection,
  }) => copyWith(
    toolsView: toolsView,
    forceSelectionValue: clearSelection,
    selectionEpoch: clearSelection ? selectionEpoch + 1 : null,
    selectionCause: clearSelection ? OcptBudgetSelectionCause.viewChanged : null,
  );

  /// Copy this state with the simplified figures switched on or off.
  OcptBudgetState copyWithSimplified({required bool isSimplified}) =>
      copyWith(isSimplified: isSimplified);

  /// Copy this state with [basis] as the tax basis the figures are shown on.
  OcptBudgetState copyWithTaxBasis({required OcptBudgetTaxBasis basis}) =>
      copyWith(taxBasis: basis);

  /// Copy this state with [expandedNodeIds] as the rows shown expanded.
  OcptBudgetState copyWithExpandedNodeIds({required Set<String> expandedNodeIds}) =>
      copyWith(expandedNodeIds: expandedNodeIds);

  /// Copy this state with [selection] selected and the inspector shown, remembered as the last
  /// right dock tab.
  OcptBudgetState copyWithInspectedSelection({required OcptBudgetSelection selection}) => copyWith(
    selection: selection,
    rightDockTab: OcptBudgetRightDockTab.inspector,
    lastRightDockTab: OcptBudgetRightDockTab.inspector,
    selectionEpoch: selectionEpoch + 1,
    selectionCause: OcptBudgetSelectionCause.selected,
  );

  /// Copy this state with [selection] selected as the record was just created.
  ///
  /// The inspector is shown, and remembered as the last right dock tab, when [opensInspector].
  OcptBudgetState copyWithCreatedSelection({
    required OcptBudgetSelection selection,
    required bool opensInspector,
  }) => copyWith(
    selection: selection,
    rightDockTab: opensInspector ? OcptBudgetRightDockTab.inspector : null,
    lastRightDockTab: opensInspector ? OcptBudgetRightDockTab.inspector : null,
    selectionEpoch: selectionEpoch + 1,
    selectionCause: OcptBudgetSelectionCause.created,
  );

  /// Copy this state with the share [shareId] selected as it was just created.
  OcptBudgetState copyWithCreatedShare({required String shareId}) => copyWith(
    selectedShareId: shareId,
    selectionEpoch: selectionEpoch + 1,
    selectionCause: OcptBudgetSelectionCause.created,
  );

  /// Copy this state with the share [shareId] selected.
  OcptBudgetState copyWithSelectedShare({required String shareId}) => copyWith(
    selectedShareId: shareId,
    selectionEpoch: selectionEpoch + 1,
    selectionCause: OcptBudgetSelectionCause.shareSelected,
  );

  /// Copy this state with the account filter cleared, moving the selection with the cause
  /// [OcptBudgetSelectionCause.filtered].
  OcptBudgetState copyWithAccountFilterCleared() => copyWith(
    forceFilterAccountIdValue: true,
    selectionEpoch: selectionEpoch + 1,
    selectionCause: OcptBudgetSelectionCause.filtered,
  );

  /// Copy this state with every view narrowed to the account [accountId], moving the selection with
  /// the cause [OcptBudgetSelectionCause.filtered].
  OcptBudgetState copyWithAccountFilter({required String accountId}) => copyWith(
    filterAccountId: accountId,
    selectionEpoch: selectionEpoch + 1,
    selectionCause: OcptBudgetSelectionCause.filtered,
  );

  /// Copy this state with the account [accountId] as the provision account, moving the selection
  /// with the cause [OcptBudgetSelectionCause.provisionSelected].
  OcptBudgetState copyWithProvisionAccount({required String accountId}) => copyWith(
    provisionAccountId: accountId,
    selectionEpoch: selectionEpoch + 1,
    selectionCause: OcptBudgetSelectionCause.provisionSelected,
  );
}
