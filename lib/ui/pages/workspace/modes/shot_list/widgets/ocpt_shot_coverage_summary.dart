// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_coverage_layout.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_coverage_range.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_fountain_line_type_labels.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_shot_list_labels.dart';

/// The shot inspector's "Scenario coverage" section: a **read-only** list of the extracts the
/// selected shot covers, one entry per range, in the order they read in the sequence.
///
/// The selecting itself happens in `OcptShotCoverageDialog`, opened by this section's own
/// `Select…` button ([onSelectRequested]): the right dock is too narrow to click words in
/// comfortably, and a shot's coverage is read far more often than it is authored, so the dock
/// shows what was selected while the dialog is where it gets selected. Nothing here is clickable
/// but that button and [onClearAll] — a single range is removed from the dialog, by clicking the
/// text it covers.
///
/// [layout] is null for an orphaned shot: its sequence's text is gone, so there is nothing left to
/// quote (nor to select), and a short hint replaces both the list and the button.
class OcptShotCoverageSummary extends StatelessWidget {
  /// The selected shot's sequence, laid out into blocks and words, or null for an orphaned shot.
  final OcptShotCoverageLayout? layout;

  /// The selected shot's own coverage ranges.
  final List<OcptShotCoverageRange> ownRanges;

  /// Every other shot's coverage ranges of [layout]'s scene, keyed by that shot's code.
  final Map<String, List<OcptShotCoverageRange>> otherShotsRanges;

  /// The ids of [ownRanges] currently disagreeing with the sequence's text, which is what marks an
  /// extract as `modified`.
  final Set<String> staleRangeIds;

  /// Called when the `Select…` button is clicked, to open the coverage dialog.
  final VoidCallback onSelectRequested;

  /// Called when the `Clear all` action is clicked.
  final VoidCallback onClearAll;

  /// Class constructor
  const OcptShotCoverageSummary({
    super.key,
    required this.layout,
    required this.ownRanges,
    required this.otherShotsRanges,
    required this.staleRangeIds,
    required this.onSelectRequested,
    required this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final layout = this.layout;

    if (layout == null) {
      return Text(
        tr.shotListCoverageOrphanHint,
        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      );
    }

    final ranges = layout.rangesInReadingOrder(ownRanges);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: onSelectRequested,
            icon: const Icon(Icons.highlight_alt_outlined, size: 16),
            label: Text(tr.shotListCoverageSelectAction),
          ),
        ),
        const SizedBox(height: 8),
        if (ranges.isEmpty)
          Text(
            tr.shotListCoverageEmptyHint,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          )
        else
          for (final range in ranges)
            _OcptShotCoverageExtract(
              layout: layout,
              range: range,
              otherShotsRanges: otherShotsRanges,
              isModified: staleRangeIds.contains(range.id),
            ),
        const SizedBox(height: 4),
        Text(
          "${tr.shotListCoverageWordsCovered(layout.countCoveredWords(ownRanges), _totalWordCount(layout))}"
          " · ${tr.shotListCoverageRangesCount(ranges.length)}",
          style: theme.textTheme.bodySmall,
        ),
        if (ranges.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(onPressed: onClearAll, child: Text(tr.shotListCoverageClearAllAction)),
          ),
      ],
    );
  }

  /// The total number of words across every block of [layout], the denominator of the footer's
  /// `N words covered of M` counter.
  int _totalWordCount(OcptShotCoverageLayout layout) =>
      layout.blocks.fold(0, (total, block) => total + block.words.length);
}

/// One covered extract of [OcptShotCoverageSummary]: the type of the block it was taken from, the
/// text itself between quotation marks, a `modified` badge when it no longer matches the
/// screenplay, and the codes of the other shots covering the same text.
class _OcptShotCoverageExtract extends StatelessWidget {
  /// The layout [range] was recorded against.
  final OcptShotCoverageLayout layout;

  /// The range quoted.
  final OcptShotCoverageRange range;

  /// Every other shot's coverage ranges of this scene, keyed by that shot's code.
  final Map<String, List<OcptShotCoverageRange>> otherShotsRanges;

  /// Whether [range] no longer matches the text it was recorded against.
  final bool isModified;

  /// Class constructor
  const _OcptShotCoverageExtract({
    required this.layout,
    required this.range,
    required this.otherShotsRanges,
    required this.isModified,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    final block = layout.blockContaining(range.startOffset);
    final otherCodes = [
      for (final entry in otherShotsRanges.entries)
        if (entry.value.any(_overlapsRange)) entry.key,
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (block != null)
                Text(
                  ocptFountainLineTypeLabel(tr, block.type).toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              if (isModified) ...[
                const SizedBox(width: 6),
                const _OcptShotCoverageModifiedBadge(),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Text(
            tr.shotListCoverageExtract(layout.coveredTextOf(range)),
            style: theme.textTheme.bodySmall,
          ),
          if (otherCodes.isNotEmpty)
            Text(
              tr.shotListCoverageAlsoCoveredBy(otherCodes.join(" · ")),
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: ocptMonospaceFontFamily,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }

  /// Whether [other] overlaps the quoted [range] at all: what decides whether the shot owning
  /// [other] is named under this extract.
  bool _overlapsRange(OcptShotCoverageRange other) =>
      other.startOffset < range.endOffset && other.endOffset > range.startOffset;
}

/// The small `Modified` badge shown next to an extract whose covered text changed since it was
/// recorded, in the same warning colour as every other "needs attention" marker of this mode.
class _OcptShotCoverageModifiedBadge extends StatelessWidget {
  /// Class constructor
  const _OcptShotCoverageModifiedBadge();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final color = ocptShotListWarningColor(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: ocptSelectedStateAlpha),
        borderRadius: BorderRadius.circular(ocptRadiusSmall),
      ),
      child: Text(
        tr.shotListCoverageModifiedBadge,
        style: theme.textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
