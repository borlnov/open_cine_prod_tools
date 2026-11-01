// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart' as ocpt_theme;
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_storyboard_panel.dart';
import 'package:open_cine_prod_tools/types/ocpt_storyboard_annotation_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_storyboard_annotation_tool.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_storyboard_panel_frame.dart';

// The strip's frames are drawn by their own widget; the strip's callers reach both through here.
export 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_storyboard_panel_frame.dart';

/// The gap left between two panel frames of a strip, and between the last frame and the trailing
/// `Import frame` slot.
const double _frameGap = 10;

/// One shot's ordered panels, laid out left to right at their shared [height] — the right half of
/// an `OcptStoryboardShotRow` — followed by a trailing dashed `Import frame` slot.
///
/// A shot with no panel shows the slot alone, labelled `no panel yet`. Reordering drags a frame
/// within the strip, built on `ReorderableListView`'s own `onReorderItem` — its `newIndex` is
/// already adjusted for the moved item's own removal, exactly the 0-based position
/// `OcptStoryboardService.reorderPanel` (and [onReordered]) expects.
///
/// **Annotation gestures suspend this strip's own reorder** while [activeAnnotationTool] is
/// non-null: dragging out an arrow and dragging a frame to reorder it are the same gesture shape
/// (a pan), so the two cannot coexist on the strip a tool is active over. [effectiveOnReordered]
/// is the guard — turning the tool back off (`activeAnnotationTool` null again) restores
/// [onReordered] exactly as it was, and every other strip on the board (a tool only ever applies
/// to the selected panel) is never affected in the first place.
class OcptStoryboardPanelStrip extends StatelessWidget {
  /// The shot's own panels, in order.
  final List<OcptStoryboardPanel> panels;

  /// The aspect ratio (width / height) every frame of this strip is drawn at, derived from the
  /// shot's own `recordingFormat` (`ocptAspectRatioOf`).
  final double aspectRatio;

  /// The common height every frame of this strip is drawn at — `OcptShotListState.boardPanelSize`.
  final double height;

  /// The id of the currently selected panel, or null while none of this shot's panels is selected.
  final String? selectedPanelId;

  /// Whether the mode shows a project version being previewed read-only, withholding every write
  /// affordance this strip offers (selecting is still allowed — it only reads).
  final bool isReadOnly;

  /// Called with a panel's id when its frame is clicked.
  final ValueChanged<String> onPanelSelected;

  /// Called with a panel's id when its own `Replace image` action is clicked, or null while
  /// withheld.
  final ValueChanged<String>? onReplaceRequested;

  /// Called with a panel's id when its own `Delete panel` action is clicked — only asks, the mode
  /// opens `OcptConfirmDialog` and dispatches the same deletion `OcptStoryboardPanelsGroup`'s own
  /// `Delete panel` action does, see `OcptStoryboardPanelFrame`'s own doc comment — or null while
  /// withheld.
  final ValueChanged<String>? onDeleteRequested;

  /// Called when the trailing `Import frame` slot is clicked, or null while withheld.
  final VoidCallback? onImportRequested;

  /// Called with a panel's id and its new 0-based position when it is dragged to reorder, or null
  /// while withheld.
  final void Function(String panelId, int newPosition)? onReordered;

  /// The annotation tool currently on for this strip's shot, or null while none is (or the mode
  /// is read-only): forwarded to the strip's currently *selected* panel's own frame only — see the
  /// class doc comment.
  final OcptStoryboardAnnotationTool? activeAnnotationTool;

  /// The id of the currently selected mark, or null while none is.
  final String? selectedAnnotationId;

  /// Called with a panel's id, the new mark's kind and its normalised tail/head once a drag draws
  /// an arrow on the panel currently carrying [activeAnnotationTool], or null while withheld.
  final void Function(
    String panelId,
    OcptStoryboardAnnotationKind kind,
    double x1,
    double y1,
    double x2,
    double y2,
  )?
  onAnnotationDrawn;

  /// Called with a panel's id and a normalised point once a click places a label there, or null
  /// while withheld.
  final void Function(String panelId, double x, double y)? onLabelPlaced;

  /// Called with a mark's id when it is clicked, selecting it. Never withheld — see
  /// `OcptStoryboardAnnotationOverlay`'s own doc comment.
  final ValueChanged<String>? onAnnotationSelected;

  /// [onReordered], withheld whenever [activeAnnotationTool] is on — see the class doc comment.
  void Function(String panelId, int newPosition)? get effectiveOnReordered =>
      activeAnnotationTool == null ? onReordered : null;

