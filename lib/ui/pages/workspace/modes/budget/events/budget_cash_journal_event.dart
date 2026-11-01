// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/models/ocpt_budget_commitment_form_fields.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry_form_fields.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/events/budget_base_event.dart';

/// The events of the budget mode about the cash journal: entries and commitments.
sealed class OcptBudgetCashJournalEvent extends OcptBudgetEvent {
  /// Class constructor
  const OcptBudgetCashJournalEvent();
}

/// Creates a new cash-journal entry from [fields], dispatched by the mode once
/// `OcptBudgetEntryDialog` returned a result for a fresh entry — mirrors
/// `OcptBudgetLineCreatedEvent`'s own "written the moment it is dispatched" reading: none of this
/// dialog's fields is typing, so none of them rides the field-edit debounce.
class OcptBudgetEntryCreationConfirmedEvent extends OcptBudgetCashJournalEvent {
  /// Every field the dialog collected.
  final OcptBudgetEntryFormFields fields;

  /// Class constructor
  const OcptBudgetEntryCreationConfirmedEvent({required this.fields});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, fields];
}

/// Writes [fields] onto entry [entryId], dispatched by the mode once `OcptBudgetEntryDialog`
/// returned a result for an existing entry it was opened to edit.
class OcptBudgetEntryUpdateConfirmedEvent extends OcptBudgetCashJournalEvent {
  /// The id of the entry being edited.
  final String entryId;

  /// Every field the dialog collected.
  final OcptBudgetEntryFormFields fields;

  /// Class constructor
  const OcptBudgetEntryUpdateConfirmedEvent({required this.entryId, required this.fields});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, entryId, fields];
}

/// Deletes cash-journal entry [entryId] for good, dispatched by the mode once its own
/// `OcptConfirmDialog` has already been answered — mirrors `OcptBudgetLineDeletionConfirmedEvent`.
class OcptBudgetEntryDeletionConfirmedEvent extends OcptBudgetCashJournalEvent {
  /// The id of the entry to delete.
  final String entryId;

  /// Class constructor
  const OcptBudgetEntryDeletionConfirmedEvent({required this.entryId});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, entryId];
}

/// Creates a new commitment from [fields], dispatched by the mode once
/// `OcptBudgetCommitmentDialog` returned a result for a fresh commitment — mirrors
/// `OcptBudgetEntryCreationConfirmedEvent`'s own "written the moment it is dispatched" reading.
class OcptBudgetCommitmentCreationConfirmedEvent extends OcptBudgetCashJournalEvent {
  /// Every field the dialog collected.
  final OcptBudgetCommitmentFormFields fields;

  /// The quote line this commitment was promoted from, or null when it was typed from scratch —
  /// the ordinary case, and the only one the `+ Commitment` button produces.
  ///
  /// **Not part of [fields], and deliberately.** The dialog collects what a user typed; this is
  /// where the movement came from, which the dialog neither knows nor asks about. Keeping it out
  /// also keeps the dialog usable, unchanged, for a commitment that has no line behind it.
  final String? lineId;

  /// Class constructor
  const OcptBudgetCommitmentCreationConfirmedEvent({required this.fields, this.lineId});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, fields, lineId];
}

/// Writes [fields] onto commitment [commitmentId], dispatched by the mode once
/// `OcptBudgetCommitmentDialog` returned a result for an existing commitment it was opened to edit.
/// [fields]' own `posteId` is never sent on: `OcptBudgetJournalService.updateCommitment` carries no
/// such parameter, a commitment's own poste being fixed the moment it is created
/// (`OcptBudgetCommitmentFormFields.posteId`'s own doc comment).
class OcptBudgetCommitmentUpdateConfirmedEvent extends OcptBudgetCashJournalEvent {
  /// The id of the commitment being edited.
  final String commitmentId;

  /// Every field the dialog collected.
  final OcptBudgetCommitmentFormFields fields;

  /// Class constructor
  const OcptBudgetCommitmentUpdateConfirmedEvent({
    required this.commitmentId,
    required this.fields,
  });

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, commitmentId, fields];
}

/// Deletes commitment [commitmentId] for good, dispatched by the mode once its own
/// `OcptConfirmDialog` has already been answered — mirrors
/// `OcptBudgetEntryDeletionConfirmedEvent`.
class OcptBudgetCommitmentDeletionConfirmedEvent extends OcptBudgetCashJournalEvent {
  /// The id of the commitment to delete.
  final String commitmentId;

  /// Class constructor
  const OcptBudgetCommitmentDeletionConfirmedEvent({required this.commitmentId});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, commitmentId];
}

/// Records commitment [commitmentId]'s own payment, dispatched by the mode once
/// `OcptBudgetEntryDialog` returned a result for the fresh entry it was opened pre-filled with,
/// from its row's own `Settle` action. The bloc creates the journal entry [fields] describes,
/// naming [commitmentId] on it, in the one handler this event reaches, then reloads once — one
/// dispatched event, one write.
class OcptBudgetCommitmentSettlementConfirmedEvent extends OcptBudgetCashJournalEvent {
  /// The id of the commitment being settled.
  final String commitmentId;

