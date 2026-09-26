// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_storyboard_annotation.dart';
import 'package:open_cine_prod_tools/models/ocpt_storyboard_panel.dart';
import 'package:open_cine_prod_tools/types/ocpt_storyboard_annotation_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_storyboard_annotation_tool.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_shot_inspector_field.dart';
import 'package:open_cine_prod_tools/ui/widgets/ocpt_referenced_image.dart';

/// The side of the small thumbnail every row of [OcptStoryboardPanelsGroup] leads with.
const double _thumbnailSize = 40;

/// The shot inspector's board-only group (`OcptShotInspectorPanel.leadingGroup`): the selected
/// shot's own panels, each with its free comment field, a reorder affordance and a `Delete panel`
/// action, followed — while a panel is selected — by its own annotation section (the `Annotate`
/// tool picker and its marks list, `docs/plans/storyboard.md`, §4.1, §4.2).
///
/// A panel's comment rides the mode's field-edit autosave debounce exactly as a shot field does
/// ([commentValueOf] reads a pending edit over the stored value, matching `OcptShotInspectorPanel`'s
/// own `fieldValueOf`), and a mark's own text ([annotationTextValueOf]) rides the very same
/// debounce, keyed differently. Deleting a panel or a mark is a two-step gesture by design: this
/// group only **asks** ([onDeleteRequested], [onAnnotationDeleteRequested]), the mode opens
/// `OcptConfirmDialog` and dispatches the deletion itself — this widget never carries the
/// question.
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

  /// The id of the currently selected panel, or null while none is: the annotation section only
  /// shows while this is set, since a mark always belongs to one specific panel.
  final String? selectedPanelId;

  /// The selected panel's own marks, in draw order, or empty while [selectedPanelId] is null.
  final List<OcptStoryboardAnnotation> annotations;

  /// The id of the currently selected mark, or null while none is.
  final String? selectedAnnotationId;

  /// The annotation tool currently on for the selected panel, or null while none is.
  final OcptStoryboardAnnotationTool? activeAnnotationTool;

  /// Called with the tool just picked from the `Annotate` control, or with null when the active one
  /// is picked again (turning it off), or null while withheld.
  final ValueChanged<OcptStoryboardAnnotationTool?>? onToolChanged;

  /// [annotations]' current text value: a pending edit still in the mode's debounce, or the mark's
  /// own stored text.
  final String Function(String annotationId) annotationTextValueOf;

  /// Called with a mark's id when its row is clicked, selecting it. Never withheld.
  final ValueChanged<String>? onAnnotationSelected;

  /// Called with a mark's id and its raw text on every keystroke, or null while withheld.
  final void Function(String annotationId, String rawValue)? onAnnotationTextChanged;

  /// Called with a mark's id when its own remove action is clicked — only asks, see the class doc
  /// comment — or null while withheld.
  final ValueChanged<String>? onAnnotationDeleteRequested;

  /// Class constructor
  const OcptStoryboardPanelsGroup({
    super.key,
    required this.panels,
    required this.commentValueOf,
    required this.isReadOnly,
    required this.onCommentChanged,
    required this.onReordered,
    required this.onDeleteRequested,
    required this.selectedPanelId,
    required this.annotations,
    required this.selectedAnnotationId,
    required this.activeAnnotationTool,
    required this.onToolChanged,
    required this.annotationTextValueOf,
    required this.onAnnotationSelected,
    required this.onAnnotationTextChanged,
    required this.onAnnotationDeleteRequested,
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
        if (selectedPanelId != null) ...[
          const SizedBox(height: 4),
          const Divider(),
          const SizedBox(height: 4),
          _AnnotationsSection(
            annotations: annotations,
            isReadOnly: isReadOnly,
            selectedAnnotationId: selectedAnnotationId,
            activeTool: activeAnnotationTool,
            onToolChanged: onToolChanged,
            textValueOf: annotationTextValueOf,
            onSelected: onAnnotationSelected,
            onTextChanged: onAnnotationTextChanged,
            onDeleteRequested: onAnnotationDeleteRequested,
          ),
        ],
      ],
    );
  }
}

