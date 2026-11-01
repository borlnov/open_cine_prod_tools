// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/models/ocpt_budget_allowance_form_fields.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_resource_form_fields.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_provision_entry.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/events/budget_base_event.dart';

/// The events of the budget mode about the financing plan and the régie: resources, defrayals and provisioning.
sealed class OcptBudgetFinancingEvent extends OcptBudgetEvent {
  /// Class constructor
  const OcptBudgetFinancingEvent();
}

/// Creates a new defrayal from [fields], dispatched by the mode once `OcptBudgetAllowanceDialog`
/// returned a result for a fresh one — mirrors `OcptBudgetResourceCreationConfirmedEvent`.
class OcptBudgetAllowanceCreationConfirmedEvent extends OcptBudgetFinancingEvent {
  /// Every field the dialog collected.
  final OcptBudgetAllowanceFormFields fields;

  /// Class constructor
  const OcptBudgetAllowanceCreationConfirmedEvent({required this.fields});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, fields];
}

/// Writes [fields] onto defrayal [allowanceId], dispatched by the mode once
/// `OcptBudgetAllowanceDialog` returned a result for an existing one it was opened to edit.
class OcptBudgetAllowanceUpdateConfirmedEvent extends OcptBudgetFinancingEvent {
  /// The id of the defrayal being edited.
  final String allowanceId;

  /// Every field the dialog collected.
  final OcptBudgetAllowanceFormFields fields;

  /// Class constructor
  const OcptBudgetAllowanceUpdateConfirmedEvent({required this.allowanceId, required this.fields});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, allowanceId, fields];
}

/// Deletes defrayal [allowanceId] for good, dispatched by the mode once its own `OcptConfirmDialog`
/// has already been answered.
class OcptBudgetAllowanceDeletionConfirmedEvent extends OcptBudgetFinancingEvent {
  /// The id of the defrayal to delete.
  final String allowanceId;

  /// Class constructor
  const OcptBudgetAllowanceDeletionConfirmedEvent({required this.allowanceId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, allowanceId];
}

/// Carries out [entries] against poste [posteId], dispatched by the mode once its own
/// `OcptConfirmDialog` has put the plan's own counts in front of the user and they agreed.
///
/// **The plan travels with the event rather than being recomputed here**, and deliberately: it is
/// what the user was shown and said yes to, and a plan recomputed after the fact could differ from
/// the one they agreed to. Its wordings are resolved by the mode, no bloc of this app ever seeing a
/// `Tr`.
class OcptBudgetProvisionConfirmedEvent extends OcptBudgetFinancingEvent {
  /// The poste the lines are written onto.
  final String posteId;

  /// Everything the provisioning would do, exactly as the user was shown it.
  final List<OcptBudgetProvisionEntry> entries;

  /// Class constructor
  const OcptBudgetProvisionConfirmedEvent({required this.posteId, required this.entries});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, posteId, entries];
}

/// Creates a new financing resource from [fields], dispatched by the mode once
/// `OcptBudgetResourceDialog` returned a result for a fresh resource — mirrors
/// `OcptBudgetCommitmentCreationConfirmedEvent`'s own "written the moment it is dispatched"
/// reading.
class OcptBudgetResourceCreationConfirmedEvent extends OcptBudgetFinancingEvent {
  /// Every field the dialog collected.
  final OcptBudgetResourceFormFields fields;

  /// Class constructor
  const OcptBudgetResourceCreationConfirmedEvent({required this.fields});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, fields];
}

/// Writes [fields] onto resource [resourceId], dispatched by the mode once
/// `OcptBudgetResourceDialog` returned a result for an existing resource it was opened to edit.
class OcptBudgetResourceUpdateConfirmedEvent extends OcptBudgetFinancingEvent {
  /// The id of the resource being edited.
  final String resourceId;

  /// Every field the dialog collected.
  final OcptBudgetResourceFormFields fields;

  /// Class constructor
  const OcptBudgetResourceUpdateConfirmedEvent({required this.resourceId, required this.fields});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, resourceId, fields];
}

/// Deletes financing resource [resourceId] for good, dispatched by the mode once its own
/// `OcptConfirmDialog` has already been answered — mirrors
/// `OcptBudgetCommitmentDeletionConfirmedEvent`.
class OcptBudgetResourceDeletionConfirmedEvent extends OcptBudgetFinancingEvent {
  /// The id of the resource to delete.
  final String resourceId;

  /// Class constructor
  const OcptBudgetResourceDeletionConfirmedEvent({required this.resourceId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, resourceId];
}
