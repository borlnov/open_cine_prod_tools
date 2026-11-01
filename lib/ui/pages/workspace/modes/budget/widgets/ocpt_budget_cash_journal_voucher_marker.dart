// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';

/// The small marker a row carries next to its own label when its entry carries a voucher — never a
/// second column of text, just an icon whose tooltip says whether the referenced file still
/// resolves, mirroring `OcptAssetFileLine`'s own "file not found" reading (ADR 0013).
///
/// A [StatefulWidget] (the documented exception) for the very reason `OcptAssetFileLine` is
/// one: the answer belongs to nobody else and is worth asking once, not from `build`, which would
/// run it on every frame the journal is rebuilt for an unrelated reason.
class OcptBudgetCashJournalVoucherMarker extends StatefulWidget {
  /// The voucher's own referenced path.
  final String path;

  /// Class constructor
  const OcptBudgetCashJournalVoucherMarker({super.key, required this.path});

  @override
  State<OcptBudgetCashJournalVoucherMarker> createState() =>
      _OcptBudgetCashJournalVoucherMarkerState();
}

/// The state of [OcptBudgetCashJournalVoucherMarker]: whether the referenced file was found, once
/// asked.
class _OcptBudgetCashJournalVoucherMarkerState extends State<OcptBudgetCashJournalVoucherMarker> {
  /// Whether the referenced file was there when it was last asked about.
  late bool _exists = File(widget.path).existsSync();

  @override
  void didUpdateWidget(covariant OcptBudgetCashJournalVoucherMarker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.path != oldWidget.path) {
      _exists = File(widget.path).existsSync();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final isMissing = !_exists;

    return Tooltip(
      message: isMissing
          ? tr.budgetCashJournalVoucherFileMissingTooltip
          : tr.budgetCashJournalVoucherAttachedTooltip,
      child: Icon(
        isMissing ? Icons.error_outline : Icons.attach_file,
        size: 14,
        color: isMissing ? theme.colorScheme.error : theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
