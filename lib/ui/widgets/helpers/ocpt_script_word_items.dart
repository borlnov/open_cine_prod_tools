// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/models/ocpt_script_word_layout.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_wrapped_line_count.dart';

/// One item of a word sheet: the indices, in [OcptScriptWordLayout.blocks], of the blocks it
/// holds.
///
/// An ordinary block is an item whose `left` holds its own index and whose `right` is null. A
/// dual-dialogue pair set side by side is an item holding the blocks of its left column in `left`
/// and those of its right column in `right`.
typedef OcptScriptWordItem = ({List<int> left, List<int>? right});

/// Group the blocks of [layout] into the items a word sheet renders, in source order.
///
/// A pair of [OcptScriptWordLayout.dualPairs] makes one item set side by side when
/// [allowSideBySide] is true, the page has room for two columns
/// ([FountainLayoutMetrics.dualDialogue] is not null) and the taller column fits a page. In every
/// other case (a sheet too narrow for two columns, a page too small for them, a pair taller than a
/// page) both members stay ordinary dialogue, one block per item, stacked.
List<OcptScriptWordItem> ocptScriptWordItemsOf({
  required OcptScriptWordLayout layout,
  required FountainLayoutMetrics metrics,
  required bool allowSideBySide,
}) {
  final pairStarting = {
    if (allowSideBySide && metrics.dualDialogue != null)
      for (final pair in layout.dualPairs)
        if (_columnsFitAPage(layout, metrics, pair)) pair.left.start: pair,
  };

  final items = <OcptScriptWordItem>[];
  var index = 0;
  while (index < layout.blocks.length) {
    final pair = pairStarting[index];
    if (pair == null) {
      items.add((left: [index], right: null));
      index++;
    } else {
      items.add((
        left: [for (var i = pair.left.start; i < pair.left.end; i++) i],
        right: [for (var i = pair.right.start; i < pair.right.end; i++) i],
      ));
      index = pair.right.end;
    }
  }

  return items;
}

/// Tell whether the taller column of [pair] fits the lines of a page, each column wrapped at its
/// own width.
bool _columnsFitAPage(
  OcptScriptWordLayout layout,
  FountainLayoutMetrics metrics,
  FountainDualDialogueLinePair pair,
) => [pair.left, pair.right].every((range) {
  var lines = 0;
  for (var i = range.start; i < range.end; i++) {
    final block = layout.blocks[i];
    lines += ocptWrappedLineCount(
      block.text.trim(),
      metrics.elementOf(block.type, side: block.dualSide).maxWidthColumns,
    );
  }
  return lines <= metrics.linesPerPage;
});
