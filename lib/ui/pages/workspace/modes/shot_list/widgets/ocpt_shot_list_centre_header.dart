// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_centre_view.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_shot_list_labels.dart';
import 'package:open_cine_prod_tools/ui/widgets/ocpt_view_switch.dart';

/// The widest the sequence's own title and summary ever grow, in logical pixels — see
/// [OcptShotListCentreHeader.build]'s own doc comment.
const double _summaryMaxWidth = 240;

/// The shot list mode's centre header, replacing the table-only `_SequenceHeader` row it used to
/// build alone: the `OcptViewSwitch` on the left, the selected sequence's own title and summary
/// beside it, then [trailing] — whatever the active view needs on the right (`Columns ▾` and
/// `Export XLSX` for the table, `Panel size ▾` for the board), built by the mode
/// (`docs/plans/storyboard.md`, §4.1).
///
/// Purely presentational, like the breakdown mode's own header: every click is reported upward,
/// nothing here reads a manager. On a **compact width** the switch offers the table only
/// ([isBoardAvailable]/[isFloorPlansAvailable] both false) — the board and the floor plans are
/// large-screen views in v1 (§4.3).
class OcptShotListCentreHeader extends StatelessWidget {
  /// The sequence currently shown, whose title and summary this header prints.
  final OcptShotSequence sequence;

  /// Which centre view is currently shown.
  final OcptShotListCentreView centreView;

  /// Whether the board segment is offered at all — false at a compact width.
  final bool isBoardAvailable;

  /// Whether the floor plans segment is offered at all — false at a compact width.
  final bool isFloorPlansAvailable;

  /// The total number of panels across [sequence]'s shots, appended to the summary line while the
  /// board is shown (`Sequence 12 · 5 shots · 6 panels`); ignored while [centreView] isn't
  /// [OcptShotListCentreView.board].
  final int boardPanelCount;

  /// Called with the view just picked, when it differs from [centreView].
  final ValueChanged<OcptShotListCentreView> onCentreViewSelected;

  /// What the active view needs on the header's trailing edge, built by the mode.
  final Widget trailing;

  /// Class constructor
  const OcptShotListCentreHeader({
    super.key,
    required this.sequence,
    required this.centreView,
    required this.isBoardAvailable,
    required this.isFloorPlansAvailable,
    required this.boardPanelCount,
    required this.onCentreViewSelected,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    // A `Wrap` rather than a `Row`: the centre's own width is only ever the mode's — a dragged
    // dock, an open inspector, a narrow window — and none of `OcptViewSwitch`, the sequence's own
    // title/summary or [trailing] (`Columns ▾`/`Export XLSX`, or `Panel size ▾`) can be dropped
    // outright, so the header reflows onto its own line under a width tight enough that a `Row`
    // would instead overflow. Each of the three sits as its own `Wrap` child (rather than the
    // switch and the summary sharing one `Row` child) so a width too narrow for all three moves
    // exactly the ones that don't fit, never throwing a `RenderFlex` overflow whatever the width.
    // The summary is additionally capped to [_summaryMaxWidth] so its own text ellipsises rather
    // than forcing the row wide on its account.
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.end,
      spacing: 16,
      runSpacing: 8,
      children: [
        OcptViewSwitch<OcptShotListCentreView>(
          value: isBoardAvailable || isFloorPlansAvailable
              ? centreView
              : OcptShotListCentreView.table,
          onChanged: onCentreViewSelected,
          segments: [
            OcptViewSwitchSegment(
              value: OcptShotListCentreView.table,
              label: tr.shotListBoardTableSegmentLabel,
            ),
            if (isBoardAvailable)
              OcptViewSwitchSegment(
                value: OcptShotListCentreView.board,
                label: tr.shotListBoardBoardSegmentLabel,
              ),
            if (isFloorPlansAvailable)
              OcptViewSwitchSegment(
                value: OcptShotListCentreView.floorPlans,
                label: tr.shotListFloorPlanSegmentLabel,
              ),
          ],
        ),
        SizedBox(
          width: _summaryMaxWidth,
          child: _SequenceSummary(sequence: sequence, boardPanelCount: _summaryPanelCount),
        ),
        trailing,
      ],
    );
  }

  /// [boardPanelCount] when the board is what is actually shown, null otherwise — the summary
  /// only ever prints the panel count for the view that made it meaningful.
  int? get _summaryPanelCount =>
      isBoardAvailable && centreView == OcptShotListCentreView.board ? boardPanelCount : null;
}

/// The sequence's own title line and the muted summary under it — the content
/// `_SequenceHeader` used to render alone, kept unchanged for the table and shared by the board,
/// which appends its own panel count to the summary.
class _SequenceSummary extends StatelessWidget {
  /// The sequence being shown.
  final OcptShotSequence sequence;

  /// The panel count to append to the summary, or null to print it exactly as the table always
  /// has.
  final int? boardPanelCount;

  /// Class constructor
  const _SequenceSummary({required this.sequence, required this.boardPanelCount});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final sequence = this.sequence;
    final boardPanelCount = this.boardPanelCount;

    final summaryParts = [
      tr.shotListShotsCount(sequence.shotCount),
      tr.shotListAverageDifficulty(ocptFormatShotDifficulty(context, sequence.averageDifficulty)),
      tr.shotListLeftToShoot(sequence.shotsLeftToShoot),
      if (boardPanelCount != null) tr.shotListBoardPanelsCount(boardPanelCount),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          switch (sequence) {
            OcptSceneShotSequence() => tr.shotListSequenceHeader(
              sequence.displaySceneNumber,
              sequence.heading,
            ),
            OcptOrphanShotSequence() => tr.shotListOrphanSequenceTitle,
          },
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          summaryParts.join(" · "),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
