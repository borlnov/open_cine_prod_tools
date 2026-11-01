// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_change_node_metadata_request.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_fountain_line_attributions.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_replace_node_text_request.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_codec.dart';
import 'package:super_editor/super_editor.dart';
import 'ocpt_wysiwyg_codec_test_doubles.dart';

/// Reads the node at [index] of [document]'s `ocptHadForcingMarker` metadata (false if absent).
bool _hadForcingMarkerAt(Document document, int index) =>
    document.getNodeAt(index)!.getMetadataValue(ocptHadForcingMarkerMetadataKey) == true;

/// Reads the node at [index] of [document]'s `ocptTypeLocked` metadata (false if absent).
bool _typeLockedAt(Document document, int index) =>
    document.getNodeAt(index)!.getMetadataValue(ocptTypeLockedMetadataKey) == true;

/// Reads the node at [index] of [document]'s `ocptSceneNumber` metadata (null if absent).
String? _sceneNumberAt(Document document, int index) {
  final value = document.getNodeAt(index)!.getMetadataValue(ocptSceneNumberMetadataKey);
  return value is String ? value : null;
}

/// Merges [entries] into the metadata of the node at [index] of [document].
void _setMetadata(MutableDocument document, int index, Map<String, dynamic> entries) {
  final node = document.getNodeAt(index)! as ParagraphNode;
  document.replaceNodeById(node.id, node.copyWithAddedMetadata(entries));
}

/// Applies [attribution] to every character of the node at [index] of [document]'s text `[start,
/// end)`, so a note-attribution test can seed a stale span to be corrected.
void _addAttribution(
  MutableDocument document,
  int index,
  Attribution attribution,
  int start,
  int end,
) {
  final node = document.getNodeAt(index)! as ParagraphNode;
  final text = AttributedText(node.text.toPlainText(), node.text.spans.copy());
  text.addAttribution(attribution, SpanRange(start, end - 1));
  document.replaceNodeById(node.id, node.copyParagraphWith(text: text));
}

/// The expected `decode`/`encode` round trip for [fileName], given its [original] source: identity
/// for every corpus file except for one deliberate, documented normalization (see
/// `OcptWysiwygCodec.encode`'s doc comment): this model has no metadata slot for a section
/// heading's original `#`-run length, so every section always re-serializes at level 1, collapsing
/// `structure.fountain`'s two `## ` sub-sections to `# `.
String _expectedRoundTrip(String fileName, String original) =>
    fileName == "structure.fountain" ? original.replaceAll("\n## ", "\n# ") : original;

