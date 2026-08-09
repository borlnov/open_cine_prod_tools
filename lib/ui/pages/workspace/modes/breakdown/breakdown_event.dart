// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_sheets_export_options.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_sheets_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_xlsx_labels.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_centre_view.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_right_dock_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_scene_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_target_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_status.dart';
import 'package:open_cine_prod_tools/utils/ocpt_breakdown_legend.dart';

/// The events handled by `OcptBreakdownBloc`.
sealed class OcptBreakdownEvent extends BlocEventForMixin {
  /// Class constructor
  const OcptBreakdownEvent();
}

/// Requests loading the current project's whole breakdown read: the screenplay text, the scenes
/// with their tags, and the three catalogues resolved into targets.
///
/// This is dispatched once by the bloc's own constructor; it isn't meant to be sent by widgets.
class OcptBreakdownLoadRequestedEvent extends OcptBreakdownEvent {
  /// Class constructor
  const OcptBreakdownLoadRequestedEvent();
}

/// Requests leaving the workspace: closes the current project and navigates back to the home page.
class OcptBreakdownBackRequestedEvent extends OcptBreakdownEvent {
  /// Class constructor
  const OcptBreakdownBackRequestedEvent();
}

/// Reports that the project settings page was closed after changing something.
///
/// Re-reads the page setup the script view is typeset with: nothing in the snapshot itself depends
/// on the page format, but reloading it here too is what keeps this mode from being the one place a
/// change made on the project settings page is silently missed, mirroring
/// `OcptShotListBloc`'s own handler.
class OcptBreakdownProjectSettingsChangedEvent extends OcptBreakdownEvent {
  /// Class constructor
  const OcptBreakdownProjectSettingsChangedEvent();
}

/// Selects scene [sceneId], dispatched by a row of `OcptBreakdownScenePanel` — the left dock's own
/// list, which selects a scene without touching the right dock.
///
/// A scene id that no longer exists in the current snapshot (a stale click on a list rebuilt
/// underneath) is ignored rather than selecting nothing.
class OcptBreakdownSceneSelectedEvent extends OcptBreakdownEvent {
  /// The id of the scene to select.
  final String sceneId;

  /// Class constructor
  const OcptBreakdownSceneSelectedEvent({required this.sceneId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, sceneId];
}

/// Selects scene [sceneId] **and shows its own breakdown sheet**, dispatched by a click on one of
/// `OcptBreakdownScriptView`'s own heading rows.
///
/// The centre views' own convention, which [OcptBreakdownTargetSelectedEvent] already follows for a
/// tagged word and the recap table for a row: a click in the script lands the user on the sheet of
/// whatever they clicked, without a second gesture. So this additionally drops the selected target
/// — the scene's sheet is what the inspector shows precisely while no target is selected — and
/// opens the right dock on its `Inspector` tab. The left dock's own list deliberately does neither
/// (see [OcptBreakdownSceneSelectedEvent]): browsing scenes there is reading, not asking for a
/// sheet.
class OcptBreakdownSceneHeadingSelectedEvent extends OcptBreakdownEvent {
  /// The id of the scene whose heading was clicked.
  final String sceneId;

  /// Class constructor
  const OcptBreakdownSceneHeadingSelectedEvent({required this.sceneId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, sceneId];
}

/// Toggles the left (scene) dock's visibility.
class OcptBreakdownLeftPanelToggledEvent extends OcptBreakdownEvent {
  /// Class constructor
  const OcptBreakdownLeftPanelToggledEvent();
}

/// Selects a tab of the right dock (the already-active tab closes the dock, any other one opens or
/// switches to it).
class OcptBreakdownRightDockTabSelectedEvent extends OcptBreakdownEvent {
  /// The tab to select.
  final OcptBreakdownRightDockTab tab;

