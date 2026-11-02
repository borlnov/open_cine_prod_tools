// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart' as ocpt_theme;
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_scene.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_tag.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_target.dart';
import 'package:open_cine_prod_tools/models/ocpt_set.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_breakdown_scene_bars.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_scene_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_target_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_status.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/widgets/ocpt_breakdown_choice_chip.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/widgets/ocpt_breakdown_set_picker_popover.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_resources_sheet_field.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_breakdown_labels.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_warning_color.dart';

/// The right dock's `Inspector` tab while a scene is selected and no target is: the scene's own
/// breakdown sheet — counts, its own status chips, **the sets it is shot in**, an alert naming the
/// elements still to find, a second alert listing the tags a save could not re-anchor, its targets
/// grouped by category and its own breakdown notes.
///
/// The sets row is the one part of this sheet that is not about tags: it reads
/// and writes the `scene_sets` link directly, so a link made by hand in the resources mode shows
/// here too, and one made here shows there. A single `+ Set` control
/// (`OcptBreakdownSetPickerPopover`) both links an existing set and **creates** one under a name
/// the user may type, a scene whose place the project has never heard of being the ordinary case at
/// the start of a breakdown pass rather than an edge one. It is where a breakdown sheet names its
/// décor, which is why it sits at the top rather than among the tagged targets below. Adding a set
/// is **not** tagging a passage: no tag is created, nothing in the script is highlighted, and
/// removing a set here leaves every tag pointing at it exactly where it is — the tag and the link
/// are two separate facts, as `OcptBreakdownService.deleteTag`'s own doc comment spells out from
/// the other side.
///
/// The "to check" alert is the same visual shape as the "to find" one right
/// above it — the warning colour, the same callout — but lists [OcptBreakdownScene.tags] whose
/// [OcptBreakdownTag.needsCheck] is set, one row per tag: the passage verbatim, and the target it
/// points at when [targetById] still resolves one (a tombstoned catalogue row still keeps its tag
/// on the scene — `OcptBreakdownSnapshot.build`'s own doc comment — so a row whose target is gone
/// shows the passage alone rather than crashing). Each row offers `Mark as checked` (clears the
/// flag alone, leaving the offsets exactly where they are — the honest answer to "the passage now
/// occurs twice in the scene so it could not be re-anchored unambiguously, but the one this tag
/// points at is still right") and `Remove` (tombstones that one tag). Both act **straight away,
/// with no inline confirmation**: the alert itself is the question, exactly as
/// `OcptRoleAlertBanner`'s own `Keep as silent` action does in the resources mode.
///
/// Purely presentational, like `OcptShotInspectorPanel`. [isReadOnly] withholds every control that
/// writes — the status chips, the sets row's own `+ Set` control and chip dismissals, the notes
/// field and the "to check" alert's two actions — while leaving every read (the sheet itself, both
/// alerts' own listing, and a click on one of its target rows, `onTargetSelected`) in place,
/// mirroring `OcptBreakdownTargetInspector`'s own convention: the panel takes the real callbacks
/// and nulls them out itself, so a control added later cannot be gated in one place and forgotten
/// in the other. [onTargetSelected] is never withheld: selecting writes nothing whatever a
/// previewed version's own gating says.
class OcptBreakdownSceneInspector extends StatefulWidget {
  /// The selected scene, or null while nothing at all is selected — the mode's own empty message is
  /// shown then.
  final OcptBreakdownScene? scene;

  /// `{(kind, id): target}`, built once by the mode from the loaded snapshot's targets.
  final OcptBreakdownTargetsById targetById;

  /// The **whole** set catalogue, every location's sets flattened. The ones [scene] is shot in are
  /// read off it ([OcptSet.sceneIds]) rather than passed separately, and the rest are what the
  /// picker offers.
  final List<OcptSet> sets;

  /// The name of every live location, keyed by id, naming the place each of [sets] belongs to
  /// (`ocptBreakdownSetLabel`).
  final Map<String, String> locationNameById;

  /// The id of the set [scene]'s own heading suggests (`ocptSceneSetSuggestionOf`), or null while
  /// it suggests none. Shown at the top of the picker, marked as a suggestion and **never applied**
  /// on its own — `INT. CUISINE` in two houses is two sets, exactly as the resources mode's own
  /// scene picker has it.
  final String? suggestedSetId;

