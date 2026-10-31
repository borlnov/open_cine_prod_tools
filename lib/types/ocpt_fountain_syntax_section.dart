// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/types/ocpt_fountain_syntax_topic.dart';

/// A group of related [OcptFountainSyntaxTopic]s in the syntax guide.
///
/// The guide lists its sections in the order this enum declares them.
enum OcptFountainSyntaxSection {
  /// The screenplay's structural building blocks: scene headings, action,
  /// dialogue and its variants, transitions and the other block types a
  /// writer assembles a scene from.
  structure,

  /// Elements that organize the document without appearing in the printed
  /// screenplay body as a scene element: sections, synopses, notes and the
  /// boneyard.
  organisation,

  /// Inline text formatting.
  formatting,

  /// The title page.
  titlePage,
}