  /// Class constructor
  const OcptBreakdownRightDockTabSelectedEvent({required this.tab});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, tab];
}

/// Toggles the right dock from the workspace toolbar: an open dock closes, a closed one reopens on
/// its single tab.
class OcptBreakdownRightDockToggledEvent extends OcptBreakdownEvent {
  /// Class constructor
  const OcptBreakdownRightDockToggledEvent();
}

/// Closes the right dock via its own × close button.
class OcptBreakdownRightDockClosedEvent extends OcptBreakdownEvent {
  /// Class constructor
  const OcptBreakdownRightDockClosedEvent();
}

/// Applies and persists whichever dock fraction the ended drag gesture reports.
///
/// Only one of [left]/[right] is ever non-null per event, mirroring how the shell's own
/// `onDockFractionsChanged` callback is shaped.
class OcptBreakdownDockFractionsChangedEvent extends OcptBreakdownEvent {
  /// The left dock's new fraction, or null when the drag was on the right divider.
  final double? left;

  /// The right dock's new fraction, or null when the drag was on the left divider.
  final double? right;

  /// Class constructor
  const OcptBreakdownDockFractionsChangedEvent({required this.left, required this.right});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, left, right];
}

/// Restores both dock fractions to their defaults, persisting them.
class OcptBreakdownDockLayoutResetEvent extends OcptBreakdownEvent {
  /// Class constructor
  const OcptBreakdownDockLayoutResetEvent();
}

/// Toggles whether legend key [key] is hidden from the script view's own highlighting, dispatched by
/// a row of `OcptBreakdownCategoryLegend`.
///
/// A reading aid for the pass in progress alone: the hidden set this event grows or shrinks is never
/// persisted, unlike the two dock fractions above.
class OcptBreakdownLegendEntryToggledEvent extends OcptBreakdownEvent {
  /// The legend key whose hidden state is toggled.
  final OcptBreakdownLegendKey key;

  /// Class constructor
  const OcptBreakdownLegendEntryToggledEvent({required this.key});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, key];
}

/// Reveals every legend key currently hidden from the script view's own highlighting, dispatched by
/// `OcptBreakdownCategoryLegend`'s own `Show all` action.
class OcptBreakdownLegendShowAllRequestedEvent extends OcptBreakdownEvent {
  /// Class constructor
  const OcptBreakdownLegendShowAllRequestedEvent();
}

/// Selects which of the two views (script or recap) the mode's centre shows, dispatched by the
/// header's own `Script`/`Recap` switch.
///
/// Clears any pending tag anchor and pending range: the popover a range interaction might be
/// driving has no script sheet left to close over once the centre leaves it — there is nothing to
/// close them on when the sheet is gone.
class OcptBreakdownCentreViewSelectedEvent extends OcptBreakdownEvent {
  /// The view to select.
  final OcptBreakdownCentreView view;

  /// Class constructor
  const OcptBreakdownCentreViewSelectedEvent({required this.view});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, view];
}

/// Records the header's own search field text as typed, dispatched on every keystroke.
///
/// The moment [query] turns non-empty while the script view is active, the bloc switches the
/// centre to the recap in the same emitted state — carrying the just-typed text into the view that
/// actually answers it — and clears any pending tag anchor and pending range, for the same reason
/// [OcptBreakdownCentreViewSelectedEvent] does. Clearing the field back to empty afterward does
/// **not** switch back to the script view: a user who read the recap and cleared the field to widen
/// it again is browsing the table, not asking to leave it.
class OcptBreakdownSearchQueryChangedEvent extends OcptBreakdownEvent {
  /// The field's raw text, as typed.
  final String query;

  /// Class constructor
  const OcptBreakdownSearchQueryChangedEvent({required this.query});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, query];
}

