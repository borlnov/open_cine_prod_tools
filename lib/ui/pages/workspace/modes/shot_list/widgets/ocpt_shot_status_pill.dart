// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_status.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_shot_list_labels.dart';

/// The status pill shown next to the inspector header's `Shot 1/3`: a read-out, not a control.
///
/// A shot's shooting status is scheduling information — it says what happened on set, not how the
/// shot is designed — so it belongs to the shooting schedule mode, which is where it will become
/// editable. The shot list only ever displays it, here and in the table's own status column.
class OcptShotStatusPill extends StatelessWidget {
  /// The status shown.
  final OcptShotStatus status;

  /// Class constructor
  const OcptShotStatusPill({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = ocptShotStatusColor(context, status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: ocptSelectedStateAlpha),
        borderRadius: BorderRadius.circular(ocptRadiusLarge),
      ),
      child: Text(
        ocptShotStatusLabel(Tr.of(context), status),
        style: theme.textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
