// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_scene.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_tag.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_target.dart';
import 'package:open_cine_prod_tools/models/ocpt_set.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_scene_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_target_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_status.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/widgets/ocpt_breakdown_choice_chip.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_resources_sheet_field.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_breakdown_labels.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_warning_color.dart';
import 'package:open_cine_prod_tools/utils/ocpt_breakdown_scene_bars.dart';

/// The right dock's `Inspector` tab while a scene is selected and no target is: the scene's own
/// breakdown sheet — counts, its own status chips, **the sets it is shot in**, an alert naming the
/// elements still to find, a second alert listing the tags a save could not re-anchor, its targets
/// grouped by category and its own breakdown notes.
///
/// The sets row ([_buildSetsRow]) is the one part of this sheet that is not about tags: it reads and
/// writes the `scene_sets` link directly, so a link made by hand in the resources mode shows here
/// too, and one made here shows there. It is where a breakdown sheet names its décor, which is why
/// it sits at the top rather than among the tagged targets below. Adding a set is **not** tagging a
/// passage: no tag is created, nothing in the script is highlighted, and removing a set here leaves
/// every tag pointing at it exactly where it is — the tag and the link are two separate facts, as
/// `OcptBreakdownService.deleteTag`'s own doc comment spells out from the other side.
///
/// The "to check" alert ([_buildToCheckAlert]) is the same visual shape as the "to find" one right
/// above it — the warning colour, the same callout — but lists [OcptBreakdownScene.tags] whose
/// [OcptBreakdownTag.needsCheck] is set, one row per tag: the passage verbatim, and the target it
/// points at when [targetById] still resolves one (a tombstoned catalogue row still keeps its tag on
/// the scene — `OcptBreakdownSnapshot.build`'s own doc comment — so a row whose target is gone shows
/// the passage alone rather than crashing). Each row offers `Mark as checked` (clears the flag alone,
/// leaving the offsets exactly where they are — the honest answer to "the passage now occurs twice
/// in the scene so it could not be re-anchored unambiguously, but the one this tag points at is
/// still right") and `Remove` (tombstones that one tag). Both act **straight away, with no inline
/// confirmation**: the alert itself is the question, exactly as `OcptRemovedRoleBanner`'s own actions
/// do in the resources mode.
///
/// Purely presentational, like `OcptShotInspectorPanel`. [isReadOnly] withholds every control that
/// writes — the status chips, the sets row's own picker and chip dismissals, the notes field and the
/// "to check" alert's two actions — while leaving
/// every read (the sheet itself, both alerts' own listing, and a click on one of its target rows,
/// `onTargetSelected`) in place, mirroring `OcptBreakdownTargetInspector`'s own convention: the panel
/// takes the real callbacks and nulls them out itself, so a control added later cannot be gated in
/// one place and forgotten in the other. [onTargetSelected] is never withheld: selecting writes
/// nothing whatever a previewed version's own gating says.
class OcptBreakdownSceneInspector extends StatelessWidget {
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
    required this.notesValue,
    required this.onTargetSelected,
    required this.onStatusChanged,
    required this.onNotesChanged,
    required this.onTagNeedsCheckCleared,
    required this.onFlaggedTagRemoved,
    this.isReadOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final scene = this.scene;

