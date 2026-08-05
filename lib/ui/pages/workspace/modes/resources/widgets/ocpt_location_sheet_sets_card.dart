// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_scene_ref.dart';
import 'package:open_cine_prod_tools/models/ocpt_set.dart';
import 'package:open_cine_prod_tools/types/ocpt_set_editable_field.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_resources_code_read_out.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_resources_sheet_card.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_resources_sheet_field.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_resources_labels.dart';

/// The width of a set's code read-out: a code is `A`, `B`, `AC` — never a sentence.
const double _codeFieldWidth = 72;

/// "Sets in this location": one row per [OcptSet] — its code (read out, never typed: it is the
/// app's own, minted by `OcptLocationsService.createSet`), its name, its notes, the scenes shot in
/// it, and the control removing it — over the action adding another.
///
/// The scenes are here rather than on a screen of their own because this is where the answer is
/// known: the user is looking at "Cuisine" and knows scene 12 happens in it. The picker offers the
/// scenes with no set of their own first, the ones this very set is *suggested* for at the top of
/// that group (`ocptSceneSetSuggestionOf`, never applied on its own — `INT. CUISINE` in two houses
/// is two sets), and the scenes already shot in another set last, under their own heading — those
/// are offered rather than hidden because a scene is regularly covered in two sets, and picking one
/// **adds** this set to it. Dropping the wrong set is its chip's own control.
///
/// A set filed under the wrong place is **moved**, never retyped: its row carries the control
/// handing it to another location, which is the only way a set's location ever changes — it is what
/// a set belongs to rather than one of its fields, so it is not among [OcptSetField]'s entries.
class OcptLocationSheetSetsCard extends StatelessWidget {
  /// The sets of the location this card belongs to, in display order.
  final List<OcptSet> sets;

  /// Every **other** location of the project, `(id, name)`, offered as the destinations a set may
  /// be moved to. Empty while this is the project's only location, the move control then being
  /// dropped altogether: there is nowhere to move to.
  final List<(String, String)> otherLocations;

  /// Every scene of the project's screenplay, in source order.
  final List<OcptSceneRef> scenes;

  /// The ids of the scenes already shot in some set, this location's or another's.
  final Set<String> assignedSceneIds;

  /// The id of the set each scene is suggested for, keyed by scene id, holding an entry only for
  /// the scenes a set is actually suggested for.
  final Map<String, String> suggestedSetIdBySceneId;

  /// A set's current value for `field`: a pending edit still in the bloc's debounce, or the set's
  /// own stored value.
  final String Function(String setId, OcptSetField field) fieldValueOf;

  /// Called with a set field's raw text on every keystroke, or null while the sheet may not be
  /// written to.
  final void Function(String setId, OcptSetField field, String rawValue)? onSetFieldChanged;

  /// Called when `+ Add a set in this location` is clicked, or null while it may not be used.
  final VoidCallback? onSetAdded;

  /// Called with a set's id when its remove control is clicked, or null while it may not be used.
  final ValueChanged<String>? onSetRemoved;

  /// Called with a set's id and the location it is moved to, or null while it may not be used.
  final void Function(String setId, String locationId)? onSetLocationChanged;

  /// Called with a scene and the set it is now shot in, or null while it may not be used.
  final void Function(String sceneId, String setId)? onSceneAssigned;

  /// Called with a scene and the set it is no longer shot in, or null while it may not be used.
  final void Function(String sceneId, String setId)? onSceneRemoved;

  /// Class constructor
  const OcptLocationSheetSetsCard({
    super.key,
    required this.sets,
    required this.otherLocations,
    required this.scenes,
    required this.assignedSceneIds,
    required this.suggestedSetIdBySceneId,
    required this.fieldValueOf,
    required this.onSetFieldChanged,
    required this.onSetAdded,
    required this.onSetRemoved,
    required this.onSetLocationChanged,
    required this.onSceneAssigned,
    required this.onSceneRemoved,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    return OcptResourcesSheetCard(
      title: tr.resourcesLocationSetsCardTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (sets.isEmpty)
            Text(
              tr.resourcesLocationNoSetHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          for (final set in sets) ...[
            _buildSetRow(context, tr, set),
            const SizedBox(height: 10),
          ],
          if (onSetAdded != null)
            OutlinedButton(onPressed: onSetAdded, child: Text(tr.resourcesAddSetAction)),
        ],
      ),
    );
  }

