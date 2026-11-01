// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/models/ocpt_budget_mileage_rate.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_resources_snapshot.dart';
import 'package:open_cine_prod_tools/types/ocpt_resources_right_dock_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_resources_selection_cause.dart';
import 'package:open_cine_prod_tools/types/ocpt_resources_tab.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_state.dart';

/// The named copies of an `OcptResourcesState`: each one is a change the bloc makes, spelled out
/// with every field the change affects.
extension OcptResourcesStateCopiesExtension on OcptResourcesState {
  /// Copies this state with the catalogue [snapshot] read again, which moves the reload epoch.
  OcptResourcesState copyWithReloadedSnapshot({required OcptResourcesSnapshot? snapshot}) =>
      copyWith(snapshot: snapshot);

  /// Copies this state with the currency and the catalogue of the project settings read again.
  OcptResourcesState copyWithReloadedProjectSettings({
    required OcptResourcesSnapshot snapshot,
    required String currencyCode,
  }) => copyWith(snapshot: snapshot, currencyCode: currencyCode);

  /// Copies this state with a write error flagged.
  OcptResourcesState copyWithWriteError() => copyWith(hasWriteError: true);

  /// Copies this state with the write error dismissed.
  OcptResourcesState copyWithWriteErrorDismissed() => copyWith(hasWriteError: false);

  /// Copies this state with the pending edits flagged as lost: a write error, and the reload epoch
  /// moved so the views read the catalogue again.
  OcptResourcesState copyWithPendingEditsLost() => copyWith(
    hasWriteError: true,
    lostEditsEpoch: lostEditsEpoch + 1,
    reloadEpoch: reloadEpoch + 1,
  );

  /// Copies this state as loaded when no project is open: the dock fractions restored, no version
  /// previewed and the selection moved with the cause [OcptResourcesSelectionCause.load].
  OcptResourcesState copyToLoadedWithoutProject({
    required double leftDockFraction,
    required double rightDockFraction,
  }) => copyWith(
    isLoading: false,
    leftDockFraction: leftDockFraction,
    rightDockFraction: rightDockFraction,
    forcePreviewedVersionIdValue: true,
    selectionEpoch: selectionEpoch + 1,
    selectionCause: OcptResourcesSelectionCause.load,
  );

  /// Copies this state as loaded from the open project: the catalogue and everything read beside
  /// it replaced, the four selections cleared, the pending reveal request consumed and the
  /// selection moved with the cause [OcptResourcesSelectionCause.load].
  ///
  /// No version is previewed when [previewedVersionId] is null.
  OcptResourcesState copyToLoaded({
    required String title,
    required String currencyCode,
    required String? previewedVersionId,
    required OcptResourcesSnapshot snapshot,
    required OcptPageSetup pageSetup,
    required List<OcptBudgetMileageRate> mileageRates,
    required Set<String> setIdsWithPlan,
    required double leftDockFraction,
    required double rightDockFraction,
  }) => copyWith(
    isLoading: false,
    title: title,
    currencyCode: currencyCode,
    previewedVersionId: previewedVersionId,
    forcePreviewedVersionIdValue: previewedVersionId == null,
    snapshot: snapshot,
    pageSetup: pageSetup,
    mileageRates: mileageRates,
    setIdsWithPlan: setIdsWithPlan,
    forceSelectedPersonIdValue: true,
    forceSelectedRoleIdValue: true,
    forceSelectedLocationIdValue: true,
    forceSelectedElementIdValue: true,
    forcePendingRevealRequestValue: true,
    leftDockFraction: leftDockFraction,
    rightDockFraction: rightDockFraction,
    selectionEpoch: selectionEpoch + 1,
    selectionCause: OcptResourcesSelectionCause.load,
  );

  /// Copies this state with [tab] active, for a reveal request.
  OcptResourcesState copyWithRevealedTab({required OcptResourcesTab tab}) =>
      copyWith(activeTab: tab);

  /// Copies this state with the person [personId] selected, for a reveal request.
  OcptResourcesState copyWithRevealedPerson({required String personId}) =>
      copyWith(selectedPersonId: personId);

  /// Copies this state with the role [roleId] selected, for a reveal request.
  OcptResourcesState copyWithRevealedRole({required String roleId}) =>
      copyWith(selectedRoleId: roleId);

  /// Copies this state with the location [locationId] selected, for a reveal request.
  OcptResourcesState copyWithRevealedLocation({required String locationId}) =>
      copyWith(selectedLocationId: locationId);

  /// Copies this state with the element [elementId] selected, for a reveal request.
  OcptResourcesState copyWithRevealedElement({required String elementId}) =>
      copyWith(selectedElementId: elementId);

  /// Copies this state with [tab] active.
  ///
  /// Landing on another tab than the current one, unless [isSameTab], clears the four selections
  /// and the search query, and moves the selection with the cause
  /// [OcptResourcesSelectionCause.tab].
  OcptResourcesState copyWithSelectedTab({
    required OcptResourcesTab tab,
    required bool isSameTab,
  }) => copyWith(
    activeTab: tab,
    forceSelectedPersonIdValue: !isSameTab,
    forceSelectedRoleIdValue: !isSameTab,
    forceSelectedLocationIdValue: !isSameTab,
    forceSelectedElementIdValue: !isSameTab,
    searchQuery: isSameTab ? null : "",
    selectionEpoch: isSameTab ? null : selectionEpoch + 1,
    selectionCause: isSameTab ? null : OcptResourcesSelectionCause.tab,
  );

  /// Copies this state with the person [personId] selected.
  OcptResourcesState copyWithSelectedPerson({required String personId}) => copyWith(
    selectedPersonId: personId,
    selectionEpoch: selectionEpoch + 1,
    selectionCause: OcptResourcesSelectionCause.person,
  );