    if (scene == null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          tr.breakdownInspectorNoSelectionHint,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      );
    }

    final targets = ocptBreakdownSceneTargetsOf(scene, targetById);
    final toFindTargets = targets.where((target) => target.status == OcptElementStatus.toFind);
    final flaggedTags = scene.tags.where((tag) => tag.needsCheck).toList();
    final buckets = ocptBreakdownSceneBarBucketsOf(scene, targetById);

    return ListView(
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
        _buildStatusChips(context, scene),
        const SizedBox(height: 16),

        Text(
          tr.breakdownSceneInspectorSetsLabel.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        _buildSetsRow(context, tr, scene),
        const SizedBox(height: 16),

        if (toFindTargets.isNotEmpty) ...[
          _buildToFindAlert(context, tr, toFindTargets.toList()),
          const SizedBox(height: 16),
        ],

        if (flaggedTags.isNotEmpty) ...[
          _buildToCheckAlert(context, tr, flaggedTags),
          const SizedBox(height: 16),
        ],

        Text(
          tr.breakdownSceneInspectorTargetsSectionTitle.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),

        if (targets.isEmpty)
          _buildEmptyHint(context, tr)
        else
          for (final bucket in buckets) _buildGroup(context, tr, bucket, targets, scene.id),
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

  /// The scene's own breakdown status chips, one per [OcptBreakdownSceneStatus], the current one
  /// filled — the read-out for the fact the third stat tile used to show, [isReadOnly] withholding
  /// the pick itself while leaving the current one visible.
  Widget _buildStatusChips(BuildContext context, OcptBreakdownScene scene) => Wrap(
    spacing: 6,
    runSpacing: 6,
    children: [
      for (final status in OcptBreakdownSceneStatus.values)
        OcptBreakdownChoiceChip(
          label: ocptBreakdownSceneStatusLabel(Tr.of(context), status),
          color: ocptBreakdownSceneStatusColor(context, status),
          isSelected: scene.status == status,
          onTap: isReadOnly || onStatusChanged == null ? null : () => onStatusChanged!(status),
        ),
    ],
  );

  /// The sets [scene] is shot in, as chips, followed by the picker adding one.
  ///
  /// A scene is regularly covered in two sets, so the picker **adds** rather than replaces, exactly
  /// as the resources mode's own scene picker does from the other side; the sets already linked are
  /// left out of it, and the suggested one comes first, marked as a suggestion.
  Widget _buildSetsRow(BuildContext context, Tr tr, OcptBreakdownScene scene) {
    final theme = Theme.of(context);
    final onSetUnlinked = this.onSetUnlinked;
    final linked = [
      for (final set in sets)
        if (set.sceneIds.contains(scene.id)) set,
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
        if (onSetLinked != null) _buildSetPicker(context, tr, scene),
      ],
    );
  }

  /// The `+ Set` picker: every set [scene] is not already shot in, the suggested one first.
  ///
  /// Drawn only while there is something left to offer — a project whose every set already covers
  /// this scene, or one with no set at all, shows the chips (or the hint) alone. Creating a set is
  /// deliberately **not** offered here: a set belongs to a location, and the place that question is
  /// answered is the script view's own tag popover, which knows the passage that names it.
  Widget _buildSetPicker(BuildContext context, Tr tr, OcptBreakdownScene scene) {
    final onSetLinked = this.onSetLinked!;

    final suggested = <OcptSet>[];
    final others = <OcptSet>[];
    for (final set in sets) {
      if (set.sceneIds.contains(scene.id)) {
        continue;
      }

      (set.id == suggestedSetId ? suggested : others).add(set);
    }

    if (suggested.isEmpty && others.isEmpty) {
      return const SizedBox.shrink();
    }

    return PopupMenuButton<String>(
      tooltip: "",
      onSelected: onSetLinked,
      itemBuilder: (context) => [
        for (final set in suggested)
          PopupMenuItem<String>(
            value: set.id,
            child: Text(
              tr.breakdownSceneInspectorSetSuggestedOption(
                ocptBreakdownSetLabel(set, locationNameById),
              ),
            ),
          ),
        for (final set in others)
          PopupMenuItem<String>(
            value: set.id,
            child: Text(ocptBreakdownSetLabel(set, locationNameById)),
          ),
      ],
      child: Chip(
        avatar: const Icon(Icons.add, size: 14),
        label: Text(tr.breakdownSceneInspectorAddSetAction),
      ),
    );
  }

  /// The warning callout naming [toFindTargets], comma-joined.
  Widget _buildToFindAlert(BuildContext context, Tr tr, List<OcptBreakdownTarget> toFindTargets) {
    final theme = Theme.of(context);
    final color = ocptWarningColor(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: ocptSelectedStateAlpha),
        borderRadius: BorderRadius.circular(ocptRadiusMedium),
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

  /// The warning callout listing [flaggedTags] — this class's own doc comment for what each row
  /// offers and why both its actions act straight away, with no inline confirmation of their own.
  Widget _buildToCheckAlert(BuildContext context, Tr tr, List<OcptBreakdownTag> flaggedTags) {
    final theme = Theme.of(context);
    final color = ocptWarningColor(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: ocptSelectedStateAlpha),
        borderRadius: BorderRadius.circular(ocptRadiusMedium),
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
          for (final tag in flaggedTags) _buildNeedsCheckRow(context, tr, tag),
        ],
      ),
    );
  }

  /// One row of [_buildToCheckAlert]: [tag]'s own passage, verbatim, and the name of the target it
  /// points at — [targetById] resolving to nothing (a tombstoned catalogue row, per
  /// `OcptBreakdownSnapshot.build`'s own doc comment) shows the passage alone rather than crashing —
  /// then, unless [isReadOnly], its two actions.
  Widget _buildNeedsCheckRow(BuildContext context, Tr tr, OcptBreakdownTag tag) {
    final theme = Theme.of(context);
    final color = ocptWarningColor(context);
    final target = targetById[(tag.targetKind, tag.targetId)];

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
                onPressed: isReadOnly || onTagNeedsCheckCleared == null
                    ? null
                    : () => onTagNeedsCheckCleared!(tag.id),
                style: TextButton.styleFrom(
                  foregroundColor: color,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(tr.breakdownSceneInspectorNeedsCheckClearAction),
              ),
              TextButton(
                onPressed: isReadOnly || onFlaggedTagRemoved == null
                    ? null
                    : () => onFlaggedTagRemoved!(tag.id),
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

  /// The dashed hint shown while [scene] has no live target at all.
  Widget _buildEmptyHint(BuildContext context, Tr tr) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(ocptRadiusMedium),
      ),
      child: Text(
        tr.breakdownSceneInspectorEmptyHint,
        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }

  /// One category (or role/set) group: [bucket]'s own swatch, label and count, then a clickable row
  /// per target of [allTargets] falling under it, alphabetised by name.
  Widget _buildGroup(
    BuildContext context,
    Tr tr,
    OcptBreakdownSceneBarBucket bucket,
    List<OcptBreakdownTarget> allTargets,
    String sceneId,
  ) {
    final theme = Theme.of(context);
    final groupTargets =
        allTargets.where((target) => target.kind == bucket.kind && target.category == bucket.category).toList()
          ..sort((a, b) => a.name.compareTo(b.name));

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
                "${groupTargets.length}",
                style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final target in groupTargets)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: InkWell(
                onTap: () => onTargetSelected(target.kind, target.id, sceneId),
                mouseCursor: ocptClickableCursor,
                borderRadius: BorderRadius.circular(ocptRadiusSmall),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(ocptRadiusSmall),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(ocptRadiusMedium),
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
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = ocptElementStatusColor(context, status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: ocptSelectedStateAlpha),
        borderRadius: BorderRadius.circular(ocptRadiusLarge),
      ),
      child: Text(
        ocptElementStatusLabel(Tr.of(context), status),
        style: theme.textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
