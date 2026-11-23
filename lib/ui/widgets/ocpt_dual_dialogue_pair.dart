// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';

/// Two dialogue groups of a dual-dialogue pair, set side by side on a word sheet.
///
/// Each column keeps the rendering of its own blocks, which sit at the indents of their column
/// (the page-wide indents of `FountainDualDialogueLayout`), so the two columns are laid over one
/// another rather than placed in a row: the pair is as tall as the taller column, and a click goes
/// to the word under the pointer in either column, since neither column has anything to hit
/// outside its own words.
class OcptDualDialoguePair extends StatelessWidget {
  /// The blocks of the left column, in reading order.
  final List<Widget> left;

  /// The blocks of the right column, in reading order.
  final List<Widget> right;

  /// Class constructor
  const OcptDualDialoguePair({super.key, required this.left, required this.right});

  /// Build the dual dialogue pair as a [Stack].
  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: left),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: right),
    ],
  );
}
