// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_regie.dart';

/// One meal block's own reading: who it fed, and at which slot.
///
/// **Deduplicated by person within this one block, not further.** Crew is read by `personId`
/// directly; cast is read by `roles.personId` — a role names a person only once it is cast, so a
/// role with no person recorded cannot be told apart from the crew and counts on its own
/// ([ocptBudgetRegieDaysOf]'s own doc comment states why this is the honest reading rather than a
/// gap). Somebody who is both cast and crew on this block's own slot is counted once.
class OcptBudgetRegieMealSitting extends Equatable {
  /// The meal block this sitting reads.
  final String blockId;

  /// The slot this block belongs to — whose own crew and cast are who it fed.
  final String slotId;

  /// How many distinct heads this sitting fed.
  final int headCount;

  /// Class constructor
  const OcptBudgetRegieMealSitting({
    required this.blockId,
    required this.slotId,
    required this.headCount,
  });

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptBudgetRegieMealSitting(blockId: $blockId, slotId: $slotId, headCount: $headCount)";

  /// List the fields that decide equality.
  @override
  List<Object?> get props => [blockId, slotId, headCount];
}
