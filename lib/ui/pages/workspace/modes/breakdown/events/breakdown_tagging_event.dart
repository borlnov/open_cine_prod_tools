// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/types/ocpt_breakdown_target_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/events/breakdown_base_event.dart';

/// The events about tagging the script: the range interaction, the popover and the suggestions.
sealed class OcptBreakdownTaggingEvent extends OcptBreakdownEvent {
  /// Class constructor
  const OcptBreakdownTaggingEvent();
}

/// Records a click on a word of the script view that overlaps no live tag, or one whose tag's
/// target has been dropped from the snapshot, dispatched by `OcptBreakdownScriptView`.
///
/// Drives the range interaction: with no pending anchor, or one in another scene, this word becomes
/// the (new) anchor; with an anchor already open in this very scene, it closes the range on the two
/// — order-insensitive — and opens the popover, unless doing so would overlap a live tag, in which
/// case the anchor is kept and nothing else changes. See `OcptBreakdownBloc`'s own handler for the
/// full rules.
class OcptBreakdownWordClickedEvent extends OcptBreakdownTaggingEvent {
  /// The id of the scene the clicked word belongs to.
  final String sceneId;

  /// The scene-relative offset at which the clicked word starts.
  final int wordStartOffset;

  /// The scene-relative offset one past the clicked word's last character.
  final int wordEndOffset;

  /// Class constructor
  const OcptBreakdownWordClickedEvent({
    required this.sceneId,
    required this.wordStartOffset,
    required this.wordEndOffset,
  });

  /// Object properties
  @override
  List<Object?> get props => [...super.props, sceneId, wordStartOffset, wordEndOffset];
}

/// Clears the pending anchor and the closed range alike, dispatched by the tag popover's own ×
/// close button, by `Escape` while it is focused, or by a tap outside it — the user changed their
/// mind about the passage itself, not just about where to send it.
class OcptBreakdownTagRangeCancelledEvent extends OcptBreakdownTaggingEvent {
  /// Class constructor
  const OcptBreakdownTagRangeCancelledEvent();
}

/// Links `OcptBreakdownState.pendingTagRange`'s own passage to the existing
/// [targetKind]/[targetId], dispatched by a click on one of the tag popover's own match rows.
class OcptBreakdownPopoverTargetLinkedEvent extends OcptBreakdownTaggingEvent {
  /// The kind of the target the passage is linked to.
  final OcptBreakdownTargetKind targetKind;

  /// The id of the target the passage is linked to.
  final String targetId;

  /// Class constructor
  const OcptBreakdownPopoverTargetLinkedEvent({required this.targetKind, required this.targetId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, targetKind, targetId];
}

/// Creates a new element of [category] named [name] and tags `OcptBreakdownState.pendingTagRange`'s
/// own passage with it, in one write, dispatched by a click on one of the tag popover's own
/// category chips.
class OcptBreakdownPopoverElementCreationRequestedEvent extends OcptBreakdownTaggingEvent {
  /// The category the new element is created in.
  final OcptElementCategory category;

  /// The new element's own name, read off the popover's search field at the moment the chip was
  /// clicked.
  final String name;

  /// Class constructor
  const OcptBreakdownPopoverElementCreationRequestedEvent({
    required this.category,
    required this.name,
  });

  /// Object properties
  @override
  List<Object?> get props => [...super.props, category, name];
}

/// Creates a new set named [name], inside location [locationId] or inside one minted along with it
/// when that is null, and tags `OcptBreakdownState.pendingTagRange`'s own passage with it, in one
/// write — dispatched by the tag popover's own `Create a set` control.
///
/// The sibling of [OcptBreakdownPopoverElementCreationRequestedEvent], for the second and last
/// thing the breakdown pass may bring into existence: see `OcptBreakdownTagPopover`'s own doc
/// comment for why a role is not one of them.
class OcptBreakdownPopoverSetCreationRequestedEvent extends OcptBreakdownTaggingEvent {
  /// The id of the location holding the new set, or null for a location minted along with it and
  /// named after it.
  final String? locationId;

  /// The new set's own name, read off the popover's search field at the moment the control was
  /// answered.
  final String name;

  /// Class constructor
  const OcptBreakdownPopoverSetCreationRequestedEvent({
    required this.locationId,
    required this.name,
  });

  /// Object properties
  @override
  List<Object?> get props => [...super.props, locationId, name];
}

/// Dismisses the transient notice that the last tag write — the popover's own link or element
/// creation, or a suggestion accepted from the target inspector — was refused.
class OcptBreakdownTagWriteErrorDismissedEvent extends OcptBreakdownTaggingEvent {
  /// Class constructor
  const OcptBreakdownTagWriteErrorDismissedEvent();
}

/// Tags one of the selected target's own suggested occurrences (`OcptBreakdownSuggestion`),
/// dispatched by a click on the add control of one of `OcptBreakdownTargetInspector`'s own
/// "Suggested occurrences" rows — the writer's second route onto
/// `OcptBreakdownService.createTag`, [OcptBreakdownPopoverTargetLinkedEvent] being the first, and
/// the field this event carries mirror the passage a `OcptBreakdownSuggestion` itself names, so a
/// widget passing one along never has to unpack it further.
class OcptBreakdownSuggestionAcceptedEvent extends OcptBreakdownTaggingEvent {
  /// The kind of the target the suggestion is accepted for.
  final OcptBreakdownTargetKind targetKind;

  /// The id of the target the suggestion is accepted for.
  final String targetId;

  /// The id of the scene the suggested passage falls in.
  final String sceneId;

  /// The scene-relative offset at which the suggested passage starts.
  final int startOffset;

  /// The scene-relative offset one past the suggested passage's last character.
  final int endOffset;

  /// The suggested passage, verbatim, as it reads in the scene right now.
  final String taggedText;

  /// Class constructor
  const OcptBreakdownSuggestionAcceptedEvent({
    required this.targetKind,
    required this.targetId,
    required this.sceneId,
    required this.startOffset,
    required this.endOffset,
    required this.taggedText,
  });

  /// Object properties
  @override
  List<Object?> get props => [
    ...super.props,
    targetKind,
    targetId,
    sceneId,
    startOffset,
    endOffset,
    taggedText,
  ];
}
