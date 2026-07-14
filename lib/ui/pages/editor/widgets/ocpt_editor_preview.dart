// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_preview_block.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_preview_layout.dart';

/// The formatted preview: a simulated paper page (white paper, black Courier text, even in dark
/// theme) rendering the parsed screenplay with its true print layout.
///
/// The page is a single continuous sheet (no on-screen pagination) whose width is the physical
/// page width at the current [pageFormat]'s metrics; it's centered in the panel. When the panel is
/// too narrow for the full page, the whole page is scaled down to fit instead of being cropped by
/// a horizontal scroll (which would otherwise leave the right margin permanently out of view): the
/// left AND right margins always stay visible, at the wide panel's own scale or smaller. The block
/// list is lazy (RFL38) and the whole preview sits behind a [RepaintBoundary] (RFL37) so typing in
/// the source editor doesn't repaint it needlessly.
///
/// When the editor caret changes line, the preview scrolls so the block containing that line is
/// visible. Because the list is lazy, an unbuilt block has no render object to `ensureVisible`,
/// so the target offset is estimated instead from each block's wrapped line count (exact enough
/// for a fixed-pitch font; see [OcptEditorPreviewLayout.estimateBlockHeight]), which stays robust
/// no matter how long the document is.
class OcptEditorPreview extends StatefulWidget {
  /// The parsed document to render, or null while nothing has been parsed yet.
  final FountainDocument? document;

  /// The page format driving the preview's layout metrics.
  final OcptPageFormat pageFormat;

  /// The 0-based source line the editor caret is currently on, driving the scroll sync.
  final int currentLine;

  /// Class constructor
  const OcptEditorPreview({
    super.key,
    required this.document,
    required this.pageFormat,
    required this.currentLine,
  });

  @override
  State<OcptEditorPreview> createState() => _OcptEditorPreviewState();
}

/// The state of [OcptEditorPreview]: owns the page scroll controller and the per-document caches
/// (printable blocks and their estimated scroll offsets).
class _OcptEditorPreviewState extends State<OcptEditorPreview> {
  /// The horizontal padding kept around the paper page inside the panel.
  static const double _pagePadding = 16;

  /// The controller of the page's vertical scroll, used by the caret scroll sync.
  final ScrollController _scrollController = ScrollController();

  /// The document [_blocks] and [_blockOffsets] were computed from, to only recompute them when
  /// the document actually changes.
  FountainDocument? _cachedDocument;

  /// The printable blocks of [_cachedDocument], in source order.
  List<FountainBlock> _blocks = const [];

  /// The estimated scroll offset of each block of [_blocks], measured from the top of the list's
  /// content (i.e. not including the page's top margin padding).
  List<double> _blockOffsets = const [];

