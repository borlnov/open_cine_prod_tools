// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart' as ocpt_theme;
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_storyboard_panel.dart';
import 'package:open_cine_prod_tools/types/ocpt_storyboard_annotation_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_storyboard_annotation_tool.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_storyboard_annotation_overlay.dart';
import 'package:open_cine_prod_tools/ui/widgets/ocpt_referenced_image.dart';

/// One imported frame of a shot's storyboard: its image (or the placeholder, at the same aspect
/// ratio, while the file is missing), the `rank/total` badge, its free comment and its ratio label
/// underneath.
///
/// **The annotation overlay** (`OcptStoryboardAnnotationOverlay`) always draws [panel]'s own
/// marks over the image — a read, kept even read-only — and turns into a live gesture surface
/// only while [activeAnnotationTool] is non-null: the strip only ever sets it for the panel that
/// is both selected and carrying a tool (`OcptStoryboardPanelStrip`'s own doc comment), so every
/// other frame stays exactly as passive as it was before this overlay existed. While it is live,
/// this frame's own `InkWell` (which otherwise selects the panel on tap) steps aside — the overlay
/// already knows this panel is selected, so a tap there means something else now.
///
/// **Deleting the panel from the board** ([onDeleteRequested]) is the same two-step gesture as the
/// inspector's own `OcptStoryboardPanelsGroup` `Delete panel` action: this frame only **asks**, the
/// mode opens `OcptConfirmDialog` and dispatches `OcptShotListPanelDeletionRequestedEvent` itself —
/// the very same handler the inspector's own action already calls, so a panel is never deleted
/// through two different paths.
class OcptStoryboardPanelFrame extends StatelessWidget {
  /// The panel this frame shows.
  final OcptStoryboardPanel panel;

  /// This panel's 1-based rank among its shot's other panels.
  final int rank;

  /// The shot's total panel count.
  final int total;

  /// The frame's own width, derived from [height] and the shot's aspect ratio.
  final double width;

  /// The strip's common panel height.
  final double height;

  /// Whether this is the currently selected panel.
  final bool isSelected;

  /// Whether the mode shows a project version being previewed read-only.
  final bool isReadOnly;

  /// Called when the frame is clicked, selecting this panel.
  final VoidCallback onTap;

  /// Called when this frame's own `Replace image` action is clicked, or null while withheld.
  final VoidCallback? onReplaceRequested;

  /// Called when this frame's own `Delete panel` action is clicked — only asks, see the class doc
  /// comment — or null while withheld.
  final VoidCallback? onDeleteRequested;

  /// The annotation tool currently on for this exact frame, or null while gestures are withheld —
  /// see the class doc comment.
  final OcptStoryboardAnnotationTool? activeAnnotationTool;

  /// The id of the currently selected mark, or null while none is.
  final String? selectedAnnotationId;

  /// Called with the new mark's kind and its normalised tail/head once a drag draws an arrow, or
  /// null while withheld.
  final void Function(
    OcptStoryboardAnnotationKind kind,
    double x1,
    double y1,
    double x2,
    double y2,
  )?
  onAnnotationDrawn;

  /// Called with a normalised point once a click places a label there, or null while withheld.
  final void Function(double x, double y)? onLabelPlaced;

  /// Called with a mark's id when it is clicked, selecting it. Never withheld.
  final ValueChanged<String>? onAnnotationSelected;

  /// Class constructor
  const OcptStoryboardPanelFrame({
    super.key,
    required this.panel,
    required this.rank,
    required this.total,
    required this.width,
    required this.height,
    required this.isSelected,
    required this.isReadOnly,
    required this.onTap,
    required this.onReplaceRequested,
    required this.onDeleteRequested,
    required this.activeAnnotationTool,
    required this.selectedAnnotationId,
    required this.onAnnotationDrawn,
    required this.onLabelPlaced,
    required this.onAnnotationSelected,
  });

  /// Build the storyboard panel frame as an [InkWell].
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final ratioLabel = tr.shotListBoardPanelRatioLabel(_formattedRatio(width / height));
    final annotationsLive = activeAnnotationTool != null;

    return InkWell(
      onTap: annotationsLive ? null : onTap,
      mouseCursor: ocpt_theme.ocptClickableCursor,
      borderRadius: BorderRadius.circular(ocpt_theme.ocptRadiusMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: width,
            height: height,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(ocpt_theme.ocptRadiusMedium),
              border: Border.all(
                color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                OcptReferencedImage(
                  path: panel.imagePath,
                  fallbackBuilder: (context) => Container(
                    color: theme.colorScheme.surfaceContainerHighest,
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.image_not_supported_outlined,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Positioned.fill(
                  child: OcptStoryboardAnnotationOverlay(
                    annotations: panel.annotations,
                    selectedAnnotationId: selectedAnnotationId,
                    activeTool: activeAnnotationTool,
                    onArrowDrawn: onAnnotationDrawn,
                    onLabelPlaced: onLabelPlaced,
                    onAnnotationSelected: onAnnotationSelected,
                  ),
                ),
                Positioned(
                  top: 4,
                  left: 4,
                  child: _RankBadge(rank: rank, total: total),
                ),
                if (onReplaceRequested != null || onDeleteRequested != null)
                  Positioned(
                    top: 2,
                    right: 2,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (onReplaceRequested != null)
                          IconButton(
                            icon: const Icon(Icons.swap_horiz, size: 18),
                            tooltip: tr.shotListBoardReplaceImageAction,
                            color: Colors.white,
                            onPressed: onReplaceRequested,
                          ),
                        if (onDeleteRequested != null)
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18),
                            tooltip: tr.shotListBoardDeletePanelAction,
                            color: Colors.white,
                            onPressed: onDeleteRequested,
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: width,
            child: Text(
              panel.comment.isEmpty ? ratioLabel : "${panel.comment} · $ratioLabel",
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// [ratio] formatted as `W:9` against a fixed 9-unit height, the reading a storyboard frame's
  /// ratio is conventionally printed at (`16:9`, `2.39:1`-derived frames read as their own decimal
  /// instead, since forcing every one onto a `:9` base would misstate a scope frame as `21:9`-ish
  /// nonsense) — kept simple and purely cosmetic: `ocptAspectRatioOf` is the one source of truth
  /// the frame's own *shape* is drawn from, this only labels it.
  String _formattedRatio(double ratio) {
    if ((ratio - (16 / 9)).abs() < 0.01) {
      return "16:9";
    }
    if ((ratio - (4 / 3)).abs() < 0.01) {
      return "4:3";
    }
    return "${ratio.toStringAsFixed(2)}:1";
  }
}

/// The panel frame's own `rank/total` badge, top-left of the image.
class _RankBadge extends StatelessWidget {
  /// This panel's 1-based rank among its shot's other panels.
  final int rank;

  /// The shot's total panel count.
  final int total;

  /// Class constructor
  const _RankBadge({required this.rank, required this.total});

  /// Build the rank badge as a [Container].
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(ocpt_theme.ocptRadiusSmall),
    ),
    child: Text(
      "$rank/$total",
      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
    ),
  );
}
