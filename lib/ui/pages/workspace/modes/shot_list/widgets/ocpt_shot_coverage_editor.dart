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

/// The alpha applied to [ColorScheme.primary] for a word covered by the shot the coverage editor
/// is showing: strong enough to read at a glance as "this shot films this text".
const double _ocptOwnCoverageAlpha = 0.32;

/// The alpha applied to [ColorScheme.primary] for a word covered by another shot: a faint wash,
/// the accent underline drawn on top of it being what actually carries the "someone else covers
/// this too" meaning.
const double _ocptOtherCoverageAlpha = 0.10;

/// A pending coverage range anchor, exactly as `OcptShotListState.pendingCoverageAnchor` holds
/// it: the first word clicked of a range currently being drawn.
typedef OcptShotCoverageAnchor = ({int blockStartOffset, int wordStartOffset, int wordEndOffset});

/// The shot inspector's "Scenario coverage" section: the selected shot's scene, laid out block by
/// block into clickable words.
///
/// Purely presentational, like every other panel of this mode: it renders exactly what [layout]
/// and the range lists describe and reports every click upward, holding no state of its own —
/// `OcptShotListBloc` is the one place deciding what a click means (see
/// `OcptShotListCoverageWordClickedEvent`'s own doc comment for the three-state interaction
/// [onWordTapped] feeds).
///
/// [layout] is null for an orphaned shot: its scene's text is gone, so there is nothing left to
/// lay out, and a short hint is shown instead. [ownRanges] is the selected shot's own coverage
/// ranges (of every scene it covers; this widget filters down to [layout]'s own scene itself,
/// through [OcptShotCoverageLayout]'s own scene-filtering query methods). [otherShotsRanges] is
/// every other shot's ranges of that same scene, keyed by that shot's `OcptShot.code`, already in
/// code order (`OcptShotListState.otherShotsCoverageOfSelectedScene`). [staleRangeIds] is the
/// subset of [ownRanges]' ids currently disagreeing with the scene's text
/// (`OcptShotListState.staleCoverageRangeIdsOfSelectedShot`), which is what decides a block's
/// `modified` badge.
class OcptShotCoverageEditor extends StatelessWidget {
  /// The selected shot's scene, laid out into blocks and words, or null for an orphaned shot.
  final OcptShotCoverageLayout? layout;

  /// The selected shot's own coverage ranges.
  final List<OcptShotCoverageRange> ownRanges;

  /// Every other shot's coverage ranges of [layout]'s scene, keyed by that shot's code.
  final Map<String, List<OcptShotCoverageRange>> otherShotsRanges;

  /// The ids of [ownRanges] currently disagreeing with the scene's text.
  final Set<String> staleRangeIds;

  /// The first word clicked of a range currently being drawn, or null while none is.
  final OcptShotCoverageAnchor? pendingAnchor;

  /// Called with a clicked word's own block start offset and its own start/end offsets — exactly
  /// what `OcptShotListCoverageWordClickedEvent` carries.
  final void Function(int blockStartOffset, int wordStartOffset, int wordEndOffset) onWordTapped;

  /// Called when the `Clear all` action is clicked.
  final VoidCallback onClearAll;

  /// Class constructor
  const OcptShotCoverageEditor({
    super.key,
    required this.layout,
    required this.ownRanges,
    required this.otherShotsRanges,
    required this.staleRangeIds,
    required this.pendingAnchor,
    required this.onWordTapped,
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

    final ownRangesOfScene = ownRanges.where((range) => range.sceneId == layout.sceneId).toList(
      growable: false,
    );
    final coveredWords = layout.countCoveredWords(ownRanges);
    final totalWords = _totalWordCount(layout);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final block in layout.blocks)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _OcptShotCoverageBlock(
              layout: layout,
              block: block,
              ownRanges: ownRanges,
              otherShotsRanges: otherShotsRanges,
              staleRangeIds: staleRangeIds,
              onWordTapped: onWordTapped,
            ),
          ),
        Text(
          "${tr.shotListCoverageWordsCovered(coveredWords, totalWords)} · "
          "${tr.shotListCoverageRangesCount(ownRangesOfScene.length)}",
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(onPressed: onClearAll, child: Text(tr.shotListCoverageClearAllAction)),
        ),
        Text(
          pendingAnchor == null
              ? tr.shotListCoverageHintNoAnchor
              : tr.shotListCoverageHintPendingAnchor,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  /// The total number of words across every block of [layout], the denominator of the footer's
  /// `N words covered of M` counter.
  int _totalWordCount(OcptShotCoverageLayout layout) =>
      layout.blocks.fold(0, (total, block) => total + block.words.length);
}

/// One block of [OcptShotCoverageEditor]: its type label, its clickable words, an "also covered
/// by" line when another shot covers part of it, and a `modified` badge when one of the selected
/// shot's own ranges of it is stale.
class _OcptShotCoverageBlock extends StatelessWidget {
  /// The layout [block] belongs to, used to resolve coverage and overlap queries.
  final OcptShotCoverageLayout layout;

