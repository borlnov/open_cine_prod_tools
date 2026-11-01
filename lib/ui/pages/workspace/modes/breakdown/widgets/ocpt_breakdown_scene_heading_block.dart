// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_script_word_block.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_preview_layout.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/widgets/ocpt_breakdown_run_style.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_fountain_line_display.dart';

/// [block]'s printed words, flattened into one run of spans: every Fountain marker hidden, every
/// inline emphasis applied on top of [base]. Used for the heading row alone, which stays row-level
/// clickable rather than word-level — every other block renders through
/// `OcptBreakdownScriptBlock`'s per-word widget instead, one per word, so a tag can hang its own
/// click target and its own highlight off it.
List<InlineSpan> _spansOf(OcptScriptWordBlock block, bool isUppercase, TextStyle base) => [
  for (final wordRuns in ocptFountainWordDisplayRuns(block))
    for (final run in wordRuns)
      TextSpan(
        text: isUppercase ? run.text.toUpperCase() : run.text,
        style: ocptBreakdownRunStyleOf(run.style, base),
      ),
];

/// A scene's heading row: clickable, tinted with the accent wash while `OcptBreakdownScriptView`'s
/// selection names this scene, and carrying its own tagged-target count on the right.
class OcptBreakdownSceneHeadingBlock extends StatelessWidget {
  /// The heading's own block.
  final OcptScriptWordBlock block;

  /// The pixel geometry the sheet is typeset with.
  final OcptEditorPreviewLayout previewLayout;

  /// The multiplier this heading's indent is scaled by — 1 on the desktop, the compact factor on a
  /// phone (`OcptEditorPreviewLayout.compactLayoutScale`).
  final double layoutScale;

  /// Whether this heading's scene is the selected one.
  final bool isSelected;

  /// The number of distinct targets tagged in this heading's scene.
  final int targetCount;

  /// Called when this row is clicked.
  final VoidCallback onTap;

  /// Whether the source leaves a blank line right after this heading.
  final bool isFollowedByBlankLine;

  /// Class constructor
  const OcptBreakdownSceneHeadingBlock({
    super.key,
    required this.block,
    required this.previewLayout,
    required this.layoutScale,
    required this.isSelected,
    required this.targetCount,
    required this.onTap,
    required this.isFollowedByBlankLine,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final element = previewLayout.metrics.sceneHeading;
    final printStyle = FountainPrintStyle.of(FountainLineType.sceneHeading);
    final baseStyle = TextStyle(
      fontFamily: OcptEditorPreviewLayout.fontFamily,
      fontSize: OcptEditorPreviewLayout.fontSize,
      height: previewLayout.lineHeightFactor,
      color: Colors.black,
      fontWeight: printStyle.isBold ? FontWeight.bold : null,
      fontStyle: printStyle.isItalic ? FontStyle.italic : null,
    );

    return Padding(
      padding: EdgeInsets.only(bottom: isFollowedByBlankLine ? previewLayout.blockSpacing : 0),
      child: InkWell(
        onTap: onTap,
        mouseCursor: ocptClickableCursor,
        child: Container(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: ocptSelectedStateAlpha)
              : null,
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Container(
                width: 3,
                height: previewLayout.lineHeight,
                color: isSelected ? theme.colorScheme.primary : Colors.transparent,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: previewLayout.indentOf(element) * layoutScale),
                  child: Text.rich(
                    TextSpan(children: _spansOf(block, printStyle.isUppercase, baseStyle)),
                    style: baseStyle,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 8, right: 8),
                child: Text(
                  tr.breakdownSceneElementsCount(targetCount),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
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