  @override
  void didUpdateWidget(OcptEditorPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentLine != widget.currentLine || oldWidget.document != widget.document) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _syncScrollToCurrentLine());
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final layout = OcptEditorPreviewLayout(metrics: _metrics);
    _refreshCaches(layout);

    if (_blocks.isEmpty) {
      return RepaintBoundary(
        child: Center(
          child: Text(
            Tr.of(context).editorPreviewEmptyHint,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final unscaledWidth = layout.pageWidth + _pagePadding * 2;
          if (constraints.maxWidth >= unscaledWidth) {
            return SizedBox(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              child: Center(
                child: SizedBox(width: layout.pageWidth, child: _paperPage(layout)),
              ),
            );
          }

          // The panel is narrower than the full page: scale the whole page down to fit it, rather
          // than crop it with horizontal scroll. `height` is inflated by the inverse of `scale` so
          // the scaled-down viewport exactly fills the panel: `_scrollController`'s viewport/target
          // math, entirely computed in this unscaled space (see `_syncScrollToCurrentLine`), stays
          // valid without any adjustment.
          //
          // This must be a `FittedBox`, not a `Transform.scale` wrapping a merely wide `SizedBox`:
          // this whole subtree already sits under a *tight* incoming width constraint (an `Expanded`
          // panel gives one), and a plain `SizedBox` cannot exceed a tight constraint — it silently
          // clamps back down to `constraints.maxWidth`, one level too late for `Transform.scale` to
          // notice, which then scales down and anchors against that wrong (already-narrow) box
          // instead of the true, wider page — visibly displacing the left margin while the vertical
          // margins (unaffected by this) still line up. `FittedBox` sidesteps this: it always lays
          // its child out with fully unconstrained constraints, so the inner `SizedBox` genuinely
          // achieves `unscaledWidth`, and `FittedBox` itself then measures that real size to compute
          // the correct scale and centering.
          final scale = constraints.maxWidth / unscaledWidth;
          return FittedBox(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: unscaledWidth,
              height: constraints.maxHeight / scale,
              child: Center(
                child: SizedBox(width: layout.pageWidth, child: _paperPage(layout)),
              ),
            ),
          );
        },
      ),
    );
  }

  /// The simulated paper sheet: white, slightly elevated and rounded, always black-on-white
  /// regardless of the app theme, with the lazy block list scrolling inside it.
  Widget _paperPage(OcptEditorPreviewLayout layout) => Material(
    color: Colors.white,
    elevation: 2,
    borderRadius: BorderRadius.circular(3),
    clipBehavior: Clip.antiAlias,
    child: ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.only(top: layout.marginTop, bottom: layout.marginBottom),
      itemCount: _blocks.length,
      itemBuilder: (context, index) =>
          OcptEditorPreviewBlock(block: _blocks[index], layout: layout),
    ),
  );

  /// The layout metrics matching the project's page format.
  FountainLayoutMetrics get _metrics => switch (widget.pageFormat) {
    OcptPageFormat.usLetter => FountainLayoutMetrics.usLetter(),
    OcptPageFormat.a4 => FountainLayoutMetrics.a4(),
  };

  /// Recomputes [_blocks] and [_blockOffsets] if the document changed since the last build.
  void _refreshCaches(OcptEditorPreviewLayout layout) {
    final document = widget.document;
    if (identical(document, _cachedDocument)) {
      return;
    }
    _cachedDocument = document;

    if (document == null) {
      _blocks = const [];
      _blockOffsets = const [];
      return;
    }

    _blocks = OcptEditorPreviewLayout.printableBlocks(document);
    final offsets = List<double>.filled(_blocks.length, 0);
    var cumulative = 0.0;
    for (var index = 0; index < _blocks.length; index++) {
      offsets[index] = cumulative;
      cumulative += layout.estimateBlockHeight(_blocks[index]);
    }
    _blockOffsets = offsets;
  }

  /// Scrolls the page so the block containing the caret's line is visible.
  ///
  /// If the target offset is already comfortably within the viewport, nothing moves (so plain
  /// typing doesn't make the preview twitch); otherwise the page animates to put the block near
  /// the upper third of the viewport.
  void _syncScrollToCurrentLine() {
    if (!mounted || !_scrollController.hasClients || _blocks.isEmpty) {
      return;
    }

    final index = _blockIndexForLine(widget.currentLine);
    if (index == null) {
      return;
    }

    final layout = OcptEditorPreviewLayout(metrics: _metrics);
    final position = _scrollController.position;
    final target = layout.marginTop + _blockOffsets[index];

    final visibleTop = position.pixels + layout.lineHeight;
    final visibleBottom = position.pixels + position.viewportDimension - layout.lineHeight * 2;
    if (target >= visibleTop && target <= visibleBottom) {
      return;
    }

    final destination = (target - position.viewportDimension / 3).clamp(
      0.0,
      position.maxScrollExtent,
    );
    unawaited(
      _scrollController.animateTo(
        destination,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  /// Returns the index, in [_blocks], of the block containing the source [line] (or the closest
  /// block above it), or null if [line] precedes every block.
  int? _blockIndexForLine(int line) {
    int? candidate;
    for (var index = 0; index < _blocks.length; index++) {
      if (_blocks[index].sourceRange.startLine <= line) {
        candidate = index;
      } else {
        break;
      }
    }

    return candidate;
  }
}
