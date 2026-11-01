// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/models/ocpt_budget_allowance.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_regie.dart';

/// One flattened row of the defrayal tree — see
/// `OcptBudgetRegieAllowanceColumn._rowsOf`'s own doc comment.
sealed class OcptBudgetRegieAllowanceTreeRow {
  /// Class constructor
  const OcptBudgetRegieAllowanceTreeRow();
}

/// A person group row — the tree's own top level, carrying that person's own running account.
class OcptBudgetRegieAllowancePersonGroupRow extends OcptBudgetRegieAllowanceTreeRow {
  /// The person's own id — every sub-row under this group names it too.
  final String personId;

  /// The person this row names, or null while [personId] names nobody the address book still
  /// holds — drawn with [OcptBudgetRegie]'s own `Nobody in particular`-style fallback rather than
  /// crashing on a stale reference.
  final OcptPerson? person;

  /// What that person is on the shoot, or null.
  final OcptRole? role;

  /// What this person has advanced — `ocptBudgetPersonAdvancedCents`.
  final int advancedCents;

  /// What this person has actually been reimbursed — `ocptBudgetPersonReimbursedCentsOf`'s own
  /// `.amountCents`.
  final int reimbursedCents;

  /// What is still owed them — `ocptBudgetPersonOutstandingCents`, not clamped at zero.
  final int outstandingCents;

  /// Whether this group is currently expanded.
  final bool isExpanded;

  /// Class constructor
  const OcptBudgetRegieAllowancePersonGroupRow({
    required this.personId,
    required this.person,
    required this.role,
    required this.advancedCents,
    required this.reimbursedCents,
    required this.outstandingCents,
    required this.isExpanded,
  });
}

/// A defrayal naming nobody — its own group of one, no twisty since there is nothing to expand onto
/// and no running account to page through: a défraiement that belongs to the production rather than
/// to one person counts against the quote and this table's own total, but against nobody's own
/// `ADVANCED`/`REIMBURSED`/`OWED` — `OcptBudgetAllowancesTable`'s own doc comment.
class OcptBudgetRegieAllowanceNoPersonGroupRow extends OcptBudgetRegieAllowanceTreeRow {
  /// The defrayal this row draws.
  final OcptBudgetAllowance allowance;

  /// Class constructor
  const OcptBudgetRegieAllowanceNoPersonGroupRow({required this.allowance});
}

/// A defrayal sub-row — one step under the person it names, drawn only while their group is
/// expanded.
class OcptBudgetRegieAllowanceDefrayalSubRow extends OcptBudgetRegieAllowanceTreeRow {
  /// The defrayal this row draws.
  final OcptBudgetAllowance allowance;

  /// Class constructor
  const OcptBudgetRegieAllowanceDefrayalSubRow({required this.allowance});
}

/// A reimbursement sub-row — one step under the person it names, drawn right after that person's
/// own defrayals, only while their group is expanded.
class OcptBudgetRegieAllowanceReimbursementSubRow extends OcptBudgetRegieAllowanceTreeRow {
  /// The journal entry this row draws.
  final OcptBudgetEntry entry;

  /// Class constructor
  const OcptBudgetRegieAllowanceReimbursementSubRow({required this.entry});
}
