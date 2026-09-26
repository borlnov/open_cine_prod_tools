// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_editable_field.dart';

/// The key of one entry of `OcptShotListState.pendingFieldEdits`: what a typed value still sitting
/// in the mode's 2 s autosave debounce is destined to write onto once it flushes.
///
/// A sealed class rather than the `(String, OcptShotListEditableField)` record the shot list mode
/// used before the board existed: the debounce is shared by every free-text field the mode owns,
/// and the board's panel comment ([OcptShotListPanelCommentEditKey]) and a mark's own text
/// ([OcptShotListAnnotationTextEditKey]) are not shot fields at all. M5 (the floor plans view's
/// sequence half, `docs/plans/storyboard.md`) adds [OcptShotListSetNameEditKey], typed in place
/// into a case's own tab. M6 (the shot half) adds [OcptShotListSymbolLabelEditKey], typed in place
/// through the canvas's own `label` tool.
///
/// [Equatable]'s structural `==`/`hashCode` (over [props]) is what lets a value of this type key a
/// `Map` the same way the record it replaces already did.
sealed class OcptShotListPendingEditKey extends Equatable {
  /// Class constructor
  const OcptShotListPendingEditKey();
}

/// A pending edit of case [setId]'s own name, typed in place into its floor plans tab.
class OcptShotListSetNameEditKey extends OcptShotListPendingEditKey {
  /// The id of the case whose name is being edited.
  final String setId;

  /// Class constructor
  const OcptShotListSetNameEditKey({required this.setId});

  /// Object properties
  @override
  List<Object?> get props => [setId];
}

/// A pending edit of shot [shotId]'s [field] — the mode's original, and still only, kind of pending
/// shot list edit.
class OcptShotListShotFieldEditKey extends OcptShotListPendingEditKey {
  /// The id of the shot whose field is being edited.
  final String shotId;

  /// The field being edited.
  final OcptShotListEditableField field;

  /// Class constructor
  const OcptShotListShotFieldEditKey({required this.shotId, required this.field});

  /// Object properties
  @override
  List<Object?> get props => [shotId, field];
}

/// A pending edit of panel [panelId]'s free comment, typed into the board's inspector Panels group.
class OcptShotListPanelCommentEditKey extends OcptShotListPendingEditKey {
  /// The id of the panel whose comment is being edited.
  final String panelId;

  /// Class constructor
  const OcptShotListPanelCommentEditKey({required this.panelId});

  /// Object properties
  @override
  List<Object?> get props => [panelId];
}

/// A pending edit of mark [annotationId]'s own text — a label's text, or an arrow's optional
/// caption — typed into the board's inspector Panels group's own annotation section.
class OcptShotListAnnotationTextEditKey extends OcptShotListPendingEditKey {
  /// The id of the mark whose text is being edited.
  final String annotationId;

  /// Class constructor
  const OcptShotListAnnotationTextEditKey({required this.annotationId});

  /// Object properties
  @override
  List<Object?> get props => [annotationId];
}

/// A pending edit of floor plan symbol [symbolId]'s own free-text label, typed in place through
/// the canvas's own `label` tool.
class OcptShotListSymbolLabelEditKey extends OcptShotListPendingEditKey {
  /// The id of the symbol whose label is being edited.
  final String symbolId;

  /// Class constructor
  const OcptShotListSymbolLabelEditKey({required this.symbolId});

  /// Object properties
  @override
  List<Object?> get props => [symbolId];
}