/// The panels group's own annotation section, shown while a panel is selected: the `Annotate` tool
/// picker (withheld read-only) and the selected panel's own marks, each with its kind, an editable
/// text field riding the same idiom [_PanelRow]'s own comment field does, and a remove action.
class _AnnotationsSection extends StatelessWidget {
  /// The selected panel's own marks, in draw order.
  final List<OcptStoryboardAnnotation> annotations;

  /// Whether the mode shows a project version being previewed read-only.
  final bool isReadOnly;

  /// The id of the currently selected mark, or null while none is.
  final String? selectedAnnotationId;

  /// The annotation tool currently on, or null while none is.
  final OcptStoryboardAnnotationTool? activeTool;

  /// Called with the tool just picked, or null when withheld — the whole `Annotate` control is
  /// omitted (not shown disabled) while this is null, per the read-only rule.
  final ValueChanged<OcptStoryboardAnnotationTool?>? onToolChanged;

  /// A mark's current text value: a pending edit still in the mode's debounce, or its own stored
  /// text.
  final String Function(String annotationId) textValueOf;

  /// Called with a mark's id when its row is clicked, selecting it. Never withheld.
  final ValueChanged<String>? onSelected;

  /// Called with a mark's id and its raw text on every keystroke, or null while withheld.
  final void Function(String annotationId, String rawValue)? onTextChanged;

  /// Called with a mark's id when its own remove action is clicked, or null while withheld.
  final ValueChanged<String>? onDeleteRequested;

  /// Class constructor
  const _AnnotationsSection({
    required this.annotations,
    required this.isReadOnly,
    required this.selectedAnnotationId,
    required this.activeTool,
    required this.onToolChanged,
    required this.textValueOf,
    required this.onSelected,
    required this.onTextChanged,
    required this.onDeleteRequested,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final onToolChanged = this.onToolChanged;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr.shotListBoardAnnotationsGroupTitle(annotations.length),
          style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary),
        ),
        const SizedBox(height: 8),
        if (onToolChanged != null) ...[
          SegmentedButton<OcptStoryboardAnnotationTool>(
            emptySelectionAllowed: true,
            selected: activeTool == null ? const {} : {activeTool!},
            onSelectionChanged: (selection) =>
                onToolChanged(selection.isEmpty ? null : selection.first),
            segments: [
              ButtonSegment(
                value: OcptStoryboardAnnotationTool.movementArrow,
                label: Text(tr.shotListBoardAnnotationToolMovementArrowLabel),
                icon: const Icon(Icons.north_east, size: 16),
              ),
              ButtonSegment(
                value: OcptStoryboardAnnotationTool.cameraMoveArrow,
                label: Text(tr.shotListBoardAnnotationToolCameraMoveArrowLabel),
                icon: const Icon(Icons.videocam_outlined, size: 16),
              ),
              ButtonSegment(
                value: OcptStoryboardAnnotationTool.label,
                label: Text(tr.shotListBoardAnnotationToolLabelSegmentLabel),
                icon: const Icon(Icons.label_outline, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        if (annotations.isEmpty)
          Text(
            tr.shotListBoardNoAnnotationsHint,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          )
        else
          for (final annotation in annotations)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _AnnotationRow(
                annotation: annotation,
                isSelected: annotation.id == selectedAnnotationId,
                textValue: textValueOf(annotation.id),
                isReadOnly: isReadOnly,
                onSelected: onSelected == null ? null : () => onSelected!(annotation.id),
                onTextChanged: onTextChanged == null
                    ? null
                    : (value) => onTextChanged!(annotation.id, value),
                onDeleteRequested: onDeleteRequested == null
                    ? null
                    : () => onDeleteRequested!(annotation.id),
              ),
            ),
      ],
    );
  }
}

/// One row of [_AnnotationsSection]: the mark's own kind icon, a text field riding the mode's
/// autosave debounce, and a remove action.
class _AnnotationRow extends StatelessWidget {
  /// The mark this row shows.
  final OcptStoryboardAnnotation annotation;

