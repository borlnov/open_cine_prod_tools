// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_status.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_shot_list_labels.dart';

/// The shot status control: plain text while [onChanged] is withheld, a picker otherwise — shared
/// by the inspector's block read-out (for the block's own shot) and its shot read-out (for the
/// selected shot itself), the very same column either way (`shots.status`).
class OcptScheduleShotStatusControl extends StatelessWidget {
  /// The status shown.
  final OcptShotStatus status;

  /// Called with the status just picked, or null while withheld.
  final ValueChanged<OcptShotStatus>? onChanged;

  /// Class constructor
  const OcptScheduleShotStatusControl({super.key, required this.status, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final onShotStatusChanged = onChanged;

    if (onShotStatusChanged == null) {
      return Text(ocptShotStatusLabel(tr, status), style: theme.textTheme.bodySmall);
    }

    return PopupMenuButton<OcptShotStatus>(
      tooltip: "",
      onSelected: onShotStatusChanged,
      itemBuilder: (context) => [
        for (final candidate in OcptShotStatus.values)
          PopupMenuItem<OcptShotStatus>(
            value: candidate,
            child: Text(ocptShotStatusLabel(tr, candidate)),
          ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            ocptShotStatusLabel(tr, status),
            style: theme.textTheme.bodySmall?.copyWith(color: ocptShotStatusColor(context, status)),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.arrow_drop_down, size: 16),
        ],
      ),
    );
  }
}