/// Selects target [targetKind]/[targetId] in the inspector, dispatched by a click on one of its
/// tagged words in `OcptBreakdownScriptView` — [sceneId] is the scene that click happened in, which
/// this event also selects, so the left dock and the sheet stay in step. Opens the right dock on the
/// `Inspector` tab.
///
/// Selecting writes nothing to the project database, so this is never withheld for a previewed
/// version's sake.
class OcptBreakdownTargetSelectedEvent extends OcptBreakdownEvent {
  /// The kind of the target to select.
  final OcptBreakdownTargetKind targetKind;

  /// The id of the target to select.
  final String targetId;

  /// The id of the scene the click happened in.
  final String sceneId;

  /// Class constructor
  const OcptBreakdownTargetSelectedEvent({
    required this.targetKind,
    required this.targetId,
    required this.sceneId,
  });

  /// Object properties
  @override
  List<Object?> get props => [...super.props, targetKind, targetId, sceneId];
}

/// Clears the currently selected target, dispatched by `OcptBreakdownTargetInspector`'s own
/// "back to the scene" affordance.
class OcptBreakdownTargetSelectionClearedEvent extends OcptBreakdownEvent {
  /// Class constructor
  const OcptBreakdownTargetSelectionClearedEvent();
}

/// Records a click on a word of the script view that overlaps no live tag, or one whose tag's target
/// has been dropped from the snapshot, dispatched by `OcptBreakdownScriptView`.
///
/// Drives the range interaction: with no pending anchor, or one in another scene, this word becomes
/// the (new) anchor; with an anchor already open in this very scene, it closes the range on the two
/// — order-insensitive — and opens the popover, unless doing so would overlap a live tag, in which
/// case the anchor is kept and nothing else changes. See `OcptBreakdownBloc`'s own handler for the
/// full rules.
class OcptBreakdownWordClickedEvent extends OcptBreakdownEvent {
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

/// Selects the scene of one of the selected target's occurrences, dispatched by a row of
/// `OcptBreakdownTargetInspector`'s own occurrences section.
class OcptBreakdownOccurrenceSelectedEvent extends OcptBreakdownEvent {
  /// The id of the occurrence's own scene.
  final String sceneId;

  /// Class constructor
  const OcptBreakdownOccurrenceSelectedEvent({required this.sceneId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, sceneId];
}

/// Writes a new breakdown status onto scene [sceneId] immediately, dispatched by a click on one of
/// `OcptBreakdownSceneInspector`'s own status chips.
class OcptBreakdownSceneStatusChangedEvent extends OcptBreakdownEvent {
  /// The id of the scene whose breakdown status changed.
  final String sceneId;

  /// The status just picked.
  final OcptBreakdownSceneStatus status;

  /// Class constructor
  const OcptBreakdownSceneStatusChangedEvent({required this.sceneId, required this.status});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, sceneId, status];
}

/// Records the raw text just typed into scene [sceneId]'s own breakdown notes field as a pending
/// edit, dispatched on every keystroke into `OcptBreakdownSceneInspector`'s notes field — rides the
/// same field-edit debounce as `OcptBreakdownElementFieldChangedEvent`.
class OcptBreakdownSceneNotesChangedEvent extends OcptBreakdownEvent {
  /// The id of the scene whose breakdown notes are being edited.
  final String sceneId;

  /// The field's raw text, as typed.
  final String rawValue;

  /// Class constructor
  const OcptBreakdownSceneNotesChangedEvent({required this.sceneId, required this.rawValue});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, sceneId, rawValue];
}

/// Writes a new status onto element [elementId] immediately, dispatched by a click on one of
/// `OcptBreakdownTargetInspector`'s status chips.
class OcptBreakdownElementStatusChangedEvent extends OcptBreakdownEvent {
  /// The id of the element whose status changed.
  final String elementId;

  /// The status just picked.
  final OcptElementStatus status;

  /// Class constructor
  const OcptBreakdownElementStatusChangedEvent({required this.elementId, required this.status});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, elementId, status];
}

/// Writes a new category onto element [elementId] immediately, dispatched by a click on one of
/// `OcptBreakdownTargetInspector`'s category chips.
class OcptBreakdownElementCategoryChangedEvent extends OcptBreakdownEvent {
  /// The id of the element whose category changed.
  final String elementId;

