// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:fountain_kit/src/layout/fountain_layout_metrics.dart';
import 'package:fountain_kit/src/models/fountain_block.dart';
import 'package:fountain_kit/src/models/fountain_document.dart';
import 'package:fountain_kit/src/models/fountain_styled_run.dart';
import 'package:fountain_kit/src/parser/fountain_inline_parser.dart';
import 'package:fountain_kit/src/parser/fountain_line_classifier.dart';

/// The literal token appended as its own line when a dialogue group is
/// split across a page boundary, at the parenthetical's indent.
///
/// A screenplay content token, not user-facing UI text, so it is a plain
/// English constant rather than something routed through localization.
const String _moreToken = '(MORE)';

/// One line of a paginated screenplay, already wrapped to its element's
/// column width and positioned in the page.
///
/// This is the line-level unit [FountainScriptComposer] emits: unlike the
/// source [FountainBlock]s (one per structural element, which may span
/// several printed lines once wrapped), every [FountainScriptLine] renders
/// as exactly one line of 12-point Courier. [leftIndentInches] and
/// [alignment] are copied from the owning element's
/// [FountainElementLayout] so a renderer never needs to look the element
/// type back up in [FountainLayoutMetrics]; [leftIndentInches] is kept in
/// inches (not columns) because the PDF renderer's own math is in
/// inches-to-points.
class FountainScriptLine extends Equatable {
  /// Creates a [FountainScriptLine].
  const FountainScriptLine({
    required this.runs,
    required this.lineType,
    required this.leftIndentInches,
    required this.alignment,
    required this.isSceneHeading,
    this.sceneNumber,
  });

  /// The line's text, already split into inline-styled runs. Empty for a
  /// blank spacer line or a preserved blank dialogue line (both are real,
  /// distinct lines that still occupy one row of the page).
  final List<FountainStyledRun> runs;

  /// The structural role of the element this line belongs to, for a
  /// renderer that wants to special-case, for example, transitions or
  /// centered text beyond what [alignment] already conveys. A blank spacer
  /// line inserted between two blocks carries [FountainLineType.blank].
  final FountainLineType lineType;

  /// The distance from the page's left edge to where this line starts, in
  /// inches, copied from the owning element's
  /// [FountainElementLayout.leftIndentInches].
  final double leftIndentInches;

  /// How this line is aligned within its element's box, copied from the
  /// owning element's [FountainElementLayout.alignment].
  final FountainLayoutAlignment alignment;

  /// Whether this line is (part of) a scene heading, so a renderer can
  /// place a scene number in both margins opposite it when the option to
  /// print scene numbers is on.
  final bool isSceneHeading;

  /// The scene number to print in the margins opposite this line, or
  /// `null` if [isSceneHeading] is `false` or the heading had no explicit
  /// `#...#` scene number in the source. Never auto-generated here: a
  /// heading with no explicit number stays unnumbered, by design.
  final String? sceneNumber;

  /// This line's text with its inline styling discarded, i.e. the
  /// concatenation of every run's [FountainStyledRun.text] in order.
  String get plainText => runs.map((run) => run.text).join();

  @override
  List<Object?> get props => [
    runs,
    lineType,
    leftIndentInches,
    alignment,
    isSceneHeading,
    sceneNumber,
  ];

  @override
  String toString() =>
      'FountainScriptLine($lineType, "${plainText}", '
      'indent: ${leftIndentInches}in)';
}

/// One printed page of a paginated screenplay: an ordered list of
/// positioned lines, already fitted to [FountainLayoutMetrics.linesPerPage].
class FountainScriptPage extends Equatable {
  /// Creates a [FountainScriptPage].
  const FountainScriptPage({required this.lines});

  /// This page's lines, top to bottom.
  final List<FountainScriptLine> lines;

  @override
  List<Object?> get props => [lines];

  @override
  String toString() => 'FountainScriptPage(${lines.length} lines)';
}

