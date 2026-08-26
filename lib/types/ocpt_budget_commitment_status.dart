// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// How far a `budget_commitments` row has progressed towards being paid, the mockup's own four
/// steps ("Devis accepté / Contrat signé / Facture reçue / Déclaré").
///
/// **There is deliberately no fifth, `settled`, value.** A commitment is settled the moment the
/// journal entries naming it (`OcptBudgetEntriesTable.commitmentId`) have paid it in full
/// (`lib/utils/ocpt_budget_projection.dart`'s own `ocptBudgetCommitmentIsSettledOf`) — a status the
/// enum itself also claimed would be a second copy of the very same fact, kept in step by hand or by
/// a write nobody could guarantee never to forget, exactly the argument `OcptBudgetPostesTable`'s own
/// doc comment makes against a stored `quotedAmount`. Reading settlement off the ledger rather than
/// off a status also means a commitment can be marked `declared` and settled at once, or settled
/// without ever having been marked `declared` at all — a production that pays before its paperwork
/// catches up is not a state this enum has to pretend cannot happen.
enum OcptBudgetCommitmentStatus {
  /// A quote has been accepted for this spend, but nothing has been signed or paid yet.
  quoteAccepted,

  /// A contract has been signed for this spend.
  contractSigned,

  /// An invoice has been received for this spend, whether or not it has been paid.
  invoiceReceived,

  /// This spend has been declared to whichever authority the production owes that declaration to
  /// (a co-producer, a commission, a tax administration) — the last step of the paperwork, tracked
  /// independently of whether the money has actually moved.
  declared,
}
