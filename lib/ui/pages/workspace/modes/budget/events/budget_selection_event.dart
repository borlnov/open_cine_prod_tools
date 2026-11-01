// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/events/budget_base_event.dart';

/// The events of the budget mode about moving the mode's shared selection.
sealed class OcptBudgetSelectionEvent extends OcptBudgetEvent {
  /// Class constructor
  const OcptBudgetSelectionEvent();
}

/// Selects poste [posteId] — a cost-tracking row — opening the right dock on the `Inspector` tab,
/// mirroring `OcptScheduleShotSelectedEvent`'s own gesture. A [posteId] naming no live poste is
/// ignored.
class OcptBudgetPosteSelectedEvent extends OcptBudgetSelectionEvent {
  /// The id of the poste to select.
  final String posteId;

  /// Class constructor
  const OcptBudgetPosteSelectedEvent({required this.posteId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, posteId];
}

/// Selects quote line [lineId] — a sub-row of the expenses tree — dispatched by its row's own
/// click. A [lineId] naming no live line is ignored, mirroring `OcptBudgetPosteSelectedEvent`.
class OcptBudgetLineSelectedEvent extends OcptBudgetSelectionEvent {
  /// The id of the line to select.
  final String lineId;

  /// Class constructor
  const OcptBudgetLineSelectedEvent({required this.lineId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, lineId];
}

/// Selects commitment [commitmentId] — a sub-row of the expenses tree — dispatched by its row's own
/// click. Draws as a plain highlight; its own `⋮` menu is what edits, settles or deletes it. A
/// [commitmentId] naming no live commitment is ignored, mirroring `OcptBudgetPosteSelectedEvent`.
class OcptBudgetCommitmentSelectedEvent extends OcptBudgetSelectionEvent {
  /// The id of the commitment to select.
  final String commitmentId;

  /// Class constructor
  const OcptBudgetCommitmentSelectedEvent({required this.commitmentId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, commitmentId];
}

/// Selects journal entry [entryId] — a sub-row of the expenses tree, whether it settles a
/// commitment or names its own poste directly — dispatched by its row's own click. A [entryId]
/// naming no live entry is ignored, mirroring `OcptBudgetPosteSelectedEvent`.
class OcptBudgetEntrySelectedEvent extends OcptBudgetSelectionEvent {
  /// The id of the entry to select.
  final String entryId;

  /// Class constructor
  const OcptBudgetEntrySelectedEvent({required this.entryId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, entryId];
}

/// Selects receipt [receiptId] — a sub-row of the resources tree, nested under the resource or the
/// revenue the underlying `budget_entries` credit names — dispatched by its row's own click.
/// Mirrors `OcptBudgetEntrySelectedEvent`: [receiptId] is a journal entry's own id, read as a
/// receipt rather than as a debit or a credit of the expenses tree. A [receiptId] naming no live
/// entry is ignored.
class OcptBudgetReceiptSelectedEvent extends OcptBudgetSelectionEvent {
  /// The id of the entry to select, read as a receipt.
  final String receiptId;

  /// Class constructor
  const OcptBudgetReceiptSelectedEvent({required this.receiptId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, receiptId];
}

/// Selects financing resource [resourceId] — a row of the financing view — dispatched by its row's
/// own click. Draws as a plain highlight, never an inspector: see `OcptBudgetFinancing`'s own class
/// doc comment. A [resourceId] naming no live resource is ignored, mirroring
/// `OcptBudgetPosteSelectedEvent`.
class OcptBudgetResourceSelectedEvent extends OcptBudgetSelectionEvent {
  /// The id of the resource to select.
  final String resourceId;

  /// Class constructor
  const OcptBudgetResourceSelectedEvent({required this.resourceId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, resourceId];
}

/// Selects revenue sharing taking [revenueId] — a row of the tools drawer's own `Partage` page,
/// or of the resources plan's own `Takings` family — dispatched by its row's own click. Either way
/// it opens the right dock's fiche exactly as `OcptBudgetResourceSelectedEvent` does: both routes
/// carry an inspector (`ocptBudgetViewHasInspector`), and a taking reads the same wherever it is
/// clicked from. A [revenueId] naming no live revenue is ignored.
class OcptBudgetRevenueSelectedEvent extends OcptBudgetSelectionEvent {
  /// The id of the revenue to select.
  final String revenueId;

  /// Class constructor
  const OcptBudgetRevenueSelectedEvent({required this.revenueId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, revenueId];
}

/// Selects share [shareId] — a row of the sharing view's own `Distribution` table — dispatched by
/// its row's own click. Draws as a plain highlight, never an inspector, mirroring
/// `OcptBudgetRevenueSelectedEvent`. A [shareId] naming no live share is ignored.
class OcptBudgetShareSelectedEvent extends OcptBudgetSelectionEvent {
  /// The id of the share to select.
  final String shareId;

  /// Class constructor
  const OcptBudgetShareSelectedEvent({required this.shareId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, shareId];
}
