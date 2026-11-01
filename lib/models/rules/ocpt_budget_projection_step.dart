// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_projection.dart';

/// One instalment of a cash projection: a commitment's own outstanding figure falling due on its
/// own date, and the balance left once it has.
class OcptBudgetProjectionStep extends Equatable {
  /// The commitment this instalment stands for.
  final String commitmentId;

  /// The date this instalment falls due, or null — see `OcptBudgetCommitment.dueDate`'s own doc
  /// comment: null means "nobody has recorded a due date", never "due immediately", and this
  /// instalment still lowers the projected balance even though no date names when.
  final DateTime? dueDate;

  /// What this instalment's own commitment still owed at the time this projection was built, read
  /// tax-inclusive — [ocptBudgetCommitmentOutstandingCentsOf], never the commitment's own full cash
  /// figure: a commitment already partly paid, and still owed the rest, only takes the rest out of
  /// the balance here, exactly the reading `OcptBudgetProjection.openingBalanceCents` itself
  /// already carries (the paid part has already left the account, and is already reflected there).
  final int amountCents;

  /// The balance once this instalment has fallen due — [amountCents] taken out of the balance the
  /// projection stood at just before this instalment.
  final int balanceAfterCents;

  /// Class constructor
  const OcptBudgetProjectionStep({
    required this.commitmentId,
    required this.dueDate,
    required this.amountCents,
    required this.balanceAfterCents,
  });

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptBudgetProjectionStep(commitmentId: $commitmentId, dueDate: $dueDate, "
      "amountCents: $amountCents, balanceAfterCents: $balanceAfterCents)";

  /// List the fields that decide equality.
  @override
  List<Object?> get props => [commitmentId, dueDate, amountCents, balanceAfterCents];
}
