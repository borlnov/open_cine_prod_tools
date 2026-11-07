// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart' as ocpt_theme;
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_scene_ref.dart';
import 'package:open_cine_prod_tools/models/ocpt_set.dart';
import 'package:open_cine_prod_tools/types/ocpt_set_editable_field.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_resources_code_read_out.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_resources_sheet_card.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_resources_sheet_field.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_resources_labels.dart';

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

  /// The ids of [sets] that hold a live floor plan row — a set's own `Floor plan · N sequences` /
  /// `No floor plan yet` line reads this alongside `set.sceneIds.length` for the count: the plan
  /// "exists" the moment a `floor_plan_sets` row does, whether or not the set is linked to a live
  /// sequence any more.
  final Set<String> setIdsWithPlan;

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

  /// Called with a set's id when its own `Open in shot list` action is clicked — never withheld
  /// under a read-only preview (it only reads), so it takes no nullable form.
  final ValueChanged<String> onOpenInShotListRequested;

  /// Class constructor
  const OcptLocationSheetSetsCard({
    super.key,
    required this.sets,
    required this.otherLocations,
    required this.scenes,
    required this.assignedSceneIds,
    required this.suggestedSetIdBySceneId,
    required this.setIdsWithPlan,
    required this.fieldValueOf,
    required this.onSetFieldChanged,
    required this.onSetAdded,
    required this.onSetRemoved,
    required this.onSetLocationChanged,
    required this.onSceneAssigned,
    required this.onSceneRemoved,
    required this.onOpenInShotListRequested,
  });

  /// Build the location sheet sets card as an [OcptResourcesSheetCard].
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
          for (final set in sets) ...[_SetRow(card: this, set: set), const SizedBox(height: 10)],
          if (onSetAdded != null)
            OutlinedButton(onPressed: onSetAdded, child: Text(tr.resourcesAddSetAction)),
        ],
      ),
    );
  }
}

/// One set: its code and its name on the first line, its notes on the second, and the scenes
/// shot in it on the third.
class _SetRow extends StatelessWidget {
  /// The card the set belongs to.
  final OcptLocationSheetSetsCard card;

  /// The set this widget shows.
  final OcptSet set;

  /// Class constructor
  const _SetRow({required this.card, required this.set});

  /// Build the set row as a [Container].
  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final theme = Theme.of(context);
    final onSetRemoved = card.onSetRemoved;

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(ocpt_theme.ocptRadiusLarge),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: _codeFieldWidth,
                child: OcptResourcesCodeReadOut(label: tr.resourcesSetCodeLabel, code: set.code),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SetField(
                  card: card,
                  set: set,
                  field: OcptSetField.name,
                  label: tr.resourcesSetNameLabel,
                ),
              ),
              if (card.onSetLocationChanged != null && card.otherLocations.isNotEmpty) ...[
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: _MoveButton(card: card, set: set),
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
          _SetField(
            card: card,
            set: set,
            field: OcptSetField.notes,
            label: tr.resourcesSetNotesLabel,
          ),
          const SizedBox(height: 8),
          _ScenesRow(card: card, set: set),
          const SizedBox(height: 8),
          _FloorPlanRow(card: card, set: set),
        ],
      ),
    );
  }
}

/// The set's own floor plan indicator (`Floor plan · N sequences` or `No floor plan yet`) and,
/// only while it is linked to at least one live sequence, the `Open in shot list` action —
/// editing the plan stays in the shot list mode, so this
/// row only ever reads, never withheld under a read-only preview.
class _FloorPlanRow extends StatelessWidget {
  /// The card the set belongs to.
  final OcptLocationSheetSetsCard card;

  /// The set this widget shows.
  final OcptSet set;

  /// Class constructor
  const _FloorPlanRow({required this.card, required this.set});

  /// Build the floor plan row as a [Row].
  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final theme = Theme.of(context);
    final hasPlan = card.setIdsWithPlan.contains(set.id);
    final sequenceCount = set.sceneIds.length;

