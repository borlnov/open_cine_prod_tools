// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';

/// What is currently selected for the right dock's own fiche — `OcptBudgetFiche`, the one panel
/// that shows an object's breadcrumb, stepper, figures and outstanding amount, whichever of the
/// mode's several kinds of row it is standing on.
///
/// **One fact, not several id fields.** The poste tree's own selection and the financing view's
/// own highlight used to be two independent ids; a fiche able to show any object can only ever be
/// looking at one of them at a time. `OcptBudgetState.selectedRevenueId` folds onto
/// [OcptBudgetRevenueSelection] — a plain getter now, read by the sharing view exactly as before —
/// while `.selectedShareId` stays its own field: a share opens no fiche in any document this
/// milestone reaches, so it has nothing to fold onto yet.
///
/// Every variant carries only the id it names — mirroring the `state` holding the actual objects,
/// exactly as `OcptBudgetState.selectedPosteId` never carried an `OcptBudgetPoste` of its own.
sealed class OcptBudgetSelection extends Equatable {
  /// Class constructor
  const OcptBudgetSelection();
}

/// A selected poste — the cost-tracking table's own row, or a poste opened from elsewhere in the
/// mode.
final class OcptBudgetPosteSelection extends OcptBudgetSelection {
  /// The id of the selected poste.
  final String posteId;

  /// Class constructor
  const OcptBudgetPosteSelection(this.posteId);

  /// Object properties
  @override
  List<Object?> get props => [posteId];
}

/// A selected quote line — the row the fiche reads its own editable fields off, in the expenses
/// tree or under the poste it belongs to.
final class OcptBudgetLineSelection extends OcptBudgetSelection {
  /// The id of the selected quote line.
  final String lineId;

  /// Class constructor
  const OcptBudgetLineSelection(this.lineId);

  /// Object properties
  @override
  List<Object?> get props => [lineId];
}

/// A selected commitment — a row of the committed spending.
final class OcptBudgetCommitmentSelection extends OcptBudgetSelection {
  /// The id of the selected commitment.
  final String commitmentId;

  /// Class constructor
  const OcptBudgetCommitmentSelection(this.commitmentId);

  /// Object properties
  @override
  List<Object?> get props => [commitmentId];
}

/// A selected journal entry — a row of the cash journal, or a receipt nested under the resource or
/// commitment it settles.
final class OcptBudgetEntrySelection extends OcptBudgetSelection {
  /// The id of the selected entry.
  final String entryId;

  /// Class constructor
  const OcptBudgetEntrySelection(this.entryId);

  /// Object properties
  @override
  List<Object?> get props => [entryId];
}

/// A selected financing resource — the financing plan's own row, previously
/// `OcptBudgetState.selectedResourceId`.
final class OcptBudgetResourceSelection extends OcptBudgetSelection {
  /// The id of the selected resource.
  final String resourceId;

  /// Class constructor
  const OcptBudgetResourceSelection(this.resourceId);

  /// Object properties
  @override
  List<Object?> get props => [resourceId];
}

/// A selected taking — the revenue sharing view's own left-column row.
final class OcptBudgetRevenueSelection extends OcptBudgetSelection {
  /// The id of the selected taking.
  final String revenueId;

  /// Class constructor
  const OcptBudgetRevenueSelection(this.revenueId);

  /// Object properties
  @override
  List<Object?> get props => [revenueId];
}

/// A selected receipt — a journal entry read as the sub-row it settles, nested under the resource
/// or the commitment that names it. Answered by the fiche already; nothing dispatches it until the
/// resources tree draws its own receipt sub-rows.
final class OcptBudgetReceiptSelection extends OcptBudgetSelection {
  /// The id of the selected receipt.
  final String receiptId;

  /// Class constructor
  const OcptBudgetReceiptSelection(this.receiptId);

  /// Object properties
  @override
  List<Object?> get props => [receiptId];
}
