// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/utils/ocpt_three_way_merge.dart';

void main() {
  String clean(OcptThreeWayMergeResult result) {
    expect(result, isA<OcptCleanThreeWayMerge>());
    return (result as OcptCleanThreeWayMerge).mergedText;
  }

  test('identical inputs merge cleanly back to the same text', () {
    const text = 'INT. HOUSE - DAY\n\nAction.\n';

    final result = ocptThreeWayMerge(base: text, left: text, right: text);

    expect(clean(result), text);
  });

  test('a left-only change merges cleanly, keeping the right side untouched', () {
    const base = 'a\nb\nc';
    const left = 'a\nX\nc';
    const right = 'a\nb\nc';

    final result = ocptThreeWayMerge(base: base, left: left, right: right);

    expect(clean(result), 'a\nX\nc');
  });

  test('a right-only change merges cleanly, keeping the left side untouched', () {
    const base = 'a\nb\nc';
    const left = 'a\nb\nc';
    const right = 'a\nY\nc';

    final result = ocptThreeWayMerge(base: base, left: left, right: right);

    expect(clean(result), 'a\nY\nc');
  });

  test('non-overlapping changes on both sides combine cleanly', () {
    const base = 'a\nb\nc\nd\ne';
    const left = 'a\nX\nc\nd\ne';
    const right = 'a\nb\nc\nY\ne';

    final result = ocptThreeWayMerge(base: base, left: left, right: right);

    expect(clean(result), 'a\nX\nc\nY\ne');
  });

  test('the same region changed differently on both sides is a conflict', () {
    const base = 'a\nb\nc';
    const left = 'a\nX\nc';
    const right = 'a\nY\nc';

    final result = ocptThreeWayMerge(base: base, left: left, right: right);

    expect(result, isA<OcptThreeWayMergeConflict>());
    final conflict = result as OcptThreeWayMergeConflict;
    expect(conflict.hunks, hasLength(1));
    expect(conflict.hunks.single.baseLines, ['b']);
    expect(conflict.hunks.single.leftLines, ['X']);
    expect(conflict.hunks.single.rightLines, ['Y']);
  });

  test('both sides making the exact same edit is clean, not a conflict', () {
    const base = 'a\nb\nc';
    const left = 'a\nX\nc';
    const right = 'a\nX\nc';

    final result = ocptThreeWayMerge(base: base, left: left, right: right);

    expect(clean(result), 'a\nX\nc');
  });

  test('an insertion on one side merges cleanly', () {
    const base = 'a\nb';
    const left = 'a\nX\nb';
    const right = 'a\nb';

    final result = ocptThreeWayMerge(base: base, left: left, right: right);

    expect(clean(result), 'a\nX\nb');
  });

  test('insertions at the end on both sides combine cleanly', () {
    const base = 'a\nb';
    const left = 'a\nb\nX';
    const right = 'a\nb\nY';

    final result = ocptThreeWayMerge(base: base, left: left, right: right);

    expect(result, isA<OcptThreeWayMergeConflict>());
    final conflict = result as OcptThreeWayMergeConflict;
    expect(conflict.hunks.single.baseLines, isEmpty);
    expect(conflict.hunks.single.leftLines, ['X']);
    expect(conflict.hunks.single.rightLines, ['Y']);
  });

  test('a deletion on one side merges cleanly', () {
    const base = 'a\nb\nc';
    const left = 'a\nc';
    const right = 'a\nb\nc';

    final result = ocptThreeWayMerge(base: base, left: left, right: right);

    expect(clean(result), 'a\nc');
  });

  test('a deletion on one side and an unrelated change on the other combine cleanly', () {
    const base = 'a\nb\nc\nd';
    const left = 'a\nc\nd';
    const right = 'a\nb\nc\nY';

    final result = ocptThreeWayMerge(base: base, left: left, right: right);

    expect(clean(result), 'a\nc\nY');
  });

  test('a trailing newline round-trips through a clean merge', () {
    const base = 'a\nb\n';
    const left = 'a\nX\n';
    const right = 'a\nb\n';

    final result = ocptThreeWayMerge(base: base, left: left, right: right);

    expect(clean(result), 'a\nX\n');
  });

  test('a whole-document rewrite on both sides, differently, is a conflict', () {
    const base = 'a\nb';
    const left = 'X\nY';
    const right = 'P\nQ';

    final result = ocptThreeWayMerge(base: base, left: left, right: right);

    expect(result, isA<OcptThreeWayMergeConflict>());
  });
}
