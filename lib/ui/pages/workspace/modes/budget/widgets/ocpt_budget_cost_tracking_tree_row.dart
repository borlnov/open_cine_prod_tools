// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/models/ocpt_budget_commitment.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_line.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cost_tracking.dart';

/// One flattened row of the expenses tree — see [OcptBudgetCostTracking._rowsOf]'s own doc
/// comment for how the list this sealed class populates is built.
sealed class OcptBudgetCostTrackingTreeRow {
  /// Class constructor
  const OcptBudgetCostTrackingTreeRow();
}

/// A poste row — the tree's own top level.
class OcptBudgetCostTrackingPosteTreeRow extends OcptBudgetCostTrackingTreeRow {
  /// The poste this row draws.
  final OcptBudgetPoste poste;

  /// Whether this poste has anything at all to expand onto.
  final bool isExpandable;

  /// Whether this poste is currently expanded.
  final bool isExpanded;

  /// Class constructor
  const OcptBudgetCostTrackingPosteTreeRow({
    required this.poste,
    required this.isExpandable,
    required this.isExpanded,
  });
}

/// A quote line row — one step under its own poste.
class OcptBudgetCostTrackingLineTreeRow extends OcptBudgetCostTrackingTreeRow {
  /// The line this row draws.
  final OcptBudgetLine line;

  /// This line's own commitments, settled or not, in the order [OcptBudgetCostTracking.commitments]
  /// gives them.
  final List<OcptBudgetCommitment> lineCommitments;

  /// Whether this line is currently expanded.
  final bool isExpanded;

  /// Whether this line has anything at all to expand onto.
  bool get isExpandable => lineCommitments.isNotEmpty;

  /// Class constructor
  const OcptBudgetCostTrackingLineTreeRow({
    required this.line,
    required this.lineCommitments,
    required this.isExpanded,
  });
}

/// A commitment row — two steps under its own poste while it names a line, one step while it does
/// not (the poste's own off-line commitments).
class OcptBudgetCostTrackingCommitmentTreeRow extends OcptBudgetCostTrackingTreeRow {
  /// The commitment this row draws.
  final OcptBudgetCommitment commitment;

  /// This row's own indentation, in steps from the poste.
  final int depth;

  /// Whether this commitment is itself an expandable node, drawing its own twisty and its payments
  /// only while it is expanded. **True only for a poste's own off-line commitment with at least one
  /// payment** — with no quote line to nest under, it owns its payments the way a line owns its
  /// commitments. A line-nested commitment is never one: its payments already show as its siblings
  /// once the line is expanded.
  final bool isExpandable;

  /// Whether this commitment is currently expanded — only ever meaningful while [isExpandable].
  final bool isExpanded;

  /// Class constructor
  const OcptBudgetCostTrackingCommitmentTreeRow({
    required this.commitment,
    required this.depth,
    this.isExpandable = false,
    this.isExpanded = false,
  });
}

/// The muted "no entry" hint drawn under an unsettled commitment, at the very same indentation as
/// that commitment — see [OcptBudgetCostTracking]'s own class doc comment.
class OcptBudgetCostTrackingCommitmentHintTreeRow extends OcptBudgetCostTrackingTreeRow {
  /// This row's own indentation, in steps from the poste — always the same as the commitment it
  /// sits under.
  final int depth;

  /// Class constructor
  const OcptBudgetCostTrackingCommitmentHintTreeRow({required this.depth});
}

/// An entry row — either the entry that settled a commitment, at that commitment's own
/// indentation, or one of the poste's own off-line entries, one step under it, or one of the
/// off-quote total's own children, also one step under it (see [OcptBudgetCostTrackingOffQuoteTreeRow]).
class OcptBudgetCostTrackingEntryTreeRow extends OcptBudgetCostTrackingTreeRow {
  /// The entry this row draws.
  final OcptBudgetEntry entry;

  /// This row's own indentation, in steps from the poste.
  final int depth;

  /// Class constructor
  const OcptBudgetCostTrackingEntryTreeRow({required this.entry, required this.depth});
}

/// The off-quote total row — the tree's own last row before `Total`, naming no poste and no line.
/// See [OcptBudgetCostTracking._rowsOf]'s own doc comment for which entries draw under it once
/// expanded.
class OcptBudgetCostTrackingOffQuoteTreeRow extends OcptBudgetCostTrackingTreeRow {
  /// Whether this row is currently expanded.
  final bool isExpanded;

  /// Class constructor
  const OcptBudgetCostTrackingOffQuoteTreeRow({required this.isExpanded});
}
