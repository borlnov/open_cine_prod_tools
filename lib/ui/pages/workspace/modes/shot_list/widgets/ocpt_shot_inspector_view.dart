// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_pending_edit_key.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_inspector_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_inspector_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_shot_coverage_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_shot_inspector_panel.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_shot_list_labels.dart';

/// The shot list mode's inspector tab: the selected shot's [OcptShotInspectorPanel], wired to the
/// mode bloc for what is shared (the shot, the cast, the suggestions, the scenario coverage layout)
/// and to [OcptShotListInspectorBloc] for what the inspector does with them.
///
/// A field shows the text still pending in the inspector bloc's debounce, when there is one, in
/// place of the shot's stored value. Every write is withheld (a null callback) under a version
/// preview by the panel itself, which reads it from the mode bloc: the view bloc has nothing to
/// know about it. Deleting the shot is only *asked*, through [onDeleteRequested]: the mode owns the
/// confirmation dialog.
class OcptShotInspectorView extends StatelessWidget {
  /// A group drawn under the header and before the character chips, naming what the active centre
  /// view adds to the découpage every view shares, or null on the table.
  final Widget? leadingGroup;

  /// Called with the selected shot when the user asked to delete it; the mode confirms it, then
  /// dispatches the deletion.
  final ValueChanged<OcptShot> onDeleteRequested;

  /// Class constructor
  const OcptShotInspectorView({
    super.key,
    required this.leadingGroup,
    required this.onDeleteRequested,
  });

  /// Build the shot inspector view as an [OcptShotInspectorPanel].
  @override
  Widget build(BuildContext context) {
    final inspectorBloc = context.read<OcptShotListInspectorBloc>();
    final mode = context.watch<OcptShotListBloc>().state;
    final inspector = context.watch<OcptShotListInspectorBloc>().state;
    final selectedShot = mode.selectedShot;
    final selectedSequence = mode.selectedSequence;
    final coverageLayout = mode.buildSelectedCoverageLayout();
    final staleCoverageRangeIds = coverageLayout == null
        ? const <String>{}
        : mode.staleCoverageRangeIdsOfSelectedShot(coverageLayout);

    /// Dispatches the event [buildEvent] builds from the selected shot's id, or does nothing while
    /// none is selected: every callback acting on "the selected shot" goes through this, so none of
    /// them has to force-unwrap it.
    void dispatchIfShotSelected(OcptShotListInspectorEvent Function(String shotId) buildEvent) {
      if (selectedShot == null) {
        return;
      }
      inspectorBloc.add(buildEvent(selectedShot.id));
    }

    return OcptShotInspectorPanel(
      shot: selectedShot,
      sequenceHeading: ocptShotSequenceHeadingOf(selectedSequence, selectedShot),
      leadingGroup: leadingGroup,
      sequenceDisplayNumber: ocptShotSequenceDisplayNumberOf(selectedSequence),
      roles: mode.roles,
      suggestions: mode.suggestions,
      coverageLayout: coverageLayout,
      otherShotsCoverageRanges: mode.otherShotsCoverageOfSelectedScene(),
      staleCoverageRangeIds: staleCoverageRangeIds,
      fieldValueOf: (field) => _fieldValueOf(inspector, selectedShot, field),
      onDifficultyChanged: (axis, value) => dispatchIfShotSelected(
        (id) => OcptShotListShotDifficultyChangedEvent(shotId: id, axis: axis, value: value),
      ),
      onCharacterToggled: (roleId) => dispatchIfShotSelected(
        (id) => OcptShotListShotCharacterToggledEvent(shotId: id, roleId: roleId),
      ),
      onCharacterAdded: (name) => dispatchIfShotSelected(
        (id) => OcptShotListCharacterAddRequestedEvent(shotId: id, characterName: name),
      ),
      onFieldChanged: (field, value) => dispatchIfShotSelected(
        (id) => OcptShotListShotFieldChangedEvent(shotId: id, field: field, rawValue: value),
      ),
      onSelectCoverageRequested: () => _showCoverageDialog(context),
      onCoverageClearAll: () =>
          dispatchIfShotSelected((id) => OcptShotListCoverageClearRequestedEvent(shotId: id)),
      onMarkAsChecked: () =>
          dispatchIfShotSelected((id) => OcptShotListShotMarkedAsCheckedEvent(shotId: id)),
      onDeleteRequested: selectedShot == null ? null : () => onDeleteRequested(selectedShot),
      isReadOnly: mode.isPreviewingVersion,
    );
  }

