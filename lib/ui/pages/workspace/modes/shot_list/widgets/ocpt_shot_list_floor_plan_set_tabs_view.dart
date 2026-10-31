// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_pending_edit_key.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_floor_plan_sets_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_floor_plan_sets_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_set_tabs.dart';

/// The floor plans view's own set tabs, the header's trailing slot while it is shown: an
/// [OcptFloorPlanSetTabs] wired to the mode bloc for the selected set and to
/// [OcptShotListFloorPlanSetsBloc] for what the tabs do with the sets.
///
/// `＋ Set` is wired only when the selected sequence is a real screenplay scene (mirroring the
/// sequence tree's own `onShotCreated` gating), and every write is withheld under a version
/// preview. Reordering is withheld unconditionally: a tab is now a `scene_sets` link, which
/// carries no order of its own. Copying a shot's blocking and unlinking a set are only *asked*,
/// through [onCopyBlockingRequested] and [onSetDeleteRequested]: the mode owns their dialogs.
class OcptShotListFloorPlanSetTabsView extends StatelessWidget {
  /// The mode's state, which the sets, the locations and the selection are read from.
  final OcptShotListState state;

  /// The selected sequence, whose heading the suggested set is made from.
  final OcptShotSequence sequence;

  /// Called with the id of the set the user asked to copy a shot's blocking onto, once and only
  /// if it is allowed; the mode asks which shot to copy from, then dispatches the copy.
  final ValueChanged<String> onCopyBlockingRequested;

  /// Called with the id of the set the user asked to unlink; the mode confirms it, then
  /// dispatches the unlinking.
  final ValueChanged<String> onSetDeleteRequested;

  /// Class constructor
  const OcptShotListFloorPlanSetTabsView({
    super.key,
    required this.state,
    required this.sequence,
    required this.onCopyBlockingRequested,
    required this.onSetDeleteRequested,
  });

  @override
  Widget build(BuildContext context) {
    final sequence = this.sequence;
    final bloc = context.read<OcptShotListBloc>();
    final setsBloc = context.read<OcptShotListFloorPlanSetsBloc>();
    final setsState = context.watch<OcptShotListFloorPlanSetsBloc>().state;
    final tr = Tr.of(context);
    final isReadOnly = state.isPreviewingVersion;
    final canCreateSet = sequence is OcptSceneShotSequence && !isReadOnly;
    final suggestedSetId = canCreateSet ? state.suggestedSetIdOf(sequence) : null;

    return OcptFloorPlanSetTabs(
      sets: state.setsOfSelectedSequence,
      selectedSetId: state.selectedSetId,
      nameValueOf: (setId) => _setNameValueOf(state, setsState, setId),
      placedShotCountOf: (setId) => _placedShotCountOf(state, setId),
      suggestedSetId: suggestedSetId,
      suggestedSetName: _suggestedSetNameOf(state, suggestedSetId),
      linkableSetsByLocation: canCreateSet ? _linkableSetsByLocationOf(state, sequence) : const [],
      locationsForCreation: canCreateSet ? _locationsForCreationOf(state) : const [],
      onSetSelected: (setId) => bloc.add(OcptShotListSetSelectedEvent(setId: setId)),
      onSetLinkRequested: canCreateSet
          ? (setId) => setsBloc.add(OcptShotListSetLinkRequestedEvent(setId: setId))
          : null,
      onSetCreationRequested: canCreateSet
          ? (locationId) =>
                setsBloc.add(OcptShotListSetCreationRequestedEvent(locationId: locationId))
          : null,
      onSetDuplicateRequested: isReadOnly
          ? null
          : (setId) => setsBloc.add(
              OcptShotListSetDuplicationRequestedEvent(
                setId: setId,
                newSetName: tr.shotListFloorPlanDuplicateSetDefaultName(
                  _setNameValueOf(state, setsState, setId),
                ),
              ),
            ),
      onCopyBlockingRequested: isReadOnly || state.selectedShotId == null
          ? null
          : onCopyBlockingRequested,
      onSetNameChanged: isReadOnly
          ? null
          : (setId, rawValue) =>
                setsBloc.add(OcptShotListSetNameChangedEvent(setId: setId, rawValue: rawValue)),
      onSetReordered: null,
      onSetDeleteRequested: isReadOnly ? null : onSetDeleteRequested,
    );
  }

  /// How many of the selected sequence's own shots carry at least one live symbol on set [setId] —
  /// the set tabs' own placed-shot count badge.
  int _placedShotCountOf(OcptShotListState state, String setId) {
    for (final floorPlanSet in state.setsOfSelectedSequence) {
      if (floorPlanSet.id == setId) {
        return floorPlanSet.symbols
            .map((symbol) => symbol.shotId)
            .whereType<String>()
            .toSet()
            .length;
      }
    }
    return 0;
  }

  /// [suggestedSetId]'s own display name, read off the project's whole Resources catalogue, or
  /// null while [suggestedSetId] is.
  String? _suggestedSetNameOf(OcptShotListState state, String? suggestedSetId) {
    if (suggestedSetId == null) {
      return null;
    }
    for (final location in state.locations) {
      for (final set in location.sets) {
        if (set.id == suggestedSetId) {
          return set.name;
        }
      }
    }
    return null;
  }

  /// Every Resources set of the project **not already linked** to [sequence], grouped by its own
  /// location's name — the `＋ Set` menu's own `Link an existing set ▸` submenu entries. A location
  /// with nothing left to offer (every one of its sets already linked) is left out entirely.
  List<(String, List<(String, String)>)> _linkableSetsByLocationOf(
    OcptShotListState state,
    OcptSceneShotSequence sequence,
  ) {
    final linkedIds = state.setsOfSelectedSequence.map((floorPlanSet) => floorPlanSet.id).toSet();

    final groups = <(String, List<(String, String)>)>[];
    for (final location in state.locations) {
      final sets = [
        for (final set in location.sets)
          if (!linkedIds.contains(set.id)) (set.id, set.name),
      ];
      if (sets.isNotEmpty) {
        groups.add((location.name, sets));
      }
    }
    return groups;
  }

  /// Every location of the project, `(id, name)` — the `＋ Set` menu's own `Create a set ▸`
  /// submenu's per-location entries.
  List<(String, String)> _locationsForCreationOf(OcptShotListState state) => [
    for (final location in state.locations) (location.id, location.name),
  ];

  /// [setId]'s current name: a pending edit still in the bloc's debounce, or the set's own
  /// stored value.
  String _setNameValueOf(
    OcptShotListState state,
    OcptShotListFloorPlanSetsState setsState,
    String setId,
  ) {
    final pending = setsState.pendingFieldEdits[OcptShotListSetNameEditKey(setId: setId)];
    if (pending != null) {
      return pending;
    }
    for (final floorPlanSet in state.setsOfSelectedSequence) {
      if (floorPlanSet.id == setId) {
        return floorPlanSet.name;
      }
    }
    return "";
  }
}
