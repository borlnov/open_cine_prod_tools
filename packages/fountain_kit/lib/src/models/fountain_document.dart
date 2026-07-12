// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <benoit.rolandeau@allcircuits.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:fountain_kit/src/models/fountain_block.dart';
import 'package:fountain_kit/src/models/fountain_title_page.dart';

/// A fully parsed Fountain screenplay.
class FountainDocument extends Equatable {
  /// Creates a [FountainDocument].
  const FountainDocument({
    required this.titlePage,
    required this.blocks,
    required this.sourceText,
  });

  /// The document's title page, or `null` if the source had none.
  final FountainTitlePage? titlePage;

  /// The document's body, as an ordered list of top-level blocks.
  final List<FountainBlock> blocks;

  /// The exact source text this document was parsed from, with line
  /// endings normalized to `\n`. Every [FountainBlock.sourceRange] refers
  /// to offsets into this string.
  final String sourceText;

  /// The scene headings in this document, in source order.
  List<FountainSceneHeading> get scenes =>
      blocks.whereType<FountainSceneHeading>().toList(growable: false);

  @override
  List<Object?> get props => [titlePage, blocks, sourceText];

  @override
  String toString() =>
      'FountainDocument(${blocks.length} blocks, '
      'titlePage: ${titlePage != null})';
}
