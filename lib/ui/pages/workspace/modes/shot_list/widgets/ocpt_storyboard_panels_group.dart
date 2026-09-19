// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_storyboard_panel.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_shot_inspector_field.dart';
import 'package:open_cine_prod_tools/ui/widgets/ocpt_referenced_image.dart';

/// The side of the small thumbnail every row of [OcptStoryboardPanelsGroup] leads with.
const double _thumbnailSize = 40;

/// The shot inspector's board-only group (`OcptShotInspectorPanel.leadingGroup`): the selected
/// shot's own panels, each with its free comment field, a reorder affordance and a `Delete panel`
/// action (`docs/plans/storyboard.md`, §4.1, §4.2).
///
/// A panel's comment rides the mode's field-edit autosave debounce exactly as a shot field does
/// ([commentValueOf] reads a pending edit over the stored value, matching `OcptShotInspectorPanel`'s
/// own `fieldValueOf`). Deleting is a two-step gesture by design: this group only **asks**
/// ([onDeleteRequested]), the mode opens `OcptConfirmDialog` and dispatches the deletion itself —
/// this widget never carries the question.
class OcptStoryboardPanelsGroup extends StatelessWidget {
  /// The selected shot's own panels, in order.
  final List<OcptStoryboardPanel> panels;

  /// [panels]' current comment value: a pending edit still in the mode's debounce, or the panel's
  /// own stored comment.
  final String Function(String panelId) commentValueOf;

  /// Whether the mode shows a project version being previewed read-only, withholding every
  /// affordance this group offers.
  final bool isReadOnly;

  /// Called with a panel's id and its raw comment text on every keystroke, or null while withheld.
  final void Function(String panelId, String rawValue)? onCommentChanged;

  /// Called with a panel's id and its new 0-based position when the reorder affordance moves it, or
  /// null while withheld.
  final void Function(String panelId, int newPosition)? onReordered;

  /// Called with a panel's id when its own `Delete panel` action is clicked — only asks, see the
  /// class doc comment — or null while withheld.
  final ValueChanged<String>? onDeleteRequested;

  /// Class constructor
  const OcptStoryboardPanelsGroup({
    super.key,
    required this.panels,
    required this.commentValueOf,
    required this.isReadOnly,
    required this.onCommentChanged,
    required this.onReordered,
    required this.onDeleteRequested,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr.shotListBoardPanelsGroupTitle(panels.length),
          style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary),
        ),
        const SizedBox(height: 8),
        if (panels.isEmpty)
          Text(
            tr.shotListBoardNoPanelYetHint,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          )
        else
          for (var index = 0; index < panels.length; index++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _PanelRow(
                panel: panels[index],
                rank: index + 1,
                total: panels.length,
                commentValue: commentValueOf(panels[index].id),
                isReadOnly: isReadOnly,
                onCommentChanged: onCommentChanged == null
                    ? null
                    : (value) => onCommentChanged!(panels[index].id, value),
                onMoveUp: onReordered == null || index == 0
                    ? null
                    : () => onReordered!(panels[index].id, index - 1),
                onMoveDown: onReordered == null || index == panels.length - 1
                    ? null
                    : () => onReordered!(panels[index].id, index + 1),
                onDeleteRequested: onDeleteRequested == null
                    ? null
                    : () => onDeleteRequested!(panels[index].id),
              ),
            ),
      ],
    );
  }
}

/// One row of [OcptStoryboardPanelsGroup]: the panel's thumbnail, its comment field, and the
/// reorder/delete actions.
class _PanelRow extends StatelessWidget {
  /// The panel this row shows.
  final OcptStoryboardPanel panel;

  /// This panel's 1-based rank among its shot's other panels.
  final int rank;

  /// The shot's total panel count.
  final int total;

  /// The comment field's current value.
  final String commentValue;

  /// Whether the mode shows a project version being previewed read-only.
  final bool isReadOnly;

  /// Called with the field's raw text on every keystroke, or null while withheld.
  final ValueChanged<String>? onCommentChanged;

  /// Called when the `move up` affordance is clicked, or null while withheld (already first, or
  /// read-only).
  final VoidCallback? onMoveUp;

  /// Called when the `move down` affordance is clicked, or null while withheld (already last, or
  /// read-only).
  final VoidCallback? onMoveDown;

  /// Called when `Delete panel` is clicked, or null while withheld.
  final VoidCallback? onDeleteRequested;

  /// Class constructor
  const _PanelRow({
    required this.panel,
    required this.rank,
    required this.total,
    required this.commentValue,
    required this.isReadOnly,
    required this.onCommentChanged,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onDeleteRequested,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(ocptRadiusMedium),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(ocptRadiusSmall),
            child: SizedBox(
              width: _thumbnailSize,
              height: _thumbnailSize,
              child: OcptReferencedImage(
                path: panel.imagePath,
                fallbackBuilder: (context) => Container(
                  color: theme.colorScheme.surfaceContainerHighest,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.image_not_supported_outlined,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "$rank/$total",
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                // `shotId` only ever tracks a switch of what this field is bound to (see its own
                // doc comment) — the panel's own id serves that exact role here.
                OcptShotInspectorField(
                  shotId: panel.id,
                  label: "",
                  value: commentValue,
                  multiline: true,
                  hintText: tr.shotListBoardPanelCommentHint,
                  onChanged: onCommentChanged,
                ),
              ],
            ),
          ),
          Column(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_upward, size: 16),
                tooltip: tr.shotListBoardMovePanelUpAction,
                visualDensity: VisualDensity.compact,
                onPressed: onMoveUp,
              ),
              IconButton(
                icon: const Icon(Icons.arrow_downward, size: 16),
                tooltip: tr.shotListBoardMovePanelDownAction,
                visualDensity: VisualDensity.compact,
                onPressed: onMoveDown,
              ),
              if (onDeleteRequested != null)
                IconButton(
                  icon: Icon(Icons.delete_outline, size: 16, color: theme.colorScheme.error),
                  tooltip: tr.shotListBoardDeletePanelAction,
                  visualDensity: VisualDensity.compact,
                  onPressed: onDeleteRequested,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
