// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/types/ocpt_budget_entry_link_kind.dart';

/// The six answers step 1 of the entry wizard asks — **in production language, never in
/// accounting terms**, the mockup's own wording being the specification this type carries no copy
/// of (`lib/types/` stays pure: no `Tr`, no formatted string, the wizard resolves every word).
///
/// Every value but [other] fixes the movement's own direction and names exactly one of the mode's
/// four ledgers to attach to — [ocptBudgetEntryNatureDirectionOf] and
/// [ocptBudgetEntryNatureLinkKindOf] answer both, so three separate widgets never each switch over
/// this enum their own way.
///
/// **[other] is the one nature that still asks the direction**, in step 2, and Benoit ruled it so
/// deliberately: agios go out, a regularisation or a bank correction can come in, and the mockup
/// states a direction for each of the four other answers and states none for this one. A credit
/// naming neither a financing resource nor a taking would otherwise have no nature at all to be
/// typed under — and that is precisely the movement the cash-flow page exists to hold, the one that
/// is drawn in no other view of the mode.
enum OcptBudgetEntryNature {
  /// `J'ai payé quelque chose` — a debit, attached to a quote poste (left unanswered, `Hors
  /// devis`), and the one nature the wizard is also opened onto pre-filled from a commitment's own
  /// `Settle` gesture.
  expense,

  /// `J'ai reçu un financement` — a credit, attached to a financing resource.
  financing,

  /// `Le film a rapporté de l'argent` — a credit, attached to a taking.
  revenue,

  /// `J'ai versé sa part à quelqu'un` — a debit, attached to a revenue-sharing participant.
  payout,

  /// `J'ai remboursé un apport` — a debit, attached to a financing resource, and the mirror image
  /// of [financing] rather than a variant of it: the same row of the financing plan, the money
  /// going the other way.
  ///
  /// **This is the one answer the mockup does not draw, and it is here because the app already has
  /// the gesture.** The sharing page's own `Repaying the contributions` card offers to repay a
  /// contributor, which writes exactly this movement; without a nature of its own it was recalled
  /// as [financing] — `J'ai reçu un financement` printed over money leaving the account. A link
  /// alone cannot tell the two apart, which is why [ocptBudgetEntryNatureOfLinks] reads the
  /// direction as well.
  repayment,

  /// `Autre mouvement` — agios, an internal transfer, a regularisation. Attached to an *optional*
  /// poste (also `Hors devis` while unanswered), and the one nature whose direction is still asked,
  /// in step 2, rather than fixed by the answer itself — see the class doc comment.
  other,
}

/// Which direction [nature] fixes the movement to: `true` for a debit (money leaving the
/// account), `false` for a credit, or `null` while [nature] leaves the direction to be asked —
/// [OcptBudgetEntryNature.other] alone, in step 2 of the wizard.
///
/// The four other natures carry no direction control of any kind in the wizard: not disabled,
/// **absent** — this is the one answer that decides whether step 2 draws one at all.
bool? ocptBudgetEntryNatureDirectionOf(OcptBudgetEntryNature nature) => switch (nature) {
  OcptBudgetEntryNature.expense => true,
  OcptBudgetEntryNature.payout => true,
  OcptBudgetEntryNature.repayment => true,
  OcptBudgetEntryNature.financing => false,
  OcptBudgetEntryNature.revenue => false,
  OcptBudgetEntryNature.other => null,
};

/// Which single field step 2 of the wizard asks for under [nature] — the one link every other
/// nature's own field is silent about, per the class doc comment.
///
/// [OcptBudgetEntryNature.other] answers [OcptBudgetEntryLinkKind.poste] too: its own poste is
/// optional, exactly as [OcptBudgetEntryNature.expense]'s is, the two natures sharing the very
/// same field for the very same reason — an entry naming no poste at all still has to land
/// somewhere a reader can see, which is what `Hors devis` is for.
OcptBudgetEntryLinkKind ocptBudgetEntryNatureLinkKindOf(OcptBudgetEntryNature nature) =>
    switch (nature) {
      OcptBudgetEntryNature.expense => OcptBudgetEntryLinkKind.poste,
      OcptBudgetEntryNature.financing => OcptBudgetEntryLinkKind.financingResource,
      OcptBudgetEntryNature.revenue => OcptBudgetEntryLinkKind.taking,
      OcptBudgetEntryNature.payout => OcptBudgetEntryLinkKind.participant,
      OcptBudgetEntryNature.repayment => OcptBudgetEntryLinkKind.financingResource,
      OcptBudgetEntryNature.other => OcptBudgetEntryLinkKind.poste,
    };

/// The nature implied by which of the four link fields an entry names, [isDebit] telling the two
/// resource-linked answers apart.
///
/// **A link alone is not enough, and that is the whole reason this takes [isDebit].** A financing
/// resource is named by money coming in ([OcptBudgetEntryNature.financing]) and by money going back
/// out ([OcptBudgetEntryNature.repayment]) alike; reading the link on its own recalled a repayment
/// as a receipt. No other pair is ambiguous — a poste, a taking and a share each admit one
/// direction only — so the direction is consulted for that one field and no other.
///
/// An entry naming none of the four is [OcptBudgetEntryNature.other], exactly the answer built for
/// that case. An entry never attaches to more than one of the four, so the order below only matters
/// defensively.
OcptBudgetEntryNature ocptBudgetEntryNatureOfLinks({
  required bool isDebit,
  required String? posteId,
  required String? resourceId,
  required String? revenueId,
  required String? shareId,
}) {
  if (resourceId != null) {
    return isDebit ? OcptBudgetEntryNature.repayment : OcptBudgetEntryNature.financing;
  }
  if (revenueId != null) {
    return OcptBudgetEntryNature.revenue;
  }
  if (shareId != null) {
    return OcptBudgetEntryNature.payout;
  }
  if (posteId != null) {
    return OcptBudgetEntryNature.expense;
  }

  return OcptBudgetEntryNature.other;
}
