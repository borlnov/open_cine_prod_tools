// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:typed_data';

import 'package:equatable/equatable.dart';

/// A line-based three-way (diff3) merge of a screenplay's Fountain text — the one column
/// `docs/plans/collaboration-and-sync.md` (§2.4/§3.4) reconciles by comparing the *content* of two
/// diverging edits against their nearest common ancestor, rather than picking one side outright the
/// way every other synchronised column does (`OcptMergeService`).
///
/// This file is a pure, dependency-free function over three plain strings: it knows nothing about
/// `screenplays`, `OcptProjectDatabase` or the sync engine at all — `OcptScreenplayMergeService` is
/// what wires it to the database, snapshots and stamping. Keeping it here, in `lib/utils/`, is what
/// lets it be tested with no database, exactly like `ocpt_fractional_key.dart` and
/// `ocpt_text_search.dart`.
///
/// [ocptThreeWayMerge] is either clean ([OcptCleanThreeWayMerge]), exactly when the two sides never
/// touch the same region of the base text, or a [OcptThreeWayMergeConflict] carrying every region
/// they changed differently — see [ocptThreeWayMerge]'s own doc comment for the algorithm and its
/// cost.
sealed class OcptThreeWayMergeResult extends Equatable {
  const OcptThreeWayMergeResult();
}

/// `ocptThreeWayMerge` found no overlapping edit: `mergedText` combines every non-overlapping
/// change from both diverging sides onto their common ancestor, and can be written back as the new
/// document text outright.
final class OcptCleanThreeWayMerge extends OcptThreeWayMergeResult {
  /// The merged text: the common ancestor with every clean change from either side applied, lines
  /// rejoined with `\n`.
  final String mergedText;

  /// Creates a clean merge result.
  const OcptCleanThreeWayMerge(this.mergedText);

  @override
  List<Object?> get props => [mergedText];

  @override
  String toString() => 'OcptCleanThreeWayMerge(mergedText: $mergedText)';
}

/// `ocptThreeWayMerge` found at least one region both sides changed differently: `hunks` is every
/// one of those overlapping regions, in document order. Nothing is merged at all — this result
/// carries no partial text, since a caller with a genuine conflict needs the three whole texts
/// originally handed to `ocptThreeWayMerge` to resolve it, not a half-applied document.
final class OcptThreeWayMergeConflict extends OcptThreeWayMergeResult {
  /// Every base region the two diverging sides changed differently, in document order.
  final List<OcptThreeWayMergeHunk> hunks;

  /// Creates a conflict result. `hunks` is never empty — that is exactly what makes this a
  /// [OcptThreeWayMergeConflict] rather than an [OcptCleanThreeWayMerge].
  const OcptThreeWayMergeConflict(this.hunks);

  @override
  List<Object?> get props => [hunks];

  @override
  String toString() => 'OcptThreeWayMergeConflict(hunks: $hunks)';
}

/// One base region a merge's two diverging sides changed differently: the base lines that region
/// held, and what each side replaced them with.
class OcptThreeWayMergeHunk extends Equatable {
  /// The lines the common ancestor held in this region.
  final List<String> baseLines;

  /// The lines the first diverging side holds in the corresponding region.
  final List<String> leftLines;

  /// The lines the second diverging side holds in the corresponding region.
  final List<String> rightLines;

  /// Creates a merge hunk.
  const OcptThreeWayMergeHunk({required this.baseLines, required this.leftLines, required this.rightLines});

  @override
  List<Object?> get props => [baseLines, leftLines, rightLines];

  @override
  String toString() => 'OcptThreeWayMergeHunk(baseLines: $baseLines, leftLines: $leftLines, rightLines: $rightLines)';
}