void main() {
  group("OcptWysiwygCodec.decode/encode corpus identity", () {
    final corpusDirectory = Directory("packages/fountain_kit/test/corpus");
    final corpusFiles =
        corpusDirectory
            .listSync()
            .whereType<File>()
            .where((file) => file.path.endsWith(".fountain"))
            .toList(growable: false)
          ..sort((a, b) => a.path.compareTo(b.path));

    test("the corpus directory is not empty", () {
      expect(corpusFiles, isNotEmpty);
    });

    for (final file in corpusFiles) {
      final fileName = file.uri.pathSegments.last;

      test("$fileName round-trips through decode then encode", () {
        final source = file.readAsStringSync();

        final decoded = OcptWysiwygCodec.decode(source);
        final encoded = OcptWysiwygCodec.encode(
          decoded.document,
          trailingBlankLines: decoded.trailingBlankLines,
        );

        expect(encoded.text, _expectedRoundTrip(fileName, source));
      });
    }
  });

  group("OcptWysiwygCodec.decode empty-document edge case", () {
    test("an empty source text decodes to a single node and round-trips to the same text", () {
      final decoded = OcptWysiwygCodec.decode("");

      expect(decoded.document.nodeCount, 1);
      expect((decoded.document.getNodeAt(0)! as ParagraphNode).text.toPlainText(), "");
      expect(decoded.trailingBlankLines, 0);

      final encoded = OcptWysiwygCodec.encode(
        decoded.document,
        trailingBlankLines: decoded.trailingBlankLines,
      );
      expect(encoded.text, "");
    });

    test("a source made only of blank lines folds all but one into the trailing count", () {
      final decoded = OcptWysiwygCodec.decode("\n\n");

      expect(decoded.document.nodeCount, 1);
      expect(decoded.trailingBlankLines, 2);

      final encoded = OcptWysiwygCodec.encode(
        decoded.document,
        trailingBlankLines: decoded.trailingBlankLines,
      );
      expect(encoded.text, "\n\n");
    });
  });

  group("OcptWysiwygCodec.decode blank-run and forcing-marker preservation", () {
    test("folds a blank run into the following node's ocptBlankLinesBefore metadata", () {
      final decoded = OcptWysiwygCodec.decode("INT. HOUSE - DAY\n\n\nSome action.");

      expect(decoded.document.nodeCount, 2);
      expect(blanksBeforeAt(decoded.document, 0), 0);
      expect(blanksBeforeAt(decoded.document, 1), 2);
    });

    test("keeps ocptBlankLinesBefore at 0 for lines with no blank run before them", () {
      final decoded = OcptWysiwygCodec.decode("SARAH\nHello.");

      expect(blanksBeforeAt(decoded.document, 0), 0);
      expect(blanksBeforeAt(decoded.document, 1), 0);
    });

    test("records a trailing blank run separately from any node", () {
      final decoded = OcptWysiwygCodec.decode("Some action.\n\n");

      expect(decoded.document.nodeCount, 1);
      expect(decoded.trailingBlankLines, 2);
    });

    test("preserves an explicit forcing marker that auto-detection would not have needed", () {
      // "Some action." on its own would already auto-detect as action, but the source forces it
      // with "!" anyway; the round trip must keep re-emitting that marker.
      final decoded = OcptWysiwygCodec.decode("!Some action.");

      expect(typeAt(decoded.document, 0), FountainLineType.action);
      expect(_hadForcingMarkerAt(decoded.document, 0), isTrue);

      final encoded = OcptWysiwygCodec.encode(
        decoded.document,
        trailingBlankLines: decoded.trailingBlankLines,
      );
      expect(encoded.text, "!Some action.");
    });

    test("does not force a marker for a line that auto-detects without one", () {
      final decoded = OcptWysiwygCodec.decode("Some action.");

      expect(_hadForcingMarkerAt(decoded.document, 0), isFalse);

      final encoded = OcptWysiwygCodec.encode(
        decoded.document,
        trailingBlankLines: decoded.trailingBlankLines,
      );
      expect(encoded.text, "Some action.");
    });
  });

  group("OcptWysiwygCodec.encode dialogue/parenthetical fallback", () {
    test(
      "a dialogue node not following a character serializes as plain text and degrades to action "
      "on reparse",
      () {
        final document = MutableDocument(
          nodes: [
            ParagraphNode(
              id: "n0",
              text: AttributedText("Just some words."),
              metadata: {
                "blockType": OcptFountainLineAttributions.attributionOf(FountainLineType.dialogue),
                ocptBlankLinesBeforeMetadataKey: 0,
                ocptTypeLockedMetadataKey: true,
                ocptHadForcingMarkerMetadataKey: false,
              },
            ),
          ],
        );

        final encoded = OcptWysiwygCodec.encode(document);
        expect(encoded.text, "Just some words.");

        final reparsed = OcptWysiwygCodec.decode(encoded.text);
        expect(typeAt(reparsed.document, 0), FountainLineType.action);
      },
    );

    test(
      "a dialogue node that does follow a character keeps classifying as dialogue on reparse",
      () {
        final document = MutableDocument(
          nodes: [
            ParagraphNode(
              id: "n0",
              text: AttributedText("SARAH"),
              metadata: {
                "blockType": OcptFountainLineAttributions.attributionOf(FountainLineType.character),
                ocptBlankLinesBeforeMetadataKey: 0,
                ocptTypeLockedMetadataKey: false,
                ocptHadForcingMarkerMetadataKey: false,
              },
            ),
            ParagraphNode(
              id: "n1",
              text: AttributedText("Hello there."),
              metadata: {
                "blockType": OcptFountainLineAttributions.attributionOf(FountainLineType.dialogue),
                ocptBlankLinesBeforeMetadataKey: 0,
                ocptTypeLockedMetadataKey: false,
                ocptHadForcingMarkerMetadataKey: false,
              },
            ),
          ],
        );

        final encoded = OcptWysiwygCodec.encode(document);
        final reparsed = OcptWysiwygCodec.decode(encoded.text);
        expect(typeAt(reparsed.document, 1), FountainLineType.dialogue);
      },
    );

    test(
      "a locked character node holding JOHN, last in the document, encodes with a forcing marker "
      "and decodes back to a character node",
      () {
        final document = MutableDocument(
          nodes: [
            ParagraphNode(
              id: "n0",
              text: AttributedText("JOHN"),
              metadata: {
                "blockType": OcptFountainLineAttributions.attributionOf(FountainLineType.character),
                ocptBlankLinesBeforeMetadataKey: 0,
                ocptTypeLockedMetadataKey: true,
                ocptHadForcingMarkerMetadataKey: false,
              },
            ),
          ],
        );

        final encoded = OcptWysiwygCodec.encode(document);
        expect(encoded.text, "@JOHN");

        final reparsed = OcptWysiwygCodec.decode(encoded.text);
        expect(typeAt(reparsed.document, 0), FountainLineType.character);
      },
    );
  });

  group("OcptWysiwygCodec.reclassifyRequests", () {
    test("requests a blockType change when typing turns an action line into a scene heading", () {
      final decoded = OcptWysiwygCodec.decode("\nSome action\n");
      expect(typeAt(decoded.document, 0), FountainLineType.action);

      replaceText(decoded.document, 0, "INT. HOUSE - DAY");
      final requests = OcptWysiwygCodec.reclassifyRequests(
        decoded.document,
      ).cast<ChangeParagraphBlockTypeRequest>();

      expect(requests, hasLength(1));
      expect(requests.single.nodeId, decoded.document.getNodeAt(0)!.id);
      expect(
        requests.single.blockType,
        OcptFountainLineAttributions.attributionOf(FountainLineType.sceneHeading),
      );
    });

    test("returns no request when no node's classified type actually changed", () {
      final decoded = OcptWysiwygCodec.decode("INT. HOUSE - DAY\n\nAction.");

      expect(OcptWysiwygCodec.reclassifyRequests(decoded.document), isEmpty);
    });

    test("a locked node is skipped even if its text would classify differently", () {
      final decoded = OcptWysiwygCodec.decode("Some action");
      _setMetadata(decoded.document, 0, {ocptTypeLockedMetadataKey: true});
      replaceText(decoded.document, 0, "INT. HOUSE - DAY");

      expect(OcptWysiwygCodec.reclassifyRequests(decoded.document), isEmpty);
    });

    test("an emptied node keeps its lock and its blockType untouched", () {
      final decoded = OcptWysiwygCodec.decode("Some action");
      _setMetadata(decoded.document, 0, {ocptTypeLockedMetadataKey: true});
      replaceText(decoded.document, 0, "");

      final requests = OcptWysiwygCodec.reclassifyRequests(decoded.document);

      expect(requests, isEmpty);
      expect(_typeLockedAt(decoded.document, 0), isTrue);
      expect(typeAt(decoded.document, 0), FountainLineType.action);
    });

    test("an emptied, unlocked node produces no request at all", () {
      final decoded = OcptWysiwygCodec.decode("Some action");
      replaceText(decoded.document, 0, "");

      expect(OcptWysiwygCodec.reclassifyRequests(decoded.document), isEmpty);
    });

    test("a locked character node whose text is emptied keeps its lock and its blockType", () {
      final decoded = OcptWysiwygCodec.decode("Some action");
      _setMetadata(decoded.document, 0, {
        "blockType": OcptFountainLineAttributions.attributionOf(FountainLineType.character),
        ocptTypeLockedMetadataKey: true,
      });
      replaceText(decoded.document, 0, "JOHN");
      replaceText(decoded.document, 0, "");

      final requests = OcptWysiwygCodec.reclassifyRequests(decoded.document);

      expect(requests, isEmpty);
      expect(_typeLockedAt(decoded.document, 0), isTrue);
      expect(typeAt(decoded.document, 0), FountainLineType.character);
    });

    test("inserting a blank line before and after re-classifies a candidate scene heading", () {
      final decoded = OcptWysiwygCodec.decode("Some text\nINT HOUSE DAY\nMore text");
      expect(typeAt(decoded.document, 1), FountainLineType.action);

      _setMetadata(decoded.document, 1, {ocptBlankLinesBeforeMetadataKey: 1});
      _setMetadata(decoded.document, 2, {ocptBlankLinesBeforeMetadataKey: 1});

      final requests = OcptWysiwygCodec.reclassifyRequests(
        decoded.document,
      ).cast<ChangeParagraphBlockTypeRequest>();

      expect(requests, hasLength(1));
      expect(requests.single.nodeId, decoded.document.getNodeAt(1)!.id);
      expect(
        requests.single.blockType,
        OcptFountainLineAttributions.attributionOf(FountainLineType.sceneHeading),
      );
    });
  });

  group("OcptWysiwygCodec.reclassifyRequests forcing-marker regression", () {
    // Every case here decodes a source line whose type only exists because of an explicit forcing
    // marker; the node's display text alone (with the marker already stripped by decode) would
    // classify as something else entirely (typically action). Before the fix, reclassifyRequests
    // fed the classifier that bare display text and demoted the node on the very first settle,
    // which encode then baked into the source as a permanent, sticky forcing marker on the next
    // decode. A freshly decoded document must be a fixed point of reclassifyRequests: no requests.

    test("a freshly decoded forced scene heading produces no reclassify request", () {
      final decoded = OcptWysiwygCodec.decode(".SALON - JOUR");
      expect(typeAt(decoded.document, 0), FountainLineType.sceneHeading);

      expect(OcptWysiwygCodec.reclassifyRequests(decoded.document), isEmpty);
    });

    test("a freshly decoded section heading produces no reclassify request", () {
      final decoded = OcptWysiwygCodec.decode("# Act One");
      expect(typeAt(decoded.document, 0), FountainLineType.section);

      expect(OcptWysiwygCodec.reclassifyRequests(decoded.document), isEmpty);
    });

    test("a freshly decoded synopsis line produces no reclassify request", () {
      final decoded = OcptWysiwygCodec.decode("= Something");
      expect(typeAt(decoded.document, 0), FountainLineType.synopsis);

      expect(OcptWysiwygCodec.reclassifyRequests(decoded.document), isEmpty);
    });

    test("a freshly decoded lyrics line produces no reclassify request", () {
      final decoded = OcptWysiwygCodec.decode("~A line");
      expect(typeAt(decoded.document, 0), FountainLineType.lyrics);

      expect(OcptWysiwygCodec.reclassifyRequests(decoded.document), isEmpty);
    });

    test("a freshly decoded centered text line produces no reclassify request", () {
      final decoded = OcptWysiwygCodec.decode("> CENTRED <");
      expect(typeAt(decoded.document, 0), FountainLineType.centeredText);

      expect(OcptWysiwygCodec.reclassifyRequests(decoded.document), isEmpty);
    });

    test(
      "a freshly decoded forced character cue and the dialogue line that follows it both produce "
      "no reclassify request (the cascade case)",
      () {
        final decoded = OcptWysiwygCodec.decode("@McCLANE\nHello.");
        expect(typeAt(decoded.document, 0), FountainLineType.character);
        expect(typeAt(decoded.document, 1), FountainLineType.dialogue);

        expect(OcptWysiwygCodec.reclassifyRequests(decoded.document), isEmpty);
      },
    );
  });

  group("OcptWysiwygCodec.reclassifyRequests corpus fixed point", () {
    final corpusDirectory = Directory("packages/fountain_kit/test/corpus");
    final corpusFiles =
        corpusDirectory
            .listSync()
            .whereType<File>()
            .where((file) => file.path.endsWith(".fountain"))
            .toList(growable: false)
          ..sort((a, b) => a.path.compareTo(b.path));

    test("the corpus directory is not empty", () {
      expect(corpusFiles, isNotEmpty);
    });

    for (final file in corpusFiles) {
      final fileName = file.uri.pathSegments.last;

      test("$fileName: a fresh decode is a fixed point of reclassifyRequests", () {
        final decoded = OcptWysiwygCodec.decode(file.readAsStringSync());

        expect(OcptWysiwygCodec.reclassifyRequests(decoded.document), isEmpty);
      });
    }
  });

  group("OcptWysiwygCodec.decode/encode scene numbers", () {
    test("strips a trailing #N# tag off a scene heading into metadata, hiding it from the display "
        "text", () {
      final decoded = OcptWysiwygCodec.decode("INT. HOUSE - DAY #4A#");

      expect(
        (decoded.document.getNodeAt(0)! as ParagraphNode).text.toPlainText(),
        "INT. HOUSE - DAY",
      );
      expect(_sceneNumberAt(decoded.document, 0), "4A");
    });

    test("a scene heading with no tag has no scene number metadata", () {
      final decoded = OcptWysiwygCodec.decode("INT. HOUSE - DAY");

      expect(_sceneNumberAt(decoded.document, 0), isNull);
    });

    test("re-appends the #N# tag on encode, byte-stable across a round trip", () {
      const source = "INT. HOUSE - DAY #4A#";
      final decoded = OcptWysiwygCodec.decode(source);

      final encoded = OcptWysiwygCodec.encode(
        decoded.document,
        trailingBlankLines: decoded.trailingBlankLines,
      );
      expect(encoded.text, source);
    });

    test("does not append a tag to an emptied heading, keeping the empty-node rule intact", () {
      final decoded = OcptWysiwygCodec.decode("INT. HOUSE - DAY #4A#");
      replaceText(decoded.document, 0, "");

      final encoded = OcptWysiwygCodec.encode(
        decoded.document,
        trailingBlankLines: decoded.trailingBlankLines,
      );
      expect(encoded.text, "");
    });
  });

  group("OcptWysiwygCodec.sceneNumberRequests", () {
    test("strips a tag typed live into a scene heading's text and stores it as metadata", () {
      final decoded = OcptWysiwygCodec.decode("INT. HOUSE - DAY");
      replaceText(decoded.document, 0, "INT. HOUSE - DAY #4A#");
      final nodeId = decoded.document.getNodeAt(0)!.id;

      final requests = OcptWysiwygCodec.sceneNumberRequests(decoded.document);
      expect(requests, hasLength(2));

      final textRequest = requests[0] as OcptReplaceNodeTextRequest;
      expect(textRequest.nodeId, nodeId);
      expect(textRequest.text.toPlainText(), "INT. HOUSE - DAY");

      final metadataRequest = requests[1] as OcptChangeNodeMetadataRequest;
      expect(metadataRequest.nodeId, nodeId);
      expect(metadataRequest.metadata[ocptSceneNumberMetadataKey], "4A");
    });

    test("returns no request for a heading with no tag typed into it", () {
      final decoded = OcptWysiwygCodec.decode("INT. HOUSE - DAY");

      expect(OcptWysiwygCodec.sceneNumberRequests(decoded.document), isEmpty);
    });

    test("ignores a tag typed into a non-scene-heading node", () {
      final decoded = OcptWysiwygCodec.decode("Some action");
      replaceText(decoded.document, 0, "Some action #4A#");

      expect(OcptWysiwygCodec.sceneNumberRequests(decoded.document), isEmpty);
    });
  });

  group("OcptWysiwygCodec.uppercaseRequests", () {
    test("uppercases a lowercase scene heading, preserving bold spans and length", () {
      final decoded = OcptWysiwygCodec.decode("int. kitchen - day");
      expect(typeAt(decoded.document, 0), FountainLineType.sceneHeading);
      _addAttribution(decoded.document, 0, boldAttribution, "int. ".length, "int. kitchen".length);

      final requests = OcptWysiwygCodec.uppercaseRequests(decoded.document);

      expect(requests, hasLength(1));
      final request = requests.single as OcptReplaceNodeTextRequest;
      expect(request.nodeId, decoded.document.getNodeAt(0)!.id);
      expect(request.text.toPlainText(), "INT. KITCHEN - DAY");
      expect(
        request.text.getAttributionSpansInRange(
          attributionFilter: (attribution) => attribution == boldAttribution,
          range: SpanRange(0, request.text.length - 1),
        ),
        hasLength(1),
      );
    });

    test("uppercases a lowercase character cue and a lowercase transition", () {
      // Both auto-detection rules require already-uppercase text (that's the whole reason this
      // feature exists), so the only way a node ends up classified character/transition with
      // lowercase text is a later edit made after classification already locked in (mirrored here
      // with `replaceText`, which — unlike typing through the live editor — never re-triggers
      // `reclassifyRequests`).
      final decoded = OcptWysiwygCodec.decode("SARAH\nHello.\n\nCUT TO:");
      expect(typeAt(decoded.document, 0), FountainLineType.character);
      expect(typeAt(decoded.document, 2), FountainLineType.transition);

      replaceText(decoded.document, 0, "sarah");
      replaceText(decoded.document, 2, "cut to:");

      final requests = OcptWysiwygCodec.uppercaseRequests(
        decoded.document,
      ).cast<OcptReplaceNodeTextRequest>();

      expect(requests, hasLength(2));
      expect(requests[0].text.toPlainText(), "SARAH");
      expect(requests[1].text.toPlainText(), "CUT TO:");
    });

    test("leaves action, dialogue and already-uppercase nodes untouched", () {
      final decoded = OcptWysiwygCodec.decode(
        "INT. HOUSE - DAY\n\nSome action.\n\nSARAH\nhello there.",
      );

      expect(OcptWysiwygCodec.uppercaseRequests(decoded.document), isEmpty);
    });

    test("the saved Fountain text round-trips with the uppercased line", () {
      final decoded = OcptWysiwygCodec.decode("int. kitchen - day");
      final requests = OcptWysiwygCodec.uppercaseRequests(
        decoded.document,
      ).cast<OcptReplaceNodeTextRequest>();
      final node = decoded.document.getNodeAt(0)! as ParagraphNode;
      decoded.document.replaceNodeById(node.id, node.copyParagraphWith(text: requests.single.text));

      final encoded = OcptWysiwygCodec.encode(
        decoded.document,
        trailingBlankLines: decoded.trailingBlankLines,
      );

      expect(encoded.text, "INT. KITCHEN - DAY");
    });
  });

  group("OcptWysiwygCodec.noteAttributionRequests", () {
    test("adds a fountainNote attribution bounding a [[...]] region", () {
      final document = MutableDocument(
        nodes: [ParagraphNode(id: "n0", text: AttributedText("Before [[a note]] after."))],
      );

      final requests = OcptWysiwygCodec.noteAttributionRequests(document);

      expect(requests, hasLength(1));
      final request = requests.single as AddTextAttributionsRequest;
      expect(request.attributions, {ocptFountainNoteAttribution});
      expect(
        (request.documentRange.start.nodePosition as TextNodePosition).offset,
        "Before ".length,
      );
      expect(
        (request.documentRange.end.nodePosition as TextNodePosition).offset,
        "Before [[a note]]".length,
      );
    });

    test("returns no request when the current spans already match", () {
      final document = MutableDocument(
        nodes: [ParagraphNode(id: "n0", text: AttributedText("Before [[a note]] after."))],
      );
      _addAttribution(
        document,
        0,
        ocptFountainNoteAttribution,
        "Before ".length,
        "Before [[a note]]".length,
      );

      expect(OcptWysiwygCodec.noteAttributionRequests(document), isEmpty);
    });

    test("re-bounds the span when a note's contents change", () {
      final document = MutableDocument(
        nodes: [ParagraphNode(id: "n0", text: AttributedText("Before [[a note]] after."))],
      );
      // Seed a stale span reflecting the note's old, shorter contents.
      _addAttribution(
        document,
        0,
        ocptFountainNoteAttribution,
        "Before ".length,
        "Before [[a]]".length,
      );

      final requests = OcptWysiwygCodec.noteAttributionRequests(document);

      expect(requests, hasLength(2));
      expect(requests.first, isA<RemoveTextAttributionsRequest>());
      final addRequest = requests[1] as AddTextAttributionsRequest;
      expect(
        (addRequest.documentRange.end.nodePosition as TextNodePosition).offset,
        "Before [[a note]]".length,
      );
    });

    test("produces no requests for a node with no note markup", () {
      final document = MutableDocument(
        nodes: [ParagraphNode(id: "n0", text: AttributedText("Just plain text."))],
      );

      expect(OcptWysiwygCodec.noteAttributionRequests(document), isEmpty);
    });
  });
}
