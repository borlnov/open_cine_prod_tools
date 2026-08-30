// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_recent_project_model.dart';
import 'package:open_cine_prod_tools/models/ocpt_specific_colors.dart';
import 'package:open_cine_prod_tools/ui/pages/home/home_state.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_relative_time.dart';

/// A single project tile in the home page's project grid.
///
/// Shows a poster-like tinted area with the project's initial letter (a placeholder ahead of real
/// thumbnails), the project name, its file path, and how long ago it was last opened. The tint
/// comes from [OcptSpecificColors.projectPosterTints], indexed by [_stablePathHash] of the
/// project's path so a project keeps the same colour across launches and machines. When
/// [OcptHomeRecentProjectEntry.exists] is false, the whole card is greyed out, tapping it is
/// disabled, and a tooltip explains why; the overflow menu still offers to remove it from the list,
/// the entry being worth clearing away even when the project it names is gone, while `Export…` goes
/// disabled with the card — there is no file left to read, let alone to package.
///
/// The `⋮` overflow menu holds three entries: `Export…`, writing the project out as a portable
/// package without opening it first (the same flow the toolbar's own `Export` panel runs from
/// inside a project, `MixinOcptProjectPackageBloc`), `Partager / Synchroniser…`, opening the
/// project and navigating to its Partager screen (`OcptRoute.sharing`), and `Remove from list`.
///
/// A project holding several episodes wears a small `⟨N episodes⟩` pill in the poster's top-left
/// corner ([_OcptProjectCardEpisodeBadge]), mirroring the `⋮` overflow menu's own top-right one.
/// [OcptRecentProjectModel.episodeCount] being null (an entry written before this app version
/// recorded it) or 1 (a single-episode project, which never names an episode anywhere) both draw
/// nothing at all — a single-episode project stays exactly what it is today.
class OcptProjectCard extends StatelessWidget {
  /// The recent project shown by this card.
  final OcptHomeRecentProjectEntry entry;

  /// Called when the card is tapped, unless [OcptHomeRecentProjectEntry.exists] is false.
  final VoidCallback onTap;

  /// Called when "Export…" is chosen from the overflow menu, unless
  /// [OcptHomeRecentProjectEntry.exists] is false: there is no file to scan or to package for an
  /// entry whose project can't be found any more.
  final VoidCallback onExport;

  /// Called when "Partager / Synchroniser…" is chosen from the overflow menu, unless
  /// [OcptHomeRecentProjectEntry.exists] is false: there is no file to open, let alone to pair
  /// with a relay, for an entry whose project can't be found any more.
  final VoidCallback onShare;

  /// Called when "Remove from list" is chosen from the overflow menu.
  final VoidCallback onRemove;

  /// Class constructor
  const OcptProjectCard({
    required this.entry,
    required this.onTap,
    required this.onExport,
    required this.onShare,
    required this.onRemove,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final exists = entry.exists;
    final episodeCount = entry.project.episodeCount;

    final posterTints = Theme.of(context).extension<OcptSpecificColors>()!.projectPosterTints;
    final posterTint = posterTints[_stablePathHash(entry.project.path) % posterTints.length];
    final onPosterTint = ThemeData.estimateBrightnessForColor(posterTint) == Brightness.dark
        ? Colors.white
        : Colors.black;

    final card = Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey(entry.project.path),
        onTap: exists ? onTap : null,
        mouseCursor: ocptClickableCursor,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ColoredBox(
                      color: posterTint,
                      child: Center(
                        child: Text(
                          entry.project.name.isEmpty ? "?" : entry.project.name[0].toUpperCase(),
                          style: Theme.of(context).textTheme.displayMedium?.copyWith(
                            color: onPosterTint,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (episodeCount != null && episodeCount > 1)
                    Positioned(
                      top: 4,
                      left: 4,
                      // Stops short of the `⋮` menu's own tap target rather than the card's edge,
                      // so the two can never overlap.
                      right: 40,
                      child: Align(
                        alignment: AlignmentDirectional.topStart,
                        child: _OcptProjectCardEpisodeBadge(
                          count: episodeCount,
                          color: onPosterTint,
                        ),
                      ),
                    ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: PopupMenuButton<void>(
                      icon: const Icon(Icons.more_vert),
                      tooltip: MaterialLocalizations.of(context).showMenuTooltip,
                      itemBuilder: (context) => [
                        PopupMenuItem<void>(
                          enabled: exists,
                          onTap: onExport,
                          child: Text(tr.homeExportProjectAction),
                        ),
                        PopupMenuItem<void>(
                          enabled: exists,
                          onTap: onShare,
                          child: Text(tr.homeShareProjectAction),
                        ),
                        PopupMenuItem<void>(
                          onTap: onRemove,
                          child: Text(tr.homeRemoveFromListAction),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    entry.project.name,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    entry.project.path,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatRelativeTime(context, entry.project.lastOpenedAt),
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (exists) {
      return card;
    }

    return Tooltip(
      message: tr.homeMissingFileTooltip,
      child: Opacity(opacity: 0.5, child: card),
    );
  }
}

/// Hashes [path] into a non-negative integer that is stable across app runs, Dart versions and
/// machines, unlike [Object.hashCode] (used here to pick a poster tint that must stay the same
/// for a given project everywhere).
int _stablePathHash(String path) {
  var hash = 5381;
  for (final unit in path.codeUnits) {
    hash = ((hash << 5) + hash + unit) & 0x7fffffff;
  }
  return hash;
}

/// The `⟨N episodes⟩` pill drawn in the top-left of a multi-episode project's poster, mirroring
/// the `⋮` overflow menu's own top-right corner.
///
/// Tinted off [color] (the card's own `onPosterTint`, already legible against the poster) rather
/// than a fixed scheme colour, since the poster tint it sits on varies per project.
class _OcptProjectCardEpisodeBadge extends StatelessWidget {
  /// How many live episodes the project holds — always > 1, the card only building this widget
  /// then.
  final int count;

  /// The colour legible against this card's own poster tint, text and background alike.
  final Color color;

  /// Class constructor
  const _OcptProjectCardEpisodeBadge({required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: ocptSelectedStateAlpha),
        borderRadius: BorderRadius.circular(ocptRadiusLarge),
      ),
      child: Text(
        Tr.of(context).homeProjectEpisodeCount(count),
        style: theme.textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w600),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