/// Merges [left] and [right], two texts that independently diverged from their common ancestor
/// [base], line by line.
///
/// ## The algorithm
///
/// [base], [left] and [right] are each split into lines on `\n` (so a trailing newline round-trips
/// as the trailing empty element `String.split` itself already produces, and joining the result
/// back with `\n` reproduces the original text exactly when nothing changed). The merge itself is
/// the classic "diff3" construction:
///
/// 1. Compute the matching blocks — runs of lines common to both sides, aligned in order — between
///    [base] and [left], and separately between [base] and [right], each through the longest common
///    subsequence (LCS) of the two line lists (see [_matchingBlocks]).
/// 2. A base line is an **anchor** when it sits inside a matching block on *both* sides at once: a
///    line neither edit touched, which is therefore identical across all three texts. Anchors are
///    what synchronises the two independent diffs into one three-way alignment.
/// 3. Between two consecutive anchors (or before the first / after the last one) sits a **gap**: the
///    base lines there, and whichever lines [left] and [right] hold in the corresponding span.
///    Comparing the three spans of one gap is the whole of the merge decision:
///    - neither side changed it (a degenerate, zero-length gap): nothing to do, the anchors already
///      cover it;
///    - only [left] changed it: the [left] span wins;
///    - only [right] changed it: the [right] span wins;
///    - both changed it to the very **same** lines: no conflict — the identical edit wins;
///    - both changed it to something different: a genuine conflict, recorded as one
///      [OcptThreeWayMergeHunk] rather than resolved.
///
/// The whole merge is clean ([OcptCleanThreeWayMerge]) exactly when no gap conflicts; otherwise it
/// is a [OcptThreeWayMergeConflict], carrying every conflicting hunk — the clean gaps around a
/// conflict are not reported, since nothing here builds a marked-up "diff3 style" merged text with
/// `<<<<<<<`/`=======`/`>>>>>>>` conflict markers: `OcptScreenplayMergeService`'s own conflict
/// record (base/local/incoming, in full) is what a future resolution view reads instead.
///
/// ## Cost
///
/// The LCS step is the classic O(n·m) dynamic-programming table, computed twice (once against
/// [left], once against [right]) — fine for a merge, which happens once per incoming edit rather
/// than per keystroke, but **not** something this function is asked to run on every parse debounce.
/// A screenplay of a few thousand lines costs a few tens of megabytes of transient `Uint32List`
/// scratch space, released as soon as this function returns.
OcptThreeWayMergeResult ocptThreeWayMerge({required String base, required String left, required String right}) {
  final baseLines = base.split('\n');
  final leftLines = left.split('\n');
  final rightLines = right.split('\n');

  final leftIndexOfBase = _matchedIndexByBaseIndex(baseLines, leftLines);
  final rightIndexOfBase = _matchedIndexByBaseIndex(baseLines, rightLines);

  final mergedLines = <String>[];
  final hunks = <OcptThreeWayMergeHunk>[];

  var lastAnchorBase = -1;
  var lastAnchorLeft = -1;
  var lastAnchorRight = -1;

  void processGap(int baseEnd, int leftEnd, int rightEnd) {
    final baseChunk = baseLines.sublist(lastAnchorBase + 1, baseEnd);
    final leftChunk = leftLines.sublist(lastAnchorLeft + 1, leftEnd);
    final rightChunk = rightLines.sublist(lastAnchorRight + 1, rightEnd);

    if (_listEquals(leftChunk, baseChunk) && _listEquals(rightChunk, baseChunk)) {
      mergedLines.addAll(baseChunk);
    } else if (_listEquals(leftChunk, baseChunk)) {
      // Only the right side touched this region.
      mergedLines.addAll(rightChunk);
    } else if (_listEquals(rightChunk, baseChunk)) {
      // Only the left side touched this region.
      mergedLines.addAll(leftChunk);
    } else if (_listEquals(leftChunk, rightChunk)) {
      // Both sides made the very same change independently: not a conflict.
      mergedLines.addAll(leftChunk);
    } else {
      hunks.add(OcptThreeWayMergeHunk(baseLines: baseChunk, leftLines: leftChunk, rightLines: rightChunk));
    }
  }

  for (var i = 0; i < baseLines.length; i++) {
    final leftIndex = leftIndexOfBase[i];
    final rightIndex = rightIndexOfBase[i];
    if (leftIndex == null || rightIndex == null) {
      continue;
    }

    // Always process the gap since the previous anchor, even when it is empty on the base side:
    // a pure insertion (on either side) skips no base line at all, yet still has to be captured as
    // a non-empty left-only or right-only chunk here — `processGap` itself is a cheap no-op when
    // every chunk it computes turns out empty.
    processGap(i, leftIndex, rightIndex);

    mergedLines.add(baseLines[i]);
    lastAnchorBase = i;
    lastAnchorLeft = leftIndex;
    lastAnchorRight = rightIndex;
  }

  processGap(baseLines.length, leftLines.length, rightLines.length);

  if (hunks.isNotEmpty) {
    return OcptThreeWayMergeConflict(hunks);
  }

  return OcptCleanThreeWayMerge(mergedLines.join('\n'));
}

