// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_scene.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_scene_status.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/widgets/ocpt_breakdown_category_legend.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_breakdown_labels.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_warning_color.dart';
import 'package:open_cine_prod_tools/utils/ocpt_breakdown_legend.dart';
import 'package:open_cine_prod_tools/utils/ocpt_breakdown_scene_bars.dart';

/// The breakdown mode's left dock: one row per scene, each showing its number — with a small ⚠
/// beside it while the scene holds at least one tag a save could not re-anchor
/// (`OcptBreakdownTag.needsCheck`), mirroring `OcptShotListSequencePanel`'s own mark on a flagged
/// shot's code — heading, a bar per category (or role/set kind) its tags cover and how many
/// distinct things are tagged in it, and its own breakdown status on the right — then, under a
/// divider, the category legend ([OcptBreakdownCategoryLegend]).
///
/// Width-agnostic, like the shot list's own sequence panel: it fills whatever width its parent
/// `OcptWorkspaceDock` gives it and owns no background of its own. Clicking a row selects that
/// scene, which is what both `OcptBreakdownScriptView` and (once it lands) the scene inspector read
/// off — this panel itself never scrolls the script view to it, since the two are siblings of the
/// same shell rather than one driving the other. The legend's own callbacks pass straight through:
/// this panel hosts it (the plan puts the legend in the left dock, under the scenes) without
/// knowing anything about what a hidden key does to the script view.
class OcptBreakdownScenePanel extends StatelessWidget {
  /// The scenes to list, in source order.
  final List<OcptBreakdownScene> scenes;

  /// `{(kind, id): target}`, built once by the mode from the loaded snapshot's targets, so each
  /// row resolves its own tags' categories without walking the whole target list.
  final OcptBreakdownTargetsById targetById;

  /// The id of the selected scene, or null if none is.
  final String? selectedSceneId;

  /// Called with a scene's id when its row is clicked.
  final ValueChanged<String> onSceneSelected;

  /// The category legend's own rows, already built by `ocptBreakdownLegendEntriesOf` from the
  /// loaded snapshot's targets.
  final List<OcptBreakdownLegendEntry> legendEntries;

  /// The legend keys currently hidden from the script view's own highlighting.
  final Set<OcptBreakdownLegendKey> hiddenLegendKeys;

  /// Called with a legend entry's key when its row is clicked, toggling whether it is hidden.
  final ValueChanged<OcptBreakdownLegendKey> onLegendEntryToggled;

  /// Called when the legend's `Show all` action is clicked.
  final VoidCallback onShowAllLegendKeysRequested;

  /// Class constructor
  const OcptBreakdownScenePanel({
    super.key,
    required this.scenes,
    required this.targetById,
    required this.selectedSceneId,
    required this.onSceneSelected,
    required this.legendEntries,
    required this.hiddenLegendKeys,
    required this.onLegendEntryToggled,
    required this.onShowAllLegendKeysRequested,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final doneCount = scenes
        .where((scene) => scene.status == OcptBreakdownSceneStatus.done)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(tr.breakdownScenesPanelTitle, style: theme.textTheme.titleSmall),
              ),
              Text(
                tr.breakdownScenesDoneCount(doneCount, scenes.length),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: scenes.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    tr.breakdownScenesEmptyHint,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: scenes.length,
                  itemBuilder: (context, index) => _SceneEntry(
                    scene: scenes[index],
                    targetById: targetById,
                    isSelected: scenes[index].id == selectedSceneId,
                    onTap: () => onSceneSelected(scenes[index].id),
                  ),
                ),
        ),
        const Divider(height: 1),
        OcptBreakdownCategoryLegend(
          entries: legendEntries,
          hiddenKeys: hiddenLegendKeys,
          onEntryToggled: onLegendEntryToggled,
          onShowAllRequested: onShowAllLegendKeysRequested,
        ),
      ],
    );
  }
}

/// One scene of the panel: its own clickable row, a ⚠ beside its number when it holds a flagged
/// tag.
class _SceneEntry extends StatelessWidget {
  /// The scene this entry shows.
  final OcptBreakdownScene scene;

  /// `{(kind, id): target}`, forwarded from [OcptBreakdownScenePanel].
  final OcptBreakdownTargetsById targetById;

  /// Whether this scene is the selected one.
  final bool isSelected;

  /// Called when this entry is clicked.
  final VoidCallback onTap;

  /// Class constructor
  const _SceneEntry({
    required this.scene,
    required this.targetById,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final buckets = ocptBreakdownSceneBarBucketsOf(scene, targetById);
    final targetCount = ocptBreakdownSceneTargetsOf(scene, targetById).length;

    return InkWell(
      onTap: onTap,
      mouseCursor: ocptClickableCursor,
      child: ColoredBox(
        color: isSelected
            ? theme.colorScheme.primary.withValues(alpha: ocptSelectedStateAlpha)
            : Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  scene.displayNumber,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (scene.tags.any((tag) => tag.needsCheck))
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Tooltip(
                    message: tr.breakdownTagNeedsCheckTooltip,
                    child: Icon(
                      Icons.warning_amber_rounded,
                      size: 12,
                      color: ocptWarningColor(context),
                    ),
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      scene.heading,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isSelected
                            ? theme.colorScheme.onSurface
                            : theme.colorScheme.onSurfaceVariant,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    if (buckets.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 3,
                        runSpacing: 3,
                        children: [for (final bucket in buckets) _CategoryBar(bucket: bucket)],
                      ),
                    ],
                    const SizedBox(height: 2),
                    Text(
                      tr.breakdownSceneElementsCount(targetCount),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  ocptBreakdownSceneStatusLabel(tr, scene.status),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: ocptBreakdownSceneStatusColor(context, scene.status),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The narrowest a category bar is ever drawn, in logical pixels — one target still reads as a bar
/// rather than a dot.
const double _ocptBreakdownBarMinWidth = 10;

/// How much wider a category bar grows per additional target it counts, in logical pixels.
const double _ocptBreakdownBarWidthPerTarget = 5;

/// The widest a category bar is ever drawn, in logical pixels — past this, the bar stops growing so
/// one very common category can't push a scene's whole row out of shape.
const double _ocptBreakdownBarMaxWidth = 48;

/// The height every category bar is drawn at, in logical pixels.
const double _ocptBreakdownBarHeight = 5;

/// One small rounded colour bar of a scene's row, tooltipped with the category (or role/set) it
/// counts.
class _CategoryBar extends StatelessWidget {
  /// The bucket this bar draws.
  final OcptBreakdownSceneBarBucket bucket;

  /// Class constructor
  const _CategoryBar({required this.bucket});

  @override
  Widget build(BuildContext context) => Tooltip(
    message: ocptBreakdownSceneBarBucketLabel(Tr.of(context), bucket),
    child: Container(
      height: _ocptBreakdownBarHeight,
      width: (_ocptBreakdownBarMinWidth + bucket.count * _ocptBreakdownBarWidthPerTarget).clamp(
        _ocptBreakdownBarMinWidth,
        _ocptBreakdownBarMaxWidth,
      ),
      decoration: BoxDecoration(
        color: Color(bucket.color),
        borderRadius: BorderRadius.circular(ocptRadiusSmall),
      ),
    ),
  );
}
