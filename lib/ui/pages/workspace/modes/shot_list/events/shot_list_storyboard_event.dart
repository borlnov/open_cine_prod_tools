// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/types/ocpt_storyboard_annotation_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_storyboard_annotation_tool.dart';
import 'package:open_cine_prod_tools/types/ocpt_storyboard_panel_size.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/events/shot_list_base_event.dart';

/// The events of `OcptShotListStoryboardBloc`, about the storyboard board and its annotations.
sealed class OcptShotListStoryboardEvent extends OcptShotListEvent {
  /// Class constructor
  const OcptShotListStoryboardEvent();
}

/// Select panel [panelId] on the board, dispatched by a click on one of the selected shot's own
/// `OcptStoryboardPanelFrame`s.
class OcptShotListPanelSelectedEvent extends OcptShotListStoryboardEvent {
  /// The id of the panel to select.
  final String panelId;

  /// Class constructor
  const OcptShotListPanelSelectedEvent({required this.panelId});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, panelId];
}

/// Set the board's common panel height to [size], dispatched by the header's own `Panel size ▾`
/// menu. A **view preference**, held in state for the session alone — never persisted.
class OcptShotListPanelSizeChangedEvent extends OcptShotListStoryboardEvent {
  /// The panel size just picked.
  final OcptStoryboardPanelSize size;

  /// Class constructor
  const OcptShotListPanelSizeChangedEvent({required this.size});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, size];
}

/// Request importing a frame onto shot [shotId]'s storyboard, dispatched by its panel strip's
/// trailing `Import frame` slot.
///
/// The bloc picks the file through `FileSelectorManager`, filtered to JPEG and PNG
/// (`ocptStoryboardPanelImageFileExtensions`), then appends a new panel carrying it. A cancelled
/// dialog changes nothing at all. [fileTypeLabel] is the localized label the native picker's own
/// file type filter shows, resolved by the mode — the bloc has no `BuildContext` of its own.
class OcptShotListPanelImportRequestedEvent extends OcptShotListStoryboardEvent {
  /// The id of the shot the new panel is appended to.
  final String shotId;

  /// The localized label of the picker's own file type filter.
  final String fileTypeLabel;

  /// Class constructor
  const OcptShotListPanelImportRequestedEvent({required this.shotId, required this.fileTypeLabel});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, shotId, fileTypeLabel];
}

/// Request replacing panel [panelId]'s image, dispatched by its frame's own `Replace image`
/// action.
///
/// The same picker [OcptShotListPanelImportRequestedEvent] uses; a cancelled dialog leaves the
/// panel's current image untouched. See [OcptShotListPanelImportRequestedEvent] for
/// [fileTypeLabel].
class OcptShotListPanelReplaceRequestedEvent extends OcptShotListStoryboardEvent {
  /// The id of the panel whose image is replaced.
  final String panelId;

  /// The localized label of the picker's own file type filter.
  final String fileTypeLabel;

  /// Class constructor
  const OcptShotListPanelReplaceRequestedEvent({
    required this.panelId,
    required this.fileTypeLabel,
  });

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, panelId, fileTypeLabel];
}

/// Move panel [panelId] of shot [shotId] to [newPosition] (0-based) among its shot's other panels,
/// dispatched by the strip's own drag-to-reorder gesture. Written immediately, one row
/// (`OcptStoryboardService.reorderPanel`).
class OcptShotListPanelReorderedEvent extends OcptShotListStoryboardEvent {
  /// The id of the shot the panel belongs to.
  final String shotId;

  /// The id of the panel being moved.
  final String panelId;

  /// The 0-based position the panel is moved to.
  final int newPosition;

  /// Class constructor
  const OcptShotListPanelReorderedEvent({
    required this.shotId,
    required this.panelId,
    required this.newPosition,
  });

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, shotId, panelId, newPosition];
}

/// Record the raw text just typed into panel [panelId]'s free comment, dispatched by the
/// inspector's Panels group on every keystroke.
///
/// Rides the mode's own field-edit autosave debounce exactly as
/// `OcptShotListShotFieldChangedEvent` does, keyed by `OcptShotListPanelCommentEditKey` rather than
/// `OcptShotListShotFieldEditKey`.
class OcptShotListPanelCommentChangedEvent extends OcptShotListStoryboardEvent {
  /// The id of the panel whose comment was edited.
  final String panelId;

  /// The comment's raw text, exactly as typed.
  final String rawValue;

  /// Class constructor
  const OcptShotListPanelCommentChangedEvent({required this.panelId, required this.rawValue});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, panelId, rawValue];
}

/// Request deleting panel [panelId] for good, dispatched once the inspector's Panels group's own
/// `Delete panel` action has already been confirmed through `OcptConfirmDialog`, by the mode.
class OcptShotListPanelDeletionRequestedEvent extends OcptShotListStoryboardEvent {
  /// The id of the panel to delete.
  final String panelId;

