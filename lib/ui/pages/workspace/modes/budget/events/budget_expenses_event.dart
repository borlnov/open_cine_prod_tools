// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/models/ocpt_budget_entry_form_fields.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_line_form_fields.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_field.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/events/budget_base_event.dart';

/// The events of the budget mode about the expenses view: postes, quote lines and the fields typed
/// into them.
sealed class OcptBudgetExpensesEvent extends OcptBudgetEvent {
  /// Class constructor
  const OcptBudgetExpensesEvent();
}

/// Create a new, unnamed poste, appended at the end of the catalogue, and select it — dispatched
/// by the cost-tracking table's own `+ Poste` footer. Mirrors
/// `OcptResourcesElementCreationRequestedEvent`: a fresh record is created empty, its own sheet's
/// placeholder reading it as unnamed until somebody types into it.
class OcptBudgetPosteCreatedEvent extends OcptBudgetExpensesEvent {
  /// Class constructor
  const OcptBudgetPosteCreatedEvent();
}

/// Move poste [posteId] to [newPosition] (0-based) within the catalogue's flat order, dispatched
/// by a row's own `⋮` menu `▲`/`▼` entries.
class OcptBudgetPosteReorderedEvent extends OcptBudgetExpensesEvent {
  /// The id of the poste to reorder.
  final String posteId;

  /// The 0-based position the poste is moved to.
  final int newPosition;

  /// Class constructor
  const OcptBudgetPosteReorderedEvent({required this.posteId, required this.newPosition});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, posteId, newPosition];
}

/// Delete poste [posteId] for good, along with every quote line it holds, dispatched by the mode
/// once its `OcptConfirmDialog` has already been answered.
class OcptBudgetPosteDeletionConfirmedEvent extends OcptBudgetExpensesEvent {
  /// The id of the poste to delete.
  final String posteId;

  /// Class constructor
  const OcptBudgetPosteDeletionConfirmedEvent({required this.posteId});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, posteId];
}

/// Create a new quote line inside poste [posteId], appended at the end of its own lines, and expand
/// it — dispatched by the poste inspector's own `+ Add` action, mirroring
/// `OcptBudgetPosteCreatedEvent`'s own "created empty" idiom.
///
/// **[fields] is nullable, and null keeps this event's own original reading exactly**: an unnamed,
/// blank line, expanded for inline editing in the tree — the only shape the `+ Add` footer has ever
/// produced. Non-null seeds the line already filled, `OcptBudgetLineFormBody`'s own small form
/// being what the entry wizard's own `addQuoteLine` gesture ends on instead of that inline editor —
/// see [OcptBudgetLineFormFields]'s own doc comment for exactly what a line can be born carrying.
class OcptBudgetLineCreatedEvent extends OcptBudgetExpensesEvent {
  /// The id of the poste the new line belongs to.
  final String posteId;

  /// The line's own fields, already typed, or null for a blank line — see the class doc comment.
  final OcptBudgetLineFormFields? fields;

  /// Class constructor
  const OcptBudgetLineCreatedEvent({required this.posteId, this.fields});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, posteId, fields];
}

/// Create a new quote line inside poste [posteId] **from** breakdown element [elementId], and
/// expand it — dispatched by the capture wizard's own breakdown selector, once per row it creates,
/// mirroring `OcptBudgetLineCreatedEvent`'s own "written the moment it is dispatched" reading. See
/// `OcptBudgetBloc._onLineCreatedFromElement`'s own doc comment for what this writes onto the fresh
/// line beyond its label.
class OcptBudgetLineCreatedFromElementEvent extends OcptBudgetExpensesEvent {
  /// The id of the poste the new line belongs to.
  final String posteId;

  /// The id of the breakdown element the new line prices.
  final String elementId;

  /// The quantity the new line is born with, in thousandths, or null to leave
  /// `OcptBudgetQuoteService.createLine`'s own default in place.
  ///
  /// **Null while nothing overrides it, never a claim about what the line ought to cost.** The
  /// capture wizard's own breakdown selector is this event's only caller once the poste fiche's own
  /// `From breakdown` action is gone: it always passes the count of scenes the element appears in,
  /// corrected in the table before creating — "the scale suggests, it never decides"
  /// (`docs/architecture/budget.md`).
  final int? quantityMilli;

  /// Class constructor
  const OcptBudgetLineCreatedFromElementEvent({
    required this.posteId,
    required this.elementId,
    this.quantityMilli,
  });

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, posteId, elementId, quantityMilli];
}

