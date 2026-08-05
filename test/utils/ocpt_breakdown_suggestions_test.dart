// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_scene.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_tag.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_scene_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_target_kind.dart';
import 'package:open_cine_prod_tools/utils/ocpt_breakdown_suggestions.dart';

/// Builds a scene at [position], its text the `[charStart, charEnd)` slice of whatever the test's
/// own whole screenplay text is, carrying [tags].
OcptBreakdownScene _scene({
  required String id,
  required int position,
  required int charStart,
  required int charEnd,
  List<OcptBreakdownTag> tags = const [],
}) => OcptBreakdownScene(
  id: id,
  position: position,
  heading: "INT. SCENE $position - DAY",
  sceneNumber: null,
  charStart: charStart,
  charEnd: charEnd,
  status: OcptBreakdownSceneStatus.toDo,
  notes: "",
  tags: tags,
);

/// Builds a live tag of [sceneId], pointing at [targetKind]/[targetId], the scene-relative
/// `[startOffset, endOffset)` passage [taggedText].
OcptBreakdownTag _tag({
  required String id,
  required String sceneId,
  required OcptBreakdownTargetKind targetKind,
  required String targetId,
  required int startOffset,
  required int endOffset,
  required String taggedText,
}) => OcptBreakdownTag(
  id: id,
  sceneId: sceneId,
  targetKind: targetKind,
  targetId: targetId,
  startOffset: startOffset,
  endOffset: endOffset,
  taggedText: taggedText,
  needsCheck: false,
);

