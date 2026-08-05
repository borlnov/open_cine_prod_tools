// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_scene.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_script_word_layout.dart';
import 'package:open_cine_prod_tools/models/ocpt_specific_colors.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_preview_layout.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_empty_mode.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_fountain_line_display.dart';
import 'package:open_cine_prod_tools/utils/ocpt_breakdown_scene_bars.dart';

/// The breakdown mode's `centre`: the whole screenplay typeset on a simulated paper sheet, centred
/// and scrollable, in Courier Prime at its true screenplay indents — one sheet, its scenes running
/// on continuously the way the raw mode's own preview reads, rather than one scene at a time.
///
/// Built scene by scene from [OcptScriptWordLayout.of], sliced out of the whole screenplay text
/// with each [OcptBreakdownScene.charStart]/`charEnd`, and rendered through
/// [ocptFountainWordDisplayRuns] so every Fountain marker (emphasis, a forcing character, a scene
/// number) stays hidden — exactly what `OcptShotCoverageDialog` already does for the scenario
/// coverage editor; this widget reuses that rendering, not its click-a-range interaction.
///
/// **The words are plain text in this milestone**: no click target, no highlight, no popover. Only
/// a scene's heading row is clickable, selecting that scene — shown with a tinted accent bar and
/// its own tagged-target count on the right — since that is the one thing this milestone's left
/// dock and this view already agree on. The clickable, taggable, category-highlighted words the
/// mock-up shows are a later milestone's.
class OcptBreakdownScriptView extends StatelessWidget {
  /// The screenplay's whole Fountain text, sliced scene by scene below.
  final String screenplayText;

  /// The scenes to typeset, in source order.
  final List<OcptBreakdownScene> scenes;

  /// `{(kind, id): target}`, forwarded to every scene's heading row for its own tagged-target
  /// count.
  final OcptBreakdownTargetsById targetById;

  /// The page setup the sheet is typeset with.
  final OcptPageSetup pageSetup;

  /// The id of the selected scene, or null if none is.
  final String? selectedSceneId;

  /// Called with a scene's id when its heading row is clicked.
  final ValueChanged<String> onSceneSelected;