/// Delete quote line [lineId] for good, dispatched by the mode once its `OcptConfirmDialog` has
/// already been answered.
class OcptBudgetLineDeletionConfirmedEvent extends OcptBudgetExpensesEvent {
  /// The id of the line to delete.
  final String lineId;

  /// Class constructor
  const OcptBudgetLineDeletionConfirmedEvent({required this.lineId});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, lineId];
}

/// Write a new including/excluding-tax basis onto line [lineId]'s own unit price immediately,
/// dispatched by its expanded card's own radio — a pick, not typing, so it never rides the
/// field-edit debounce.
class OcptBudgetLineTaxInclusiveChangedEvent extends OcptBudgetExpensesEvent {
  /// The id of the line being edited.
  final String lineId;

  /// Whether the price just picked includes tax.
  final bool isTaxInclusive;

  /// Class constructor
  const OcptBudgetLineTaxInclusiveChangedEvent({
    required this.lineId,
    required this.isTaxInclusive,
  });

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, lineId, isTaxInclusive];
}

/// Put line [lineId]'s own VAT rate back to inheriting the project's default, dispatched by its
/// expanded card's own `Inherit` action — the field's dedicated way back to null, exactly as the
/// project settings' own `No rate` button is for `defaultVatRateBasisPoints`
/// (`OcptBudgetField`'s own doc comment explains why an empty typed submission cannot mean this).
/// Written immediately, never through the field-edit debounce.
class OcptBudgetLineVatRateInheritedRequestedEvent extends OcptBudgetExpensesEvent {
  /// The id of the line being edited.
  final String lineId;

  /// Class constructor
  const OcptBudgetLineVatRateInheritedRequestedEvent({required this.lineId});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, lineId];
}

/// Put poste [posteId]'s own estimate to complete back to being derived, dispatched by the
/// inspector's own `Derive again` action — the field's dedicated way back to null, exactly as
/// [OcptBudgetLineVatRateInheritedRequestedEvent] is for a line's rate. Written immediately, never
/// through the field-edit debounce, and not an irreversible action: it puts the poste back to a
/// figure the app can recompute at any time, so it needs no `OcptConfirmDialog`.
class OcptBudgetPosteEstimateToCompleteDerivedRequestedEvent extends OcptBudgetExpensesEvent {
  /// The id of the poste being edited.
  final String posteId;

  /// Class constructor
  const OcptBudgetPosteEstimateToCompleteDerivedRequestedEvent({required this.posteId});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, posteId];
}

/// Record the raw text just typed into [field] of entity [targetId] as a pending edit, dispatched
/// on every keystroke into a poste's or a line's own free-text field — rides `OcptBudgetBloc`'s own
/// 2 s field-edit debounce.
class OcptBudgetFieldChangedEvent extends OcptBudgetExpensesEvent {
  /// The id of the poste or line being edited, according to [field].
  final String targetId;

  /// Which field is being edited.
  final OcptBudgetField field;

  /// The field's raw text, as typed.
  final String rawValue;

  /// Class constructor
  const OcptBudgetFieldChangedEvent({
    required this.targetId,
    required this.field,
    required this.rawValue,
  });

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, targetId, field, rawValue];
}

/// Fired by the field-edit debounce timer once it elapses with no further typing: writes every
/// pending field edit. Not meant to be dispatched by a widget; the bloc dispatches it itself.
class OcptBudgetFieldEditFlushRequestedEvent extends OcptBudgetExpensesEvent {
  /// Class constructor
  const OcptBudgetFieldEditFlushRequestedEvent();
}

/// Pay quote line [lineId] directly, promoting it into a commitment in the same gesture — the
/// line's own `Pay` action, for the common case where a production quotes a cost and then pay it
/// without ever thinking of the commitment in between. The bloc creates the commitment from the
/// line first (`OcptBudgetJournalService.createCommitment`, seeded from the line as
/// `OcptBudgetCommitmentCreationConfirmedEvent` would), then records [fields] as a debit naming it
/// (`OcptBudgetCommitmentSettlementConfirmedEvent`'s own reading): the engagement is real in the
/// data — it is what carries the outstanding and the
/// matching — but transparent to the reader, who only ever quoted and paid. A partial payment
/// leaves the commitment standing with its own outstanding, exactly as one against a commitment
/// made by hand.
class OcptBudgetLinePaidDirectlyEvent extends OcptBudgetExpensesEvent {
  /// The id of the quote line being paid, and promoted into a commitment as it is.
  final String lineId;

  /// Every field the capture wizard collected for the payment itself.
  final OcptBudgetEntryFormFields fields;

  /// Class constructor
  const OcptBudgetLinePaidDirectlyEvent({required this.lineId, required this.fields});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, lineId, fields];
}
