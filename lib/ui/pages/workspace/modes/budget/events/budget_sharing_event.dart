// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/models/ocpt_budget_revenue_form_fields.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_share_form_fields.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/events/budget_base_event.dart';

/// The events of the budget mode about the revenue sharing: takings and shares.
sealed class OcptBudgetSharingEvent extends OcptBudgetEvent {
  /// Class constructor
  const OcptBudgetSharingEvent();
}

/// Create a new taking from [fields], dispatched by the mode once `OcptBudgetRevenueDialog`
/// returned a result for a fresh revenue — mirrors `OcptBudgetResourceCreationConfirmedEvent`'s own
/// "written the moment it is dispatched" reading.
class OcptBudgetRevenueCreationConfirmedEvent extends OcptBudgetSharingEvent {
  /// Every field the dialog collected.
  final OcptBudgetRevenueFormFields fields;

  /// Class constructor
  const OcptBudgetRevenueCreationConfirmedEvent({required this.fields});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, fields];
}

/// Write [fields] onto revenue [revenueId], dispatched by the mode once
/// `OcptBudgetRevenueDialog` returned a result for an existing revenue it was opened to edit.
class OcptBudgetRevenueUpdateConfirmedEvent extends OcptBudgetSharingEvent {
  /// The id of the revenue being edited.
  final String revenueId;

  /// Every field the dialog collected.
  final OcptBudgetRevenueFormFields fields;

  /// Class constructor
  const OcptBudgetRevenueUpdateConfirmedEvent({required this.revenueId, required this.fields});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, revenueId, fields];
}

/// Move revenue [revenueId] to [newPosition] (0-based) within the sharing view's own flat order,
/// dispatched by a row's own `⋮` menu `▲`/`▼` entries — mirrors `OcptBudgetAccountReorderedEvent`.
class OcptBudgetRevenueReorderedEvent extends OcptBudgetSharingEvent {
  /// The id of the revenue to reorder.
  final String revenueId;

  /// The 0-based position the revenue is moved to.
  final int newPosition;

  /// Class constructor
  const OcptBudgetRevenueReorderedEvent({required this.revenueId, required this.newPosition});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, revenueId, newPosition];
}

/// Delete taking [revenueId] for good, dispatched by the mode once its own `OcptConfirmDialog`
/// has already been answered — mirrors `OcptBudgetResourceDeletionConfirmedEvent`.
class OcptBudgetRevenueDeletionConfirmedEvent extends OcptBudgetSharingEvent {
  /// The id of the revenue to delete.
  final String revenueId;

  /// Class constructor
  const OcptBudgetRevenueDeletionConfirmedEvent({required this.revenueId});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, revenueId];
}

/// Create a new share from [fields], dispatched by the mode once `OcptBudgetShareDialog` returned
/// a result for a fresh share — mirrors `OcptBudgetRevenueCreationConfirmedEvent`.
class OcptBudgetShareCreationConfirmedEvent extends OcptBudgetSharingEvent {
  /// Every field the dialog collected.
  final OcptBudgetShareFormFields fields;

  /// Class constructor
  const OcptBudgetShareCreationConfirmedEvent({required this.fields});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, fields];
}

/// Write [fields] onto share [shareId], dispatched by the mode once `OcptBudgetShareDialog`
/// returned a result for an existing share it was opened to edit.
class OcptBudgetShareUpdateConfirmedEvent extends OcptBudgetSharingEvent {
  /// The id of the share being edited.
  final String shareId;

  /// Every field the dialog collected.
  final OcptBudgetShareFormFields fields;

  /// Class constructor
  const OcptBudgetShareUpdateConfirmedEvent({required this.shareId, required this.fields});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, shareId, fields];
}

/// Move share [shareId] to [newPosition] (0-based) within the sharing view's own flat order,
/// dispatched by a row's own `⋮` menu `▲`/`▼` entries — mirrors `OcptBudgetRevenueReorderedEvent`.
class OcptBudgetShareReorderedEvent extends OcptBudgetSharingEvent {
  /// The id of the share to reorder.
  final String shareId;

  /// The 0-based position the share is moved to.
  final int newPosition;

  /// Class constructor
  const OcptBudgetShareReorderedEvent({required this.shareId, required this.newPosition});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, shareId, newPosition];
}

/// Delete share [shareId] for good, dispatched by the mode once its own `OcptConfirmDialog` has
/// already been answered — mirrors `OcptBudgetRevenueDeletionConfirmedEvent`.
class OcptBudgetShareDeletionConfirmedEvent extends OcptBudgetSharingEvent {
  /// The id of the share to delete.
  final String shareId;

  /// Class constructor
  const OcptBudgetShareDeletionConfirmedEvent({required this.shareId});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, shareId];
}