  /// Called with a set's id when the picker offers it and it is picked, saying [scene] is shot in
  /// it; null while it may not be written.
  final ValueChanged<String>? onSetLinked;

  /// Called with a set's id when its chip is dismissed, saying [scene] is no longer shot in it;
  /// null under the same condition as [onSetLinked].
  final ValueChanged<String>? onSetUnlinked;

  /// Every live location of the project, `(id, name)`, offered as the place a set created from this
  /// sheet is filed under. Empty while the project has none, the menu then offering its own
  /// "in a new location" entry alone.
  final List<(String, String)> locations;

  /// The `+ Set` popover's own name field's default text — the place [scene]'s own heading names
  /// (`ocptSceneHeadingPlaceOf`), resolved by the mode so this panel derives nothing. Editable by
  /// the user before either linking or creating, it is only ever the field's *starting* text.
  final String newSetName;

  /// Called with the field's current trimmed text and the location the set to create belongs to —
  /// null meaning "in a new location of its own" — when a create-in entry of the `+ Set` popover is
  /// clicked; itself null while nothing may be written.
  final void Function(String name, String? locationId)? onSetCreationRequested;

  /// [scene]'s current value for its own breakdown notes — a pending edit still in the bloc's own
  /// debounce, or the scene's own stored value. Ignored while [scene] is null.
  final String notesValue;

  /// Called with a target's kind, its id and [scene]'s own id when one of its rows is clicked.
  final void Function(OcptBreakdownTargetKind kind, String id, String sceneId) onTargetSelected;

  /// Called with the breakdown status just picked, or null while it may not be changed.
  final ValueChanged<OcptBreakdownSceneStatus>? onStatusChanged;

  /// Called with the notes field's raw text on every keystroke, or null while the sheet may not be
  /// written to.
  final ValueChanged<String>? onNotesChanged;

  /// Called with a flagged tag's id when its "to check" alert row's `Mark as checked` action is
  /// clicked, or null while it may not be answered.
  final ValueChanged<String>? onTagNeedsCheckCleared;

  /// Called with a flagged tag's id when its "to check" alert row's `Remove` action is clicked, or
  /// null while it may not be answered.
  final ValueChanged<String>? onFlaggedTagRemoved;

  /// Whether what the mode shows is a project version being previewed read-only, which no callback
  /// of this panel may write through.
  final bool isReadOnly;

  /// Class constructor
  const OcptBreakdownSceneInspector({
    super.key,
    required this.scene,
    required this.targetById,
    required this.sets,
    required this.locationNameById,
    required this.suggestedSetId,
    required this.onSetLinked,
    required this.onSetUnlinked,
    required this.locations,
    required this.newSetName,
    required this.onSetCreationRequested,
    required this.notesValue,
    required this.onTargetSelected,
    required this.onStatusChanged,
    required this.onNotesChanged,
    required this.onTagNeedsCheckCleared,
    required this.onFlaggedTagRemoved,
    this.isReadOnly = false,
  });

  /// Create the [_OcptBreakdownSceneInspectorState] holding the state of the breakdown scene
  /// inspector.
  @override
  State<OcptBreakdownSceneInspector> createState() => _OcptBreakdownSceneInspectorState();
}

/// What [OcptBreakdownSceneInspector] reads off one scene: its live targets, the ones still to
/// find, its tags flagged to check, and one group of alphabetised targets per bucket.
class _OcptBreakdownSceneInspection {
  /// Every live target of the scene.
  final List<OcptBreakdownTarget> targets;

  /// The scene's targets whose status is still `toFind`.
  final List<OcptBreakdownTarget> toFindTargets;

  /// The scene's tags flagged to check.
  final List<OcptBreakdownTag> flaggedTags;

  /// The scene's buckets, each with its own targets alphabetised by name.
  final List<({OcptBreakdownSceneBarBucket bucket, List<OcptBreakdownTarget> targets})> groups;

  /// Class constructor
  const _OcptBreakdownSceneInspection({
    required this.targets,
    required this.toFindTargets,
    required this.flaggedTags,
    required this.groups,
  });