  /// Class constructor
  const OcptShotListPanelDeletionRequestedEvent({required this.panelId});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, panelId];
}

/// Set the board's active annotation tool to [tool], dispatched by the inspector's own `Annotate`
/// control, or clear it (null) when the tool already on is picked again. Scoped to the currently
/// selected panel — see `OcptShotListState.activeAnnotationTool`'s own doc comment for when it is
/// cleared on its own.
class OcptShotListAnnotationToolSelectedEvent extends OcptShotListStoryboardEvent {
  /// The tool just picked, or null to turn annotation editing off.
  final OcptStoryboardAnnotationTool? tool;

  /// Class constructor
  const OcptShotListAnnotationToolSelectedEvent({required this.tool});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, tool];
}

/// Add a mark of [kind] to panel [panelId] at the normalised tail/head `(x1, y1)`-`(x2, y2)`,
/// dispatched once a drag over the selected panel's own frame finishes drawing an arrow. Written
/// immediately, then selects the freshly minted mark (`OcptStoryboardService.addAnnotation`).
class OcptShotListAnnotationDrawnEvent extends OcptShotListStoryboardEvent {
  /// The id of the panel the mark is added to.
  final String panelId;

  /// The kind of mark just drawn (one of the two arrow kinds — a label is placed by
  /// [OcptShotListAnnotationPlacedEvent] instead).
  final OcptStoryboardAnnotationKind kind;

  /// The arrow's tail X coordinate, normalised 0..1 to the frame.
  final double x1;

  /// The arrow's tail Y coordinate, normalised 0..1 to the frame.
  final double y1;

  /// The arrow's head X coordinate, normalised 0..1 to the frame.
  final double x2;

  /// The arrow's head Y coordinate, normalised 0..1 to the frame.
  final double y2;

  /// Class constructor
  const OcptShotListAnnotationDrawnEvent({
    required this.panelId,
    required this.kind,
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
  });

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, panelId, kind, x1, y1, x2, y2];
}

/// Place a [OcptStoryboardAnnotationKind.label] on panel [panelId] at the normalised point
/// `(x1, y1)`, dispatched by a click over the selected panel's own frame while the label tool is
/// on. Written immediately, then selects the freshly minted mark so its text field opens ready
/// for typing (`OcptStoryboardService.addAnnotation`).
class OcptShotListAnnotationPlacedEvent extends OcptShotListStoryboardEvent {
  /// The id of the panel the label is added to.
  final String panelId;

  /// The label's anchor X coordinate, normalised 0..1 to the frame.
  final double x1;

  /// The label's anchor Y coordinate, normalised 0..1 to the frame.
  final double y1;

  /// Class constructor
  const OcptShotListAnnotationPlacedEvent({
    required this.panelId,
    required this.x1,
    required this.y1,
  });

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, panelId, x1, y1];
}

/// Select mark [annotationId], dispatched by a click on it (either on the frame's own overlay, or
/// on its row of the inspector Panels group's annotation section).
class OcptShotListAnnotationSelectedEvent extends OcptShotListStoryboardEvent {
  /// The id of the mark to select.
  final String annotationId;

  /// Class constructor
  const OcptShotListAnnotationSelectedEvent({required this.annotationId});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, annotationId];
}

/// Record the raw text just typed into mark [annotationId]'s own text — a label's text, or an
/// arrow's optional caption — dispatched by the annotation section's own text field on every
/// keystroke. Rides the mode's field-edit autosave debounce, keyed by
/// `OcptShotListAnnotationTextEditKey`.
class OcptShotListAnnotationTextChangedEvent extends OcptShotListStoryboardEvent {
  /// The id of the mark whose text was edited.
  final String annotationId;

  /// The text's raw value, exactly as typed.
  final String rawValue;

  /// Class constructor
  const OcptShotListAnnotationTextChangedEvent({
    required this.annotationId,
    required this.rawValue,
  });

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, annotationId, rawValue];
}

/// Request deleting mark [annotationId] for good, dispatched once the annotation section's own
/// remove action has already been confirmed through `OcptConfirmDialog`, by the mode.
class OcptShotListAnnotationDeletionRequestedEvent extends OcptShotListStoryboardEvent {
  /// The id of the mark to delete.
  final String annotationId;

  /// Class constructor
  const OcptShotListAnnotationDeletionRequestedEvent({required this.annotationId});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, annotationId];
}

/// Request writing every panel comment and mark text still sitting in the board's autosave
/// debounce, dispatched by the bloc itself once the delay since the last keystroke has elapsed.
class OcptShotListStoryboardFieldEditFlushRequestedEvent extends OcptShotListStoryboardEvent {
  /// Class constructor
  const OcptShotListStoryboardFieldEditFlushRequestedEvent();
}

/// Dismiss the transient write error the board currently shows, if any.
class OcptShotListStoryboardWriteErrorDismissedEvent extends OcptShotListStoryboardEvent {
  /// Class constructor
  const OcptShotListStoryboardWriteErrorDismissedEvent();
}