/// A whole screenplay laid out into printed pages by
/// [FountainScriptComposer.compose].
class FountainScriptLayout extends Equatable {
  /// Creates a [FountainScriptLayout].
  const FountainScriptLayout({required this.pages});

  /// The screenplay's pages, in reading order.
  final List<FountainScriptPage> pages;

  @override
  List<Object?> get props => [pages];

  @override
  String toString() => 'FountainScriptLayout(${pages.length} pages)';
}

/// Turns a parsed [FountainDocument] into a [FountainScriptLayout] applying
/// the professional US screenplay pagination conventions: a forced page
/// break always starts a fresh page (without ever emitting a blank page); a
/// blank spacer line separates two consecutive top-level blocks that land
/// on the same page; a scene heading is never left as a page's last line; a
/// character cue is never left as a page's last line; and a dialogue group
/// that doesn't fit on the current page is split with a trailing `(MORE)`
/// and a repeated `NAME (CONT'D)` cue at the top of the next page.
///
/// This class only lays out lines: it does not touch a `pdf` package or any
/// other rendering concern, which is what keeps it usable from both the
/// PDF exporter and, in principle, any other consumer of a line-level
/// screenplay layout (a future plain-text exporter, for example).
class FountainScriptComposer {
  /// Creates a [FountainScriptComposer].
  const FountainScriptComposer();

  /// The inline parser used to resolve bold/italic/underline/note runs
  /// before wrapping. Stateless, so one instance is shared.
  static const FountainInlineParser _inlineParser = FountainInlineParser();

  /// Lays out every printable block of [document] into pages sized by
  /// [metrics].
  FountainScriptLayout compose({
    required FountainDocument document,
    required FountainLayoutMetrics metrics,
  }) {
    final blocks = _printableBlocks(document);
    final builder = _PageBuilder(metrics);

    for (var index = 0; index < blocks.length; index++) {
      final block = blocks[index];
      switch (block) {
        case FountainPageBreak():
          builder.forcePageBreak();
        case FountainSceneHeading():
          final hasFollowingContent =
              index + 1 < blocks.length &&
              blocks[index + 1] is! FountainPageBreak;
          builder.placeSceneHeading(
            _sceneHeadingLines(block, metrics),
            hasFollowingContent: hasFollowingContent,
          );
        case FountainDialogueGroup(:final character, :final children):
          builder.placeDialogueGroup(
            character: character,
            cueLines: _characterCueLines(character, metrics),
            childLines: _dialogueChildLines(children, metrics),
          );
        default:
          builder.placeGeneric(_genericBlockLines(block, metrics));
      }
    }

    return builder.finish();
  }

  /// Returns the blocks of [document] that are part of the printed
  /// screenplay, in source order: sections, synopses, notes and boneyard
  /// comments are editor-only constructs, never printed. Mirrors
  /// `OcptEditorPreviewLayout.printableBlocks`'s filter without depending on
  /// it, since this package must stay Flutter-free.
  static List<FountainBlock> _printableBlocks(FountainDocument document) =>
      document.blocks
          .where(
            (block) => switch (block) {
              FountainSection() ||
              FountainSynopsis() ||
              FountainNoteBlock() ||
              FountainBoneyard() => false,
              _ => true,
            },
          )
          .toList(growable: false);

  /// Wraps [heading]'s text (with its scene number prefixed, exactly as the
  /// on-screen preview builds it) into the wrapped lines of a
  /// [FountainLineType.sceneHeading] element.
  static List<FountainScriptLine> _sceneHeadingLines(
    FountainSceneHeading heading,
    FountainLayoutMetrics metrics,
  ) {
    final text = heading.sceneNumber == null
        ? heading.headingText
        : '${heading.sceneNumber}. ${heading.headingText}';
    return _wrapToLines(
      text,
      metrics.sceneHeading,
      FountainLineType.sceneHeading,
      isSceneHeading: true,
      sceneNumber: heading.sceneNumber,
    );
  }

