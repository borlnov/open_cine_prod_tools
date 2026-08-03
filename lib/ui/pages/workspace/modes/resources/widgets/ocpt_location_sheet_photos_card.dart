// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_asset_ref.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_dashed_rounded_rect_painter.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_resources_sheet_card.dart';

/// The number of tiles the photo grid fits on one row, straight from the mock-up.
const int _tilesPerRow = 4;

/// The height of a photo tile.
const double _tileHeight = 96;

/// The spacing between two tiles, horizontally and vertically alike.
const double _tileSpacing = 8;

/// "Scouting photos": the location's referenced photos as a grid of thumbnails, and the tile that
/// references another.
///
/// **Nothing here is stored in the project**: an `assets` row holds a path and the tile reads the
/// file at it (`docs/adr/0013-binary-assets-referenced-by-path.md`). A path that resolves to
/// nothing — the file moved, or the `.ocpt` travelled to another machine — is the **normal**
/// outcome of that choice, not a failure: the tile then says the file was not found and keeps the
/// reference, which is what lets the user re-point it by referencing the file again.
class OcptLocationSheetPhotosCard extends StatelessWidget {
  /// The photos referenced for this location, in display order.
  final List<OcptAssetRef> photos;

  /// Called when the `+` tile is clicked, or null while the sheet may not be written to — the tile
  /// is then not rendered at all.
  final VoidCallback? onPhotoAddRequested;

  /// Called with a photo's asset id when its remove control is clicked, or null while it may not be
  /// used.
  final ValueChanged<String>? onPhotoRemoved;

  /// Class constructor
  const OcptLocationSheetPhotosCard({
    super.key,
    required this.photos,
    required this.onPhotoAddRequested,
    required this.onPhotoRemoved,
  });

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final onPhotoAddRequested = this.onPhotoAddRequested;

    return OcptResourcesSheetCard(
      title: tr.resourcesLocationPhotosCardTitle,
      hint: tr.resourcesLocationPhotosCount(photos.length),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tileWidth =
              (constraints.maxWidth - _tileSpacing * (_tilesPerRow - 1)) / _tilesPerRow;

          return Wrap(
            spacing: _tileSpacing,
            runSpacing: _tileSpacing,
            children: [
              for (final photo in photos)
                SizedBox(
                  width: tileWidth,
                  height: _tileHeight,
                  child: _OcptPhotoTile(
                    photo: photo,
                    onRemoved: onPhotoRemoved == null ? null : () => onPhotoRemoved!(photo.id),
                  ),
                ),
              if (onPhotoAddRequested != null)
                SizedBox(
                  width: tileWidth,
                  height: _tileHeight,
                  child: _OcptAddPhotoTile(onPressed: onPhotoAddRequested),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// One referenced photo: its thumbnail, or the "file not found" state when the path resolves to
/// nothing, with the control dropping the reference on top of it.
///
/// A [StatefulWidget] (the documented RFL1 exception) for the reason `OcptAssetFileLine` is one:
/// whether the file is there is asked once, with a single `stat`, when the tile is built or given
/// another path — never from `build`. The tile could have left the question to [Image.file]'s own
/// `errorBuilder`, but that answer only arrives once the image pipeline has tried and failed, which
/// is a frame later and never at all in a widget test; the check stays the tile's own, and
/// `errorBuilder` the second guard, for the file that *is* there and still cannot be decoded.
class _OcptPhotoTile extends StatefulWidget {
  /// The photo this tile shows.
  final OcptAssetRef photo;

  /// Called when the remove control is clicked, or null while it may not be used.
  final VoidCallback? onRemoved;

  /// Class constructor
  const _OcptPhotoTile({required this.photo, required this.onRemoved});

  @override
  State<_OcptPhotoTile> createState() => _OcptPhotoTileState();
}

/// The state of [_OcptPhotoTile]: whether the referenced file was found, once asked.
class _OcptPhotoTileState extends State<_OcptPhotoTile> {
  /// Whether the referenced file was there when it was last asked about.
  late bool _exists = File(widget.photo.path).existsSync();

  @override
  void didUpdateWidget(covariant _OcptPhotoTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.photo.path != oldWidget.photo.path) {
      _exists = File(widget.photo.path).existsSync();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final photo = widget.photo;
    final onRemoved = widget.onRemoved;

    return Tooltip(
      message: photo.path,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(ocptRadiusLarge),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(
              color: theme.colorScheme.surfaceContainerHigh,
              // A missing file is a state, not an error to report: the reference is kept and the
              // tile says so, so the user can point it at the file's new home.
              child: _exists
                  ? Image.file(
                      File(photo.path),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => _buildMissingFile(context),
                    )
                  : _buildMissingFile(context),
            ),
            if (onRemoved != null)
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: const Icon(Icons.close, size: 14),
                  tooltip: Tr.of(context).resourcesRemovePhotoTooltip,
                  style: IconButton.styleFrom(
                    backgroundColor: theme.colorScheme.surface.withValues(alpha: 0.7),
                    minimumSize: const Size(24, 24),
                    padding: EdgeInsets.zero,
                  ),
                  onPressed: onRemoved,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// What a tile shows in place of a thumbnail when its path resolves to nothing.
  Widget _buildMissingFile(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.image_not_supported_outlined, size: 18, color: theme.colorScheme.error),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              Tr.of(context).resourcesAssetFileMissing,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }
}

/// The dashed tile referencing another photo, wearing the mock-up's own "drop a photo" styling.
class _OcptAddPhotoTile extends StatelessWidget {
  /// Called when the tile is clicked.
  final VoidCallback onPressed;

  /// Class constructor
  const _OcptAddPhotoTile({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    return CustomPaint(
      painter: OcptDashedRoundedRectPainter(color: theme.colorScheme.outline),
      child: InkWell(
        onTap: onPressed,
        mouseCursor: ocptClickableCursor,
        borderRadius: BorderRadius.circular(ocptRadiusLarge),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              tr.resourcesAddPhotoAction,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
