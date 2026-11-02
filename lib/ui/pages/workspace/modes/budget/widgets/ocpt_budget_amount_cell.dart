// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';

/// One right-aligned cell of an amount column of the budget mode's tables: a [Text] of [text] on a
/// single line, cut with an ellipsis when it does not fit, in a box [width] wide.
///
/// Used by every row of the cost tracking, the cash journal, the financing and the logistics
/// tables, header rows included, so their columns share one reading.
class OcptBudgetAmountCell extends StatelessWidget {
  /// The width of the column the cell belongs to.
  final double width;

  /// The text the cell prints.
  final String text;

  /// The style [text] is printed in.
  final TextStyle? style;

  /// Class constructor
  const OcptBudgetAmountCell({
    super.key,
    required this.width,
    required this.text,
    required this.style,
  });

  /// Build the budget amount cell as a [SizedBox].
  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Text(
      text,
      textAlign: TextAlign.right,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style,
    ),
  );
}
