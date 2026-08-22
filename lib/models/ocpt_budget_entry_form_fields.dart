// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';

/// What `OcptBudgetEntryDialog` collected, handed back to the mode that opened it — one shape for
/// both creating and editing a `budget_entries` movement, the decision taken for this milestone
/// (`docs/architecture/budget.md`).
///
/// [isDebit] is the one field with no direct column mirror: the dialog shows a single [amountCents]
/// and a single direction choice rather than the entry's own two separate `debitCents`/`creditCents`
/// columns, so the mode reading this back writes [amountCents] onto whichever of the two [isDebit]
/// names and zero onto the other.
class OcptBudgetEntryFormFields extends Equatable {
  /// The date this movement is recorded under.
  final DateTime date;

  /// This entry's free-text wording, trimmed — the dialog's own only required field.
  final String label;

  /// The poste this entry is priced against, or null meaning "no poste" — a real state an entry may
  /// carry on purpose (`OcptBudgetEntry.posteId`'s own doc comment), not an unfinished pick.
  final String? posteId;

  /// The financing resource this entry settles, or null meaning "no resource" — the normal case,
  /// read exactly the way [posteId]'s own null is.
  final String? resourceId;

  /// The taking this entry is the actual cash for, or null meaning "no taking" — the normal case,
  /// read exactly the way [resourceId]'s own null is. Set by the sharing view's own `Record a
  /// receipt` gesture, which pre-fills this dialog with the revenue already named, exactly as
  /// `OcptBudgetFinancing`'s own receipt gesture pre-fills [resourceId].
  final String? revenueId;

  /// The participant this entry actually pays, or null meaning "no participant" — mirrors
  /// [revenueId], set instead by the sharing view's own `Record a payout` gesture.
  final String? shareId;

  /// Whether [amountCents] left the account (`true`) or came into it (`false`).
  final bool isDebit;

  /// The amount typed, in cents, exactly as typed — never negative, the direction living in
  /// [isDebit] rather than in this figure's own sign.
  final int amountCents;

  /// Whether [amountCents] already includes tax.
  final bool isTaxInclusive;

  /// The VAT rate this entry's figures carry, in basis points, or null.
  ///
  /// **Null means "inherit the project's own rate", whether the field was left empty or typed
  /// something that didn't parse.** Unlike the poste inspector's own per-line override — where an
  /// empty submission must not be read as "inherit", since it rides a keystroke-by-keystroke
  /// autosave a stray backspace could trigger by accident — this dialog submits a whole entry at
  /// once, on one explicit `Save` action nobody reaches without meaning to: there is no accidental
  /// keystroke this reading could be mistaken for, so the dedicated `Inherit` gesture the line card
  /// needs has no reason to exist a second time here.
  final int? vatRateBasisPoints;

  /// The accounting reference the user just typed, or null — creating a new entry offers no such
  /// field at all (`OcptBudgetJournalService.createEntry` mints one), so this is only ever set when
  /// `OcptBudgetEntryDialog` was opened to edit an existing entry.
  final String? voucherNumber;

  /// The path of a voucher file just picked through the native selector, to reference against this
  /// entry once it is written — null while nothing new was picked this dialog session, which is
  /// **not** the same fact as [isReceiptDetached].
  ///
  /// Picked by `OcptBudgetEntryDialog` itself (a plain read of a path, no data write), but only
  /// ever *written* by the bloc's own entry-writing handlers
  /// (`OcptBudgetBloc._writeEntryReceiptChange`), in the same handler that creates or updates the
  /// entry — the dialog never touches `assets` itself, exactly as it never touches
  /// `budget_entries`.
  final String? pickedReceiptPath;

  /// Whether the dialog's own `Detach` action was used on the voucher already referenced — the
  /// entry's current receipt, if it carries one, is to be dropped. **Never both this and
  /// [pickedReceiptPath] meaningful at once**: attaching a fresh file already replaces whatever was
  /// there, so a caller reads [pickedReceiptPath] first and only falls back to this flag once it is
  /// null.
  final bool isReceiptDetached;

  /// Class constructor
  const OcptBudgetEntryFormFields({
    required this.date,
    required this.label,
    required this.posteId,
    required this.resourceId,
    required this.revenueId,
    required this.shareId,
    required this.isDebit,
    required this.amountCents,
    required this.isTaxInclusive,
    required this.vatRateBasisPoints,
    required this.voucherNumber,
    required this.pickedReceiptPath,
    required this.isReceiptDetached,
  });

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptBudgetEntryFormFields(date: $date, label: $label, posteId: $posteId, "
      "isDebit: $isDebit, amountCents: $amountCents)";

  /// Object properties
  @override
  List<Object?> get props => [
    date,
    label,
    posteId,
    resourceId,
    revenueId,
    shareId,
    isDebit,
    amountCents,
    isTaxInclusive,
    vatRateBasisPoints,
    voucherNumber,
    pickedReceiptPath,
    isReceiptDetached,
  ];
}