  /// Read [scene] against [targetById].
  factory _OcptBreakdownSceneInspection.of(
    OcptBreakdownScene scene,
    OcptBreakdownTargetsById targetById,
  ) {
    final targets = ocptBreakdownSceneTargetsOf(scene, targetById);

    return _OcptBreakdownSceneInspection(
      targets: targets,
      toFindTargets: targets.where((target) => target.status == OcptElementStatus.toFind).toList(),
      flaggedTags: scene.tags.where((tag) => tag.needsCheck).toList(),
      groups: [
        for (final bucket in ocptBreakdownSceneBarBucketsOf(scene, targetById))
          (
            bucket: bucket,
            targets:
                targets
                    .where(
                      (target) => target.kind == bucket.kind && target.category == bucket.category,
                    )
                    .toList()
                  ..sort((a, b) => a.name.compareTo(b.name)),
          ),
      ],
    );
  }
}

/// The state of [OcptBreakdownSceneInspector]: it keeps what is read off the scene, so that a
/// rebuild which changes neither the scene nor its targets does not read it again.
class _OcptBreakdownSceneInspectorState extends State<OcptBreakdownSceneInspector> {
  /// What is read off the scene, or null while no scene is selected.
  late _OcptBreakdownSceneInspection? _inspection = _inspectionOf(widget);

