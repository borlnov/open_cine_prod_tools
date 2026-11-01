// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/models/ocpt_storyboard_panel.dart';
import 'package:open_cine_prod_tools/types/ocpt_storyboard_annotation_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_storyboard_annotation_tool.dart';
import 'package:open_cine_prod_tools/types/ocpt_storyboard_panel_size.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_storyboard_shot_row.dart';

/// The shot list's board centre view: the selected sequence's shots, each as an
/// `OcptStoryboardShotRow` — the row *is* the shot, and selecting it sets `selectedShotId`.
///
/// Purely presentational: every write goes upward through a nullable callback, withheld (null)
/// under a version preview exactly like the table.
class OcptStoryboardBoard extends StatelessWidget {
  /// The selected sequence's shots, in display order.
  final List<OcptShot> shots;

  /// The production's whole cast, for each row's leader card.
  final List<OcptRole> roles;

  /// [shots]' own panels, keyed by shot id.
  final Map<String, List<OcptStoryboardPanel>> panelsByShotId;

  /// The common panel height every strip is drawn at.
  final OcptStoryboardPanelSize panelSize;

  /// The id of the currently selected shot, or null while none is.
  final String? selectedShotId;

  /// The id of the currently selected panel, or null while none is.
  final String? selectedPanelId;

  /// Whether the mode shows a project version being previewed read-only.
  final bool isReadOnly;

  /// Called with a shot's id when its row is clicked.
  final ValueChanged<String> onShotSelected;

  /// Called with a panel's id when its frame is clicked.
  final ValueChanged<String> onPanelSelected;

  /// Called with a shot's id when its strip's own `Import frame` slot is clicked, or null while
  /// withheld.
  final ValueChanged<String>? onImportRequested;

  /// Called with a panel's id when its own `Replace image` action is clicked, or null while
  /// withheld.
  final ValueChanged<String>? onReplaceRequested;

  /// Called with a panel's id when its own `Delete panel` action is clicked — only asks, see
  /// `OcptStoryboardPanelFrame`'s own doc comment — or null while withheld.
  final ValueChanged<String>? onDeleteRequested;

  /// Called with a shot's id, a panel's id and its new 0-based position when a strip's own frame is
  /// dragged to reorder, or null while withheld.
  final void Function(String shotId, String panelId, int newPosition)? onPanelReordered;

  /// The annotation tool currently on for the selected panel, or null while none is (or the mode
  /// is read-only). Only ever forwarded to the selected shot's own row — see
  /// `OcptStoryboardShotRow`'s own doc comment.
  final OcptStoryboardAnnotationTool? activeAnnotationTool;

  /// The id of the currently selected mark, or null while none is.
  final String? selectedAnnotationId;

  /// Called with a panel's id, the new mark's kind and its normalised tail/head once a drag draws
  /// an arrow, or null while withheld.
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

  /// Called with a mark's id when it is clicked, selecting it. Never withheld.
  final ValueChanged<String>? onAnnotationSelected;

  /// Class constructor
  const OcptStoryboardBoard({
    super.key,
    required this.shots,
    required this.roles,
    required this.panelsByShotId,
    required this.panelSize,
    required this.selectedShotId,
    required this.selectedPanelId,
    required this.isReadOnly,
    required this.onShotSelected,
    required this.onPanelSelected,
    required this.onImportRequested,
    required this.onReplaceRequested,
    required this.onDeleteRequested,
    required this.onPanelReordered,
    required this.activeAnnotationTool,
    required this.selectedAnnotationId,
    required this.onAnnotationDrawn,
    required this.onLabelPlaced,
    required this.onAnnotationSelected,
  });

  /// Build the storyboard board as a [ListView].
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    if (shots.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          tr.shotListShotsEmptyHint,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(4),
      itemCount: shots.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final shot = shots[index];
        final isSelectedShot = shot.id == selectedShotId;
        return OcptStoryboardShotRow(
          key: ValueKey(shot.id),
          shot: shot,
          attachedRoles: [
            for (final role in roles)
              if (shot.characterRoleIds.contains(role.id)) role,
          ],
          panels: panelsByShotId[shot.id] ?? const [],
          panelSize: panelSize,
          isSelected: isSelectedShot,
          selectedPanelId: selectedPanelId,
          isReadOnly: isReadOnly,
          onTap: () => onShotSelected(shot.id),
          onPanelSelected: onPanelSelected,
          onImportRequested: onImportRequested == null ? null : () => onImportRequested!(shot.id),
          onReplaceRequested: onReplaceRequested,
          onDeleteRequested: onDeleteRequested,
          onPanelReordered: onPanelReordered == null
              ? null
              : (panelId, newPosition) => onPanelReordered!(shot.id, panelId, newPosition),
          activeAnnotationTool: isSelectedShot ? activeAnnotationTool : null,
          selectedAnnotationId: isSelectedShot ? selectedAnnotationId : null,
          onAnnotationDrawn: onAnnotationDrawn,
          onLabelPlaced: onLabelPlaced,
          onAnnotationSelected: onAnnotationSelected,
        );
      },
    );
  }
}