  /// The category just picked.
  final OcptElementCategory category;

  /// Class constructor
  const OcptBreakdownElementCategoryChangedEvent({required this.elementId, required this.category});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, elementId, category];
}

/// Records the raw text just typed into [field] of element [elementId] as a pending edit, dispatched
/// on every keystroke into one of `OcptBreakdownTargetInspector`'s Details fields.
class OcptBreakdownElementFieldChangedEvent extends OcptBreakdownEvent {
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

  /// Object properties
  @override
  List<Object?> get props => [...super.props, elementId, field, rawValue];
}

/// Fired by the field-edit debounce timer once it elapses with no further typing: writes every
/// pending element field edit.
///
/// Not meant to be dispatched by a widget; the bloc dispatches it itself.
class OcptBreakdownFieldEditFlushRequestedEvent extends OcptBreakdownEvent {
  /// Class constructor
  const OcptBreakdownFieldEditFlushRequestedEvent();
}

/// Writes a new owner onto element [elementId] immediately, dispatched by
/// `OcptBreakdownTargetInspector`'s own owner picker.
class OcptBreakdownElementOwnerChangedEvent extends OcptBreakdownEvent {
  /// The id of the element whose owner changed.
  final String elementId;

  /// The id of the person just picked, or null to clear the owner.
  final String? personId;

  /// Class constructor
  const OcptBreakdownElementOwnerChangedEvent({required this.elementId, required this.personId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, elementId, personId];
}

/// Writes a new who-brings-it onto element [elementId] immediately, dispatched by
/// `OcptBreakdownTargetInspector`'s own who-brings-it picker.
class OcptBreakdownElementBringerChangedEvent extends OcptBreakdownEvent {
  /// The id of the element whose who-brings-it changed.
  final String elementId;

  /// The id of the person just picked, or null to clear it.
  final String? personId;

  /// Class constructor
  const OcptBreakdownElementBringerChangedEvent({required this.elementId, required this.personId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, elementId, personId];
}

/// Says scene [sceneId] is shot in set [setId], dispatched by the scene inspector's own sets picker.
///
/// **Not** a tagging: no passage of the script is involved, no tag is created, and nothing is
/// highlighted. It writes the `scene_sets` link alone — the very link the resources mode's own
/// location sheet writes from the other side — so a scene may name its décor without a word of the
/// screenplay having to spell it.
class OcptBreakdownSceneSetLinkedEvent extends OcptBreakdownEvent {
  /// The id of the scene shot in [setId].
  final String sceneId;

  /// The id of the set it is shot in.
  final String setId;

  /// Class constructor
  const OcptBreakdownSceneSetLinkedEvent({required this.sceneId, required this.setId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, sceneId, setId];
}

/// Renames set [setId] to [rawValue], dispatched on every keystroke of the target inspector's own
/// title while a set is selected.
///
/// The set sibling of [OcptBreakdownElementFieldChangedEvent], and it rides the very same debounce:
/// a set has no sheet of its own here, only the name the popover gave it after the passage that
/// named it, which is exactly what the title is for.
class OcptBreakdownSetNameChangedEvent extends OcptBreakdownEvent {
  /// The id of the set being renamed.
  final String setId;

  /// The raw text the title field now holds.
  final String rawValue;

  /// Class constructor
  const OcptBreakdownSetNameChangedEvent({required this.setId, required this.rawValue});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, setId, rawValue];
}

/// Creates a set named [name] inside location [locationId] — or inside a location minted along with
/// it when that is null — and says scene [sceneId] is shot in it, dispatched by the scene
/// inspector's own `Create a set…` control.
///
/// The sibling of [OcptBreakdownPopoverSetCreationRequestedEvent] for the sheet rather than the
/// script: it writes **no tag**, there being no passage involved, and [name] is the place the
/// scene's own heading names rather than a passage the user selected.
class OcptBreakdownSceneSetCreationRequestedEvent extends OcptBreakdownEvent {
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

