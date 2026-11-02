// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/types/ocpt_budget_gesture.dart';

/// What the wizard's own step 2 asks for under a gesture, and the reason a gesture takes two steps
/// or three: a gesture attaching to [none] has nothing to name before its own form, a gesture
/// attaching to anything else names it first.
///
/// [ocptBudgetGestureAttachmentOf] is the only way a caller asks which of these a given
/// [OcptBudgetGesture] draws step 2 for.
enum OcptBudgetGestureAttachment {
  /// Step 2 is skipped outright — the wizard goes straight from step 1 to the form.
  none,

  /// A quote account, answered — the wizard offers no `Hors devis` here, unlike [optionalAccount]:
  /// the gestures naming this attachment always price a real line of the quote.
  account,

  /// A quote account, left unanswered reading `Hors devis` exactly as the account field of the
  /// existing entry dialog already does — a real fact an entry may carry on purpose, not an
  /// unfinished pick.
  optionalAccount,

  /// A quote account and, optionally, one of its own lines — [OcptBudgetGesture.commitSpend] alone:
  /// a commitment may hang off the account directly, which the model already allows and the
  /// expenses table already draws.
  accountAndLine,

  /// A financing resource — `budget_resources`.
  financingResource,

  /// A participant in the revenue-sharing split — `budget_shares`.
  participant,

  /// A person the production owes for having advanced money on its behalf — `people`.
  person,
}
