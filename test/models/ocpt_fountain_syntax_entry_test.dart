// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/models/ocpt_fountain_syntax_entry.dart';
import 'package:open_cine_prod_tools/types/ocpt_fountain_syntax_topic.dart';

void main() {
  group('ocptFountainSyntaxEntries table completeness', () {
    test('has exactly one entry per OcptFountainSyntaxTopic, each non-empty', () {
      final topics = ocptFountainSyntaxEntries.map((entry) => entry.topic).toList();

      expect(topics.toSet(), OcptFountainSyntaxTopic.values.toSet());
      expect(topics.length, OcptFountainSyntaxTopic.values.length);
      for (final entry in ocptFountainSyntaxEntries) {
        expect(entry.snippetLines, isNotEmpty, reason: '${entry.topic} has an empty snippet');
      }
    });

    test('is ordered by section, matching the declared per-section topic order', () {
      const expectedOrder = [
        // structure
        OcptFountainSyntaxTopic.sceneHeading,
        OcptFountainSyntaxTopic.sceneNumber,
        OcptFountainSyntaxTopic.action,
        OcptFountainSyntaxTopic.character,
        OcptFountainSyntaxTopic.parenthetical,
        OcptFountainSyntaxTopic.dialogue,
        OcptFountainSyntaxTopic.dualDialogue,
        OcptFountainSyntaxTopic.transition,
        OcptFountainSyntaxTopic.centeredText,
        OcptFountainSyntaxTopic.lyrics,
        OcptFountainSyntaxTopic.pageBreak,
        // organisation
        OcptFountainSyntaxTopic.section,
        OcptFountainSyntaxTopic.synopsis,
        OcptFountainSyntaxTopic.note,
        OcptFountainSyntaxTopic.boneyard,
        // formatting
        OcptFountainSyntaxTopic.emphasis,
        // titlePage
        OcptFountainSyntaxTopic.titlePage,
      ];

      expect(ocptFountainSyntaxEntries.map((entry) => entry.topic).toList(), expectedOrder);

      const expectedSections = [
        OcptFountainSyntaxSection.structure,
        OcptFountainSyntaxSection.organisation,
        OcptFountainSyntaxSection.formatting,
        OcptFountainSyntaxSection.titlePage,
      ];
      final sectionRun = <OcptFountainSyntaxSection>[];
      for (final entry in ocptFountainSyntaxEntries) {
        if (sectionRun.isEmpty || sectionRun.last != entry.section) {
          sectionRun.add(entry.section);
        }
      }
      expect(sectionRun, expectedSections);
    });
  });

  group('snippet correctness against the real Fountain classifier', () {
    // FountainLineClassifier.classify is used directly (not the full FountainParser) because
    // several one/two-line snippets here would otherwise be swallowed by FountainParser's own
    // title page pre-pass (any `key:` line at the very start of the source, which several
    // snippets below happen to start with, e.g. "CUT TO:") before the line classifier ever sees
    // them. The classifier is the exact tool that assigns a FountainLineType to a body line, so
    // feeding it these entries' snippetLines directly is the correct way to verify the guide
    // matches fountain_kit's real behaviour, and it is what FountainParser itself calls
    // internally for the document body.
    const classifier = FountainLineClassifier();

    for (final entry in ocptFountainSyntaxEntries) {
      final lineType = entry.lineType;
      if (lineType == null) {
        continue;
      }

      test('${entry.topic} snippet classifies as $lineType', () {
        final classifiedTypes = classifier.classify(entry.snippetLines);

        expect(
          classifiedTypes,
          contains(lineType),
          reason:
              'Expected one line of ${entry.snippetLines} to classify as $lineType, '
              'got $classifiedTypes',
        );
      });
    }

    test('every entry with no FountainLineType is one of the documented exceptions', () {
      const topicsWithoutLineType = {
        OcptFountainSyntaxTopic.dualDialogue,
        OcptFountainSyntaxTopic.note,
        OcptFountainSyntaxTopic.boneyard,
        OcptFountainSyntaxTopic.emphasis,
        OcptFountainSyntaxTopic.titlePage,
      };

      for (final entry in ocptFountainSyntaxEntries) {
        if (entry.lineType == null) {
          expect(topicsWithoutLineType, contains(entry.topic));
        } else {
          expect(topicsWithoutLineType, isNot(contains(entry.topic)));
        }
      }
    });
  });

  group('snippets with no single line type, verified against the wider parser', () {
    test('dualDialogue snippet produces two dialogue groups, the second marked dual', () {
      const parser = FountainParser();
      final entry = ocptFountainSyntaxEntries.firstWhere(
        (entry) => entry.topic == OcptFountainSyntaxTopic.dualDialogue,
      );

      // A scene heading is prepended so the snippet cannot be mistaken for a title page by the
      // full parser's pre-pass (an all-caps "MARIE" line has no colon, so this is only a concern
      // for documentation purposes, not a real ambiguity; it keeps this test's intent obvious).
      final document = parser.parse(['INT. KITCHEN - DAY', '', ...entry.snippetLines].join('\n'));

      final dialogueGroups = document.blocks.whereType<FountainDialogueGroup>().toList();

      expect(dialogueGroups, hasLength(2));
      expect(dialogueGroups.first.character.isDualDialogue, isFalse);
      expect(dialogueGroups.last.character.isDualDialogue, isTrue);
    });

    test('note snippet is extracted as a standalone note block', () {
      const parser = FountainParser();
      final entry = ocptFountainSyntaxEntries.firstWhere(
        (entry) => entry.topic == OcptFountainSyntaxTopic.note,
      );

      final document = parser.parse(entry.snippetLines.join('\n'));

      final noteBlocks = document.blocks.whereType<FountainNoteBlock>().toList();
      expect(noteBlocks, hasLength(1));
    });

    test('boneyard snippet is extracted as a standalone boneyard block', () {
      const parser = FountainParser();
      final entry = ocptFountainSyntaxEntries.firstWhere(
        (entry) => entry.topic == OcptFountainSyntaxTopic.boneyard,
      );

      final document = parser.parse(entry.snippetLines.join('\n'));

      final boneyardBlocks = document.blocks.whereType<FountainBoneyard>().toList();
      expect(boneyardBlocks, hasLength(1));
    });

    test('emphasis snippet lines each carry the advertised inline style', () {
      const inlineParser = FountainInlineParser();
      final entry = ocptFountainSyntaxEntries.firstWhere(
        (entry) => entry.topic == OcptFountainSyntaxTopic.emphasis,
      );
      const expectedStyles = [
        FountainInlineStyle.italic,
        FountainInlineStyle.bold,
        FountainInlineStyle.underline,
      ];

      expect(entry.snippetLines, hasLength(expectedStyles.length));
      for (var index = 0; index < expectedStyles.length; index++) {
        final spans = inlineParser.parse(entry.snippetLines[index]);
        expect(spans, hasLength(1));
        expect(spans.single.style, expectedStyles[index]);
      }
    });

    test('titlePage snippet is parsed as the document title page', () {
      const parser = FountainParser();
      final entry = ocptFountainSyntaxEntries.firstWhere(
        (entry) => entry.topic == OcptFountainSyntaxTopic.titlePage,
      );

      final document = parser.parse(entry.snippetLines.join('\n'));

      expect(document.titlePage, isNotNull);
      expect(document.titlePage!.entries, hasLength(entry.snippetLines.length));
    });
  });
}