  /// The block rendered.
  final OcptShotCoverageBlock block;

  /// The selected shot's own coverage ranges (of every scene it covers).
  final List<OcptShotCoverageRange> ownRanges;

  /// Every other shot's coverage ranges of this scene, keyed by that shot's code.
  final Map<String, List<OcptShotCoverageRange>> otherShotsRanges;

  /// The ids of [ownRanges] currently disagreeing with the scene's text.
  final Set<String> staleRangeIds;

  /// Called with a clicked word's own block start offset and its own start/end offsets.
  final void Function(int blockStartOffset, int wordStartOffset, int wordEndOffset) onWordTapped;

  /// Class constructor
  const _OcptShotCoverageBlock({
    required this.layout,
    required this.block,
    required this.ownRanges,
    required this.otherShotsRanges,
    required this.staleRangeIds,
    required this.onWordTapped,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    final ownRangesOfBlock = layout.rangesIn(block, ownRanges);
    final isModified = ownRangesOfBlock.any((range) => staleRangeIds.contains(range.id));
    final otherCodes = [
      for (final entry in otherShotsRanges.entries)
        if (layout.rangesIn(block, entry.value).isNotEmpty) entry.key,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              ocptFountainLineTypeLabel(tr, block.type).toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            if (isModified) ...[
              const SizedBox(width: 6),
              const _OcptShotCoverageModifiedBadge(),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            for (final word in block.words)
              _OcptShotCoverageWordChip(
                word: word,
                isOwnCovered: layout.isWordCovered(word, ownRanges),
                isOtherCovered: otherShotsRanges.values.any(
                  (ranges) => layout.isWordCovered(word, ranges),
                ),
                onTap: () => onWordTapped(block.startOffset, word.startOffset, word.endOffset),
              ),
          ],
        ),
        if (otherCodes.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            tr.shotListCoverageAlsoCoveredBy(otherCodes.join(" · ")),
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: ocptMonospaceFontFamily,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

/// The small "Modified" badge shown next to a block whose covered text changed since it was
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

/// One clickable word of [_OcptShotCoverageBlock]: a strong accent background when [isOwnCovered],
/// a faint accent wash with an accent underline when [isOtherCovered] (and not [isOwnCovered], the
/// selected shot's own coverage always winning the visual conflict), plain text otherwise.
class _OcptShotCoverageWordChip extends StatelessWidget {
  /// The word rendered.
  final OcptShotCoverageWord word;

  /// Whether the selected shot's own ranges cover [word].
  final bool isOwnCovered;

  /// Whether another shot's ranges cover [word].
  final bool isOtherCovered;

  /// Called when this word is tapped.
  final VoidCallback onTap;

  /// Class constructor
  const _OcptShotCoverageWordChip({
    required this.word,
    required this.isOwnCovered,
    required this.isOtherCovered,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;

    final backgroundColor = isOwnCovered
        ? accent.withValues(alpha: _ocptOwnCoverageAlpha)
        : (isOtherCovered ? accent.withValues(alpha: _ocptOtherCoverageAlpha) : null);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ocptRadiusSmall),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(ocptRadiusSmall),
        ),
        child: Text(
          word.text,
          style: theme.textTheme.bodySmall?.copyWith(
            decoration: isOwnCovered
                ? null
                : (isOtherCovered ? TextDecoration.underline : null),
            decorationColor: accent,
          ),
        ),
      ),
    );
  }
}