  /// One set: its code and its name on the first line, its notes on the second, and the scenes
  /// shot in it on the third.
  Widget _buildSetRow(BuildContext context, Tr tr, OcptSet set) {
    final theme = Theme.of(context);
    final onSetRemoved = this.onSetRemoved;

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(ocptRadiusLarge),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: _codeFieldWidth,
                child: OcptResourcesCodeReadOut(
                  label: tr.resourcesSetCodeLabel,
                  code: set.code,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: _buildSetField(set, OcptSetField.name, tr.resourcesSetNameLabel)),
              if (onSetLocationChanged != null && otherLocations.isNotEmpty) ...[
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: _buildMoveButton(tr, set),
                ),
              ],
              if (onSetRemoved != null) ...[
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    tooltip: tr.resourcesRemoveSetTooltip,
                    onPressed: () => onSetRemoved(set.id),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          _buildSetField(set, OcptSetField.notes, tr.resourcesSetNotesLabel),
          const SizedBox(height: 8),
          _buildScenesRow(context, tr, set),
        ],
      ),
    );
  }

  /// The control handing [set] to another location: every other location of the project, picked
  /// from a menu. The set leaves this sheet the moment one is picked, which is what a move is.
  Widget _buildMoveButton(Tr tr, OcptSet set) {
    final onSetLocationChanged = this.onSetLocationChanged!;

    return PopupMenuButton<String>(
      tooltip: tr.resourcesMoveSetTooltip,
      icon: const Icon(Icons.drive_file_move_outline, size: 16),
      onSelected: (locationId) => onSetLocationChanged(set.id, locationId),
      itemBuilder: (context) => [
        PopupMenuItem<String>(enabled: false, child: Text(tr.resourcesMoveSetMenuTitle)),
        for (final (id, name) in otherLocations)
          PopupMenuItem<String>(value: id, child: Text(name)),
      ],
    );
  }

  /// One text field of a set row.
  Widget _buildSetField(OcptSet set, OcptSetField field, String label) {
    final onSetFieldChanged = this.onSetFieldChanged;

    return OcptResourcesSheetField(
      ownerId: set.id,
      label: label,
      value: fieldValueOf(set.id, field),
      onChanged: onSetFieldChanged == null
          ? null
          : (value) => onSetFieldChanged(set.id, field, value),
    );
  }

  /// The scenes shot in [set], as chips, followed by the picker adding one.
  Widget _buildScenesRow(BuildContext context, Tr tr, OcptSet set) {
    final theme = Theme.of(context);
    final onSceneRemoved = this.onSceneRemoved;
    final sceneById = {for (final scene in scenes) scene.id: scene};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr.resourcesSetScenesLabel.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (set.sceneIds.isEmpty)
              Text(
                ocptResourcesEmptyValue,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            for (final sceneId in set.sceneIds)
              if (sceneById[sceneId] case final scene?)
                Chip(
                  label: Text(ocptSceneRefLabel(scene)),
                  onDeleted: onSceneRemoved == null ? null : () => onSceneRemoved(scene.id, set.id),
                ),
            if (onSceneAssigned != null) _buildScenePicker(context, tr, set),
          ],
        ),
      ],
    );
  }

  /// The `+ Scene` picker of [set]: the scenes with no set at all first, this set's suggested ones
  /// at the top of them, then the scenes already shot elsewhere under their own heading — picking
  /// one of those adds this set beside the ones it already has.
  Widget _buildScenePicker(BuildContext context, Tr tr, OcptSet set) {
    final onSceneAssigned = this.onSceneAssigned!;

    final suggested = <OcptSceneRef>[];
    final unassigned = <OcptSceneRef>[];
    final assignedElsewhere = <OcptSceneRef>[];

    for (final scene in scenes) {
      if (set.sceneIds.contains(scene.id)) {
        continue;
      }

      if (!assignedSceneIds.contains(scene.id)) {
        if (suggestedSetIdBySceneId[scene.id] == set.id) {
          suggested.add(scene);
        } else {
          unassigned.add(scene);
        }
      } else {
        assignedElsewhere.add(scene);
      }
    }

    if (suggested.isEmpty && unassigned.isEmpty && assignedElsewhere.isEmpty) {
      return const SizedBox.shrink();
    }

    return PopupMenuButton<String>(
      tooltip: "",
      onSelected: (sceneId) => onSceneAssigned(sceneId, set.id),
      itemBuilder: (context) => [
        for (final scene in suggested)
          PopupMenuItem<String>(
            value: scene.id,
            child: Text(tr.resourcesSceneSuggestedOption(ocptSceneRefLabel(scene))),
          ),
        for (final scene in unassigned)
          PopupMenuItem<String>(value: scene.id, child: Text(ocptSceneRefLabel(scene))),
        if (assignedElsewhere.isNotEmpty) ...[
          const PopupMenuDivider(),
          PopupMenuItem<String>(enabled: false, child: Text(tr.resourcesScenesInAnotherSetLabel)),
          for (final scene in assignedElsewhere)
            PopupMenuItem<String>(value: scene.id, child: Text(ocptSceneRefLabel(scene))),
        ],
      ],
      child: Chip(
        avatar: const Icon(Icons.add, size: 14),
        label: Text(tr.resourcesAddSceneToSetAction),
      ),
    );
  }

}
