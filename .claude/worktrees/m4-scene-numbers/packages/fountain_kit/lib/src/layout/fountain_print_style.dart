// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:fountain_kit/src/layout/fountain_layout_metrics.dart';
import 'package:fountain_kit/src/parser/fountain_line_classifier.dart';

/// The base typographic treatment a printed screenplay element gets,
/// independent of any inline emphasis (`**bold**`, `*italic*`...) its own
/// text might additionally carry.
///
/// This is the single source of truth for how a printed screenplay element
/// is typeset — its base weight, slope and letter case — shared by the PDF
/// exporter, the raw mode's paper preview and the styled editor's
/// stylesheet, so the three renderers can never drift apart on the question
/// of, say, whether a scene heading prints bold. It deliberately sits
/// alongside [FountainLayoutMetrics], which already owns the other half of
/// the same job: the indent/width/page geometry a renderer needs, as
/// opposed to the weight/slope/case a renderer needs.
///
/// A run's own inline flags never *replace* this base treatment: a
/// `**bold**` word inside an italic [FountainLineType.lyrics] line resolves
/// to bold-italic, and an `*italic*` word inside a bold
/// [FountainLineType.sceneHeading] likewise. Composing the two is left to
/// each renderer (each already has its own idea of "combine a base flag and
/// a run flag" — a boolean OR for the PDF exporter's font-variant lookup, a
/// `TextStyle.copyWith` for the on-screen renderers), since this package
/// stays free of any rendering-toolkit dependency here.
class FountainPrintStyle extends Equatable {
  /// Creates a [FountainPrintStyle]. Prefer [FountainPrintStyle.of] unless a
  /// bespoke combination is genuinely required.
  const FountainPrintStyle({
    this.isBold = false,
    this.isItalic = false,
    this.isUppercase = false,
  });

  /// The print style shared by every [FountainLineType] with no base
  /// treatment of its own (action, dialogue, parenthetical, centered text,
  /// and the non-printing types): plain roman, sentence case.
  static const FountainPrintStyle plain = FountainPrintStyle();

  /// Whether the element's text prints in bold.
  final bool isBold;

  /// Whether the element's text prints in italic.
  final bool isItalic;

  /// Whether the element's text prints upper-cased, regardless of the
  /// casing it carries in the parsed model.
  final bool isUppercase;

  /// The base print style of a [FountainLineType.sceneHeading], a
  /// [FountainLineType.character] cue, a [FountainLineType.transition] or a
  /// [FountainLineType.lyrics] line; every other type prints as [plain].
  ///
  /// A `switch` over every [FountainLineType] value (rather than a
  /// catch-all `default`), so adding a new line type forces a deliberate
  /// decision here instead of silently inheriting [plain].
  factory FountainPrintStyle.of(FountainLineType type) => switch (type) {
    FountainLineType.sceneHeading => const FountainPrintStyle(
      isBold: true,
      isUppercase: true,
    ),
    FountainLineType.character => const FountainPrintStyle(isUppercase: true),
    FountainLineType.transition => const FountainPrintStyle(isUppercase: true),
    FountainLineType.lyrics => const FountainPrintStyle(isItalic: true),
    FountainLineType.blank ||
    FountainLineType.pageBreak ||
    FountainLineType.section ||
    FountainLineType.synopsis ||
    FountainLineType.centeredText ||
    FountainLineType.parenthetical ||
    FountainLineType.dialogue ||
    FountainLineType.action => plain,
  };

  @override
  List<Object?> get props => [isBold, isItalic, isUppercase];

  @override
  String toString() {
    final flags = [
      if (isBold) 'bold',
      if (isItalic) 'italic',
      if (isUppercase) 'uppercase',
    ];
    return 'FountainPrintStyle(${flags.isEmpty ? 'plain' : flags.join('+')})';
  }
}
