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
/// When [isPageSimulationEnabled] is off, the page is a single continuous sheet (no on-screen
/// pagination). When it's on, the screenplay is split into distinct paper sheets, one per printed
/// page (real page height, a themed gap between sheets, forced by a [FountainPageBreak] or by
/// running out of [FountainLayoutMetrics.linesPerPage]). Either way, the sheet's width is the
/// physical page width at the current [pageFormat]'s metrics; it's centered in the panel. When the
/// panel is too narrow for the full page, the whole page is scaled down to fit instead of being
/// cropped by a horizontal scroll (which would otherwise leave the right margin permanently out of
/// view): the left AND right margins always stay visible, at the wide panel's own scale or smaller.
/// The block list is lazy (RFL38) and the whole preview sits behind a [RepaintBoundary] (RFL37) so
/// typing in the source editor doesn't repaint it needlessly.
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

  /// Whether the screenplay is split into distinct paper sheets, one per printed page, rather
  /// than rendered as a single continuous sheet.
  final bool isPageSimulationEnabled;

  /// Class constructor
  const OcptEditorPreview({
    super.key,
    required this.document,
    required this.pageFormat,
    required this.currentLine,
    required this.isPageSimulationEnabled,
  });

  @override
  State<OcptEditorPreview> createState() => _OcptEditorPreviewState();
}

/// The state of [OcptEditorPreview]: owns the page scroll controller and the per-document caches
/// (printable blocks, their pagination, and their estimated scroll offsets).
class _OcptEditorPreviewState extends State<OcptEditorPreview> {
  /// The horizontal padding kept around the paper page inside the panel.
  static const double _pagePadding = 16;

  /// The themed gap left between two consecutive paper sheets when [OcptEditorPreview
  /// .isPageSimulationEnabled] is on.
  static const double _pageGap = 16;

  /// The controller of the page's vertical scroll, used by the caret scroll sync.
  final ScrollController _scrollController = ScrollController();

  /// The document and page-simulation flag [_blocks], [_pages] and [_blockOffsets] were computed
  /// from, to only recompute them when either actually changes.
  FountainDocument? _cachedDocument;

  /// See [_cachedDocument].
  bool _cachedIsPageSimulationEnabled = false;

  /// The printable blocks of [_cachedDocument], in source order (a [FountainPageBreak] is kept
  /// here for [_blockIndexForLine]'s sake even when [_pages] doesn't render it as content).
  List<FountainBlock> _blocks = const [];

  /// The blocks of [_cachedDocument] split into pages, only populated while [OcptEditorPreview
  /// .isPageSimulationEnabled] is on; a [FountainPageBreak] forces a new page and isn't itself
  /// carried over as page content (the fresh sheet already is its visual representation).
  List<List<FountainBlock>> _pages = const [];