  /// Get [shot]'s current value for [field], for the inspector's editable fields: a pending edit
  /// still sitting in the inspector bloc's debounce takes priority over the shot's own stored
  /// value, so typing is never overwritten by an unrelated reload. Formatted for an editable field
  /// (an empty string for a missing value, never [ocptShotListEmptyValue], which is the table and
  /// read-only fields' own placeholder).
  String _fieldValueOf(
    OcptShotListInspectorState inspector,
    OcptShot? shot,
    OcptShotListEditableField field,
  ) {
    if (shot == null) {
      return "";
    }

    final pending =
        inspector.pendingFieldEdits[OcptShotListShotFieldEditKey(shotId: shot.id, field: field)];
    if (pending != null) {
      return pending;
    }

    return switch (field) {
      OcptShotListEditableField.shotSize => shot.shotSize,
      OcptShotListEditableField.abbreviation => shot.abbreviation,
      OcptShotListEditableField.framing => shot.framing,
      OcptShotListEditableField.cameraMove => shot.cameraMove,
      OcptShotListEditableField.lens => shot.lens,
      OcptShotListEditableField.recordingFormat => shot.recordingFormat,
      OcptShotListEditableField.estimatedDuration =>
        shot.estimatedDurationMs == null ? "" : ocptFormatShotDuration(shot.estimatedDurationMs),
      OcptShotListEditableField.sound => shot.sound,
      OcptShotListEditableField.notes => shot.notes,
      OcptShotListEditableField.locationNotes => shot.locationNotes,
    };
  }

  /// Open the dialog a shot's scenario coverage is selected in, keeping it in step with the blocs
  /// for as long as it is open.
  ///
  /// The dialog is built inside a [_CoverageDialogHost] on the blocs explicitly handed down rather
  /// than read from the dialog's context: a dialog is mounted in the navigator's own subtree,
  /// above this mode, so it inherits nothing from it. That host is what makes a range appear the
  /// moment it is recorded, since every click writes through the same bloc events the inspector
  /// uses. It renders nothing at all in the two states where there is nothing to select in — no
  /// shot selected any more, or a shot whose sequence disappeared from the screenplay — which can
  /// only happen if the selection changes underneath an open dialog.
  Future<void> _showCoverageDialog(BuildContext context) {
    final modeBloc = context.read<OcptShotListBloc>();
    final inspectorBloc = context.read<OcptShotListInspectorBloc>();

    return showDialog<void>(
      context: context,
      builder: (dialogContext) => MultiBlocProvider(
        providers: [
          BlocProvider.value(value: modeBloc),
          BlocProvider.value(value: inspectorBloc),
        ],
        child: const _CoverageDialogHost(),
      ),
    );
  }
}

/// The scenario coverage dialog of the selected shot, rebuilt from the mode bloc and the inspector
/// bloc handed down to it by [OcptShotInspectorView].
class _CoverageDialogHost extends StatelessWidget {
  /// Class constructor
  const _CoverageDialogHost();

  /// Build the coverage dialog host as an [OcptShotCoverageDialog].
  @override
  Widget build(BuildContext context) {
    final inspectorBloc = context.read<OcptShotListInspectorBloc>();
    final mode = context.watch<OcptShotListBloc>().state;
    final inspector = context.watch<OcptShotListInspectorBloc>().state;
    final shot = mode.selectedShot;
    final layout = mode.buildSelectedCoverageLayout();
    if (shot == null || layout == null) {
      return const SizedBox.shrink();
    }

    return OcptShotCoverageDialog(
      shotCode: shot.code,
      sequenceHeading: ocptShotSequenceHeadingOf(mode.selectedSequence, shot),
      layout: layout,
      pageSetup: mode.pageSetup,
      ownRanges: shot.coverageRanges,
      otherShotsRanges: mode.otherShotsCoverageOfSelectedScene(),
      pendingAnchor: inspector.pendingCoverageAnchor,
      onWordTapped: (wordStartOffset, wordEndOffset) => inspectorBloc.add(
        OcptShotListCoverageWordClickedEvent(
          shotId: shot.id,
          wordStartOffset: wordStartOffset,
          wordEndOffset: wordEndOffset,
        ),
      ),
      onClearAll: () => inspectorBloc.add(OcptShotListCoverageClearRequestedEvent(shotId: shot.id)),
      onAnchorCancelled: () => inspectorBloc.add(const OcptShotListCoverageAnchorCancelledEvent()),
    );
  }
}
