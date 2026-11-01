// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/types/ocpt_budget_right_dock_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_tax_basis.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_tools_view.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_view.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/events/budget_base_event.dart';

/// The events of the budget mode about workspace shell, docks, views, toggles and the mode's own reads.
sealed class OcptBudgetWorkspaceEvent extends OcptBudgetEvent {
  /// Class constructor
  const OcptBudgetWorkspaceEvent();
}

/// Request leaving the workspace: closes the current project and navigates back to the home page.
class OcptBudgetBackRequestedEvent extends OcptBudgetWorkspaceEvent {
  /// Class constructor
  const OcptBudgetBackRequestedEvent();
}

/// Select a tab of the right dock (the already-active tab closes the dock, any other one opens or
/// switches to it).
class OcptBudgetRightDockTabSelectedEvent extends OcptBudgetWorkspaceEvent {
  /// The tab to select.
  final OcptBudgetRightDockTab tab;

  /// Class constructor
  const OcptBudgetRightDockTabSelectedEvent({required this.tab});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, tab];
}

/// Toggle the right dock from the workspace toolbar: an open dock closes, a closed one reopens on
/// its last tab.
class OcptBudgetRightDockToggledEvent extends OcptBudgetWorkspaceEvent {
  /// Class constructor
  const OcptBudgetRightDockToggledEvent();
}

/// Close the right dock via its own × close button.
class OcptBudgetRightDockClosedEvent extends OcptBudgetWorkspaceEvent {
  /// Class constructor
  const OcptBudgetRightDockClosedEvent();
}

/// Apply and persist the right dock's new width fraction once a divider drag ends.
class OcptBudgetRightDockFractionChangedEvent extends OcptBudgetWorkspaceEvent {
  /// The right dock's new fraction of the mode's content row width.
  final double fraction;

  /// Class constructor
  const OcptBudgetRightDockFractionChangedEvent({required this.fraction});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, fraction];
}

/// Select which of the mode's views is shown, dispatched by the header's own view switch, by the
/// feed card's own catering row wherever it is drawn, and by every other gesture that used to open
/// a document, a reading or a sub-page of its own.
///
/// [clearSelection] drops the fiche's own selection as the view changes — **true only for the
/// header's own chip**, where the reader is leaving one document for another and the object they
/// had open belonged to the one they are leaving, so the Inspector greets the new view empty rather
/// than still showing a poste on the takings page. It is **false for every gesture that switches
/// the view *and* selects something in one move** (`_handleDashboardPosteOpened`,
/// `_handleLineShowCommitment` Requested), which would otherwise wipe the very selection it just
/// made, whichever order the two events happen to run in.
class OcptBudgetViewSelectedEvent extends OcptBudgetWorkspaceEvent {
  /// The view to select.
  final OcptBudgetView view;

  /// Whether to drop the fiche's own selection as the view changes — see the class doc comment.
  final bool clearSelection;

  /// Class constructor
  const OcptBudgetViewSelectedEvent({required this.view, this.clearSelection = false});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, view, clearSelection];
}

/// Select which of the tools drawer's own three pages is shown, dispatched by the header's own
/// second segmented switch — mirrors [OcptBudgetViewSelectedEvent], the two events staying
/// independent so picking one never clears the other. [clearSelection] reads exactly as it does
/// there: true only for the header's own switch, false for a gesture that also selects something.
class OcptBudgetToolsViewSelectedEvent extends OcptBudgetWorkspaceEvent {
  /// The tools page to select.
  final OcptBudgetToolsView toolsView;

  /// Whether to drop the fiche's own selection as the tools page changes — see the class doc
  /// comment.
  final bool clearSelection;

  /// Class constructor
  const OcptBudgetToolsViewSelectedEvent({required this.toolsView, this.clearSelection = false});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, toolsView, clearSelection];
}

/// Toggle the header's simplified/detailed switch. Session-only, never persisted, mirroring the
/// schedule mode's own agenda mode.
class OcptBudgetSimplifiedToggledEvent extends OcptBudgetWorkspaceEvent {
  /// The switch's new value.
  final bool isSimplified;

  /// Class constructor
  const OcptBudgetSimplifiedToggledEvent({required this.isSimplified});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, isSimplified];
}

/// Switch the header's excluding/including-tax toggle — the **display** basis alone, never
/// written anywhere (`OcptBudgetTaxBasis`'s own doc comment). Session-only, never persisted.
class OcptBudgetTaxBasisChangedEvent extends OcptBudgetWorkspaceEvent {
  /// The basis to read every amount in from now on.
  final OcptBudgetTaxBasis basis;

  /// Class constructor
  const OcptBudgetTaxBasisChangedEvent({required this.basis});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, basis];
}

/// Expand or collapse expenses-tree node [nodeId] — a poste's or a quote line's own id, whichever
/// twisty was clicked: an already-expanded node collapses, a collapsed one expands, independently
/// of every other one, so several branches of the tree can stand open together.
class OcptBudgetRowExpansionToggledEvent extends OcptBudgetWorkspaceEvent {
  /// The id of the node whose twisty was clicked.
  final String nodeId;

  /// Class constructor
  const OcptBudgetRowExpansionToggledEvent({required this.nodeId});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, nodeId];
}

/// Re-read the project's currency and default VAT rate after the project settings page changed
/// something — mirrors `OcptScheduleProjectSettingsChangedEvent` for the same reason: the settings
/// page is exactly where both are changed.
class OcptBudgetProjectSettingsChangedEvent extends OcptBudgetWorkspaceEvent {
  /// Class constructor
  const OcptBudgetProjectSettingsChangedEvent();
}

/// Narrow every view of the mode to poste [posteId], or clear the filter when it is null —
/// dispatched by the header's own poste filter, the only control that sets it.
///
/// **Not `OcptBudgetPosteSelectedEvent`'s inverse, and no longer the same field.** The filter used
/// to *be* `OcptBudgetState.selectedPosteId`, which meant clicking a row in the quote silently
/// narrowed the cash journal — a view the reader was not looking at, so they discovered it on
/// arriving there, with no obvious way back. Selecting and filtering are now two facts:
/// `OcptBudgetPosteSelectedEvent` says what the inspector reads,
/// `OcptBudgetState.filterPosteId` says what every view is narrowed to, and only a gesture
/// that says "filter" sets it.
class OcptBudgetPosteFilterSelectedEvent extends OcptBudgetWorkspaceEvent {
  /// The poste to narrow every view to, or null to go back to the whole project.
  final String? posteId;

  /// Class constructor
  const OcptBudgetPosteFilterSelectedEvent({required this.posteId});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, posteId];
}

/// Point the régie view's own provisioning at poste [posteId] — a selection, written to no
/// project and remembered for as long as the mode is open.
class OcptBudgetProvisionPosteSelectedEvent extends OcptBudgetWorkspaceEvent {
  /// The id of the poste just picked.
  final String posteId;

  /// Class constructor
  const OcptBudgetProvisionPosteSelectedEvent({required this.posteId});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, posteId];
}
