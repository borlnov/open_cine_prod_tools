// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/types/ocpt_breakdown_scene_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_status.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/events/breakdown_base_event.dart';

/// The events about the inspector: the selected scene's sheet, the selected target's sheet and the tags they remove.
sealed class OcptBreakdownInspectorEvent extends OcptBreakdownEvent {
  /// Class constructor
  const OcptBreakdownInspectorEvent();
}

/// Write a new breakdown status onto scene [sceneId] immediately, dispatched by a click on one of
/// `OcptBreakdownSceneInspector`'s own status chips.
class OcptBreakdownSceneStatusChangedEvent extends OcptBreakdownInspectorEvent {
  /// The id of the scene whose breakdown status changed.
  final String sceneId;

  /// The status just picked.
  final OcptBreakdownSceneStatus status;

  /// Class constructor
  const OcptBreakdownSceneStatusChangedEvent({required this.sceneId, required this.status});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, sceneId, status];
}

/// Record the raw text just typed into scene [sceneId]'s own breakdown notes field as a pending
/// edit, dispatched on every keystroke into `OcptBreakdownSceneInspector`'s notes field — rides the
/// same field-edit debounce as `OcptBreakdownElementFieldChangedEvent`.
class OcptBreakdownSceneNotesChangedEvent extends OcptBreakdownInspectorEvent {
  /// The id of the scene whose breakdown notes are being edited.
  final String sceneId;

  /// The field's raw text, as typed.
  final String rawValue;

  /// Class constructor
  const OcptBreakdownSceneNotesChangedEvent({required this.sceneId, required this.rawValue});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, sceneId, rawValue];
}

/// Write a new status onto element [elementId] immediately, dispatched by a click on one of
/// `OcptBreakdownTargetInspector`'s status chips.
class OcptBreakdownElementStatusChangedEvent extends OcptBreakdownInspectorEvent {
  /// The id of the element whose status changed.
  final String elementId;

  /// The status just picked.
  final OcptElementStatus status;

  /// Class constructor
  const OcptBreakdownElementStatusChangedEvent({required this.elementId, required this.status});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, elementId, status];
}

/// Write a new category onto element [elementId] immediately, dispatched by a click on one of
/// `OcptBreakdownTargetInspector`'s category chips.
class OcptBreakdownElementCategoryChangedEvent extends OcptBreakdownInspectorEvent {
  /// The id of the element whose category changed.
  final String elementId;

  /// The category just picked.
  final OcptElementCategory category;

  /// Class constructor
  const OcptBreakdownElementCategoryChangedEvent({required this.elementId, required this.category});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, elementId, category];
}

/// Record the raw text just typed into [field] of element [elementId] as a pending edit,
/// dispatched on every keystroke into one of `OcptBreakdownTargetInspector`'s Details fields.
class OcptBreakdownElementFieldChangedEvent extends OcptBreakdownInspectorEvent {
  /// The id of the element being edited.
  final String elementId;

  /// Which of the element's own fields is being edited — only `subCategory`, `quantity` and `notes`
  /// are ever named here, the target inspector's other fields being single picks written
  /// immediately by their own event.
  final OcptElementField field;

  /// The field's raw text, as typed.
  final String rawValue;

  /// Class constructor
  const OcptBreakdownElementFieldChangedEvent({
    required this.elementId,
    required this.field,
    required this.rawValue,
  });

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, elementId, field, rawValue];
}

/// Fired by the field-edit debounce timer once it elapses with no further typing: writes every
/// pending element field edit.
///
/// Not meant to be dispatched by a widget; the bloc dispatches it itself.
class OcptBreakdownFieldEditFlushRequestedEvent extends OcptBreakdownInspectorEvent {
  /// Class constructor
  const OcptBreakdownFieldEditFlushRequestedEvent();
}

/// Write a new owner onto element [elementId] immediately, dispatched by
/// `OcptBreakdownTargetInspector`'s own owner picker.
class OcptBreakdownElementOwnerChangedEvent extends OcptBreakdownInspectorEvent {
  /// The id of the element whose owner changed.
  final String elementId;

  /// The id of the person just picked, or null to clear the owner.
  final String? personId;

  /// Class constructor
  const OcptBreakdownElementOwnerChangedEvent({required this.elementId, required this.personId});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, elementId, personId];
}

/// Write a new who-brings-it onto element [elementId] immediately, dispatched by
/// `OcptBreakdownTargetInspector`'s own who-brings-it picker.
class OcptBreakdownElementBringerChangedEvent extends OcptBreakdownInspectorEvent {
  /// The id of the element whose who-brings-it changed.
  final String elementId;

  /// The id of the person just picked, or null to clear it.
  final String? personId;

  /// Class constructor
  const OcptBreakdownElementBringerChangedEvent({required this.elementId, required this.personId});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, elementId, personId];
}