  /// Read the scene again when it or its targets have changed.
  @override
  void didUpdateWidget(covariant OcptBreakdownSceneInspector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.scene, widget.scene) ||
        !identical(oldWidget.targetById, widget.targetById)) {
      _inspection = _inspectionOf(widget);
    }
  }

  /// Build the breakdown scene inspector as a [ListView].
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final scene = widget.scene;
    final derived = _inspection;

    if (scene == null || derived == null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          tr.breakdownInspectorNoSelectionHint,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      );
    }

    final targetById = widget.targetById;
    final sets = widget.sets;
    final locationNameById = widget.locationNameById;
    final suggestedSetId = widget.suggestedSetId;
    final onSetLinked = widget.onSetLinked;
    final onSetUnlinked = widget.onSetUnlinked;
    final locations = widget.locations;
    final newSetName = widget.newSetName;
    final onSetCreationRequested = widget.onSetCreationRequested;
    final notesValue = widget.notesValue;
    final onTargetSelected = widget.onTargetSelected;
    final onStatusChanged = widget.onStatusChanged;
    final onNotesChanged = widget.onNotesChanged;
    final onTagNeedsCheckCleared = widget.onTagNeedsCheckCleared;
    final onFlaggedTagRemoved = widget.onFlaggedTagRemoved;
    final isReadOnly = widget.isReadOnly;
    final targets = derived.targets;
    final toFindTargets = derived.toFindTargets;
    final flaggedTags = derived.flaggedTags;

    return ListView(
      // Keyed by the scene's own id so switching scenes always resets the scroll offset to the top
      // rather than keeping whatever position the previous scene's sheet was left at — the "to
      // check" callout sits near the top precisely so the warning-mark path
      // (`OcptBreakdownScenePanel.onWarningTapped`) lands the user on it without a further scroll.
      key: ValueKey(scene.id),
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          tr.breakdownSceneInspectorTitle(scene.displayNumber),
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 4),
        Text(
          scene.heading,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(
              child: _StatTile(
                label: tr.breakdownSceneInspectorTaggedLabel,
                value: "${targets.length}",
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatTile(
                label: tr.breakdownSceneInspectorToFindLabel,
                value: "${toFindTargets.length}",
                color: toFindTargets.isEmpty ? null : ocptWarningColor(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        Text(
          tr.breakdownSceneInspectorStatusLabel.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        _StatusChips(
          currentStatus: scene.status,
          onStatusChanged: isReadOnly ? null : onStatusChanged,
        ),
        const SizedBox(height: 16),

        Text(
          tr.breakdownSceneInspectorSetsLabel.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        _SetsRow(
          sceneId: scene.id,
          sets: sets,
          locationNameById: locationNameById,
          suggestedSetId: suggestedSetId,
          onSetLinked: onSetLinked,
          onSetUnlinked: onSetUnlinked,
          locations: locations,
          newSetName: newSetName,
          onSetCreationRequested: onSetCreationRequested,
        ),
        const SizedBox(height: 16),

        if (toFindTargets.isNotEmpty) ...[
          _ToFindAlert(toFindTargets: toFindTargets),
          const SizedBox(height: 16),
        ],

        if (flaggedTags.isNotEmpty) ...[
          _ToCheckAlert(
            flaggedTags: flaggedTags,
            targetById: targetById,
            onTagNeedsCheckCleared: isReadOnly ? null : onTagNeedsCheckCleared,
            onFlaggedTagRemoved: isReadOnly ? null : onFlaggedTagRemoved,
          ),
          const SizedBox(height: 16),
        ],

        Text(
          tr.breakdownSceneInspectorTargetsSectionTitle.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),

        if (targets.isEmpty)
          const _EmptyHint()
        else
          for (final group in derived.groups)
            _Group(
              bucket: group.bucket,
              targets: group.targets,
              sceneId: scene.id,
              onTargetSelected: onTargetSelected,
            ),
        const SizedBox(height: 16),

        OcptResourcesSheetField(
          ownerId: scene.id,
          label: tr.breakdownSceneNotesLabel,
          value: notesValue,
          multiline: true,
          onChanged: isReadOnly ? null : onNotesChanged,
        ),

        const SizedBox(height: 8),
        Divider(height: 1, color: theme.colorScheme.outlineVariant),
        const SizedBox(height: 8),
        Text(
          tr.breakdownSceneInspectorFooterHint,
          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }

  /// Read the scene of [widget], or null while it has none.
  static _OcptBreakdownSceneInspection? _inspectionOf(OcptBreakdownSceneInspector widget) {
    final scene = widget.scene;
    return scene == null ? null : _OcptBreakdownSceneInspection.of(scene, widget.targetById);
  }
}

/// The scene's own breakdown status chips, one per [OcptBreakdownSceneStatus], the current one
/// filled — the read-out for the fact the third stat tile used to show. A null [onStatusChanged]
/// withholds the pick itself while leaving the current one visible.
class _StatusChips extends StatelessWidget {
  /// The status the scene currently has.
  final OcptBreakdownSceneStatus currentStatus;

  /// Called with the status just picked, or null while it may not be changed.
  final ValueChanged<OcptBreakdownSceneStatus>? onStatusChanged;

  /// Class constructor
  const _StatusChips({required this.currentStatus, required this.onStatusChanged});

  /// Build the status chips as a [Wrap].
  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final onStatusChanged = this.onStatusChanged;

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final status in OcptBreakdownSceneStatus.values)
          OcptBreakdownChoiceChip(
            label: ocptBreakdownSceneStatusLabel(tr, status),
            color: ocptBreakdownSceneStatusColor(context, status),
            isSelected: currentStatus == status,
            onTap: onStatusChanged == null ? null : () => onStatusChanged(status),
          ),
      ],
    );
  }
}

/// The sets the scene is shot in, as chips, followed by the picker adding one.
///
/// A scene is regularly covered in two sets, so the picker **adds** rather than replaces, exactly
/// as the resources mode's own scene picker does from the other side; the sets already linked are
/// left out of it, and the suggested one comes first, marked as a suggestion.
class _SetsRow extends StatelessWidget {
  /// The id of the scene the row belongs to.
  final String sceneId;

  /// The whole set catalogue.
  final List<OcptSet> sets;

  /// The name of every live location, keyed by id.
  final Map<String, String> locationNameById;

  /// The id of the set the scene's heading suggests, or null.
  final String? suggestedSetId;

  /// Called with a set's id when it is picked, or null while it may not be written.
  final ValueChanged<String>? onSetLinked;

  /// Called with a set's id when its chip is dismissed, or null while it may not be written.
  final ValueChanged<String>? onSetUnlinked;

  /// Every live location of the project, `(id, name)`.
  final List<(String, String)> locations;

  /// The picker's name field's default text.
  final String newSetName;

  /// Called when a create-in entry of the picker is clicked, or null while nothing may be written.
  final void Function(String name, String? locationId)? onSetCreationRequested;

  /// Class constructor
  const _SetsRow({
    required this.sceneId,
    required this.sets,
    required this.locationNameById,
    required this.suggestedSetId,
    required this.onSetLinked,
    required this.onSetUnlinked,
    required this.locations,
    required this.newSetName,
    required this.onSetCreationRequested,
  });

  /// Build the sets row as a [Wrap].
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final onSetUnlinked = this.onSetUnlinked;
    final onSetLinked = this.onSetLinked;
    final onSetCreationRequested = this.onSetCreationRequested;
    final linked = [
      for (final set in sets)
        if (set.sceneIds.contains(sceneId)) set,
    ];

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (linked.isEmpty)
          Text(
            tr.breakdownSceneInspectorNoSetHint,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        for (final set in linked)
          Chip(
            label: Text(ocptBreakdownSetLabel(set, locationNameById)),
            onDeleted: onSetUnlinked == null ? null : () => onSetUnlinked(set.id),
          ),
        if (onSetLinked != null && onSetCreationRequested != null)
          OcptBreakdownSetPickerPopover(
            defaultName: newSetName,
            sets: sets,
            locationNameById: locationNameById,
            sceneId: sceneId,
            suggestedSetId: suggestedSetId,
            locations: locations,
            onSetLinked: onSetLinked,
            onSetCreationRequested: onSetCreationRequested,
          ),
      ],
    );
  }
}