  /// Object properties
  @override
  List<Object?> get props => [...super.props, sceneId, locationId, name];
}

/// Says scene [sceneId] is no longer shot in set [setId], dispatched by one of the scene
/// inspector's own set chips being dismissed.
///
/// Drops the `scene_sets` link alone and **leaves every tag pointing at that set exactly where it
/// is**: a tag is a passage of the script, the link is a fact about the scene, and
/// `OcptBreakdownService.deleteTag` already refuses to conflate the two from the other side.
class OcptBreakdownSceneSetUnlinkedEvent extends OcptBreakdownEvent {
  /// The id of the scene no longer shot in [setId].
  final String sceneId;

  /// The id of the set it is no longer shot in.
  final String setId;

  /// Class constructor
  const OcptBreakdownSceneSetUnlinkedEvent({required this.sceneId, required this.setId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, sceneId, setId];
}

/// Removes the selected target's tags from the selected scene for good, dispatched by the mode once
/// its `OcptConfirmDialog` — opened by `OcptBreakdownTargetInspector`'s own `Remove from the
/// breakdown` action — has already been answered.
class OcptBreakdownTagRemovalConfirmedEvent extends OcptBreakdownEvent {
  /// Class constructor
  const OcptBreakdownTagRemovalConfirmedEvent();
}

/// Clears the pending anchor and the closed range alike, dispatched by the tag popover's own × close
/// button, by `Escape` while it is focused, or by a tap outside it — the user changed their mind
/// about the passage itself, not just about where to send it.
class OcptBreakdownTagRangeCancelledEvent extends OcptBreakdownEvent {
  /// Class constructor
  const OcptBreakdownTagRangeCancelledEvent();
}

/// Links `OcptBreakdownState.pendingTagRange`'s own passage to the existing [targetKind]/[targetId],
/// dispatched by a click on one of the tag popover's own match rows.
class OcptBreakdownPopoverTargetLinkedEvent extends OcptBreakdownEvent {
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
/// own passage with it, in one write, dispatched by a click on one of the tag popover's own category
/// chips.
class OcptBreakdownPopoverElementCreationRequestedEvent extends OcptBreakdownEvent {
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
/// The sibling of [OcptBreakdownPopoverElementCreationRequestedEvent], for the second and last thing
/// the breakdown pass may bring into existence: see `OcptBreakdownTagPopover`'s own doc comment for
/// why a role is not one of them.
class OcptBreakdownPopoverSetCreationRequestedEvent extends OcptBreakdownEvent {
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
class OcptBreakdownTagWriteErrorDismissedEvent extends OcptBreakdownEvent {
  /// Class constructor
  const OcptBreakdownTagWriteErrorDismissedEvent();
}

/// Clears `needsCheck` on tag [tagId], dispatched by `OcptBreakdownSceneInspector`'s own "to check"
/// alert's `Mark as checked` action.
///
/// A single pick, not typing, so it is written immediately and rides no field-edit debounce, and
/// it acts straight away with no further confirmation: the alert itself is the question, exactly
/// as `OcptRemovedRoleBanner`'s own actions do.
class OcptBreakdownTagNeedsCheckClearedEvent extends OcptBreakdownEvent {
  /// The id of the tag whose flag is cleared.
  final String tagId;

