// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';

/// One candidate shot [OcptFloorPlanCopyBlockingDialog] offers as the source of a
/// `OcptFloorPlanService.copyShotBlocking` call.
class OcptFloorPlanCopyBlockingCandidate {
  /// The candidate shot's own id.
  final String shotId;

  /// The candidate shot's own display code (`12/3`).
  final String shotCode;

  /// Class constructor
  const OcptFloorPlanCopyBlockingCandidate({required this.shotId, required this.shotCode});
}

/// The dialog opened by the set tabs' own `＋ Set` menu's `Copy blocking from another shot` entry
/// (R3, `docs/plans/storyboard.md`, §9.4): a plain list of [candidates], each a one-click pick.
///
/// Purely presentational, modelled on `OcptFloorPlanCharacterNamePickerDialog`: [show] opens it and
/// returns the picked shot's id, or null if the user dismissed it. The router manager
/// (`OcptRouterManager`, never `Navigator`) is what actually pops it.
class OcptFloorPlanCopyBlockingDialog extends StatelessWidget {
  /// Every shot of the sequence the current one may copy its own set's blocking from, in order.
  final List<OcptFloorPlanCopyBlockingCandidate> candidates;

  /// Class constructor
  const OcptFloorPlanCopyBlockingDialog({super.key, required this.candidates});

  /// Shows the dialog and returns the picked shot's id, or null if the user dismissed it.
  static Future<String?> show(
    BuildContext context, {
    required List<OcptFloorPlanCopyBlockingCandidate> candidates,
  }) => showDialog<String>(
    context: context,
    builder: (context) => OcptFloorPlanCopyBlockingDialog(candidates: candidates),
  );

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    return AlertDialog(
      title: Text(tr.shotListFloorPlanCopyBlockingDialogTitle),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr.shotListFloorPlanCopyBlockingDialogHint),
            const SizedBox(height: 12),
            for (final candidate in candidates)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(candidate.shotCode),
                onTap: () =>
                    globalGetIt().get<OcptRouterManager>().pop<String>(candidate.shotId),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => globalGetIt().get<OcptRouterManager>().pop(),
          child: Text(tr.shotListFloorPlanCopyBlockingCancelAction),
        ),
      ],
    );
  }
}
