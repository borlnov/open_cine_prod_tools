// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/types/ocpt_fountain_syntax_topic.dart';

/// One row of the Fountain syntax guide: a [topic], the [section] it belongs
/// to, the literal Fountain source lines that demonstrate it, and the
/// [FountainLineType] those lines classify as, when the topic maps to a
/// single line type.
///
/// [snippetLines] are syntax literals, one string per source line, and are
/// never translated: only their surrounding title/description (looked up
/// through the matching ARB keys) are localized. [lineType] is `null` for
/// topics with no single-line-type equivalent: [OcptFountainSyntaxTopic.dualDialogue]
/// (a pairing of two character/dialogue blocks, not a line type of its own),
/// [OcptFountainSyntaxTopic.note] and [OcptFountainSyntaxTopic.boneyard]
/// (stripped from the source before line classification even runs, per
/// `FountainParser`'s own passes), [OcptFountainSyntaxTopic.emphasis] (inline
/// formatting, not a line-level concern) and [OcptFountainSyntaxTopic.titlePage]
/// (parsed by a dedicated pre-pass, not the line classifier).
class OcptFountainSyntaxEntry extends Equatable {
  /// The topic this entry documents.
  final OcptFountainSyntaxTopic topic;

  /// The section [topic] is grouped under in the guide.
  final OcptFountainSyntaxSection section;

  /// The literal, untranslated Fountain source lines demonstrating [topic].
  final List<String> snippetLines;

  /// The [FountainLineType] [snippetLines] classifies as, or `null` when
  /// [topic] has no single-line-type equivalent.
  final FountainLineType? lineType;

  /// Class constructor
  const OcptFountainSyntaxEntry({
    required this.topic,
    required this.section,
    required this.snippetLines,
    this.lineType,
  });

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptFountainSyntaxEntry(topic: $topic, section: $section, "
      "snippetLines: $snippetLines, lineType: $lineType)";

  /// Object properties
  @override
  List<Object?> get props => [topic, section, snippetLines, lineType];
}

/// The Fountain syntax guide's content, one entry per [OcptFountainSyntaxTopic],
/// grouped and ordered by [OcptFountainSyntaxSection] in the order the guide
/// displays them.
///
/// Every snippet here is verified against `fountain_kit`'s real parsing code
/// by `test/models/ocpt_fountain_syntax_entry_test.dart`, so this table
/// cannot silently drift away from the parser's actual behaviour.
const List<OcptFountainSyntaxEntry> ocptFountainSyntaxEntries = [
  // Structure.
  OcptFountainSyntaxEntry(
    topic: OcptFountainSyntaxTopic.sceneHeading,
    section: OcptFountainSyntaxSection.structure,
    snippetLines: ["INT. KITCHEN - DAY"],
    lineType: FountainLineType.sceneHeading,
  ),
  OcptFountainSyntaxEntry(
    topic: OcptFountainSyntaxTopic.action,
    section: OcptFountainSyntaxSection.structure,
    snippetLines: ["She walks in, breathless."],
    lineType: FountainLineType.action,
  ),
  OcptFountainSyntaxEntry(
    topic: OcptFountainSyntaxTopic.character,
    section: OcptFountainSyntaxSection.structure,
    snippetLines: ["MARIE", "Where have you been?"],
    lineType: FountainLineType.character,
  ),
  OcptFountainSyntaxEntry(
    topic: OcptFountainSyntaxTopic.parenthetical,
    section: OcptFountainSyntaxSection.structure,
    snippetLines: ["MARIE", "(beat)"],
    lineType: FountainLineType.parenthetical,
  ),
  OcptFountainSyntaxEntry(
    topic: OcptFountainSyntaxTopic.dialogue,
    section: OcptFountainSyntaxSection.structure,
    snippetLines: ["MARIE", "You are late."],
    lineType: FountainLineType.dialogue,
  ),
  OcptFountainSyntaxEntry(
    topic: OcptFountainSyntaxTopic.dualDialogue,
    section: OcptFountainSyntaxSection.structure,
    snippetLines: ["MARIE", "You first.", "", "JOHN ^", "No, you."],
  ),
  OcptFountainSyntaxEntry(
    topic: OcptFountainSyntaxTopic.transition,
    section: OcptFountainSyntaxSection.structure,
    snippetLines: ["CUT TO:"],
    lineType: FountainLineType.transition,
  ),
  OcptFountainSyntaxEntry(
    topic: OcptFountainSyntaxTopic.centeredText,
    section: OcptFountainSyntaxSection.structure,
    snippetLines: ["> THE END <"],
    lineType: FountainLineType.centeredText,
  ),
  OcptFountainSyntaxEntry(
    topic: OcptFountainSyntaxTopic.lyrics,
    section: OcptFountainSyntaxSection.structure,
    snippetLines: ["~ singing in the rain"],
    lineType: FountainLineType.lyrics,
  ),
  OcptFountainSyntaxEntry(
    topic: OcptFountainSyntaxTopic.pageBreak,
    section: OcptFountainSyntaxSection.structure,
    snippetLines: ["==="],
    lineType: FountainLineType.pageBreak,
  ),

  // Organisation.
  OcptFountainSyntaxEntry(
    topic: OcptFountainSyntaxTopic.section,
    section: OcptFountainSyntaxSection.organisation,
    snippetLines: ["# Act One"],
    lineType: FountainLineType.section,
  ),
  OcptFountainSyntaxEntry(
    topic: OcptFountainSyntaxTopic.synopsis,
    section: OcptFountainSyntaxSection.organisation,
    snippetLines: ["= A quiet morning turns violent."],
    lineType: FountainLineType.synopsis,
  ),
  OcptFountainSyntaxEntry(
    topic: OcptFountainSyntaxTopic.note,
    section: OcptFountainSyntaxSection.organisation,
    snippetLines: ["[[a note for the reader]]"],
  ),
  OcptFountainSyntaxEntry(
    topic: OcptFountainSyntaxTopic.boneyard,
    section: OcptFountainSyntaxSection.organisation,
    snippetLines: ["/* cut for pacing */"],
  ),

  // Formatting.
  OcptFountainSyntaxEntry(
    topic: OcptFountainSyntaxTopic.emphasis,
    section: OcptFountainSyntaxSection.formatting,
    snippetLines: ["*italic*", "**bold**", "_underline_"],
  ),

  // Title page.
  OcptFountainSyntaxEntry(
    topic: OcptFountainSyntaxTopic.titlePage,
    section: OcptFountainSyntaxSection.titlePage,
    snippetLines: ["Title: Working Title", "Author: Jane Doe"],
  ),
];
