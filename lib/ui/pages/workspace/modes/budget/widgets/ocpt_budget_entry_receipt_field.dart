// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_asset_ref.dart';
import 'package:open_cine_prod_tools/types/ocpt_asset_kind.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_asset_file_line.dart';

/// `Justificatif`.
class OcptBudgetEntryReceiptField extends StatelessWidget {
  /// The path currently shown, or null while no voucher is attached.
  final String? displayedReceiptPath;

  /// The voucher already referenced by the entry, or null.
  final OcptAssetRef? existingReceipt;

  /// Called when the voucher's own remove action is used.
  final VoidCallback onRemoved;

  /// Called when the attach or replace button is pressed.
  final VoidCallback onPickRequested;

  /// Class constructor
  const OcptBudgetEntryReceiptField({
    super.key,
    required this.displayedReceiptPath,
    required this.existingReceipt,
    required this.onRemoved,
    required this.onPickRequested,
  });

  /// Build the budget entry receipt field as a [Column].
  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final theme = Theme.of(context);
    final displayedReceiptPath = this.displayedReceiptPath;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr.budgetEntryDialogReceiptFieldLabel.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        if (displayedReceiptPath != null)
          OcptAssetFileLine(
            asset: OcptAssetRef(
              id: existingReceipt?.id ?? "",
              kind: OcptAssetKind.receipt,
              path: displayedReceiptPath,
              label: "",
              addedAt: existingReceipt?.addedAt ?? DateTime.now(),
              personId: null,
              locationId: null,
              elementId: null,
              validFrom: null,
              validUntil: null,
            ),
            onRemoved: onRemoved,
          )
        else
          Text(
            tr.budgetEntryDialogReceiptEmptyHint,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: onPickRequested,
            child: Text(
              displayedReceiptPath == null
                  ? tr.budgetEntryDialogReceiptAttachAction
                  : tr.budgetEntryDialogReceiptReplaceAction,
            ),
          ),
        ),
      ],
    );
  }
}