/// The warning callout naming the elements still to find, comma-joined.
class _ToFindAlert extends StatelessWidget {
  /// The targets still to find.
  final List<OcptBreakdownTarget> toFindTargets;

  /// Class constructor
  const _ToFindAlert({required this.toFindTargets});

  /// Build the to find alert as a [Container].
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final color = ocptWarningColor(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: ocpt_theme.ocptSelectedStateAlpha),
        borderRadius: BorderRadius.circular(ocpt_theme.ocptRadiusMedium),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr.breakdownSceneInspectorAlertTitle(toFindTargets.length),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  toFindTargets.map((target) => target.name).join(", "),
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The warning callout listing the flagged tags — `OcptBreakdownSceneInspector`'s own doc comment
/// for what each row offers and why both its actions act straight away, with no inline
/// confirmation of their own.
class _ToCheckAlert extends StatelessWidget {
  /// The tags whose `needsCheck` is set.
  final List<OcptBreakdownTag> flaggedTags;

  /// `{(kind, id): target}`, resolving each tag's target.
  final OcptBreakdownTargetsById targetById;

  /// Called with a tag's id when `Mark as checked` is clicked, or null while it may not be
  /// answered.
  final ValueChanged<String>? onTagNeedsCheckCleared;

  /// Called with a tag's id when `Remove` is clicked, or null while it may not be answered.
  final ValueChanged<String>? onFlaggedTagRemoved;

  /// Class constructor
  const _ToCheckAlert({
    required this.flaggedTags,
    required this.targetById,
    required this.onTagNeedsCheckCleared,
    required this.onFlaggedTagRemoved,
  });

  /// Build the to check alert as a [Container].
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final color = ocptWarningColor(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: ocpt_theme.ocptSelectedStateAlpha),
        borderRadius: BorderRadius.circular(ocpt_theme.ocptRadiusMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber_rounded, size: 16, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tr.breakdownSceneInspectorNeedsCheckAlertTitle(flaggedTags.length),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          for (final tag in flaggedTags)
            _NeedsCheckRow(
              tag: tag,
              target: targetById[(tag.targetKind, tag.targetId)],
              onTagNeedsCheckCleared: onTagNeedsCheckCleared,
              onFlaggedTagRemoved: onFlaggedTagRemoved,
            ),
        ],
      ),
    );
  }
}

/// One row of [_ToCheckAlert]: the tag's own passage, verbatim, and the name of the target it
/// points at — a null target (a tombstoned catalogue row, per `OcptBreakdownSnapshot.build`'s own
/// doc comment) shows the passage alone rather than crashing — then its two actions, each withheld
/// while its callback is null.
class _NeedsCheckRow extends StatelessWidget {
  /// The flagged tag.
  final OcptBreakdownTag tag;

  /// The target [tag] points at, or null when it no longer resolves.
  final OcptBreakdownTarget? target;

  /// Called with the tag's id when `Mark as checked` is clicked, or null while it may not be
  /// answered.
  final ValueChanged<String>? onTagNeedsCheckCleared;

  /// Called with the tag's id when `Remove` is clicked, or null while it may not be answered.
  final ValueChanged<String>? onFlaggedTagRemoved;

