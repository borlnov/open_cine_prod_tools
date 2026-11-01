// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_target.dart';
import 'package:open_cine_prod_tools/models/ocpt_element.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_workspace_reveal_request.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_breakdown_scene_bars.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_scene_set_suggestion.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_target_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_resources_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_workspace_mode.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/breakdown_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/breakdown_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/breakdown_inspector_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/breakdown_inspector_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/breakdown_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/breakdown_tagging_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/widgets/ocpt_breakdown_scene_inspector.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/widgets/ocpt_breakdown_target_inspector.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/workspace_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/workspace_event.dart';

/// The `Inspector` tab's own content: the selected target's sheet, or — while nothing is
/// selected — the selected scene's own breakdown sheet.
///
/// The sheet sits inside a [BlocBuilder] on [OcptBreakdownInspectorBloc], so a keystroke in one of
/// its fields redraws the sheet and not the shell around it. Removing the target's tags is only
/// *asked*, through [onTagRemovalRequested]: the mode owns the confirmation dialog.
class OcptBreakdownInspectorView extends StatelessWidget {
  /// The mode's state, which the selection and the catalogues are read from.
  final OcptBreakdownState state;

  /// Called when the user asked to remove the selected target's tags from the selected scene.
  final VoidCallback onTagRemovalRequested;

  /// Class constructor
  const OcptBreakdownInspectorView({
    super.key,
    required this.state,
    required this.onTagRemovalRequested,
  });

  @override
  Widget build(BuildContext context) {
    final target = state.selectedTarget;

    return BlocBuilder<OcptBreakdownInspectorBloc, OcptBreakdownInspectorState>(
      builder: (context, inspectorState) => target == null
          ? _SceneInspector(state: state, inspectorState: inspectorState)
          : _TargetInspector(
              state: state,
              inspectorState: inspectorState,
              target: target,
              onTagRemovalRequested: onTagRemovalRequested,
            ),
    );
  }
}

/// The selected scene's own breakdown sheet, shown while no target is selected.
class _SceneInspector extends StatelessWidget {
  /// The mode's state, which the selected scene and the catalogues are read from.
  final OcptBreakdownState state;

  /// The inspector's state, which the notes typed and not yet written are read from.
  final OcptBreakdownInspectorState inspectorState;

  /// Class constructor
  const _SceneInspector({required this.state, required this.inspectorState});

  /// The default name the `+ Set` popover's own name field opens with, for the scene sheet of a
  /// scene headed [heading]: the place that heading names (`ocptSceneHeadingPlaceOf` — its
  /// interior/exterior prefix and its time of day dropped), falling back to the whole heading when
  /// there is nothing left of it. The user may edit it before creating; only the starting text is
  /// resolved here.
  String _newSetNameOf(String heading) {
    final place = ocptSceneHeadingPlaceOf(heading);
    return place.isEmpty ? heading : place;
  }

  @override
  Widget build(BuildContext context) {
    final scene = state.selectedScene;
    final bloc = context.read<OcptBreakdownBloc>();
    final inspectorBloc = context.read<OcptBreakdownInspectorBloc>();
    final isReadOnly = state.isPreviewingVersion;

    return OcptBreakdownSceneInspector(
      scene: scene,
      targetById: ocptBreakdownTargetsById(state.targets),
      sets: state.sets,
      locationNameById: state.locationNameById,
      suggestedSetId: scene == null
          ? null
          : ocptSceneSetSuggestionOf(heading: scene.heading, locations: state.locations),
      onSetLinked: isReadOnly || scene == null
          ? null
          : (setId) => inspectorBloc.add(
              OcptBreakdownSceneSetLinkedEvent(sceneId: scene.id, setId: setId),
            ),
      onSetUnlinked: isReadOnly || scene == null
          ? null
          : (setId) => inspectorBloc.add(
              OcptBreakdownSceneSetUnlinkedEvent(sceneId: scene.id, setId: setId),
            ),
      locations: [for (final location in state.locations) (location.id, location.name)],
      newSetName: scene == null ? "" : _newSetNameOf(scene.heading),
      onSetCreationRequested: isReadOnly || scene == null
          ? null
          : (name, locationId) => inspectorBloc.add(
              OcptBreakdownSceneSetCreationRequestedEvent(
                sceneId: scene.id,
                locationId: locationId,
                name: name,
              ),
            ),
      notesValue: scene == null ? "" : inspectorState.sceneNotesValueOf(scene.id, scene.notes),
      onTargetSelected: (targetKind, targetId, sceneId) => bloc.add(
        OcptBreakdownTargetSelectedEvent(
          targetKind: targetKind,
          targetId: targetId,
          sceneId: sceneId,
        ),
      ),
      onStatusChanged: scene == null
          ? null
          : (status) => inspectorBloc.add(
              OcptBreakdownSceneStatusChangedEvent(sceneId: scene.id, status: status),
            ),
      onNotesChanged: scene == null
          ? null
          : (rawValue) => inspectorBloc.add(
              OcptBreakdownSceneNotesChangedEvent(sceneId: scene.id, rawValue: rawValue),
            ),
      onTagNeedsCheckCleared: (tagId) =>
          inspectorBloc.add(OcptBreakdownTagNeedsCheckClearedEvent(tagId: tagId)),
      onFlaggedTagRemoved: (tagId) =>
          inspectorBloc.add(OcptBreakdownFlaggedTagRemovedEvent(tagId: tagId)),
      isReadOnly: isReadOnly,
    );
  }
}