  /// Whether this is the currently selected mark.
  final bool isSelected;

  /// The text field's current value.
  final String textValue;

  /// Whether the mode shows a project version being previewed read-only.
  final bool isReadOnly;

  /// Called when this row is clicked, selecting it, or null while withheld.
  final VoidCallback? onSelected;

  /// Called with the field's raw text on every keystroke, or null while withheld.
  final ValueChanged<String>? onTextChanged;

  /// Called when the remove action is clicked, or null while withheld.
  final VoidCallback? onDeleteRequested;

  /// Class constructor
  const _AnnotationRow({
    required this.annotation,
    required this.isSelected,
    required this.textValue,
    required this.isReadOnly,
    required this.onSelected,
    required this.onTextChanged,
    required this.onDeleteRequested,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    return InkWell(
      onTap: onSelected,
      mouseCursor: ocptClickableCursor,
      borderRadius: BorderRadius.circular(ocptRadiusMedium),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: ocptSelectedStateAlpha)
              : theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(ocptRadiusMedium),
          border: isSelected ? Border.all(color: theme.colorScheme.primary) : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 4, right: 8),
              child: Icon(_iconOf(annotation.kind), size: 16, color: _colorOf(theme, annotation.kind)),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _labelOf(tr, annotation.kind),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // `shotId` only ever tracks a switch of what this field is bound to (see its own
                  // doc comment) — the mark's own id serves that exact role here.
                  OcptShotInspectorField(
                    shotId: annotation.id,
                    label: "",
                    value: textValue,
                    hintText: tr.shotListBoardAnnotationTextHint,
                    onChanged: onTextChanged,
                  ),
                ],
              ),
            ),
            if (onDeleteRequested != null)
              IconButton(
                icon: Icon(Icons.delete_outline, size: 16, color: theme.colorScheme.error),
                tooltip: tr.shotListBoardRemoveAnnotationAction,
                visualDensity: VisualDensity.compact,
                onPressed: onDeleteRequested,
              ),
          ],
        ),
      ),
    );
  }

  /// The icon shown for [kind].
  IconData _iconOf(OcptStoryboardAnnotationKind kind) => switch (kind) {
    OcptStoryboardAnnotationKind.movementArrow => Icons.north_east,
    OcptStoryboardAnnotationKind.cameraMoveArrow => Icons.videocam_outlined,
    OcptStoryboardAnnotationKind.label => Icons.label_outline,
  };

  /// The colour [kind] is drawn with on the frame's own overlay — matches
  /// `OcptStoryboardAnnotationOverlay`'s own colour tokens, so a mark reads the same here as it
  /// does on the image.
  Color _colorOf(ThemeData theme, OcptStoryboardAnnotationKind kind) => switch (kind) {
    OcptStoryboardAnnotationKind.movementArrow => theme.colorScheme.primary,
    OcptStoryboardAnnotationKind.cameraMoveArrow => theme.colorScheme.tertiary,
    OcptStoryboardAnnotationKind.label => theme.colorScheme.secondary,
  };

  /// The localized label of [kind].
  String _labelOf(Tr tr, OcptStoryboardAnnotationKind kind) => switch (kind) {
    OcptStoryboardAnnotationKind.movementArrow => tr.shotListBoardAnnotationKindMovementArrow,
    OcptStoryboardAnnotationKind.cameraMoveArrow => tr.shotListBoardAnnotationKindCameraMoveArrow,
    OcptStoryboardAnnotationKind.label => tr.shotListBoardAnnotationKindLabel,
  };
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