void main() {
  group("ocptBreakdownSuggestionsOf — basic matching", () {
    test("suggests an untagged occurrence of a tag's own text in another scene", () {
      const sceneAText = "A desk lamp glows softly.\n";
      const sceneBText = "He switches the desk lamp on.\n";
      final screenplayText = sceneAText + sceneBText;

      final taggedStart = sceneAText.indexOf("desk lamp");
      final sceneA = _scene(
        id: "scene-a",
        position: 0,
        charStart: 0,
        charEnd: sceneAText.length,
        tags: [
          _tag(
            id: "tag-1",
            sceneId: "scene-a",
            targetKind: OcptBreakdownTargetKind.element,
            targetId: "element-1",
            startOffset: taggedStart,
            endOffset: taggedStart + "desk lamp".length,
            taggedText: "desk lamp",
          ),
        ],
      );
      final sceneB = _scene(
        id: "scene-b",
        position: 1,
        charStart: sceneAText.length,
        charEnd: screenplayText.length,
      );

      final suggestions = ocptBreakdownSuggestionsOf(
        scenes: [sceneA, sceneB],
        screenplayText: screenplayText,
      );

      final expectedStart = sceneBText.indexOf("desk lamp");
      expect(suggestions, hasLength(1));
      expect(suggestions.single.targetKind, OcptBreakdownTargetKind.element);
      expect(suggestions.single.targetId, "element-1");
      expect(suggestions.single.sceneId, "scene-b");
      expect(suggestions.single.startOffset, expectedStart);
      expect(suggestions.single.endOffset, expectedStart + "desk lamp".length);
      expect(suggestions.single.text, "desk lamp");
    });

    test("a tag's own passage is never suggested to itself", () {
      const sceneText = "A desk lamp glows softly.\n";
      final taggedStart = sceneText.indexOf("desk lamp");
      final scene = _scene(
        id: "scene-a",
        position: 0,
        charStart: 0,
        charEnd: sceneText.length,
        tags: [
          _tag(
            id: "tag-1",
            sceneId: "scene-a",
            targetKind: OcptBreakdownTargetKind.element,
            targetId: "element-1",
            startOffset: taggedStart,
            endOffset: taggedStart + "desk lamp".length,
            taggedText: "desk lamp",
          ),
        ],
      );

      final suggestions = ocptBreakdownSuggestionsOf(
        scenes: [scene],
        screenplayText: sceneText,
      );

      expect(suggestions, isEmpty);
    });

    test("nothing is suggested when the tagged text occurs nowhere else", () {
      const sceneAText = "A desk lamp glows softly.\n";
      const sceneBText = "Nothing else happens here.\n";
      final screenplayText = sceneAText + sceneBText;

      final taggedStart = sceneAText.indexOf("desk lamp");
      final sceneA = _scene(
        id: "scene-a",
        position: 0,
        charStart: 0,
        charEnd: sceneAText.length,
        tags: [
          _tag(
            id: "tag-1",
            sceneId: "scene-a",
            targetKind: OcptBreakdownTargetKind.element,
            targetId: "element-1",
            startOffset: taggedStart,
            endOffset: taggedStart + "desk lamp".length,
            taggedText: "desk lamp",
          ),
        ],
      );
      final sceneB = _scene(
        id: "scene-b",
        position: 1,
        charStart: sceneAText.length,
        charEnd: screenplayText.length,
      );

      final suggestions = ocptBreakdownSuggestionsOf(
        scenes: [sceneA, sceneB],
        screenplayText: screenplayText,
      );

      expect(suggestions, isEmpty);
    });

    test("an occurrence repeated within the tag's own scene is still suggested", () {
      const sceneText = "A chair. Another chair.\n";
      final taggedStart = sceneText.indexOf("chair");
      final scene = _scene(
        id: "scene-a",
        position: 0,
        charStart: 0,
        charEnd: sceneText.length,
        tags: [
          _tag(
            id: "tag-1",
            sceneId: "scene-a",
            targetKind: OcptBreakdownTargetKind.element,
            targetId: "element-1",
            startOffset: taggedStart,
            endOffset: taggedStart + "chair".length,
            taggedText: "chair",
          ),
        ],
      );

      final suggestions = ocptBreakdownSuggestionsOf(
        scenes: [scene],
        screenplayText: sceneText,
      );

      final expectedStart = sceneText.indexOf("chair", taggedStart + 1);
      expect(suggestions, hasLength(1));
      expect(suggestions.single.sceneId, "scene-a");
      expect(suggestions.single.startOffset, expectedStart);
      expect(suggestions.single.text, "chair");
    });
  });

  group("ocptBreakdownSuggestionsOf — a tag that overlaps a live tag is dropped", () {
    test("a match overlapping another live tag of the same scene is not suggested", () {
      const sceneAText = "A crown sits on the table.\n";
      const sceneBText = "The crown gleams under the light.\n";
      final screenplayText = sceneAText + sceneBText;

      final taggedStart = sceneAText.indexOf("crown");
      final sceneA = _scene(
        id: "scene-a",
        position: 0,
        charStart: 0,
        charEnd: sceneAText.length,
        tags: [
          _tag(
            id: "tag-1",
            sceneId: "scene-a",
            targetKind: OcptBreakdownTargetKind.element,
            targetId: "element-1",
            startOffset: taggedStart,
            endOffset: taggedStart + "crown".length,
            taggedText: "crown",
          ),
        ],
      );

      // scene-b's own "crown" is already tagged to a different target (a role, say): it must not
      // be offered as a suggestion for element-1 as well.
      final otherStart = sceneBText.indexOf("crown");
      final sceneB = _scene(
        id: "scene-b",
        position: 1,
        charStart: sceneAText.length,
        charEnd: screenplayText.length,
        tags: [
          _tag(
            id: "tag-2",
            sceneId: "scene-b",
            targetKind: OcptBreakdownTargetKind.role,
            targetId: "role-1",
            startOffset: otherStart,
            endOffset: otherStart + "crown".length,
            taggedText: "crown",
          ),
        ],
      );

      final suggestions = ocptBreakdownSuggestionsOf(
        scenes: [sceneA, sceneB],
        screenplayText: screenplayText,
      );

      expect(suggestions, isEmpty);
    });
  });

  group("ocptBreakdownSuggestionsOf — whole-word bounding", () {
    test("a shorter word does not match inside a longer one", () {
      const sceneAText = "Il cherche la clé partout.\n";
      const sceneBText = "Les clés du tiroir sont introuables.\n";
      const sceneCText = "Elle range la clé dans le tiroir.\n";
      final screenplayText = sceneAText + sceneBText + sceneCText;

      final taggedStart = sceneAText.indexOf("clé");
      final sceneA = _scene(
        id: "scene-a",
        position: 0,
        charStart: 0,
        charEnd: sceneAText.length,
        tags: [
          _tag(
            id: "tag-1",
            sceneId: "scene-a",
            targetKind: OcptBreakdownTargetKind.element,
            targetId: "element-1",
            startOffset: taggedStart,
            endOffset: taggedStart + "clé".length,
            taggedText: "clé",
          ),
        ],
      );
      final sceneB = _scene(
        id: "scene-b",
        position: 1,
        charStart: sceneAText.length,
        charEnd: sceneAText.length + sceneBText.length,
      );
      final sceneC = _scene(
        id: "scene-c",
        position: 2,
        charStart: sceneAText.length + sceneBText.length,
        charEnd: screenplayText.length,
      );

      final suggestions = ocptBreakdownSuggestionsOf(
        scenes: [sceneA, sceneB, sceneC],
        screenplayText: screenplayText,
      );

      // "clés" (scene-b) must not match; the stand-alone "clé" of scene-c must.
      expect(suggestions, hasLength(1));
      expect(suggestions.single.sceneId, "scene-c");
      expect(suggestions.single.text, "clé");
    });
  });

  group("ocptBreakdownSuggestionsOf — diacritic folding", () {
    test("an unaccented tag finds an accented occurrence, offsets addressing the real text", () {
      const sceneAText = "Sa soeur arrive demain.\n";
      const sceneBText = "Il retrouve sa sœur perdue.\n";
      final screenplayText = sceneAText + sceneBText;

      final taggedStart = sceneAText.indexOf("soeur");
      final sceneA = _scene(
        id: "scene-a",
        position: 0,
        charStart: 0,
        charEnd: sceneAText.length,
        tags: [
          _tag(
            id: "tag-1",
            sceneId: "scene-a",
            targetKind: OcptBreakdownTargetKind.role,
            targetId: "role-1",
            startOffset: taggedStart,
            endOffset: taggedStart + "soeur".length,
            taggedText: "soeur",
          ),
        ],
      );
      final sceneB = _scene(
        id: "scene-b",
        position: 1,
        charStart: sceneAText.length,
        charEnd: screenplayText.length,
      );

      final suggestions = ocptBreakdownSuggestionsOf(
        scenes: [sceneA, sceneB],
        screenplayText: screenplayText,
      );

      final expectedStart = sceneBText.indexOf("sœur");
      expect(suggestions, hasLength(1));
      expect(suggestions.single.sceneId, "scene-b");
      expect(suggestions.single.startOffset, expectedStart);
      expect(suggestions.single.endOffset, expectedStart + "sœur".length);
      expect(suggestions.single.text, "sœur");
    });

    test("an accented tag finds an unaccented occurrence, offsets addressing the real text", () {
      const sceneAText = "Sa sœur arrive demain.\n";
      const sceneBText = "Il retrouve sa soeur perdue.\n";
      final screenplayText = sceneAText + sceneBText;

      final taggedStart = sceneAText.indexOf("sœur");
      final sceneA = _scene(
        id: "scene-a",
        position: 0,
        charStart: 0,
        charEnd: sceneAText.length,
        tags: [
          _tag(
            id: "tag-1",
            sceneId: "scene-a",
            targetKind: OcptBreakdownTargetKind.role,
            targetId: "role-1",
            startOffset: taggedStart,
            endOffset: taggedStart + "sœur".length,
            taggedText: "sœur",
          ),
        ],
      );
      final sceneB = _scene(
        id: "scene-b",
        position: 1,
        charStart: sceneAText.length,
        charEnd: screenplayText.length,
      );

      final suggestions = ocptBreakdownSuggestionsOf(
        scenes: [sceneA, sceneB],
        screenplayText: screenplayText,
      );

      final expectedStart = sceneBText.indexOf("soeur");
      expect(suggestions, hasLength(1));
      expect(suggestions.single.sceneId, "scene-b");
      expect(suggestions.single.startOffset, expectedStart);
      expect(suggestions.single.endOffset, expectedStart + "soeur".length);
      expect(suggestions.single.text, "soeur");
    });
  });

  group("ocptBreakdownSuggestionsOf — deduplication", () {
    test("two tags of the same target sharing the same text yield one suggestion, not two", () {
      const sceneAText = "The crown gleams.\n";
      const sceneBText = "A crown, engraved.\n";
      const sceneCText = "The old crown rests in the vault.\n";
      final screenplayText = sceneAText + sceneBText + sceneCText;

      final startA = sceneAText.indexOf("crown");
      final sceneA = _scene(
        id: "scene-a",
        position: 0,
        charStart: 0,
        charEnd: sceneAText.length,
        tags: [
          _tag(
            id: "tag-1",
            sceneId: "scene-a",
            targetKind: OcptBreakdownTargetKind.element,
            targetId: "element-1",
            startOffset: startA,
            endOffset: startA + "crown".length,
            taggedText: "crown",
          ),
        ],
      );
      final startB = sceneBText.indexOf("crown");
      final sceneB = _scene(
        id: "scene-b",
        position: 1,
        charStart: sceneAText.length,
        charEnd: sceneAText.length + sceneBText.length,
        tags: [
          _tag(
            id: "tag-2",
            sceneId: "scene-b",
            targetKind: OcptBreakdownTargetKind.element,
            targetId: "element-1",
            startOffset: startB,
            endOffset: startB + "crown".length,
            taggedText: "crown",
          ),
        ],
      );
      final sceneC = _scene(
        id: "scene-c",
        position: 2,
        charStart: sceneAText.length + sceneBText.length,
        charEnd: screenplayText.length,
      );

      final suggestions = ocptBreakdownSuggestionsOf(
        scenes: [sceneA, sceneB, sceneC],
        screenplayText: screenplayText,
      );

      expect(suggestions, hasLength(1));
      expect(suggestions.single.sceneId, "scene-c");
    });
  });

  group("ocptBreakdownSuggestionsOf — ordering", () {
    test("results are ordered by scene position, then by offset within the scene", () {
      const sceneAText = "A chair sits alone.\n";
      const sceneBText = "A chair, then another chair.\n";
      const sceneCText = "One last chair here.\n";
      final screenplayText = sceneAText + sceneBText + sceneCText;

      final taggedStart = sceneAText.indexOf("chair");
      final sceneA = _scene(
        id: "scene-a",
        position: 0,
        charStart: 0,
        charEnd: sceneAText.length,
        tags: [
          _tag(
            id: "tag-1",
            sceneId: "scene-a",
            targetKind: OcptBreakdownTargetKind.element,
            targetId: "element-1",
            startOffset: taggedStart,
            endOffset: taggedStart + "chair".length,
            taggedText: "chair",
          ),
        ],
      );
      final sceneB = _scene(
        id: "scene-b",
        position: 1,
        charStart: sceneAText.length,
        charEnd: sceneAText.length + sceneBText.length,
      );
      final sceneC = _scene(
        id: "scene-c",
        position: 2,
        charStart: sceneAText.length + sceneBText.length,
        charEnd: screenplayText.length,
      );

      final suggestions = ocptBreakdownSuggestionsOf(
        // Given in source order, exactly as `OcptBreakdownState.scenes` always is.
        scenes: [sceneA, sceneB, sceneC],
        screenplayText: screenplayText,
      );

      expect(suggestions, hasLength(3));
      expect(suggestions.map((s) => s.sceneId), ["scene-b", "scene-b", "scene-c"]);
      expect(
        suggestions[0].startOffset,
        lessThan(suggestions[1].startOffset),
      );
    });
  });

  group("ocptBreakdownSuggestionsOf — tags with no letter or digit", () {
    test("a tag made only of punctuation is never searched for", () {
      const sceneAText = "Wait -- for it.\n";
      const sceneBText = "Look -- over there.\n";
      final screenplayText = sceneAText + sceneBText;

      final taggedStart = sceneAText.indexOf("--");
      final sceneA = _scene(
        id: "scene-a",
        position: 0,
        charStart: 0,
        charEnd: sceneAText.length,
        tags: [
          _tag(
            id: "tag-1",
            sceneId: "scene-a",
            targetKind: OcptBreakdownTargetKind.element,
            targetId: "element-1",
            startOffset: taggedStart,
            endOffset: taggedStart + "--".length,
            taggedText: "--",
          ),
        ],
      );
      final sceneB = _scene(
        id: "scene-b",
        position: 1,
        charStart: sceneAText.length,
        charEnd: screenplayText.length,
      );

      final suggestions = ocptBreakdownSuggestionsOf(
        scenes: [sceneA, sceneB],
        screenplayText: screenplayText,
      );

      expect(suggestions, isEmpty);
    });
  });

  group("ocptBreakdownSuggestionsOf — defensive bounds", () {
    test("a scene whose offsets no longer fit the text is clamped rather than crashing", () {
      const screenplayText = "A short scene.\n";
      final scene = _scene(
        id: "scene-a",
        position: 0,
        charStart: 0,
        // Well past the end of screenplayText — a stale read racing an edit.
        charEnd: screenplayText.length + 500,
      );

      expect(
        () => ocptBreakdownSuggestionsOf(scenes: [scene], screenplayText: screenplayText),
        returnsNormally,
      );
    });

    test("no scene at all yields no suggestion", () {
      expect(
        ocptBreakdownSuggestionsOf(scenes: const [], screenplayText: ""),
        isEmpty,
      );
    });
  });
}
