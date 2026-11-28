// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:material_ui/material_ui.dart';

/// Two dialogue groups of a dual-dialogue pair, set side by side on a word sheet.
///
/// Each column keeps the rendering of its own blocks, which sit at the indents of their column
/// (the page-wide indents of `FountainDualDialogueLayout`), so the two columns are laid over one
/// another rather than placed in a row: the pair is as tall as the taller column, and a click goes
/// to the word under the pointer in either column, since neither column has anything to hit
/// outside its own words. The blank line that follows the pair in the source is [bottomSpacing],
/// added once under both columns: the last block of each column carries no spacing of its own, as
/// the shorter column's would be lost under the taller one.
class OcptDualDialoguePair extends StatelessWidget {
  /// The blocks of the left column, in reading order.
  final List<Widget> left;

  /// The blocks of the right column, in reading order.
  final List<Widget> right;

  /// A widget set under both columns, or null: what concerns the pair as a whole, so that it
  /// leaves the rows of the two columns where they are.
  final Widget? footer;

  /// The space left under the pair, in logical pixels.
  final double bottomSpacing;

  /// Class constructor
  const OcptDualDialoguePair({
    super.key,
    required this.left,
    required this.right,
    this.footer,
    this.bottomSpacing = 0,
  });

  /// Build the dual dialogue pair as a [Stack], its footer and its bottom spacing.
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: bottomSpacing),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: left),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: right),
          ],
        ),
        ?footer,
      ],
    ),
  );
}
