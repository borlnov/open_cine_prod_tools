// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/types/ocpt_sides_presentation.dart';

/// One printed page of a sides booklet.
///
/// [lines] is already the exact row order a renderer draws: build a `FountainScriptPage` straight
/// from it and every line lands where this layout put it, whichever presentation produced it.
class OcptScriptSidesPage extends Equatable {
  /// The 0-based index, into the composed script's own `FountainScriptLayout.pages`, of the
  /// screenplay page this one reproduces — null for a [OcptSidesPresentation.packed] page, which
  /// reproduces no single one.
  final int? scriptPageIndex;

  /// The lines drawn on this page, its first row first.
  final List<FountainScriptLine> lines;

  /// Class constructor
  const OcptScriptSidesPage({required this.scriptPageIndex, required this.lines});

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptScriptSidesPage(scriptPageIndex: $scriptPageIndex, lines: ${lines.length})";

  /// Object properties
  @override
  List<Object?> get props => [scriptPageIndex, lines];
}