    return Row(
      children: [
        Icon(Icons.dashboard_outlined, size: 14, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          hasPlan
              ? tr.resourcesSetFloorPlanCountLabel(sequenceCount)
              : tr.resourcesSetNoFloorPlanLabel,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        if (sequenceCount > 0) ...[
          const Spacer(),
          TextButton(
            onPressed: () => card.onOpenInShotListRequested(set.id),
            child: Text(tr.resourcesOpenSetInShotListAction),
          ),
        ],
      ],
    );
  }
}

/// The control handing [set] to another location: every other location of the project, picked
/// from a menu. The set leaves this sheet the moment one is picked, which is what a move is.
class _MoveButton extends StatelessWidget {
  /// The card the set belongs to.
  final OcptLocationSheetSetsCard card;

  /// The set this widget shows.
  final OcptSet set;

  /// Class constructor
  const _MoveButton({required this.card, required this.set});

  /// Build the move button as a [PopupMenuButton].
  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final onSetLocationChanged = card.onSetLocationChanged!;

    return PopupMenuButton<String>(
      tooltip: tr.resourcesMoveSetTooltip,
      icon: const Icon(Icons.drive_file_move_outline, size: 16),
      onSelected: (locationId) => onSetLocationChanged(set.id, locationId),
      itemBuilder: (context) => [
        PopupMenuItem<String>(enabled: false, child: Text(tr.resourcesMoveSetMenuTitle)),
        for (final (id, name) in card.otherLocations)
          PopupMenuItem<String>(value: id, child: Text(name)),
      ],
    );
  }
}

/// One text field of a set row.
class _SetField extends StatelessWidget {
  /// The card the set belongs to.
  final OcptLocationSheetSetsCard card;

  /// The set this widget shows.
  final OcptSet set;

  /// The set field this one writes.
  final OcptSetField field;

  /// The field's label.
  final String label;

  /// Class constructor
  const _SetField({
    required this.card,
    required this.set,
    required this.field,
    required this.label,
  });

  /// Build the set field as an [OcptResourcesSheetField].
  @override
  Widget build(BuildContext context) {
    final onSetFieldChanged = card.onSetFieldChanged;

    return OcptResourcesSheetField(
      ownerId: set.id,
      label: label,
      value: card.fieldValueOf(set.id, field),
      onChanged: onSetFieldChanged == null
          ? null
          : (value) => onSetFieldChanged(set.id, field, value),
    );
  }
}

/// The scenes shot in [set], as chips, followed by the picker adding one.
class _ScenesRow extends StatelessWidget {
  /// The card the set belongs to.
  final OcptLocationSheetSetsCard card;

  /// The set this widget shows.
  final OcptSet set;

  /// Class constructor
  const _ScenesRow({required this.card, required this.set});

  /// Build the scenes row as a [Column].
  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final theme = Theme.of(context);
    final onSceneRemoved = card.onSceneRemoved;
    final sceneById = {for (final scene in card.scenes) scene.id: scene};

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
            if (card.onSceneAssigned != null) _ScenePicker(card: card, set: set),
          ],
        ),
      ],
    );
  }
}

/// The `Scene` picker of [set]: the scenes with no set at all first, this set's suggested ones
/// at the top of them, then the scenes already shot elsewhere under their own heading — picking
/// one of those adds this set beside the ones it already has.
class _ScenePicker extends StatelessWidget {
  /// The card the set belongs to.
  final OcptLocationSheetSetsCard card;

  /// The set this widget shows.
  final OcptSet set;

  /// Class constructor
  const _ScenePicker({required this.card, required this.set});

  /// Build the scene picker as a [PopupMenuButton].
  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final onSceneAssigned = card.onSceneAssigned!;

    final suggested = <OcptSceneRef>[];
    final unassigned = <OcptSceneRef>[];
    final assignedElsewhere = <OcptSceneRef>[];

    for (final scene in card.scenes) {
      if (set.sceneIds.contains(scene.id)) {
        continue;
      }

      if (!card.assignedSceneIds.contains(scene.id)) {
        if (card.suggestedSetIdBySceneId[scene.id] == set.id) {
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