/// The selected target's sheet.
class _TargetInspector extends StatelessWidget {
  /// The mode's state, which the selected element and the catalogues are read from.
  final OcptBreakdownState state;

  /// The inspector's state, which the fields typed and not yet written are read from.
  final OcptBreakdownInspectorState inspectorState;

  /// The selected target.
  final OcptBreakdownTarget target;

  /// Called when the user asked to remove the target's tags from the selected scene.
  final VoidCallback onTagRemovalRequested;

  /// Class constructor
  const _TargetInspector({
    required this.state,
    required this.inspectorState,
    required this.target,
    required this.onTagRemovalRequested,
  });

  /// Where the resources mode should land when `Open in Resources` is clicked on [target]'s own
  /// sheet: the tab that holds it, with its record already selected.
  ///
  /// A **set** has no sheet of its own — it lives in the sets card of the location that holds it —
  /// so it is that location which is revealed, resolved here out of [OcptBreakdownState.sets]. A
  /// set whose location has gone missing from the snapshot reveals the locations tab and nothing
  /// on it, which is as close as the mode can honestly get.
  OcptWorkspaceRevealRequest _revealRequestOf() => switch (target.kind) {
    OcptBreakdownTargetKind.element => OcptResourcesRevealRequest(
      tab: OcptResourcesTab.elements,
      recordId: target.id,
    ),
    OcptBreakdownTargetKind.role => OcptResourcesRevealRequest(
      tab: OcptResourcesTab.roles,
      recordId: target.id,
    ),
    OcptBreakdownTargetKind.set => OcptResourcesRevealRequest(
      tab: OcptResourcesTab.locations,
      recordId: _locationIdOfSet(target.id),
    ),
  };

  /// The id of the location holding the set [setId] names, or null while no set of
  /// [OcptBreakdownState.sets] has that id.
  String? _locationIdOfSet(String setId) {
    for (final set in state.sets) {
      if (set.id == setId) {
        return set.locationId;
      }
    }

    return null;
  }

  /// The person named by [personId] among [people], or null while [personId] is null or names
  /// nobody in [people].
  OcptPerson? _personById(List<OcptPerson> people, String? personId) {
    if (personId == null) {
      return null;
    }

    for (final person in people) {
      if (person.id == personId) {
        return person;
      }
    }

    return null;
  }

  /// [element]'s own stored value for `field` — only `name`, `subCategory`, `quantity` and `notes`
  /// are ever asked for, the target inspector's other fields being single picks rather than typed
  /// text.
  String _storedElementFieldValue(OcptElement element, OcptElementField field) => switch (field) {
    OcptElementField.name => element.name,
    OcptElementField.subCategory => element.subCategory,
    OcptElementField.quantity => element.quantity,
    OcptElementField.notes => element.notes,
    OcptElementField.ownerNotes ||
    OcptElementField.storageNotes ||
    OcptElementField.cost ||
    OcptElementField.purposeNotes => "",
  };

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<OcptBreakdownBloc>();
    final inspectorBloc = context.read<OcptBreakdownInspectorBloc>();
    final taggingBloc = context.read<OcptBreakdownTaggingBloc>();
    final element = state.selectedElement;
    final isReadOnly = state.isPreviewingVersion;