  /// Every field the entry dialog collected for the payment itself.
  final OcptBudgetEntryFormFields fields;

  /// Class constructor
  const OcptBudgetCommitmentSettlementConfirmedEvent({
    required this.commitmentId,
    required this.fields,
  });

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, commitmentId, fields];
}

/// Promotes off-line debit entry [entryId] into the quote it never went through — the banner's own
/// `Add to the quote` action, dispatched on an entry that names a poste but no commitment (a till
/// receipt for something the quote never anticipated). The bloc creates a quote line from the entry
/// first (`OcptBudgetQuoteService.createLine`, the entry's own label, quantity `1.0`, unit price
/// and tax basis), then a commitment from that line exactly as `OcptBudgetLinePaidDirectlyEvent`
/// does (`OcptBudgetJournalService.createCommitment`, seeded from the line, naming it through
/// `lineId`), and finally **re-points [entryId] at that fresh commitment**
/// (`OcptBudgetJournalService.updateEntry`, `commitmentId` alone) rather than minting a second
/// entry — the entry already exists, so the debit that settles the commitment is the very one this
/// event promotes. Skipping the relink would leave the commitment unsettled, adding to the poste's
/// committed total on top of what is already paid: the exact double-count this whole mode refuses
/// everywhere else.
class OcptBudgetEntryPromotedToQuoteEvent extends OcptBudgetCashJournalEvent {
  /// The id of the off-line debit entry to promote.
  final String entryId;

  /// Class constructor
  const OcptBudgetEntryPromotedToQuoteEvent({required this.entryId});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, entryId];
}

/// Detaches off-line debit entry [entryId] from its poste — the banner's own `Move off-quote`
/// action, dispatched on the very same kind of entry [OcptBudgetEntryPromotedToQuoteEvent]
/// promotes, the other way to reconcile it: rather than folding the spend into the quote, this
/// admits it was never quoted at all. Clears `posteId` back to null
/// (`OcptBudgetJournalService.updateEntry`) and nothing else, so the entry becomes an honest
/// off-quote spend, read by `ocptBudgetOffQuotePaidTotalOf` like any other
/// (`docs/architecture/budget.md`'s "Off-quote spending is named, never hidden").
class OcptBudgetEntryMovedOffQuoteEvent extends OcptBudgetCashJournalEvent {
  /// The id of the off-line debit entry to detach from its poste.
  final String entryId;

  /// Class constructor
  const OcptBudgetEntryMovedOffQuoteEvent({required this.entryId});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, entryId];
}

/// Promotes off-line commitment [commitmentId] into the quote — the fiche's own banner and its
/// `Add to the quote` action, offered on a commitment that names a poste but no quote line
/// (`ocptBudgetCommitmentIsOffLine`). This is `OcptBudgetLinePaidDirectlyEvent` run the other way
/// round: the bloc creates a quote line from the commitment (`OcptBudgetQuoteService.createLine`,
/// the commitment's own label, quantity `1.0`, its amount and tax basis), then **re-points the
/// commitment at that fresh line** (`OcptBudgetJournalService.updateCommitment`, `lineId` alone).
/// The entry that settles the commitment is untouched — it already names the commitment, so the
/// chain simply gains the quote line it lacked, and the poste's quote grows by the amount that made
/// it overrun. A commitment always names a poste, so there is no "move off-quote" counterpart, the
/// way an off-line debit has one.
class OcptBudgetCommitmentPromotedToQuoteEvent extends OcptBudgetCashJournalEvent {
  /// The id of the off-line commitment to promote.
  final String commitmentId;

  /// Class constructor
  const OcptBudgetCommitmentPromotedToQuoteEvent({required this.commitmentId});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, commitmentId];
}

/// Undoes commitment [commitmentId]'s own settlement, dispatched by its row's own `Undo settlement`
/// action — clears `commitmentId` back to null on **every** live entry naming it, each entry itself
/// left untouched otherwise. `Undo settlement`'s own label promises the commitment is not paid, and
/// a commitment can be paid in several instalments (`OcptBudgetEntryFormFields.commitmentId`'s own
/// doc comment), so leaving some of them still attached would contradict that promise. **The
/// journal entries it named are never touched otherwise**: each is a movement that either happened
/// or did not, and the journal is where one is deleted, if it should be — this event only forgets
/// the link, not the payment. This event unlinks all of them at once, not one instalment among
/// several.
class OcptBudgetCommitmentUnsettleRequestedEvent extends OcptBudgetCashJournalEvent {
  /// The id of the commitment to unsettle.
  final String commitmentId;

  /// Class constructor
  const OcptBudgetCommitmentUnsettleRequestedEvent({required this.commitmentId});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, commitmentId];
}