/// For every index of [base] that sits inside a matching block shared with [other] (see
/// [_matchingBlocks]), the corresponding index into [other] — `null` for a [base] index [other]
/// does not hold unchanged, which is exactly the set of base lines this side of the merge touched.
List<int?> _matchedIndexByBaseIndex(List<String> base, List<String> other) {
  final result = List<int?>.filled(base.length, null);
  for (final block in _matchingBlocks(base, other)) {
    for (var offset = 0; offset < block.length; offset++) {
      result[block.baseStart + offset] = block.otherStart + offset;
    }
  }
  return result;
}

/// One run of consecutive lines [_matchingBlocks] found identical, in order, between two texts.
class _MatchingBlock {
  final int baseStart;
  final int otherStart;
  final int length;

  const _MatchingBlock({required this.baseStart, required this.otherStart, required this.length});
}

/// The matching blocks — maximal runs of consecutive lines common to [base] and [other], in
/// document order on both sides — computed from the longest common subsequence of the two line
/// lists.
///
/// The LCS itself is the standard bottom-up dynamic-programming table, `dp[i][j]` holding the
/// length of the LCS of `base[i:]` and `other[j:]`; matching blocks are then reconstructed by
/// walking it forward from `(0, 0)`, always stepping onto an equal pair when one is available and
/// otherwise following whichever neighbour cell (`dp[i+1][j]` or `dp[i][j+1]`) carries the larger
/// remaining LCS length — the usual LCS backtrack, run forward instead of backward so the blocks
/// come out already in order.
List<_MatchingBlock> _matchingBlocks(List<String> base, List<String> other) {
  final n = base.length;
  final m = other.length;

  // dp[i] is row i of the table, holding dp[i][j] for every j — built bottom-up (i from n down to
  // 0) so dp[i+1] is already complete by the time row i is computed. Stored as Uint32List rather
  // than a boxed List<int>: a screenplay of a few thousand lines makes this table large enough that
  // the difference matters (see the top-level `ocptThreeWayMerge`'s own doc comment on cost).
  final dp = List.generate(n + 1, (_) => Uint32List(m + 1));
  for (var i = n - 1; i >= 0; i--) {
    final rowBelow = dp[i + 1];
    final row = dp[i];
    for (var j = m - 1; j >= 0; j--) {
      row[j] = base[i] == other[j] ? rowBelow[j + 1] + 1 : (rowBelow[j] >= row[j + 1] ? rowBelow[j] : row[j + 1]);
    }
  }

  final blocks = <_MatchingBlock>[];
  var i = 0;
  var j = 0;
  while (i < n && j < m) {
    if (base[i] == other[j]) {
      final blockBaseStart = i;
      final blockOtherStart = j;
      while (i < n && j < m && base[i] == other[j]) {
        i++;
        j++;
      }
      blocks.add(_MatchingBlock(baseStart: blockBaseStart, otherStart: blockOtherStart, length: i - blockBaseStart));
    } else if (dp[i + 1][j] >= dp[i][j + 1]) {
      i++;
    } else {
      j++;
    }
  }

  return blocks;
}

/// Whether [a] and [b] hold the same lines in the same order — `List<String>`'s own `==` is
/// identity, not content equality, so every comparison [ocptThreeWayMerge] itself makes goes
/// through this instead.
bool _listEquals(List<String> a, List<String> b) {
  if (identical(a, b)) {
    return true;
  }
  if (a.length != b.length) {
    return false;
  }
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}
