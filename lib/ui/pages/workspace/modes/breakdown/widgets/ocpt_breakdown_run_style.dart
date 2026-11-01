// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:fountain_kit/fountain_kit.dart';

/// Applies a run's own inline emphasis on top of [base], mirroring `OcptShotCoverageDialog`'s own
/// `_styleOf`.
TextStyle ocptBreakdownRunStyleOf(FountainInlineStyle style, TextStyle base) => switch (style) {
  FountainInlineStyle.italic => base.copyWith(fontStyle: FontStyle.italic),
  FountainInlineStyle.bold => base.copyWith(fontWeight: FontWeight.bold),
  FountainInlineStyle.boldItalic => base.copyWith(
    fontWeight: FontWeight.bold,
    fontStyle: FontStyle.italic,
  ),
  FountainInlineStyle.underline => base.copyWith(decoration: TextDecoration.underline),
  // A note never reaches here: `ocptFountainWordDisplayRuns` drops its text entirely.
  FountainInlineStyle.plain || FountainInlineStyle.note => base,
};
