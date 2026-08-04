// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_asset_ref.dart';
import 'package:path/path.dart' as p;

/// One referenced document, read as a line rather than as a thumbnail: its file name, its whole
/// path as a tooltip, whether that path still resolves to anything, and the control dropping the
/// reference.
///
/// A document is a PDF as often as an image, and a production reads it by its name — so unlike a
/// scouting photo (`OcptLocationSheetPhotosCard`), which *is* its thumbnail, this one asks the
/// file system whether the file is still there rather than trying to draw it.
///
/// A [StatefulWidget] (the documented RFL1 exception) because that answer belongs to nobody else
/// and is worth asking once: the bloc has no business holding a flag about a file it never reads,
/// and a missing file is a normal state (see
/// `docs/adr/0013-binary-assets-referenced-by-path.md`) rather than an error to report. The check
/// is a single `stat` of one file, run when the line is built or given another path — never from
/// `build`, which would run it on every frame the sheet is rebuilt for an unrelated reason.
class OcptAssetFileLine extends StatefulWidget {
  /// The referenced document.
  final OcptAssetRef asset;

  /// Called when the remove control is clicked, or null while the sheet may not be written to —
  /// no control is rendered at all then.
  final VoidCallback? onRemoved;

  /// Class constructor
  const OcptAssetFileLine({super.key, required this.asset, required this.onRemoved});

  @override
  State<OcptAssetFileLine> createState() => _OcptAssetFileLineState();
}

/// The state of [OcptAssetFileLine]: whether the referenced file was found, once asked.
class _OcptAssetFileLineState extends State<OcptAssetFileLine> {
  /// Whether the referenced file was there when it was last asked about.
  late bool _exists = File(widget.asset.path).existsSync();

  @override
  void didUpdateWidget(covariant OcptAssetFileLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.asset.path != oldWidget.asset.path) {
      _exists = File(widget.asset.path).existsSync();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final isMissing = !_exists;

    return Row(
      children: [
        Icon(
          isMissing ? Icons.error_outline : Icons.description_outlined,
          size: 14,
          color: isMissing ? theme.colorScheme.error : theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Tooltip(
            message: widget.asset.path,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.basename(widget.asset.path),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
                if (isMissing)
                  Text(
                    tr.resourcesAssetFileMissing,
                    style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.error),
                  ),
              ],
            ),
          ),
        ),
        if (widget.onRemoved != null)
          IconButton(
            icon: const Icon(Icons.close, size: 14),
            tooltip: tr.resourcesRemoveDocumentTooltip,
            onPressed: widget.onRemoved,
          ),
      ],
    );
  }
}
