// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:fountain_kit/src/layout/fountain_layout_metrics.dart';
import 'package:fountain_kit/src/layout/fountain_print_style.dart';
import 'package:fountain_kit/src/models/fountain_block.dart';
import 'package:fountain_kit/src/models/fountain_document.dart';
import 'package:fountain_kit/src/models/fountain_source_range.dart';
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
    this.isSynthetic = false,
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

  /// Whether this line is composed text with no source behind it: the
  /// `(MORE)` token closing a split dialogue group, and the `NAME (CONT'D)`
  /// cue repeated at the top of the page it continues onto.
  ///
  /// A synthetic line never carries a [sourceRange], but the converse does
  /// not hold — a blank spacer line has no range either and is not synthetic.
  /// A consumer mapping source offsets onto printed rows needs to tell the
  /// two apart: both are bridged over rather than resolved, but only a
  /// synthetic line renders text that the source never contained.
  final bool isSynthetic;

  /// This line's text with its inline styling discarded, i.e. the
  /// concatenation of every run's [FountainStyledRun.text] in order.
  String get plainText => runs.map((run) => run.text).join();

  /// The span of source text this printed line was composed from, or `null`
  /// when it has none: a blank spacer line, a preserved blank dialogue line,
  /// a synthetic line, or a line the composer could not anchor in the
  /// document's source text (see [FountainScriptComposer.compose]).
  ///
  /// It is the union of this line's runs' own
  /// [FountainStyledRun.sourceRange]s. Since no run's range covers its own
  /// emphasis markers, a marker *between* two runs of a line is part of that
  /// line's range while one sitting at either end of it is not — nothing on
  /// the line renders it. Consecutive printed lines of one wrapped paragraph
  /// have adjacent, non-overlapping ranges: the space a line breaks at
  /// belongs to neither of them, exactly as it belongs to neither line's
  /// text.
  FountainSourceRange? get sourceRange {
    FountainSourceRange? result;
    for (final run in runs) {
      final range = run.sourceRange;
      if (range == null) {
        continue;
      }
      result = result == null ? range : result.merge(range);
    }
    return result;
  }

  @override
  List<Object?> get props => [
    runs,
    lineType,
    leftIndentInches,
    alignment,
    isSceneHeading,
    sceneNumber,
    isSynthetic,
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
///
/// Every line it emits carries a [FountainScriptLine.sourceRange] pointing
/// back into [FountainDocument.sourceText], so a consumer can map a span of
/// source characters onto the rows it was printed on. Only the paginator
/// knows how it wrapped the text, which is why that mapping is produced here
/// rather than recomputed by a caller.
class FountainScriptComposer {
  /// Creates a [FountainScriptComposer].
  const FountainScriptComposer();

  /// The inline parser used to resolve bold/italic/underline/note runs
  /// before wrapping. Stateless, so one instance is shared.
  static const FountainInlineParser _inlineParser = FountainInlineParser();

  /// Lays out every printable block of [document] into pages sized by
  /// [metrics].
  ///
  /// The lines it produces are anchored back into [document]'s own
  /// [FountainDocument.sourceText] on a best-effort basis: a printed line
  /// whose text cannot be located in the source (a document parsed from a
  /// source string it no longer carries, a line the parser rewrote beyond
  /// recognition) simply gets no [FountainScriptLine.sourceRange], never a
  /// wrong one.
  FountainScriptLayout compose({
    required FountainDocument document,
    required FountainLayoutMetrics metrics,
  }) {
    final blocks = _printableBlocks(document);
    final builder = _PageBuilder(metrics);
    final anchors = _SourceAnchors(document.sourceText);

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
            _sceneHeadingLines(block, metrics, anchors),
            hasFollowingContent: hasFollowingContent,
          );
        case FountainDialogueGroup(:final character, :final children):
          builder.placeDialogueGroup(
            character: character,
            cueLines: _characterCueLines(character, metrics, anchors),
            childLines: _dialogueChildLines(children, metrics, anchors),
          );
        default:
          builder.placeGeneric(_genericBlockLines(block, metrics, anchors));
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

  /// Wraps [heading]'s text into the wrapped lines of a
  /// [FountainLineType.sceneHeading] element.
  ///
  /// The scene number is never prefixed into the printed text here (unlike
  /// the on-screen preview, which has no margins to draw it in and so keeps
  /// it inline): [FountainScriptLine.sceneNumber] already carries it
  /// separately, so a renderer with margins to print in — the PDF exporter
  /// — places it there instead, and a heading's printed text is never
  /// duplicated between the two.
  static List<FountainScriptLine> _sceneHeadingLines(
    FountainSceneHeading heading,
    FountainLayoutMetrics metrics,
    _SourceAnchors anchors,
  ) => _wrapToLines(
    heading.headingText,
    metrics.sceneHeading,
    FountainLineType.sceneHeading,
    anchors.ofBlock(heading, heading.headingText),
    isSceneHeading: true,
    sceneNumber: heading.sceneNumber,
  );

  /// Wraps [character]'s cue text (name plus its parenthetical extension,
  /// if any) into the wrapped lines of a [FountainLineType.character]
  /// element, upper-cased per [FountainPrintStyle.of]'s print-time rule for
  /// [FountainLineType.character].
  static List<FountainScriptLine> _characterCueLines(
    FountainCharacter character,
    FountainLayoutMetrics metrics,
    _SourceAnchors anchors,
  ) {
    final text = character.extension == null
        ? character.name
        : '${character.name} (${character.extension})';
    final printed = _printed(text, FountainLineType.character);
    return _wrapToLines(
      printed,
      metrics.character,
      FountainLineType.character,
      anchors.ofBlock(character, printed),
    );
  }

  /// Wraps a dialogue group's children (parentheticals and dialogue lines,
  /// in source order) into a flat list of lines, each tagged with its own
  /// element type. A parenthetical's text is wrapped with its enclosing
  /// parentheses included, exactly as it is printed.
  static List<FountainScriptLine> _dialogueChildLines(
    List<FountainBlock> children,
    FountainLayoutMetrics metrics,
    _SourceAnchors anchors,
  ) {
    final result = <FountainScriptLine>[];
    for (final child in children) {
      switch (child) {
        case FountainParenthetical(:final text):
          final printed = '($text)';
          result.addAll(
            _wrapToLines(
              printed,
              metrics.parenthetical,
              FountainLineType.parenthetical,
              anchors.ofBlock(child, printed),
            ),
          );
        case FountainDialogueLine(:final text):
          result.addAll(
            _wrapToLines(
              text,
              metrics.dialogue,
              FountainLineType.dialogue,
              anchors.ofBlock(child, text),
            ),
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
    _SourceAnchors anchors,
  ) => switch (block) {
    FountainActionBlock(:final lines) => _multiLineLines(
      lines,
      metrics.action,
      FountainLineType.action,
      anchors.ofLines(block, lines),
    ),
    FountainTransition(:final text) => _wrapToLines(
      _printed(text, FountainLineType.transition),
      metrics.transition,
      FountainLineType.transition,
      anchors.ofBlock(block, _printed(text, FountainLineType.transition)),
    ),
    FountainCenteredText(:final text) => _wrapToLines(
      text,
      metrics.centeredText,
      FountainLineType.centeredText,
      anchors.ofBlock(block, text),
    ),
    FountainLyrics(:final lines) => _multiLineLines(
      lines,
      metrics.lyrics,
      FountainLineType.lyrics,
      anchors.ofLines(block, lines),
    ),
    _ => const [],
  };

  /// Applies [FountainPrintStyle.of]'s print-time letter case to [text] for
  /// a line of [lineType], upper-casing it when that type's print style
  /// says so. Routed through the shared table (rather than a literal
  /// `.toUpperCase()` at each call site) so every renderer that prints a
  /// screenplay element derives the same casing decision from the same
  /// place.
  static String _printed(String text, FountainLineType lineType) =>
      FountainPrintStyle.of(lineType).isUppercase ? text.toUpperCase() : text;

  /// Wraps each of [sourceLines] independently at [layout]'s width (a
  /// block like action or lyrics keeps its source line breaks as real line
  /// breaks, rather than reflowing them into one paragraph), concatenating
  /// every source line's own wrapped output.
  ///
  /// [anchors] holds one entry per element of [sourceLines], in the same
  /// order, each either that line's own source anchor or `null`.
  static List<FountainScriptLine> _multiLineLines(
    List<String> sourceLines,
    FountainElementLayout layout,
    FountainLineType lineType,
    List<_SourceAnchor?> anchors,
  ) => [
    for (var index = 0; index < sourceLines.length; index++)
      ..._wrapToLines(sourceLines[index], layout, lineType, anchors[index]),
  ];

  /// Wraps [text] at [layout]'s column width into one [FountainScriptLine]
  /// per output line, each carrying [layout]'s indent/alignment, [lineType],
  /// and its own slice of [text]'s inline-styled runs.
  ///
  /// [anchor] is where `text[0]` sits in the document source, or `null` when
  /// that is unknown, in which case none of the produced runs carries a
  /// source range.
  static List<FountainScriptLine> _wrapToLines(
    String text,
    FountainElementLayout layout,
    FountainLineType lineType,
    _SourceAnchor? anchor, {
    bool isSceneHeading = false,
    String? sceneNumber,
  }) => [
    for (final runs in _wrapStyledRuns(text, layout.maxWidthColumns, anchor))
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
    _SourceAnchor? anchor,
  ) {
    final runs = _inlineParser.parseRuns(
      text,
      line: anchor?.line,
      startOffset: anchor?.offset,
    );

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
  ///
  /// A split run's [FountainStyledRun.sourceRange] is narrowed to the part
  /// that survives, so a wrapped paragraph's printed lines each point at the
  /// source characters they alone were composed from.
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
      final localStart = overlapStart - runRange.start;
      final localEnd = overlapEnd - runRange.start;
      result.add(
        FountainStyledRun(
          text: run.text.substring(localStart, localEnd),
          isBold: run.isBold,
          isItalic: run.isItalic,
          isUnderline: run.isUnderline,
          isNote: run.isNote,
          sourceRange: _sliceSourceRange(
            run.sourceRange,
            run.text.length,
            localStart,
            localEnd,
          ),
        ),
      );
    }
    return result;
  }

  /// Narrows [range] — the source range of a run [textLength] characters
  /// long — to the part of that run covering `[localStart, localEnd)`.
  ///
  /// The two scales are the same whenever the run's rendered text is as long
  /// as the source it came from, which is the ordinary case; when a
  /// print-time `toUpperCase()` or an escape sequence has made them differ,
  /// the offsets are interpolated proportionally instead. The imprecision
  /// that leaves is a character or two *within* one printed line, never a
  /// whole line.
  static FountainSourceRange? _sliceSourceRange(
    FountainSourceRange? range,
    int textLength,
    int localStart,
    int localEnd,
  ) {
    if (range == null) {
      return null;
    }
    if (localStart == 0 && localEnd == textLength) {
      return range;
    }
    final sourceLength = range.endOffset - range.startOffset;
    int mapped(int offset) => textLength == 0
        ? range.startOffset
        : range.startOffset + (offset * sourceLength / textLength).round();
    return FountainSourceRange(
      startLine: range.startLine,
      endLine: range.endLine,
      startOffset: mapped(localStart),
      endOffset: mapped(localEnd),
    );
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

/// Where a piece of text the composer is about to wrap sits in the document
/// source: the 0-based source line it belongs to, and the character offset
/// of its first character.
///
/// This is exactly the pair [FountainInlineParser.parseRuns] anchors its runs
/// with, and the only thing the composer has to work out for itself before
/// wrapping — everything downstream (run slicing, line ranges) follows from
/// it mechanically.
class _SourceAnchor {
  /// Creates a [_SourceAnchor].
  const _SourceAnchor({required this.line, required this.offset});

  /// The 0-based source line the anchored text was taken from.
  final int line;

  /// The character offset, in the document source, of the anchored text's
  /// first character.
  final int offset;
}

/// Resolves the [_SourceAnchor] of each piece of text the composer prints,
/// against the source string the document was parsed from.
///
/// A block's own [FountainBlock.sourceRange] covers its **raw** source lines,
/// markers and all, while what gets printed is the parser's cleaned-up text:
/// a forced heading loses its `.`, a lyric line its `~`, a parenthetical its
/// surrounding whitespace, a transition or a cue gets upper-cased. So the
/// text is looked up verbatim inside the source line it came from, which puts
/// the anchor exactly where it belongs whenever the parser only *removed*
/// characters, and the block's own start offset is the fallback for the rest
/// (an upper-cased line whose source was not already upper-case, mostly),
/// off by however many characters the parser stripped from the line's head.
///
/// Everything here is best effort by design: an anchor is only ever produced
/// when the block's range genuinely addresses the source text it is resolved
/// against, so a document carrying no source text at all (or one whose text
/// has since been edited out from under it) yields no anchors rather than
/// wrong ones.
class _SourceAnchors {
  /// Creates a [_SourceAnchors] resolving against [_sourceText].
  const _SourceAnchors(this._sourceText);

  /// The document source every anchor points into.
  final String _sourceText;

  /// The anchor of [printedText], a single-line block [block]'s whole
  /// printed text, or `null` when [block]'s range does not address
  /// [_sourceText].
  _SourceAnchor? ofBlock(FountainBlock block, String printedText) {
    final range = block.sourceRange;
    if (!_addressesSource(range)) {
      return null;
    }
    final found = _sourceText.indexOf(printedText, range.startOffset);
    final isWithinBlock =
        found >= 0 && found + printedText.length <= range.endOffset;
    return _SourceAnchor(
      line: range.startLine,
      offset: isWithinBlock ? found : range.startOffset,
    );
  }

  /// The anchors of a multi-line block [block]'s [lines], one entry per line
  /// in the same order.
  ///
  /// A multi-line block holds exactly one entry in [lines] per source line it
  /// spans, in order, which is what makes each line's own number simply its
  /// index past the block's first. Only its offset has to be searched for,
  /// and only within the source line it belongs to, so a line whose text also
  /// appears elsewhere in the block can never be anchored onto that other
  /// occurrence.
  List<_SourceAnchor?> ofLines(FountainBlock block, List<String> lines) {
    final range = block.sourceRange;
    if (!_addressesSource(range)) {
      return List.filled(lines.length, null);
    }

    final anchors = <_SourceAnchor?>[];
    var lineStart = range.startOffset;
    for (var index = 0; index < lines.length; index++) {
      final lineEnd = _endOfLine(lineStart, range.endOffset);
      final found = _sourceText.indexOf(lines[index], lineStart);
      anchors.add(
        found >= 0 && found + lines[index].length <= lineEnd
            ? _SourceAnchor(line: range.startLine + index, offset: found)
            : null,
      );
      lineStart = lineEnd + 1;
    }
    return anchors;
  }

  /// Whether [range] genuinely addresses [_sourceText], i.e. covers at least
  /// one character of it and stays within its bounds. A document built by
  /// hand (as a test's fixtures are) carries no source text, and its blocks'
  /// ranges must not be read as if it did.
  bool _addressesSource(FountainSourceRange range) =>
      range.endOffset > range.startOffset &&
      range.endOffset <= _sourceText.length;

  /// The offset of the end of the source line starting at [lineStart],
  /// clamped to [limit] so the search for one line's text never wanders past
  /// the block it belongs to.
  int _endOfLine(int lineStart, int limit) {
    final newline = _sourceText.indexOf('\n', lineStart);
    return newline < 0 || newline > limit ? limit : newline;
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
        isSynthetic: true,
      );

  /// The repeated `NAME (CONT'D)` cue placed at the top of the page a
  /// split dialogue group continues onto, set at the character's indent
  /// and alignment. The original cue's `extension` is deliberately ignored
  /// here: a continued cue always reads `(CONT'D)`, never the original
  /// extension. Upper-cased, exactly like every other
  /// [FountainLineType.character] cue.
  static FountainScriptLine _contdCueLine(
    FountainCharacter character,
    FountainLayoutMetrics metrics,
  ) => FountainScriptLine(
    runs: [
      FountainStyledRun(
        text: FountainScriptComposer._printed(
          "${character.name} (CONT'D)",
          FountainLineType.character,
        ),
      ),
    ],
    lineType: FountainLineType.character,
    leftIndentInches: metrics.character.leftIndentInches,
    alignment: metrics.character.alignment,
    isSceneHeading: false,
    isSynthetic: true,
  );
}