  /// Class constructor
  const OcptBreakdownTagNeedsCheckClearedEvent({required this.tagId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, tagId];
}

/// Tags one of the selected target's own suggested occurrences (`OcptBreakdownSuggestion`),
/// dispatched by a click on the add control of one of `OcptBreakdownTargetInspector`'s own
/// "Suggested occurrences" rows — the writer's second route onto
/// `OcptBreakdownService.createTag`, [OcptBreakdownPopoverTargetLinkedEvent] being the first, and
/// the field this event carries mirror the passage a `OcptBreakdownSuggestion` itself names, so a
/// widget passing one along never has to unpack it further.
class OcptBreakdownSuggestionAcceptedEvent extends OcptBreakdownEvent {
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

/// Removes tag [tagId] for good, dispatched by `OcptBreakdownSceneInspector`'s own "to check" alert's
/// `Remove` action.
///
/// Mirrors [OcptBreakdownTagNeedsCheckClearedEvent] in every respect but the write it performs:
/// acts straight away, with no inline confirmation of its own — this is a different tag-removal
/// path than [OcptBreakdownTagRemovalConfirmedEvent], which answers a two-step confirmation asked
/// about the *selected target's* tags; this one answers the "to check" alert's own row, named by
/// its tag id directly, and needs none.
class OcptBreakdownFlaggedTagRemovedEvent extends OcptBreakdownEvent {
  /// The id of the tag to remove.
  final String tagId;

  /// Class constructor
  const OcptBreakdownFlaggedTagRemovedEvent({required this.tagId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, tagId];
}

/// Requests exporting one breakdown sheet per scene as a PDF, dispatched by the mode's `⋮` menu
/// once its own options dialog has resolved.
///
/// [options] is what that dialog returned — the page format and margins the document is typeset
/// with, which scenes are printed, and the two sections a sheet may leave out. Both localized
/// payloads are resolved by the widget dispatching this, since the bloc has no `BuildContext` of
/// its own: [labels] is every string the document itself carries (see
/// `ocptBreakdownSheetsLabelsOf`), [fileTypeLabel] the label the native save dialog shows for the
/// `.pdf` type. Any pending field edit is flushed first, exactly as the other two modes' own export
/// events do, so an element renamed or a note typed seconds before the export is on the sheet
/// rather than only on screen.
class OcptBreakdownSheetsExportRequestedEvent extends OcptBreakdownEvent {
  /// The one-off options the export runs with.
  final OcptBreakdownSheetsExportOptions options;

  /// Every localized string the exported document holds.
  final OcptBreakdownSheetsLabels labels;

  /// The localized label of the `.pdf` file type, shown by the native save dialog.
  final String fileTypeLabel;

  /// Class constructor
  const OcptBreakdownSheetsExportRequestedEvent({
    required this.options,
    required this.labels,
    required this.fileTypeLabel,
  });

  /// Object properties
  @override
  List<Object?> get props => [...super.props, options, labels, fileTypeLabel];
}

/// Requests exporting the whole breakdown as a two-sheet XLSX workbook, dispatched by the mode's
/// export panel — this document takes no options dialog, so this event goes straight from the
/// panel's own card to the bloc.
///
/// [labels] is every string the workbook itself carries (see `ocptBreakdownXlsxLabelsOf`),
/// resolved by the widget dispatching this since the bloc has no `BuildContext` of its own, and
/// [fileTypeLabel] the label the native save dialog shows for the `.xlsx` type. Any pending field
/// edit is flushed first, exactly as [OcptBreakdownSheetsExportRequestedEvent] already does, so an
/// element renamed or a note typed seconds before the export lands in a cell rather than only on
/// screen.
class OcptBreakdownXlsxExportRequestedEvent extends OcptBreakdownEvent {
  /// Every localized string the exported workbook holds.
  final OcptBreakdownXlsxLabels labels;

  /// The localized label of the `.xlsx` file type, shown by the native save dialog.
  final String fileTypeLabel;

  /// Class constructor
  const OcptBreakdownXlsxExportRequestedEvent({required this.labels, required this.fileTypeLabel});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, labels, fileTypeLabel];
}

/// Dismisses the transient export notice currently shown, if any.
class OcptBreakdownIoNoticeDismissedEvent extends OcptBreakdownEvent {
  /// Class constructor
  const OcptBreakdownIoNoticeDismissedEvent();
}