/// Say scene [sceneId] is shot in set [setId], dispatched by the scene inspector's own sets
/// picker.
///
/// **Not** a tagging: no passage of the script is involved, no tag is created, and nothing is
/// highlighted. It writes the `scene_sets` link alone — the very link the resources mode's own
/// location sheet writes from the other side — so a scene may name its décor without a word of the
/// screenplay having to spell it.
class OcptBreakdownSceneSetLinkedEvent extends OcptBreakdownInspectorEvent {
  /// The id of the scene shot in [setId].
  final String sceneId;

  /// The id of the set it is shot in.
  final String setId;

  /// Class constructor
  const OcptBreakdownSceneSetLinkedEvent({required this.sceneId, required this.setId});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, sceneId, setId];
}

/// Rename set [setId] to [rawValue], dispatched on every keystroke of the target inspector's own
/// title while a set is selected.
///
/// The set sibling of [OcptBreakdownElementFieldChangedEvent], and it rides the very same debounce:
/// a set has no sheet of its own here, only the name the popover gave it after the passage that
/// named it, which is exactly what the title is for.
class OcptBreakdownSetNameChangedEvent extends OcptBreakdownInspectorEvent {
  /// The id of the set being renamed.
  final String setId;

  /// The raw text the title field now holds.
  final String rawValue;

  /// Class constructor
  const OcptBreakdownSetNameChangedEvent({required this.setId, required this.rawValue});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, setId, rawValue];
}

/// Create a set named [name] inside location [locationId] — or inside a location minted along with
/// it when that is null — and say scene [sceneId] is shot in it, dispatched by the scene
/// inspector's own `Create a set…` control.
///
/// The sibling of `OcptBreakdownPopoverSetCreationRequestedEvent` for the sheet rather than the
/// script: it writes **no tag**, there being no passage involved, and [name] is the place the
/// scene's own heading names rather than a passage the user selected.
class OcptBreakdownSceneSetCreationRequestedEvent extends OcptBreakdownInspectorEvent {
  /// The id of the scene the new set is shot in.
  final String sceneId;

  /// The location holding the new set, or null to mint one named [name] to hold it.
  final String? locationId;

  /// The name the new set is given.
  final String name;

  /// Class constructor
  const OcptBreakdownSceneSetCreationRequestedEvent({
    required this.sceneId,
    required this.locationId,
    required this.name,
  });

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, sceneId, locationId, name];
}

/// Say scene [sceneId] is no longer shot in set [setId], dispatched by one of the scene
/// inspector's own set chips being dismissed.
///
/// Drops the `scene_sets` link alone and **leaves every tag pointing at that set exactly where it
/// is**: a tag is a passage of the script, the link is a fact about the scene, and
/// `OcptBreakdownService.deleteTag` already refuses to conflate the two from the other side.
class OcptBreakdownSceneSetUnlinkedEvent extends OcptBreakdownInspectorEvent {
  /// The id of the scene no longer shot in [setId].
  final String sceneId;

  /// The id of the set it is no longer shot in.
  final String setId;

  /// Class constructor
  const OcptBreakdownSceneSetUnlinkedEvent({required this.sceneId, required this.setId});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, sceneId, setId];
}

/// Remove the selected target's tags from the selected scene for good, dispatched by the mode once
/// its `OcptConfirmDialog` — opened by `OcptBreakdownTargetInspector`'s own `Remove from the
/// breakdown` action — has already been answered.
class OcptBreakdownTagRemovalConfirmedEvent extends OcptBreakdownInspectorEvent {
  /// Class constructor
  const OcptBreakdownTagRemovalConfirmedEvent();
}

/// Clear `needsCheck` on tag [tagId], dispatched by `OcptBreakdownSceneInspector`'s own "to check"
/// alert's `Mark as checked` action.
///
/// A single pick, not typing, so it is written immediately and rides no field-edit debounce, and
/// it acts straight away with no further confirmation: the alert itself is the question, exactly
/// as `OcptRoleAlertBanner`'s own `Keep as silent` action does.
class OcptBreakdownTagNeedsCheckClearedEvent extends OcptBreakdownInspectorEvent {
  /// The id of the tag whose flag is cleared.
  final String tagId;

  /// Class constructor
  const OcptBreakdownTagNeedsCheckClearedEvent({required this.tagId});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, tagId];
}

/// Remove tag [tagId] for good, dispatched by `OcptBreakdownSceneInspector`'s own "to check"
/// alert's `Remove` action.
///
/// Mirrors [OcptBreakdownTagNeedsCheckClearedEvent] in every respect but the write it performs:
/// acts straight away, with no inline confirmation of its own — this is a different tag-removal
/// path than [OcptBreakdownTagRemovalConfirmedEvent], which answers a two-step confirmation asked
/// about the *selected target's* tags; this one answers the "to check" alert's own row, named by
/// its tag id directly, and needs none.
class OcptBreakdownFlaggedTagRemovedEvent extends OcptBreakdownInspectorEvent {
  /// The id of the tag to remove.
  final String tagId;

  /// Class constructor
  const OcptBreakdownFlaggedTagRemovedEvent({required this.tagId});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, tagId];
}
