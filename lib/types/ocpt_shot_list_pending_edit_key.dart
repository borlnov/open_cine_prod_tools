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
/// ([OcptShotListAnnotationTextEditKey]) are not shot fields at all. M5/M6 (the floor plans view,
/// `docs/plans/storyboard.md`) add `symbolLabel`/`caseName` cases of their own here — deliberately
/// not added by this milestone, since neither has a write path yet and a case with nothing to
/// flush into would be a dead branch in every `switch` over this type.
///
/// [Equatable]'s structural `==`/`hashCode` (over [props]) is what lets a value of this type key a
/// `Map` the same way the record it replaces already did.
sealed class OcptShotListPendingEditKey extends Equatable {
  /// Class constructor
  const OcptShotListPendingEditKey();
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
