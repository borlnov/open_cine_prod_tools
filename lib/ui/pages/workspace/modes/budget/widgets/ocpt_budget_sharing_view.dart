// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_sharing_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_view_actions.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_wizard_flows.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_sharing.dart';

/// The revenue sharing view: the pot, the repayments owed and the participants' shares.
class OcptBudgetSharingView extends StatelessWidget {
  /// The mode's state, which the shares, the pot and the repayments are read from.
  final OcptBudgetState state;

  /// Asks the mode to confirm, then delete, the share with this id.
  final ValueChanged<String> onShareDeletionRequested;

  /// Class constructor
  const OcptBudgetSharingView({
    super.key,
    required this.state,
    required this.onShareDeletionRequested,
  });

  /// Build the budget sharing view as an [OcptBudgetSharing].
  @override
  Widget build(BuildContext context) {
    final bloc = context.read<OcptBudgetBloc>();
    final sharingBloc = context.read<OcptBudgetSharingBloc>();
    final isReadOnly = state.isPreviewingVersion;

    return OcptBudgetSharing(
      shares: state.shares,
      sharingPot: state.sharingPot,
      repaymentLines: state.repaymentLines,
      shareSplits: state.shareSplits,
      people: state.people,
      currencyCode: state.currencyCode,
      selectedShareId: state.selectedShareId,
      isReadOnly: isReadOnly,
      onShareSelected: (shareId) => bloc.add(OcptBudgetShareSelectedEvent(shareId: shareId)),
      onShareEditRequested: isReadOnly
          ? null
          : (share) => unawaited(ocptBudgetEditShare(context, state, share)),
      onSharePayoutRequested: isReadOnly
          ? null
          : (share) => unawaited(ocptBudgetPayShare(context, state, share)),
      onShareReorderRequested: isReadOnly
          ? null
          : (shareId, {required moveUp}) => sharingBloc.add(
              OcptBudgetShareReorderedEvent(
                shareId: shareId,
                newPosition: _shareReorderedPosition(state, shareId, moveUp),
              ),
            ),
      onShareDeletionRequested: isReadOnly ? null : onShareDeletionRequested,
      onRepaymentRequested: isReadOnly
          ? null
          : (line) => unawaited(ocptBudgetRepayLine(context, state, line)),
    );
  }
}

/// The 0-based position share [shareId] moves to when its row's own `⋮` menu `▲`/`▼` entry is
/// clicked — one above or below its current position in [OcptBudgetState.shares]' own order, a
/// share id no longer found there falling back to the first position.
int _shareReorderedPosition(OcptBudgetState state, String shareId, bool moveUp) {
  final currentIndex = state.shares.indexWhere((share) => share.id == shareId);
  if (currentIndex < 0) {
    return 0;
  }

  return moveUp ? currentIndex - 1 : currentIndex + 1;
}