    return OcptBreakdownTargetInspector(
      target: target,
      element: element,
      owner: element == null ? null : _personById(state.people, element.ownerPersonId),
      bringer: element == null ? null : _personById(state.people, element.broughtByPersonId),
      people: state.people,
      scenes: state.scenes,
      fieldValueOf: (field) => element == null
          ? ""
          : inspectorState.elementFieldValueOf(
              element.id,
              field,
              _storedElementFieldValue(element, field),
            ),
      onBackToSceneRequested: () => bloc.add(const OcptBreakdownTargetSelectionClearedEvent()),
      nameValue: switch (target.kind) {
        OcptBreakdownTargetKind.element =>
          element == null
              ? target.name
              : inspectorState.elementFieldValueOf(element.id, OcptElementField.name, element.name),
        OcptBreakdownTargetKind.set => inspectorState.setNameValueOf(target.id, target.name),
        OcptBreakdownTargetKind.role => target.name,
      },
      onNameChanged: isReadOnly
          ? null
          : switch (target.kind) {
              // A role's name is the screenplay's: `OcptRoleIndexService` reconciles it from the
              // cue, so a rename here would be undone by the next save.
              OcptBreakdownTargetKind.role => null,
              OcptBreakdownTargetKind.element =>
                element == null
                    ? null
                    : (rawValue) => inspectorBloc.add(
                        OcptBreakdownElementFieldChangedEvent(
                          elementId: element.id,
                          field: OcptElementField.name,
                          rawValue: rawValue,
                        ),
                      ),
              OcptBreakdownTargetKind.set => (rawValue) => inspectorBloc.add(
                OcptBreakdownSetNameChangedEvent(setId: target.id, rawValue: rawValue),
              ),
            },
      onStatusChanged: isReadOnly || element == null
          ? null
          : (status) => inspectorBloc.add(
              OcptBreakdownElementStatusChangedEvent(elementId: element.id, status: status),
            ),
      onCategoryChanged: isReadOnly || element == null
          ? null
          : (category) => inspectorBloc.add(
              OcptBreakdownElementCategoryChangedEvent(elementId: element.id, category: category),
            ),
      onFieldChanged: isReadOnly || element == null
          ? null
          : (field, rawValue) => inspectorBloc.add(
              OcptBreakdownElementFieldChangedEvent(
                elementId: element.id,
                field: field,
                rawValue: rawValue,
              ),
            ),
      onOwnerChanged: isReadOnly || element == null
          ? null
          : (personId) => inspectorBloc.add(
              OcptBreakdownElementOwnerChangedEvent(elementId: element.id, personId: personId),
            ),
      onBringerChanged: isReadOnly || element == null
          ? null
          : (personId) => inspectorBloc.add(
              OcptBreakdownElementBringerChangedEvent(elementId: element.id, personId: personId),
            ),
      onOccurrenceSelected: (sceneId) =>
          bloc.add(OcptBreakdownOccurrenceSelectedEvent(sceneId: sceneId)),
      suggestions: state.selectedTargetSuggestions,
      onSuggestionAccepted: isReadOnly
          ? null
          : (suggestion) => taggingBloc.add(
              OcptBreakdownSuggestionAcceptedEvent(
                targetKind: suggestion.targetKind,
                targetId: suggestion.targetId,
                sceneId: suggestion.sceneId,
                startOffset: suggestion.startOffset,
                endOffset: suggestion.endOffset,
                taggedText: suggestion.text,
              ),
            ),
      onOpenInResourcesRequested: () => context.read<OcptWorkspaceBloc>().add(
        OcptWorkspaceModeSelectedEvent(
          mode: OcptWorkspaceMode.resources,
          revealRequest: _revealRequestOf(),
        ),
      ),
      onTagRemovalRequested: isReadOnly ? null : onTagRemovalRequested,
      isReadOnly: isReadOnly,
    );
  }
}