  /// Class constructor
  const OcptStoryboardPanelStrip({
    super.key,
    required this.panels,
    required this.aspectRatio,
    required this.height,
    required this.selectedPanelId,
    required this.isReadOnly,
    required this.onPanelSelected,
    required this.onReplaceRequested,
    required this.onDeleteRequested,
    required this.onImportRequested,
    required this.onReordered,
    required this.activeAnnotationTool,
    required this.selectedAnnotationId,
    required this.onAnnotationDrawn,
    required this.onLabelPlaced,
    required this.onAnnotationSelected,
  });

  /// Build the storyboard panel strip as a [SizedBox].
  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final frameWidth = height * aspectRatio;

    if (panels.isEmpty) {
      return SizedBox(
        height: height,
        child: _ImportSlot(
          width: frameWidth,
          label: tr.shotListBoardNoPanelYetHint,
          onTap: onImportRequested,
        ),
      );
    }

    // A `SingleChildScrollView` around the whole row — the list *and* the trailing import slot
    // together — rather than an `Expanded` list beside a fixed-width slot: the centre can be
    // narrower than a single frame (a wide shot format, both docks open on a modest window), and
    // an `Expanded` sibling cannot shrink a fixed-width sibling below its own natural size, which
    // would overflow instead of scrolling. The inner list is `shrinkWrap`ped with its own
    // scrolling turned off, so this outer view is the only one that ever scrolls.
    return SizedBox(
      height: height + 48,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ReorderableListView.builder(
              scrollDirection: Axis.horizontal,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: effectiveOnReordered != null,
              itemCount: panels.length,
              onReorderItem: _handleReorder,
              itemBuilder: (context, index) {
                final panel = panels[index];
                final isSelected = panel.id == selectedPanelId;
                return Padding(
                  key: ValueKey(panel.id),
                  padding: const EdgeInsets.only(right: _frameGap),
                  child: OcptStoryboardPanelFrame(
                    panel: panel,
                    rank: index + 1,
                    total: panels.length,
                    width: frameWidth,
                    height: height,
                    isSelected: isSelected,
                    isReadOnly: isReadOnly,
                    onTap: () => onPanelSelected(panel.id),
                    onReplaceRequested: onReplaceRequested == null
                        ? null
                        : () => onReplaceRequested!(panel.id),
                    onDeleteRequested: onDeleteRequested == null
                        ? null
                        : () => onDeleteRequested!(panel.id),
                    activeAnnotationTool: isSelected ? activeAnnotationTool : null,
                    selectedAnnotationId: selectedAnnotationId,
                    onAnnotationDrawn: onAnnotationDrawn == null
                        ? null
                        : (kind, x1, y1, x2, y2) =>
                              onAnnotationDrawn!(panel.id, kind, x1, y1, x2, y2),
                    onLabelPlaced: onLabelPlaced == null
                        ? null
                        : (x, y) => onLabelPlaced!(panel.id, x, y),
                    onAnnotationSelected: onAnnotationSelected,
                  ),
                );
              },
            ),
            _ImportSlot(width: frameWidth, label: null, onTap: onImportRequested),
          ],
        ),
      ),
    );
  }

  /// Reports [effectiveOnReordered] with the panel dragged from [oldIndex] and the 0-based
  /// position it lands on: `ReorderableListView`'s own `onReorderItem` already hands back
  /// [newIndex] adjusted for the moved item's own removal — exactly the position
  /// `OcptStoryboardService.reorderPanel` expects — so nothing is translated here beyond reading
  /// the panel's id off [oldIndex].
  void _handleReorder(int oldIndex, int newIndex) {
    final onReordered = effectiveOnReordered;
    if (onReordered == null || newIndex == oldIndex) {
      return;
    }

    onReordered(panels[oldIndex].id, newIndex);
  }
}

/// The strip's trailing `Import frame` slot: a dashed placeholder-shaped button.
class _ImportSlot extends StatelessWidget {
  /// The slot's own width, matching a frame's.
  final double width;

  /// The slot's own label, or null for the default `Import frame` wording (the empty-strip case
  /// uses [label] for `no panel yet` instead).
  final String? label;

  /// Called when the slot is clicked, or null while withheld.
  final VoidCallback? onTap;

  /// Class constructor
  const _ImportSlot({required this.width, required this.label, required this.onTap});

  /// Build the import slot as an [InkWell].
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    return InkWell(
      onTap: onTap,
      mouseCursor: ocpt_theme.ocptClickableCursor,
      borderRadius: BorderRadius.circular(ocpt_theme.ocptRadiusMedium),
      child: Container(
        width: width,
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(ocpt_theme.ocptRadiusMedium),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.add_photo_alternate_outlined,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 6),
                Text(
                  label ?? tr.shotListBoardImportFrameAction,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