  /// Class constructor
  const _NeedsCheckRow({
    required this.tag,
    required this.target,
    required this.onTagNeedsCheckCleared,
    required this.onFlaggedTagRemoved,
  });

  /// Build the needs check row as a [Padding].
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final color = ocptWarningColor(context);
    final target = this.target;
    final onTagNeedsCheckCleared = this.onTagNeedsCheckCleared;
    final onFlaggedTagRemoved = this.onFlaggedTagRemoved;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            target == null
                ? tr.breakdownSceneInspectorNeedsCheckRowNoTarget(tag.taggedText)
                : tr.breakdownSceneInspectorNeedsCheckRow(tag.taggedText, target.name),
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface),
          ),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 4,
            runSpacing: 2,
            children: [
              TextButton(
                onPressed: onTagNeedsCheckCleared == null
                    ? null
                    : () => onTagNeedsCheckCleared(tag.id),
                style: TextButton.styleFrom(
                  foregroundColor: color,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(tr.breakdownSceneInspectorNeedsCheckClearAction),
              ),
              TextButton(
                onPressed: onFlaggedTagRemoved == null ? null : () => onFlaggedTagRemoved(tag.id),
                style: TextButton.styleFrom(
                  foregroundColor: color,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(tr.breakdownSceneInspectorNeedsCheckRemoveAction),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The dashed hint shown while the scene has no live target at all.
class _EmptyHint extends StatelessWidget {
  /// Class constructor
  const _EmptyHint();

  /// Build the empty hint as a [Container].
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(ocpt_theme.ocptRadiusMedium),
      ),
      child: Text(
        tr.breakdownSceneInspectorEmptyHint,
        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }
}

/// One category (or role/set) group: [bucket]'s own swatch, label and count, then a clickable row
/// per target of [targets], which are the ones falling under it.
class _Group extends StatelessWidget {
  /// The bucket the group shows.
  final OcptBreakdownSceneBarBucket bucket;

  /// The live targets of the scene under [bucket], alphabetised by name.
  final List<OcptBreakdownTarget> targets;

  /// The id of the scene the targets are selected under.
  final String sceneId;

  /// Called with a target's kind, its id and [sceneId] when one of its rows is clicked.
  final void Function(OcptBreakdownTargetKind kind, String id, String sceneId) onTargetSelected;

  /// Class constructor
  const _Group({
    required this.bucket,
    required this.targets,
    required this.sceneId,
    required this.onTargetSelected,
  });

  /// Build the group as a [Padding].
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Color(bucket.color),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  ocptBreakdownSceneBarBucketLabel(tr, bucket).toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Color(bucket.color),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                "${targets.length}",
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final target in targets)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: InkWell(
                onTap: () => onTargetSelected(target.kind, target.id, sceneId),
                mouseCursor: ocpt_theme.ocptClickableCursor,
                borderRadius: BorderRadius.circular(ocpt_theme.ocptRadiusSmall),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(ocpt_theme.ocptRadiusSmall),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          target.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                      if (target.status != null) ...[
                        const SizedBox(width: 8),
                        _StatusPill(status: target.status!),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One of the two stat tiles under the scene's own heading.
class _StatTile extends StatelessWidget {
  /// The tile's own small, muted label.
  final String label;

  /// The tile's own value.
  final String value;

  /// The value's own colour, or null for the theme's plain text colour.
  final Color? color;

  /// Class constructor
  const _StatTile({required this.label, required this.value, this.color});

  /// Build the stat tile as a [Container].
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(ocpt_theme.ocptRadiusMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}

/// The small status pill shown beside a target row, only when the target carries one
/// (`OcptBreakdownTarget.status` is non-null only for an element).
class _StatusPill extends StatelessWidget {
  /// The status shown.
  final OcptElementStatus status;

  /// Class constructor
  const _StatusPill({required this.status});

  /// Build the status pill as a [Container].
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = ocptElementStatusColor(context, status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: ocpt_theme.ocptSelectedStateAlpha),
        borderRadius: BorderRadius.circular(ocpt_theme.ocptRadiusLarge),
      ),
      child: Text(
        ocptElementStatusLabel(Tr.of(context), status),
        style: theme.textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