  /// Wraps [character]'s cue text (name plus its parenthetical extension,
  /// if any) into the wrapped lines of a [FountainLineType.character]
  /// element.
  static List<FountainScriptLine> _characterCueLines(
    FountainCharacter character,
    FountainLayoutMetrics metrics,
  ) {
    final text = character.extension == null
        ? character.name
        : '${character.name} (${character.extension})';
    return _wrapToLines(text, metrics.character, FountainLineType.character);
  }

  /// Wraps a dialogue group's children (parentheticals and dialogue lines,
  /// in source order) into a flat list of lines, each tagged with its own
  /// element type. A parenthetical's text is wrapped with its enclosing
  /// parentheses included, exactly as it is printed.
  static List<FountainScriptLine> _dialogueChildLines(
    List<FountainBlock> children,
    FountainLayoutMetrics metrics,
  ) {
    final result = <FountainScriptLine>[];
    for (final child in children) {
      switch (child) {
        case FountainParenthetical(:final text):
          result.addAll(
            _wrapToLines(
              '($text)',
              metrics.parenthetical,
              FountainLineType.parenthetical,
            ),
          );
        case FountainDialogueLine(:final text):
          result.addAll(
            _wrapToLines(text, metrics.dialogue, FountainLineType.dialogue),
          );
        default:
          // A dialogue group's children are always a parenthetical or a
          // dialogue line; nothing else can reach this switch.
          break;
      }
    }
    return result;
  }

  /// Wraps every other printable top-level block kind (action, transition,
  /// centered text, lyrics) into its lines. Scene headings, dialogue groups
  /// and page breaks are handled separately by [compose], since each needs
  /// its own placement rule rather than plain line wrapping.
  static List<FountainScriptLine> _genericBlockLines(
    FountainBlock block,
    FountainLayoutMetrics metrics,
  ) => switch (block) {
    FountainActionBlock(:final lines) => _multiLineLines(
      lines,
      metrics.action,
      FountainLineType.action,
    ),
    FountainTransition(:final text) => _wrapToLines(
      text,
      metrics.transition,
      FountainLineType.transition,
    ),
    FountainCenteredText(:final text) => _wrapToLines(
      text,
      metrics.centeredText,
      FountainLineType.centeredText,
    ),
    FountainLyrics(:final lines) => _multiLineLines(
      lines,
      metrics.lyrics,
      FountainLineType.lyrics,
    ),
    _ => const [],
  };

  /// Wraps each of [sourceLines] independently at [layout]'s width (a
  /// block like action or lyrics keeps its source line breaks as real line
  /// breaks, rather than reflowing them into one paragraph), concatenating
  /// every source line's own wrapped output.
  static List<FountainScriptLine> _multiLineLines(
    List<String> sourceLines,
    FountainElementLayout layout,
    FountainLineType lineType,
  ) => [for (final line in sourceLines) ..._wrapToLines(line, layout, lineType)];

  /// Wraps [text] at [layout]'s column width into one [FountainScriptLine]
  /// per output line, each carrying [layout]'s indent/alignment, [lineType],
  /// and its own slice of [text]'s inline-styled runs.
  static List<FountainScriptLine> _wrapToLines(
    String text,
    FountainElementLayout layout,
    FountainLineType lineType, {
    bool isSceneHeading = false,
    String? sceneNumber,
  }) => [
    for (final runs in _wrapStyledRuns(text, layout.maxWidthColumns))
      FountainScriptLine(
        runs: runs,
        lineType: lineType,
        leftIndentInches: layout.leftIndentInches,
        alignment: layout.alignment,
        isSceneHeading: isSceneHeading,
        sceneNumber: sceneNumber,
      ),
  ];

