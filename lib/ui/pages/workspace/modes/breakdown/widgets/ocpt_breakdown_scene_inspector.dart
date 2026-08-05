// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_scene.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_target.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_target_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_status.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_breakdown_labels.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_warning_color.dart';
import 'package:open_cine_prod_tools/utils/ocpt_breakdown_scene_bars.dart';

/// The right dock's `Inspector` tab while a scene is selected and no target is: the scene's own
/// breakdown sheet — counts, an alert naming the elements still to find, and its targets grouped by
/// category.
///
/// Purely presentational, like `OcptShotInspectorPanel`, but with nothing to write: the scene's
/// breakdown status shown here is a read-out (`ocptBreakdownSceneStatusLabel`), its own control
/// belonging to a later change, so this panel carries no `isReadOnly` flag — a click on one of its
/// target rows only selects that target (`onTargetSelected`), and selecting writes nothing whatever
/// a previewed version's own gating says.
class OcptBreakdownSceneInspector extends StatelessWidget {
  /// The selected scene, or null while nothing at all is selected — the mode's own empty message is
  /// shown then.
  final OcptBreakdownScene? scene;

  /// `{(kind, id): target}`, built once by the mode from the loaded snapshot's targets.
  final OcptBreakdownTargetsById targetById;

  /// Called with a target's kind, its id and [scene]'s own id when one of its rows is clicked.
  final void Function(OcptBreakdownTargetKind kind, String id, String sceneId) onTargetSelected;

  /// Class constructor
  const OcptBreakdownSceneInspector({
    super.key,
    required this.scene,
    required this.targetById,
    required this.onTargetSelected,
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
            const SizedBox(width: 8),
            Expanded(
              child: _StatTile(
                label: tr.breakdownSceneInspectorStatusLabel,
                value: ocptBreakdownSceneStatusLabel(tr, scene.status),
                color: ocptBreakdownSceneStatusColor(context, scene.status),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        if (toFindTargets.isNotEmpty) ...[
          _buildToFindAlert(context, tr, toFindTargets.toList()),
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

/// One of the three stat tiles under the scene's own heading.
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