  /// Class constructor
  const OcptBreakdownScriptView({
    super.key,
    required this.screenplayText,
    required this.scenes,
    required this.targetById,
    required this.pageSetup,
    required this.selectedSceneId,
    required this.onSceneSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (scenes.isEmpty) {
      return OcptWorkspaceEmptyMode(
        icon: Icons.fact_check_outlined,
        message: Tr.of(context).breakdownScenesEmptyHint,
      );
    }

    final theme = Theme.of(context);
    final previewLayout = OcptEditorPreviewLayout(metrics: pageSetup.toMetrics());

    return ColoredBox(
      color: theme.extension<OcptSpecificColors>()!.previewBackdrop,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Material(
            color: Colors.white,
            elevation: 2,
            borderRadius: BorderRadius.circular(3),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              width: previewLayout.pageWidth,
              child: Padding(
                padding: EdgeInsets.only(
                  top: previewLayout.marginTop,
                  bottom: previewLayout.marginBottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final scene in scenes)
                      _OcptBreakdownSceneSheet(
                        scene: scene,
                        sceneText: _sceneTextOf(scene),
                        targetById: targetById,
                        previewLayout: previewLayout,
                        isSelected: scene.id == selectedSceneId,
                        onHeadingTapped: () => onSceneSelected(scene.id),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// [scene]'s own slice of [screenplayText], clamped to its bounds: the load that read [scenes]
  /// and the one that read [screenplayText] are the same snapshot read, so the offsets always fit,
  /// but a scene sliced this way is never worth a `RangeError` over.
  String _sceneTextOf(OcptBreakdownScene scene) {
    final start = scene.charStart.clamp(0, screenplayText.length);
    final end = scene.charEnd.clamp(start, screenplayText.length);
    return screenplayText.substring(start, end);
  }
}

/// One scene's sheet: its heading row, then every other block of its text, laid out exactly as the
/// raw mode's own preview lays the same text out.
class _OcptBreakdownSceneSheet extends StatelessWidget {
  /// The scene this sheet shows.
  final OcptBreakdownScene scene;

  /// [scene]'s own text, already sliced out of the screenplay.
  final String sceneText;

  /// `{(kind, id): target}`, forwarded from [OcptBreakdownScriptView].
  final OcptBreakdownTargetsById targetById;

  /// The pixel geometry the sheet is typeset with.
  final OcptEditorPreviewLayout previewLayout;

  /// Whether [scene] is the selected one.
  final bool isSelected;

  /// Called when the heading row is clicked.
  final VoidCallback onHeadingTapped;

  /// Class constructor
  const _OcptBreakdownSceneSheet({
    required this.scene,
    required this.sceneText,
    required this.targetById,
    required this.previewLayout,
    required this.isSelected,
    required this.onHeadingTapped,
  });

  @override
  Widget build(BuildContext context) {
    final layout = OcptScriptWordLayout.of(sceneId: scene.id, sceneText: sceneText);
    final targetCount = ocptBreakdownSceneTargetsOf(scene, targetById).length;

    return Padding(
      // The gap to the next scene's own heading: a scene's last block never sees the heading that
      // follows it (they belong to different `OcptScriptWordLayout`s), so this closes that gap the
      // way `isFollowedByBlankLine` closes every gap inside one scene's own blocks below.
      padding: EdgeInsets.only(bottom: previewLayout.blockSpacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < layout.blocks.length; i++)
            if (layout.blocks[i].type == FountainLineType.sceneHeading)
              _OcptBreakdownSceneHeadingBlock(
                block: layout.blocks[i],
                previewLayout: previewLayout,
                isSelected: isSelected,
                targetCount: targetCount,
                onTap: onHeadingTapped,
                isFollowedByBlankLine: _isFollowedByBlankLine(layout, i),
              )
            else
              _OcptBreakdownScriptBlock(
                block: layout.blocks[i],
                previewLayout: previewLayout,
                isFollowedByBlankLine: _isFollowedByBlankLine(layout, i),
              ),
        ],
      ),
    );
  }

  /// Whether [layout]'s block at [index] is followed by a blank source line — the only place the
  /// sheet leaves a vertical gap, mirroring `OcptShotCoverageDialog`'s own block spacing.
  bool _isFollowedByBlankLine(OcptScriptWordLayout layout, int index) =>
      index + 1 < layout.blocks.length &&
      layout.blocks[index + 1].startOffset - layout.blocks[index].endOffset > 1;
}

/// A scene's heading row: clickable, tinted with the accent wash while [OcptBreakdownScriptView]'s
/// selection names this scene, and carrying its own tagged-target count on the right.
class _OcptBreakdownSceneHeadingBlock extends StatelessWidget {
  /// The heading's own block.
  final OcptScriptWordBlock block;

  /// The pixel geometry the sheet is typeset with.
  final OcptEditorPreviewLayout previewLayout;

  /// Whether this heading's scene is the selected one.
  final bool isSelected;

  /// The number of distinct targets tagged in this heading's scene.
  final int targetCount;

  /// Called when this row is clicked.
  final VoidCallback onTap;

  /// Whether the source leaves a blank line right after this heading.
  final bool isFollowedByBlankLine;

  /// Class constructor
  const _OcptBreakdownSceneHeadingBlock({
    required this.block,
    required this.previewLayout,
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
                  padding: EdgeInsets.only(left: previewLayout.indentOf(element)),
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

/// One non-heading block of the sheet: plain, non-clickable printed text at the block's own
/// screenplay indent, width and alignment.
class _OcptBreakdownScriptBlock extends StatelessWidget {
  /// The block rendered.
  final OcptScriptWordBlock block;

  /// The pixel geometry the sheet is typeset with.
  final OcptEditorPreviewLayout previewLayout;

  /// Whether the source leaves a blank line right after this block.
  final bool isFollowedByBlankLine;

  /// Class constructor
  const _OcptBreakdownScriptBlock({
    required this.block,
    required this.previewLayout,
    required this.isFollowedByBlankLine,
  });

  @override
  Widget build(BuildContext context) {
    final element = _elementLayoutOf(block.type, previewLayout.metrics);
    final printStyle = FountainPrintStyle.of(block.type);
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
      child: Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: EdgeInsets.only(left: previewLayout.indentOf(element)),
          child: SizedBox(
            width: previewLayout.widthOf(element),
            child: Text.rich(
              TextSpan(children: _spansOf(block, printStyle.isUppercase, baseStyle)),
              style: baseStyle,
              textAlign: _textAlignOf(element),
            ),
          ),
        ),
      ),
    );
  }
}

/// The screenplay layout box a line of [type] is typeset in, mirroring
/// `OcptShotCoverageDialog`'s own `_elementLayout` getter.
FountainElementLayout _elementLayoutOf(FountainLineType type, FountainLayoutMetrics metrics) =>
    switch (type) {
      FountainLineType.sceneHeading => metrics.sceneHeading,
      FountainLineType.character => metrics.character,
      FountainLineType.parenthetical => metrics.parenthetical,
      FountainLineType.dialogue => metrics.dialogue,
      FountainLineType.transition => metrics.transition,
      FountainLineType.centeredText => metrics.centeredText,
      FountainLineType.lyrics => metrics.lyrics,
      FountainLineType.action ||
      FountainLineType.section ||
      FountainLineType.synopsis ||
      FountainLineType.pageBreak ||
      FountainLineType.blank => metrics.action,
    };

/// The horizontal alignment [element] is typeset with.
TextAlign _textAlignOf(FountainElementLayout element) => switch (element.alignment) {
  FountainLayoutAlignment.center => TextAlign.center,
  FountainLayoutAlignment.right => TextAlign.right,
  FountainLayoutAlignment.left => TextAlign.left,
};

/// [block]'s printed words, flattened into one run of spans: every Fountain marker hidden, every
/// inline emphasis applied on top of [base], exactly as `OcptShotCoverageDialog` renders per word —
/// flattened here since this milestone draws no per-word click target to hang a `WidgetSpan` off.
List<InlineSpan> _spansOf(OcptScriptWordBlock block, bool isUppercase, TextStyle base) => [
  for (final wordRuns in ocptFountainWordDisplayRuns(block))
    for (final run in wordRuns)
      TextSpan(text: isUppercase ? run.text.toUpperCase() : run.text, style: _runStyleOf(run.style, base)),
];

/// Applies a run's own inline emphasis on top of [base], mirroring `OcptShotCoverageDialog`'s own
/// `_styleOf`.
TextStyle _runStyleOf(FountainInlineStyle style, TextStyle base) => switch (style) {
  FountainInlineStyle.italic => base.copyWith(fontStyle: FontStyle.italic),
  FountainInlineStyle.bold => base.copyWith(fontWeight: FontWeight.bold),
  FountainInlineStyle.boldItalic => base.copyWith(
    fontWeight: FontWeight.bold,
    fontStyle: FontStyle.italic,
  ),
  FountainInlineStyle.underline => base.copyWith(decoration: TextDecoration.underline),
  // A note never reaches here: `ocptFountainWordDisplayRuns` drops its text entirely.
  FountainInlineStyle.plain || FountainInlineStyle.note => base,
};