  /// Wraps [text]'s inline-styled runs into the lines a box [maxColumns]
  /// columns wide breaks it into, using the same greedy, word-by-word
  /// wrapping decisions as the preview's `wrappedLineCount` (place words on
  /// the current line while they fit; hard-wrap mid-word only when a
  /// single word alone exceeds [maxColumns]), but wrapping the *rendered*
  /// text (inline emphasis markers already stripped by
  /// [FountainInlineParser.parseRuns]) rather than the raw source text.
  ///
  /// Wrapping the rendered text, not the raw markup, is deliberate: a `**`
  /// or `_` marker never actually occupies a printed column, so wrapping on
  /// the raw character count would break lines earlier than what the PDF
  /// renderer (working from these same runs) will actually lay out. It also
  /// keeps run-slicing exact, since the wrap boundaries and the runs live
  /// in the same offset space (the concatenation of the runs' own text)
  /// instead of needing a raw-offset-to-rendered-offset translation.
  static List<List<FountainStyledRun>> _wrapStyledRuns(
    String text,
    int maxColumns,
  ) {
    final runs = _inlineParser.parseRuns(text);

    final runRanges = <_LineRange>[];
    var cursor = 0;
    for (final run in runs) {
      runRanges.add(_LineRange(cursor, cursor + run.text.length));
      cursor += run.text.length;
    }
    final plain = runs.map((run) => run.text).join();

    return [
      for (final boundary in _wrapRanges(plain, maxColumns))
        _sliceRuns(runs, runRanges, boundary),
    ];
  }

  /// Returns the [FountainStyledRun]s of [runs] (whose offsets into the
  /// concatenated rendered text are [runRanges]) that fall within
  /// [boundary], splitting a run into a shorter one when [boundary] only
  /// partially overlaps it so each flag combination (bold/italic/
  /// underline/note) survives the split intact.
  static List<FountainStyledRun> _sliceRuns(
    List<FountainStyledRun> runs,
    List<_LineRange> runRanges,
    _LineRange boundary,
  ) {
    final result = <FountainStyledRun>[];
    for (var index = 0; index < runs.length; index++) {
      final runRange = runRanges[index];
      final overlapStart = boundary.start > runRange.start
          ? boundary.start
          : runRange.start;
      final overlapEnd = boundary.end < runRange.end
          ? boundary.end
          : runRange.end;
      if (overlapStart >= overlapEnd) {
        continue;
      }
      final run = runs[index];
      result.add(
        FountainStyledRun(
          text: run.text.substring(
            overlapStart - runRange.start,
            overlapEnd - runRange.start,
          ),
          isBold: run.isBold,
          isItalic: run.isItalic,
          isUnderline: run.isUnderline,
          isNote: run.isNote,
        ),
      );
    }
    return result;
  }

  /// Computes the `[start, end)` ranges of [text] a greedy word wrap at
  /// [maxColumns] columns places on each output line. The space at which a
  /// line breaks belongs to neither the line before nor the line after it,
  /// exactly like ordinary text wrapping (and like `wrappedLineCount`'s own
  /// line-count math, which this generalizes into actual substring ranges
  /// rather than just a count).
  static List<_LineRange> _wrapRanges(String text, int maxColumns) {
    if (text.isEmpty) {
      return [const _LineRange(0, 0)];
    }

    final words = <_LineRange>[];
    var wordStart = 0;
    for (var index = 0; index <= text.length; index++) {
      if (index == text.length || text[index] == ' ') {
        words.add(_LineRange(wordStart, index));
        wordStart = index + 1;
      }
    }

    final lines = <_LineRange>[];
    int? lineStart;
    var lineEnd = 0;

    void startFreshLine(_LineRange word) {
      final wordLength = word.end - word.start;
      if (wordLength > maxColumns) {
        var position = word.start;
        while (word.end - position > maxColumns) {
          lines.add(_LineRange(position, position + maxColumns));
          position += maxColumns;
        }
        lineStart = position;
        lineEnd = word.end;
      } else {
        lineStart = word.start;
        lineEnd = word.end;
      }
    }

    for (final word in words) {
      if (lineStart == null) {
        startFreshLine(word);
        continue;
      }
      final wordLength = word.end - word.start;
      final needed = (lineEnd - lineStart!) + 1 + wordLength;
      if (needed <= maxColumns) {
        lineEnd = word.end;
      } else {
        lines.add(_LineRange(lineStart!, lineEnd));
        lineStart = null;
        startFreshLine(word);
      }
    }
    if (lineStart != null) {
      lines.add(_LineRange(lineStart!, lineEnd));
    }

    return lines;
  }
}