  /// The estimated scroll offset of each block of [_blocks], measured from the top of the page
  /// scroll view's content (i.e. already including every margin/gap above it).
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
                child: SizedBox(width: layout.pageWidth, child: _content(layout)),
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
                child: SizedBox(width: layout.pageWidth, child: _content(layout)),
              ),
            ),
          );
        },
      ),
    );
  }

  /// The preview's content: paginated paper sheets, or the single continuous sheet, depending on
  /// [OcptEditorPreview.isPageSimulationEnabled].
  Widget _content(OcptEditorPreviewLayout layout) =>
      widget.isPageSimulationEnabled ? _paginatedPages(layout) : _paperPage(layout);

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

  /// Distinct paper sheets, one per page in [_pages], separated by a themed gap: the panel's own
  /// (themed) background shows through the gap, while each sheet stays white regardless of theme.
  ///
  /// A sheet is a fixed-height white [Material] behind its blocks, laid out in a plain [Column]
  /// (not lazily: a single page's block count is always small). A block taller than a page is
  /// simply allowed to render past the sheet's nominal height (no clipping) rather than splitting
  /// it — true intra-block pagination is the PDF exporter's job later.
  Widget _paginatedPages(OcptEditorPreviewLayout layout) => ListView.builder(
    controller: _scrollController,
    itemCount: _pages.length,
    itemBuilder: (context, index) => Padding(
      padding: EdgeInsets.only(bottom: index == _pages.length - 1 ? 0 : _pageGap),
      child: Stack(
        children: [
          SizedBox(
            height: layout.pageHeight,
            child: Material(
              color: Colors.white,
              elevation: 2,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(top: layout.marginTop, bottom: layout.marginBottom),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final block in _pages[index])
                  OcptEditorPreviewBlock(block: block, layout: layout),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  /// The layout metrics matching the project's page format.
  FountainLayoutMetrics get _metrics => switch (widget.pageFormat) {
    OcptPageFormat.usLetter => FountainLayoutMetrics.usLetter(),
    OcptPageFormat.a4 => FountainLayoutMetrics.a4(),
  };

  /// Recomputes [_blocks], [_pages] and [_blockOffsets] if the document or the page-simulation
  /// flag changed since the last build.
  void _refreshCaches(OcptEditorPreviewLayout layout) {
    final document = widget.document;
    if (identical(document, _cachedDocument) &&
        _cachedIsPageSimulationEnabled == widget.isPageSimulationEnabled) {
      return;
    }
    _cachedDocument = document;
    _cachedIsPageSimulationEnabled = widget.isPageSimulationEnabled;

    if (document == null) {
      _blocks = const [];
      _pages = const [];
      _blockOffsets = const [];
      return;
    }

    _blocks = OcptEditorPreviewLayout.printableBlocks(document);
    if (widget.isPageSimulationEnabled) {
      _refreshPaginatedCaches(layout);
    } else {
      _refreshContinuousCaches(layout);
    }
  }

  /// Computes [_blockOffsets] for the single-continuous-sheet rendering: a plain running sum of
  /// each block's estimated height, starting after the page's top margin.
  void _refreshContinuousCaches(OcptEditorPreviewLayout layout) {
    _pages = const [];

    final offsets = List<double>.filled(_blocks.length, 0);
    var cumulative = layout.marginTop;
    for (var index = 0; index < _blocks.length; index++) {
      offsets[index] = cumulative;
      cumulative += layout.estimateBlockHeight(_blocks[index]);
    }
    _blockOffsets = offsets;
  }

  /// Splits [_blocks] into [_pages] and computes [_blockOffsets] for the paginated rendering.
  ///
  /// Blocks are greedily packed onto the current page while the running sum of
  /// [OcptEditorPreviewLayout.estimatedLineCount] stays within [FountainLayoutMetrics
  /// .linesPerPage]; a [FountainPageBreak] always starts a fresh page (and isn't itself added as
  /// page content). Each page is assumed to occupy exactly [OcptEditorPreviewLayout.pageHeight]
  /// plus [_pageGap] of scroll extent: an approximation (a page whose content estimate is close to
  /// the limit may render slightly shorter or taller than that), acceptable since block offsets
  /// only ever drive the caret scroll sync, not pixel-exact placement.
  void _refreshPaginatedCaches(OcptEditorPreviewLayout layout) {
    final pages = <List<FountainBlock>>[];
    final offsets = List<double>.filled(_blocks.length, 0);
    var currentPage = <FountainBlock>[];
    var currentLines = 0;
    var withinPageOffset = layout.marginTop;

    double offsetOfCurrentPage() => pages.length * (layout.pageHeight + _pageGap);

    for (var index = 0; index < _blocks.length; index++) {
      final block = _blocks[index];

      if (block is FountainPageBreak) {
        offsets[index] = offsetOfCurrentPage() + withinPageOffset;
        if (currentPage.isNotEmpty) {
          pages.add(currentPage);
          currentPage = [];
          currentLines = 0;
          withinPageOffset = layout.marginTop;
        }
        continue;
      }

      final lines = layout.estimatedLineCount(block);
      if (currentPage.isNotEmpty && currentLines + lines > layout.metrics.linesPerPage) {
        pages.add(currentPage);
        currentPage = [];
        currentLines = 0;
        withinPageOffset = layout.marginTop;
      }

      offsets[index] = offsetOfCurrentPage() + withinPageOffset;
      currentPage.add(block);
      currentLines += lines;
      withinPageOffset += layout.estimateBlockHeight(block);
    }
    if (currentPage.isNotEmpty) {
      pages.add(currentPage);
    }

    _pages = pages;
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
    final target = _blockOffsets[index];

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
