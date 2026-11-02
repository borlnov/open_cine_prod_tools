// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/types/ocpt_budget_selection.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/events/budget_base_event.dart';

/// The events of the budget mode about moving the mode's shared selection.
sealed class OcptBudgetSelectionEvent extends OcptBudgetEvent {
  /// Class constructor
  const OcptBudgetSelectionEvent();
}

/// Select poste [posteId] — a cost-tracking row — opening the right dock on the `Inspector` tab,
/// mirroring `OcptScheduleShotSelectedEvent`'s own gesture. A [posteId] naming no live poste is
/// ignored.
class OcptBudgetPosteSelectedEvent extends OcptBudgetSelectionEvent {
  /// The id of the poste to select.
  final String posteId;

  /// Class constructor
  const OcptBudgetPosteSelectedEvent({required this.posteId});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, posteId];
}

/// Select quote line [lineId] — a sub-row of the expenses tree — dispatched by its row's own
/// click. A [lineId] naming no live line is ignored, mirroring `OcptBudgetPosteSelectedEvent`.
class OcptBudgetLineSelectedEvent extends OcptBudgetSelectionEvent {
  /// The id of the line to select.
  final String lineId;

  /// Class constructor
  const OcptBudgetLineSelectedEvent({required this.lineId});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, lineId];
}

/// Select commitment [commitmentId] — a sub-row of the expenses tree — dispatched by its row's own
/// click. Draws as a plain highlight; its own `⋮` menu is what edits, settles or deletes it. A
/// [commitmentId] naming no live commitment is ignored, mirroring `OcptBudgetPosteSelectedEvent`.
class OcptBudgetCommitmentSelectedEvent extends OcptBudgetSelectionEvent {
  /// The id of the commitment to select.
  final String commitmentId;

  /// Class constructor
  const OcptBudgetCommitmentSelectedEvent({required this.commitmentId});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, commitmentId];
}

/// Select journal entry [entryId] — a sub-row of the expenses tree, whether it settles a
/// commitment or names its own poste directly — dispatched by its row's own click. A [entryId]
/// naming no live entry is ignored, mirroring `OcptBudgetPosteSelectedEvent`.
class OcptBudgetEntrySelectedEvent extends OcptBudgetSelectionEvent {
  /// The id of the entry to select.
  final String entryId;

  /// Class constructor
  const OcptBudgetEntrySelectedEvent({required this.entryId});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, entryId];
}

/// Select receipt [receiptId] — a sub-row of the resources tree, nested under the resource or the
/// revenue the underlying `budget_entries` credit names — dispatched by its row's own click.
/// Mirrors `OcptBudgetEntrySelectedEvent`: [receiptId] is a journal entry's own id, read as a
/// receipt rather than as a debit or a credit of the expenses tree. A [receiptId] naming no live
/// entry is ignored.
class OcptBudgetReceiptSelectedEvent extends OcptBudgetSelectionEvent {
  /// The id of the entry to select, read as a receipt.
  final String receiptId;

  /// Class constructor
  const OcptBudgetReceiptSelectedEvent({required this.receiptId});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, receiptId];
}

/// Select financing resource [resourceId] — a row of the financing view — dispatched by its row's
/// own click. Draws as a plain highlight, never an inspector: see `OcptBudgetFinancing`'s own class
/// doc comment. A [resourceId] naming no live resource is ignored, mirroring
/// `OcptBudgetPosteSelectedEvent`.
class OcptBudgetResourceSelectedEvent extends OcptBudgetSelectionEvent {
  /// The id of the resource to select.
  final String resourceId;

  /// Class constructor
  const OcptBudgetResourceSelectedEvent({required this.resourceId});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, resourceId];
}

/// Select revenue sharing taking [revenueId] — a row of the tools drawer's own `Partage` page,
/// or of the resources plan's own `Takings` family — dispatched by its row's own click. Either way
/// it opens the right dock's detail panel exactly as `OcptBudgetResourceSelectedEvent` does: both
/// routes carry an inspector (`ocptBudgetViewHasInspector`), and a taking reads the same wherever
/// it is clicked from. A [revenueId] naming no live revenue is ignored.
class OcptBudgetRevenueSelectedEvent extends OcptBudgetSelectionEvent {
  /// The id of the revenue to select.
  final String revenueId;

  /// Class constructor
  const OcptBudgetRevenueSelectedEvent({required this.revenueId});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, revenueId];
}

/// Select share [shareId] — a row of the sharing view's own `Distribution` table — dispatched by
/// its row's own click. Draws as a plain highlight, never an inspector, mirroring
/// `OcptBudgetRevenueSelectedEvent`. A [shareId] naming no live share is ignored.
class OcptBudgetShareSelectedEvent extends OcptBudgetSelectionEvent {
  /// The id of the share to select.
  final String shareId;

  /// Class constructor
  const OcptBudgetShareSelectedEvent({required this.shareId});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, shareId];
}

/// Select the record a view has just created and read the snapshot again for — a poste, a quote
/// line, a financing resource or a taking — without writing what is pending: the view did so.
///
/// Dispatched through `addToModeAndWait` by the view that created the record, and handled by the
/// mode so that the view's own state is emitted after the selection has landed.
class OcptBudgetSelectionCreatedEvent extends OcptBudgetSelectionEvent {
  /// What to select.
  final OcptBudgetSelection selection;

  /// Whether the right dock opens on its `Inspector` tab: a poste and a quote line do, a resource
  /// and a taking are drawn as a plain highlight.
  final bool opensInspector;

  /// Class constructor
  const OcptBudgetSelectionCreatedEvent({required this.selection, required this.opensInspector});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, selection, opensInspector];
}

/// Highlight the revenue sharing share a view has just created and read the snapshot again for,
/// without writing what is pending — mirrors `OcptBudgetSelectionCreatedEvent`.
class OcptBudgetShareCreatedEvent extends OcptBudgetSelectionEvent {
  /// The id of the share to highlight.
  final String shareId;

  /// Class constructor
  const OcptBudgetShareCreatedEvent({required this.shareId});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, shareId];
}