/// A half-open `[start, end)` character range, used both for a wrapped
/// line's span and for a run's span within the same text, so the two can
/// be intersected directly.
class _LineRange {
  /// Creates a [_LineRange].
  const _LineRange(this.start, this.end);

  /// The range's inclusive start offset.
  final int start;

  /// The range's exclusive end offset.
  final int end;
}

/// The mutable page-building state behind [FountainScriptComposer.compose]:
/// the pages already closed, and the page currently being filled.
///
/// Kept as its own class (rather than a handful of local closures) because
/// the dialogue-splitting rule needs to loop, closing and reopening pages
/// several times for one input group, which reads far more clearly as a
/// small state machine than as a recursive local function.
class _PageBuilder {
  /// Creates a [_PageBuilder] laying out pages of [_metrics.linesPerPage]
  /// lines.
  _PageBuilder(this._metrics);

  /// The metrics every placement decision is measured against.
  final FountainLayoutMetrics _metrics;

  /// The pages already closed, in order.
  final List<FountainScriptPage> _pages = [];

  /// The lines placed so far on the page still being filled.
  final List<FountainScriptLine> _current = [];

  /// How many more lines fit on the page currently being filled.
  int get _capacity => _metrics.linesPerPage - _current.length;

  /// Closes the page currently being filled and starts a fresh one.
  void _closePage() {
    _pages.add(FountainScriptPage(lines: List.unmodifiable(_current)));
    _current.clear();
  }

  /// Handles a source [FountainPageBreak]: starts a fresh page, unless the
  /// current one is already empty (two consecutive breaks, or a break as
  /// the very first block, must never produce a blank page).
  void forcePageBreak() {
    if (_current.isNotEmpty) {
      _closePage();
    }
  }

  /// Places a plain block's [lines] (action, transition, lyrics, centered
  /// text): a lone spacer line first if another block already occupies
  /// this page, then the block's own lines, silently continuing onto a
  /// fresh page (no special marker, no spacer) if the block outgrows the
  /// current page. Only dialogue groups and scene headings get a more
  /// specific placement rule.
  void placeGeneric(List<FountainScriptLine> lines) {
    if (_current.isNotEmpty) {
      if (_capacity == 0) {
        _closePage();
      } else {
        _current.add(_spacerLine());
      }
    }
    for (final line in lines) {
      if (_current.length >= _metrics.linesPerPage) {
        _closePage();
      }
      _current.add(line);
    }
  }

  /// Places a scene heading's [lines], pushing the whole heading to a
  /// fresh page instead of letting it land as the current page's last
  /// content, whenever [hasFollowingContent] says more printable material
  /// still follows it in the document (so the push is actually meaningful
  /// rather than moving an already-empty page's content to another
  /// equally-empty page).
  void placeSceneHeading(
    List<FountainScriptLine> lines, {
    required bool hasFollowingContent,
  }) {
    if (_current.isNotEmpty && _capacity == 0) {
      _closePage();
    }

    final needsSpacer = _current.isNotEmpty;
    final totalNeeded = (needsSpacer ? 1 : 0) + lines.length;

    if (needsSpacer && hasFollowingContent && totalNeeded >= _capacity) {
      // Placing the heading here would leave it as this page's last line:
      // push the whole heading to a fresh page instead.
      _closePage();
      _current.addAll(lines);
      return;
    }

    if (needsSpacer) {
      _current.add(_spacerLine());
    }
    _current.addAll(lines);
  }