  /// Copies this state with the role [roleId] selected, on the roles tab.
  ///
  /// The search query is cleared unless [isAlreadyOnRolesTab].
  OcptResourcesState copyWithSelectedRole({
    required String roleId,
    required bool isAlreadyOnRolesTab,
  }) => copyWith(
    selectedRoleId: roleId,
    activeTab: OcptResourcesTab.roles,
    searchQuery: isAlreadyOnRolesTab ? null : "",
    selectionEpoch: selectionEpoch + 1,
    selectionCause: OcptResourcesSelectionCause.role,
  );

  /// Copies this state with the location [locationId] selected.
  OcptResourcesState copyWithSelectedLocation({required String locationId}) => copyWith(
    selectedLocationId: locationId,
    selectionEpoch: selectionEpoch + 1,
    selectionCause: OcptResourcesSelectionCause.location,
  );

  /// Copies this state with the element [elementId] selected.
  OcptResourcesState copyWithSelectedElement({required String elementId}) => copyWith(
    selectedElementId: elementId,
    selectionEpoch: selectionEpoch + 1,
    selectionCause: OcptResourcesSelectionCause.element,
  );

  /// Copies this state with the sheet of the person [personId] open on the people tab, and the
  /// other selections cleared.
  OcptResourcesState copyWithOpenedPersonSheet({required String personId}) => copyWith(
    activeTab: OcptResourcesTab.people,
    selectedPersonId: personId,
    forceSelectedRoleIdValue: true,
    forceSelectedLocationIdValue: true,
    forceSelectedElementIdValue: true,
    selectionEpoch: selectionEpoch + 1,
    selectionCause: OcptResourcesSelectionCause.personSheetOpened,
  );

  /// Copies this state with the sheet of the role [roleId] open on the roles tab, and the other
  /// selections cleared.
  OcptResourcesState copyWithOpenedRoleSheet({required String roleId}) => copyWith(
    activeTab: OcptResourcesTab.roles,
    selectedRoleId: roleId,
    forceSelectedPersonIdValue: true,
    forceSelectedLocationIdValue: true,
    forceSelectedElementIdValue: true,
    selectionEpoch: selectionEpoch + 1,
    selectionCause: OcptResourcesSelectionCause.roleSheetOpened,
  );

  /// Copies this state with the record [recordId] of [tab] selected, as the record was just
  /// created.
  OcptResourcesState copyWithCreatedRecord({
    required OcptResourcesTab tab,
    required String recordId,
  }) =>
      switch (tab) {
        OcptResourcesTab.people => copyWith(selectedPersonId: recordId),
        OcptResourcesTab.roles => copyWith(selectedRoleId: recordId),
        OcptResourcesTab.locations => copyWith(selectedLocationId: recordId),
        OcptResourcesTab.elements => copyWith(selectedElementId: recordId),
      }.copyWith(
        selectionEpoch: selectionEpoch + 1,
        selectionCause: OcptResourcesSelectionCause.created,
      );

  /// Copies this state with the selection of [tab] cleared, as its selected record was dropped.
  OcptResourcesState copyWithDroppedRecord({required OcptResourcesTab tab}) => copyWith(
    forceSelectedPersonIdValue: tab == OcptResourcesTab.people,
    forceSelectedRoleIdValue: tab == OcptResourcesTab.roles,
    forceSelectedLocationIdValue: tab == OcptResourcesTab.locations,
    forceSelectedElementIdValue: tab == OcptResourcesTab.elements,
    selectionEpoch: selectionEpoch + 1,
    selectionCause: OcptResourcesSelectionCause.dropped,
  );

  /// Copies this state with a request to reveal [reveal] in the shot list pending.
  OcptResourcesState copyWithShotListReveal({
    required ({String episodeId, String sceneId, String setId}) reveal,
  }) => copyWith(pendingShotListReveal: reveal);

  /// Copies this state with the pending shot list reveal dismissed.
  OcptResourcesState copyWithShotListRevealDismissed() =>
      copyWith(forcePendingShotListRevealValue: true);

  /// Copies this state with the list panel hidden when it was shown, and shown when it was hidden.
  OcptResourcesState copyWithToggledListPanel() =>
      copyWith(isListPanelVisible: !isListPanelVisible);

  /// Copies this state with the search bar toggled.
  ///
  /// Opening it shows the list panel, and closing it clears the search query.
  OcptResourcesState copyWithToggledSearch() {
    final isOpening = !isSearchVisible;
    return copyWith(
      isSearchVisible: isOpening,
      isListPanelVisible: isOpening ? true : null,
      searchQuery: isOpening ? null : "",
    );
  }

  /// Copies this state with the search query [query].
  OcptResourcesState copyWithSearchQuery({required String query}) => copyWith(searchQuery: query);

  /// Copies this state with the right dock tab [tab] shown, or the dock closed when
  /// [isAlreadyActive].
  OcptResourcesState copyWithToggledRightDockTab({
    required OcptResourcesRightDockTab tab,
    required bool isAlreadyActive,
  }) =>
      copyWith(rightDockTab: isAlreadyActive ? null : tab, forceRightDockTabValue: isAlreadyActive);

  /// Copies this state with the versions tab of the right dock shown.
  OcptResourcesState copyWithVersionsDockOpened() =>
      copyWith(rightDockTab: OcptResourcesRightDockTab.versions);

  /// Copies this state with the right dock closed.
  OcptResourcesState copyWithRightDockClosed() => copyWith(forceRightDockTabValue: true);

  /// Copies this state with the dock fractions [left] and [right], each one kept when null.
  OcptResourcesState copyWithDockFractions({required double? left, required double? right}) =>
      copyWith(leftDockFraction: left, rightDockFraction: right);
}