  /// Places a dialogue group's [cueLines] and [childLines] (its
  /// parentheticals and dialogue lines, already flattened in source
  /// order), applying both the no-orphan-cue rule and the `(MORE)`/
  /// `CONT'D` split when the group doesn't fit on the current page.
  ///
  /// This loops (rather than recursing) over however many pages the group
  /// ends up spanning: each iteration either finishes the group (the fast
  /// path once whatever remains fits) or places one more page's worth of
  /// content, appends `(MORE)`, closes the page and continues with a
  /// repeated `NAME (CONT'D)` cue.
  void placeDialogueGroup({
    required FountainCharacter character,
    required List<FountainScriptLine> cueLines,
    required List<FountainScriptLine> childLines,
  }) {
    var remaining = List<FountainScriptLine>.of(childLines);
    var isFirst = true;

    while (true) {
      final currentCue = isFirst
          ? cueLines
          : [_contdCueLine(character, _metrics)];
      final needsSpacer = isFirst && _current.isNotEmpty;
      final spacerCost = needsSpacer ? 1 : 0;
      final capacity = _capacity;
      final totalRemaining = currentCue.length + remaining.length;

      if (spacerCost + totalRemaining <= capacity) {
        // Whatever is left of the group fits entirely: place it and stop.
        if (needsSpacer) {
          _current.add(_spacerLine());
        }
        _current.addAll(currentCue);
        _current.addAll(remaining);
        return;
      }

      // Doesn't all fit: figure out how much can be placed before a
      // trailing "(MORE)" line, reserving one line for it.
      final roomForContent = capacity - spacerCost - 1;
      final childCapacity = roomForContent - currentCue.length;

      if (childCapacity < 1 && _current.isNotEmpty) {
        // Not even room for the cue plus one child line: that would leave
        // the cue orphaned as the page's last line. Push the whole cue to
        // a fresh page and retry there, where there is genuinely more
        // room (retrying on an already-empty page would achieve nothing).
        _closePage();
        continue;
      }

      final placeCount = childCapacity <= 0
          ? 0
          : (childCapacity < remaining.length
                ? childCapacity
                : remaining.length);

      if (needsSpacer) {
        _current.add(_spacerLine());
      }
      _current.addAll(currentCue);
      _current.addAll(remaining.take(placeCount));
      _current.add(_moreLine(_metrics));
      remaining = remaining.skip(placeCount).toList();
      _closePage();
      isFirst = false;
    }
  }

  /// Closes the page still being filled, if any, and returns the finished
  /// [FountainScriptLayout].
  FountainScriptLayout finish() {
    if (_current.isNotEmpty) {
      _closePage();
    }
    return FountainScriptLayout(pages: List.unmodifiable(_pages));
  }

  /// A single blank line inserted between two consecutive top-level blocks
  /// that land on the same page.
  static FountainScriptLine _spacerLine() => const FountainScriptLine(
    runs: [],
    lineType: FountainLineType.blank,
    leftIndentInches: 0,
    alignment: FountainLayoutAlignment.left,
    isSceneHeading: false,
  );

  /// The `(MORE)` line appended at the bottom of a page when a dialogue
  /// group is split across a page boundary, set at the parenthetical's
  /// indent and alignment.
  static FountainScriptLine _moreLine(FountainLayoutMetrics metrics) =>
      FountainScriptLine(
        runs: const [FountainStyledRun(text: _moreToken)],
        lineType: FountainLineType.parenthetical,
        leftIndentInches: metrics.parenthetical.leftIndentInches,
        alignment: metrics.parenthetical.alignment,
        isSceneHeading: false,
      );

  /// The repeated `NAME (CONT'D)` cue placed at the top of the page a
  /// split dialogue group continues onto, set at the character's indent
  /// and alignment. The original cue's `extension` is deliberately ignored
  /// here: a continued cue always reads `(CONT'D)`, never the original
  /// extension.
  static FountainScriptLine _contdCueLine(
    FountainCharacter character,
    FountainLayoutMetrics metrics,
  ) => FountainScriptLine(
    runs: [FountainStyledRun(text: "${character.name} (CONT'D)")],
    lineType: FountainLineType.character,
    leftIndentInches: metrics.character.leftIndentInches,
    alignment: metrics.character.alignment,
    isSceneHeading: false,
  );
}
