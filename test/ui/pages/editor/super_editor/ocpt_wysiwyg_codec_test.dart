// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_fountain_line_attributions.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_codec.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_edit_requests.dart';
import 'package:super_editor/super_editor.dart';

/// Reads the classified [FountainLineType] the node at [index] of [document] currently carries.
FountainLineType _typeAt(Document document, int index) =>
    OcptFountainLineAttributions.typeOfAttributionValue(document.getNodeAt(index)!.getMetadataValue("blockType"));

/// Reads the node at [index] of [document]'s `ocptBlankLinesBefore` metadata (0 if absent).
int _blanksBeforeAt(Document document, int index) {
  final value = document.getNodeAt(index)!.getMetadataValue(ocptBlankLinesBeforeMetadataKey);
  return value is int ? value : 0;
}

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

/// Replaces the text of the node at [index] of [document] with [newText], keeping its id and every
/// other metadata entry, the same way a real edit would change a node's text before the next
/// reclassification/note-attribution pass.
void _replaceText(MutableDocument document, int index, String newText) {
  final node = document.getNodeAt(index)! as ParagraphNode;
  document.replaceNodeById(node.id, node.copyParagraphWith(text: AttributedText(newText)));
}

/// Merges [entries] into the metadata of the node at [index] of [document].
void _setMetadata(MutableDocument document, int index, Map<String, dynamic> entries) {
  final node = document.getNodeAt(index)! as ParagraphNode;
  document.replaceNodeById(node.id, node.copyWithAddedMetadata(entries));
}

/// Applies [attribution] to every character of the node at [index] of [document]'s text `[start,
/// end)`, so a note-attribution test can seed a stale span to be corrected.
void _addAttribution(MutableDocument document, int index, Attribution attribution, int start, int end) {
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
        corpusDirectory.listSync().whereType<File>().where((file) => file.path.endsWith(".fountain")).toList(
          growable: false,
        )..sort((a, b) => a.path.compareTo(b.path));

    test("the corpus directory is not empty", () {
      expect(corpusFiles, isNotEmpty);
    });

    for (final file in corpusFiles) {
      final fileName = file.uri.pathSegments.last;

      test("$fileName round-trips through decode then encode", () {
        final source = file.readAsStringSync();

        final decoded = OcptWysiwygCodec.decode(source);
        final encoded = OcptWysiwygCodec.encode(decoded.document, trailingBlankLines: decoded.trailingBlankLines);

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

      final encoded = OcptWysiwygCodec.encode(decoded.document, trailingBlankLines: decoded.trailingBlankLines);
      expect(encoded.text, "");
    });

    test("a source made only of blank lines folds all but one into the trailing count", () {
      final decoded = OcptWysiwygCodec.decode("\n\n");

      expect(decoded.document.nodeCount, 1);
      expect(decoded.trailingBlankLines, 2);

      final encoded = OcptWysiwygCodec.encode(decoded.document, trailingBlankLines: decoded.trailingBlankLines);
      expect(encoded.text, "\n\n");
    });
  });

  group("OcptWysiwygCodec.decode blank-run and forcing-marker preservation", () {
    test("folds a blank run into the following node's ocptBlankLinesBefore metadata", () {
      final decoded = OcptWysiwygCodec.decode("INT. HOUSE - DAY\n\n\nSome action.");

      expect(decoded.document.nodeCount, 2);
      expect(_blanksBeforeAt(decoded.document, 0), 0);
      expect(_blanksBeforeAt(decoded.document, 1), 2);
    });

    test("keeps ocptBlankLinesBefore at 0 for lines with no blank run before them", () {
      final decoded = OcptWysiwygCodec.decode("SARAH\nHello.");

      expect(_blanksBeforeAt(decoded.document, 0), 0);
      expect(_blanksBeforeAt(decoded.document, 1), 0);
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

      expect(_typeAt(decoded.document, 0), FountainLineType.action);
      expect(_hadForcingMarkerAt(decoded.document, 0), isTrue);

      final encoded = OcptWysiwygCodec.encode(decoded.document, trailingBlankLines: decoded.trailingBlankLines);
      expect(encoded.text, "!Some action.");
    });

    test("does not force a marker for a line that auto-detects without one", () {
      final decoded = OcptWysiwygCodec.decode("Some action.");

      expect(_hadForcingMarkerAt(decoded.document, 0), isFalse);

      final encoded = OcptWysiwygCodec.encode(decoded.document, trailingBlankLines: decoded.trailingBlankLines);
      expect(encoded.text, "Some action.");
    });
  });

  group("OcptWysiwygCodec.encode dialogue/parenthetical fallback", () {
    test(
      "a dialogue node not following a character serializes as plain text and degrades to action on reparse",
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
        expect(_typeAt(reparsed.document, 0), FountainLineType.action);
      },
    );

    test("a dialogue node that does follow a character keeps classifying as dialogue on reparse", () {
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
      expect(_typeAt(reparsed.document, 1), FountainLineType.dialogue);
    });

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
        expect(_typeAt(reparsed.document, 0), FountainLineType.character);
      },
    );
  });

  group("OcptWysiwygCodec.reclassifyRequests", () {
    test("requests a blockType change when typing turns an action line into a scene heading", () {
      final decoded = OcptWysiwygCodec.decode("\nSome action\n");
      expect(_typeAt(decoded.document, 0), FountainLineType.action);

      _replaceText(decoded.document, 0, "INT. HOUSE - DAY");
      final requests = OcptWysiwygCodec.reclassifyRequests(decoded.document).cast<ChangeParagraphBlockTypeRequest>();

      expect(requests, hasLength(1));
      expect(requests.single.nodeId, decoded.document.getNodeAt(0)!.id);
      expect(requests.single.blockType, OcptFountainLineAttributions.attributionOf(FountainLineType.sceneHeading));
    });

    test("returns no request when no node's classified type actually changed", () {
      final decoded = OcptWysiwygCodec.decode("INT. HOUSE - DAY\n\nAction.");

      expect(OcptWysiwygCodec.reclassifyRequests(decoded.document), isEmpty);
    });

    test("a locked node is skipped even if its text would classify differently", () {
      final decoded = OcptWysiwygCodec.decode("Some action");
      _setMetadata(decoded.document, 0, {ocptTypeLockedMetadataKey: true});
      _replaceText(decoded.document, 0, "INT. HOUSE - DAY");

      expect(OcptWysiwygCodec.reclassifyRequests(decoded.document), isEmpty);
    });

    test("an emptied node keeps its lock and its blockType untouched", () {
      final decoded = OcptWysiwygCodec.decode("Some action");
      _setMetadata(decoded.document, 0, {ocptTypeLockedMetadataKey: true});
      _replaceText(decoded.document, 0, "");

      final requests = OcptWysiwygCodec.reclassifyRequests(decoded.document);

      expect(requests, isEmpty);
      expect(_typeLockedAt(decoded.document, 0), isTrue);
      expect(_typeAt(decoded.document, 0), FountainLineType.action);
    });

    test("an emptied, unlocked node produces no request at all", () {
      final decoded = OcptWysiwygCodec.decode("Some action");
      _replaceText(decoded.document, 0, "");

      expect(OcptWysiwygCodec.reclassifyRequests(decoded.document), isEmpty);
    });

    test("a locked character node whose text is emptied keeps its lock and its blockType", () {
      final decoded = OcptWysiwygCodec.decode("Some action");
      _setMetadata(decoded.document, 0, {
        "blockType": OcptFountainLineAttributions.attributionOf(FountainLineType.character),
        ocptTypeLockedMetadataKey: true,
      });
      _replaceText(decoded.document, 0, "JOHN");
      _replaceText(decoded.document, 0, "");

      final requests = OcptWysiwygCodec.reclassifyRequests(decoded.document);

      expect(requests, isEmpty);
      expect(_typeLockedAt(decoded.document, 0), isTrue);
      expect(_typeAt(decoded.document, 0), FountainLineType.character);
    });

    test("inserting a blank line before and after re-classifies a candidate scene heading", () {
      final decoded = OcptWysiwygCodec.decode("Some text\nINT HOUSE DAY\nMore text");
      expect(_typeAt(decoded.document, 1), FountainLineType.action);

      _setMetadata(decoded.document, 1, {ocptBlankLinesBeforeMetadataKey: 1});
      _setMetadata(decoded.document, 2, {ocptBlankLinesBeforeMetadataKey: 1});

      final requests = OcptWysiwygCodec.reclassifyRequests(decoded.document).cast<ChangeParagraphBlockTypeRequest>();

      expect(requests, hasLength(1));
      expect(requests.single.nodeId, decoded.document.getNodeAt(1)!.id);
      expect(requests.single.blockType, OcptFountainLineAttributions.attributionOf(FountainLineType.sceneHeading));
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
      expect(_typeAt(decoded.document, 0), FountainLineType.sceneHeading);

      expect(OcptWysiwygCodec.reclassifyRequests(decoded.document), isEmpty);
    });

    test("a freshly decoded section heading produces no reclassify request", () {
      final decoded = OcptWysiwygCodec.decode("# Act One");
      expect(_typeAt(decoded.document, 0), FountainLineType.section);

      expect(OcptWysiwygCodec.reclassifyRequests(decoded.document), isEmpty);
    });

    test("a freshly decoded synopsis line produces no reclassify request", () {
      final decoded = OcptWysiwygCodec.decode("= Something");
      expect(_typeAt(decoded.document, 0), FountainLineType.synopsis);

      expect(OcptWysiwygCodec.reclassifyRequests(decoded.document), isEmpty);
    });

    test("a freshly decoded lyrics line produces no reclassify request", () {
      final decoded = OcptWysiwygCodec.decode("~A line");
      expect(_typeAt(decoded.document, 0), FountainLineType.lyrics);

      expect(OcptWysiwygCodec.reclassifyRequests(decoded.document), isEmpty);
    });

    test("a freshly decoded centered text line produces no reclassify request", () {
      final decoded = OcptWysiwygCodec.decode("> CENTRED <");
      expect(_typeAt(decoded.document, 0), FountainLineType.centeredText);

      expect(OcptWysiwygCodec.reclassifyRequests(decoded.document), isEmpty);
    });

    test(
      "a freshly decoded forced character cue and the dialogue line that follows it both produce "
      "no reclassify request (the cascade case)",
      () {
        final decoded = OcptWysiwygCodec.decode("@McCLANE\nHello.");
        expect(_typeAt(decoded.document, 0), FountainLineType.character);
        expect(_typeAt(decoded.document, 1), FountainLineType.dialogue);

        expect(OcptWysiwygCodec.reclassifyRequests(decoded.document), isEmpty);
      },
    );
  });

  group("OcptWysiwygCodec.reclassifyRequests corpus fixed point", () {
    final corpusDirectory = Directory("packages/fountain_kit/test/corpus");
    final corpusFiles =
        corpusDirectory.listSync().whereType<File>().where((file) => file.path.endsWith(".fountain")).toList(
          growable: false,
        )..sort((a, b) => a.path.compareTo(b.path));

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
    test("strips a trailing #N# tag off a scene heading into metadata, hiding it from the display text", () {
      final decoded = OcptWysiwygCodec.decode("INT. HOUSE - DAY #4A#");

      expect((decoded.document.getNodeAt(0)! as ParagraphNode).text.toPlainText(), "INT. HOUSE - DAY");
      expect(_sceneNumberAt(decoded.document, 0), "4A");
    });

    test("a scene heading with no tag has no scene number metadata", () {
      final decoded = OcptWysiwygCodec.decode("INT. HOUSE - DAY");

      expect(_sceneNumberAt(decoded.document, 0), isNull);
    });

    test("re-appends the #N# tag on encode, byte-stable across a round trip", () {
      const source = "INT. HOUSE - DAY #4A#";
      final decoded = OcptWysiwygCodec.decode(source);

      final encoded = OcptWysiwygCodec.encode(decoded.document, trailingBlankLines: decoded.trailingBlankLines);
      expect(encoded.text, source);
    });

    test("does not append a tag to an emptied heading, keeping the empty-node rule intact", () {
      final decoded = OcptWysiwygCodec.decode("INT. HOUSE - DAY #4A#");
      _replaceText(decoded.document, 0, "");

      final encoded = OcptWysiwygCodec.encode(decoded.document, trailingBlankLines: decoded.trailingBlankLines);
      expect(encoded.text, "");
    });
  });

  group("OcptWysiwygCodec.sceneNumberRequests", () {
    test("strips a tag typed live into a scene heading's text and stores it as metadata", () {
      final decoded = OcptWysiwygCodec.decode("INT. HOUSE - DAY");
      _replaceText(decoded.document, 0, "INT. HOUSE - DAY #4A#");
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
      _replaceText(decoded.document, 0, "Some action #4A#");

      expect(OcptWysiwygCodec.sceneNumberRequests(decoded.document), isEmpty);
    });
  });

  group("OcptWysiwygCodec.uppercaseRequests", () {
    test("uppercases a lowercase scene heading, preserving bold spans and length", () {
      final decoded = OcptWysiwygCodec.decode("int. kitchen - day");
      expect(_typeAt(decoded.document, 0), FountainLineType.sceneHeading);
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
      // with `_replaceText`, which — unlike typing through the live editor — never re-triggers
      // `reclassifyRequests`).
      final decoded = OcptWysiwygCodec.decode("SARAH\nHello.\n\nCUT TO:");
      expect(_typeAt(decoded.document, 0), FountainLineType.character);
      expect(_typeAt(decoded.document, 2), FountainLineType.transition);

      _replaceText(decoded.document, 0, "sarah");
      _replaceText(decoded.document, 2, "cut to:");

      final requests = OcptWysiwygCodec.uppercaseRequests(decoded.document).cast<OcptReplaceNodeTextRequest>();

      expect(requests, hasLength(2));
      expect(requests[0].text.toPlainText(), "SARAH");
      expect(requests[1].text.toPlainText(), "CUT TO:");
    });

    test("leaves action, dialogue and already-uppercase nodes untouched", () {
      final decoded = OcptWysiwygCodec.decode("INT. HOUSE - DAY\n\nSome action.\n\nSARAH\nhello there.");

      expect(OcptWysiwygCodec.uppercaseRequests(decoded.document), isEmpty);
    });

    test("the saved Fountain text round-trips with the uppercased line", () {
      final decoded = OcptWysiwygCodec.decode("int. kitchen - day");
      final requests = OcptWysiwygCodec.uppercaseRequests(decoded.document).cast<OcptReplaceNodeTextRequest>();
      final node = decoded.document.getNodeAt(0)! as ParagraphNode;
      decoded.document.replaceNodeById(node.id, node.copyParagraphWith(text: requests.single.text));

      final encoded = OcptWysiwygCodec.encode(decoded.document, trailingBlankLines: decoded.trailingBlankLines);

      expect(encoded.text, "INT. KITCHEN - DAY");
    });
  });

  group("OcptWysiwygCodec.noteAttributionRequests", () {
    test("adds a fountainNote attribution bounding a [[...]] region", () {
      final document = MutableDocument(
        nodes: [
          ParagraphNode(id: "n0", text: AttributedText("Before [[a note]] after.")),
        ],
      );

      final requests = OcptWysiwygCodec.noteAttributionRequests(document);

      expect(requests, hasLength(1));
      final request = requests.single as AddTextAttributionsRequest;
      expect(request.attributions, {ocptFountainNoteAttribution});
      expect((request.documentRange.start.nodePosition as TextNodePosition).offset, "Before ".length);
      expect(
        (request.documentRange.end.nodePosition as TextNodePosition).offset,
        "Before [[a note]]".length,
      );
    });

    test("returns no request when the current spans already match", () {
      final document = MutableDocument(
        nodes: [
          ParagraphNode(id: "n0", text: AttributedText("Before [[a note]] after.")),
        ],
      );
      _addAttribution(document, 0, ocptFountainNoteAttribution, "Before ".length, "Before [[a note]]".length);

      expect(OcptWysiwygCodec.noteAttributionRequests(document), isEmpty);
    });

    test("re-bounds the span when a note's contents change", () {
      final document = MutableDocument(
        nodes: [
          ParagraphNode(id: "n0", text: AttributedText("Before [[a note]] after.")),
        ],
      );
      // Seed a stale span reflecting the note's old, shorter contents.
      _addAttribution(document, 0, ocptFountainNoteAttribution, "Before ".length, "Before [[a]]".length);

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
        nodes: [
          ParagraphNode(id: "n0", text: AttributedText("Just plain text.")),
        ],
      );

      expect(OcptWysiwygCodec.noteAttributionRequests(document), isEmpty);
    });
  });

  group("OcptWysiwygLineMapping", () {
    test("lineOfNodeIndex accounts for every preceding node's blank-lines-before count", () {
      final decoded = OcptWysiwygCodec.decode("INT. HOUSE - DAY\n\nSome action.\n\n\nSARAH\nHello.");

      expect(decoded.mapping.lineOfNodeIndex(0), 0);
      expect(decoded.mapping.lineOfNodeIndex(1), 2);
      expect(decoded.mapping.lineOfNodeIndex(2), 5);
      expect(decoded.mapping.lineOfNodeIndex(3), 6);
    });

    test("nodeIndexOfCharOffset resolves a real offset to the node owning that line", () {
      const source = "INT. HOUSE - DAY\n\nSome action.\n\n\nSARAH\nHello.";
      final decoded = OcptWysiwygCodec.decode(source);

      expect(decoded.mapping.nodeIndexOfCharOffset(0), 0);
      expect(decoded.mapping.nodeIndexOfCharOffset(source.indexOf("Some action.")), 1);
      expect(decoded.mapping.nodeIndexOfCharOffset(source.indexOf("SARAH")), 2);
      expect(decoded.mapping.nodeIndexOfCharOffset(source.indexOf("Hello.")), 3);
    });

    test("a blank line's offset snaps to the node that follows it", () {
      const source = "INT. HOUSE - DAY\n\nSome action.";
      final decoded = OcptWysiwygCodec.decode(source);

      // The offset right after the heading's own newline sits on the blank line between the
      // heading and the action line.
      final blankLineOffset = "INT. HOUSE - DAY\n".length;
      expect(decoded.mapping.nodeIndexOfCharOffset(blankLineOffset), 1);
    });

    test("clamps an out-of-range offset to the last line's node", () {
      const source = "line0\nline1";
      final decoded = OcptWysiwygCodec.decode(source);

      expect(decoded.mapping.nodeIndexOfCharOffset(source.length + 10), 1);
      expect(decoded.mapping.nodeIndexOfCharOffset(-5), 0);
    });

    test("a trailing blank run's offset snaps to the last node", () {
      const source = "Some action.\n\n\n";
      final decoded = OcptWysiwygCodec.decode(source);

      expect(decoded.mapping.nodeIndexOfCharOffset(source.length), 0);
    });

    test("encode produces a fresh mapping consistent with its own output text", () {
      final decoded = OcptWysiwygCodec.decode("INT. HOUSE - DAY\n\nSARAH\nHello.");
      final encoded = OcptWysiwygCodec.encode(decoded.document, trailingBlankLines: decoded.trailingBlankLines);

      expect(encoded.mapping.lineOfNodeIndex(0), 0);
      expect(encoded.mapping.lineOfNodeIndex(1), 2);
      expect(encoded.mapping.lineOfNodeIndex(2), 3);
      expect(encoded.mapping.nodeIndexOfCharOffset(encoded.text.indexOf("SARAH")), 1);
    });
  });

  group("OcptWysiwygCodec.encodeSelectionToFountain / decodeNodesFromFountain", () {
    /// Builds an expanded [DocumentSelection] spanning the full node at [fromIndex] to the full
    /// node at [toIndex] of [document] (inclusive), in whichever order [base]/[extent] are asked
    /// for, so a reversed selection can be exercised too.
    DocumentSelection selectFullNodes(Document document, {required int fromIndex, required int toIndex}) {
      final fromNode = document.getNodeAt(fromIndex)! as ParagraphNode;
      final toNode = document.getNodeAt(toIndex)! as ParagraphNode;
      return DocumentSelection(
        base: DocumentPosition(nodeId: fromNode.id, nodePosition: const TextNodePosition(offset: 0)),
        extent: DocumentPosition(
          nodeId: toNode.id,
          nodePosition: TextNodePosition(offset: toNode.text.toPlainText().length),
        ),
      );
    }

    test(
      "a selection spanning a scene heading, an action line, a character cue and dialogue "
      "round-trips with types and blank lines intact, but never starts with a leading blank line",
      () {
        // The action line originally sits 2 blank lines below the heading; the copied fragment
        // must start directly with it instead (see encodeSelectionToFountain's doc comment).
        const source = "INT. HOUSE - DAY\n\n\nSome action.\n\nSARAH\nHello there.";
        final decoded = OcptWysiwygCodec.decode(source);
        final document = decoded.document;
        expect(_blanksBeforeAt(document, 1), 2);

        final selection = selectFullNodes(document, fromIndex: 1, toIndex: 3);
        final fragmentText = OcptWysiwygCodec.encodeSelectionToFountain(document, selection);

        expect(fragmentText, "Some action.\n\nSARAH\nHello there.");

        final fragmentNodes = OcptWysiwygCodec.decodeNodesFromFountain(fragmentText);
        expect(fragmentNodes, hasLength(3));
        expect(
          OcptFountainLineAttributions.typeOfAttributionValue(fragmentNodes[0].getMetadataValue("blockType")),
          FountainLineType.action,
        );
        expect(
          OcptFountainLineAttributions.typeOfAttributionValue(fragmentNodes[1].getMetadataValue("blockType")),
          FountainLineType.character,
        );
        expect(
          OcptFountainLineAttributions.typeOfAttributionValue(fragmentNodes[2].getMetadataValue("blockType")),
          FountainLineType.dialogue,
        );
        expect(fragmentNodes[0].getMetadataValue(ocptBlankLinesBeforeMetadataKey), 0);
        expect(fragmentNodes[1].getMetadataValue(ocptBlankLinesBeforeMetadataKey), 1);
        expect(fragmentNodes[2].getMetadataValue(ocptBlankLinesBeforeMetadataKey), 0);
      },
    );

    test("a reversed selection (base after extent in document order) encodes the same fragment", () {
      const source = "SARAH\nHello there.\n\nJOHN\nHi.";
      final decoded = OcptWysiwygCodec.decode(source);
      final document = decoded.document;

      final forwardSelection = selectFullNodes(document, fromIndex: 0, toIndex: 3);
      final reversedSelection = DocumentSelection(base: forwardSelection.extent, extent: forwardSelection.base);

      expect(
        OcptWysiwygCodec.encodeSelectionToFountain(document, reversedSelection),
        OcptWysiwygCodec.encodeSelectionToFountain(document, forwardSelection),
      );
    });

    test("a partial single-node selection yields just its selected text", () {
      final decoded = OcptWysiwygCodec.decode("Some action text here.");
      final node = decoded.document.getNodeAt(0)! as ParagraphNode;

      final selection = DocumentSelection(
        base: DocumentPosition(nodeId: node.id, nodePosition: const TextNodePosition(offset: 5)),
        extent: DocumentPosition(nodeId: node.id, nodePosition: const TextNodePosition(offset: 11)),
      );

      expect(OcptWysiwygCodec.encodeSelectionToFountain(decoded.document, selection), "action");
    });

    test("decodeNodesFromFountain returns an empty list for all-blank text", () {
      expect(OcptWysiwygCodec.decodeNodesFromFountain(""), isEmpty);
      expect(OcptWysiwygCodec.decodeNodesFromFountain("\n\n"), isEmpty);
    });

    test("decodeNodesFromFountain preserves an explicit forcing marker", () {
      final fragmentNodes = OcptWysiwygCodec.decodeNodesFromFountain("!Some action.");

      expect(fragmentNodes, hasLength(1));
      expect(fragmentNodes.single.getMetadataValue(ocptHadForcingMarkerMetadataKey), isTrue);
      expect(fragmentNodes.single.text.toPlainText(), "Some action.");
    });
  });

  group("decodeWithTitlePage / encodeWithTitlePage", () {
    /// The [ocptTitlePageKeyMetadataKey] of the node at [index] of [document], or null if it isn't
    /// a title-page field node.
    String? titlePageKeyAt(Document document, int index) {
      final value = document.getNodeAt(index)!.getMetadataValue(ocptTitlePageKeyMetadataKey);
      return value is String ? value : null;
    }

    test("a screenplay with no title page still synthesizes all six fields, empty, in canonical order", () {
      final decoded = OcptWysiwygCodec.decodeWithTitlePage("INT. HOUSE - DAY\n\nSome action.");

      expect(decoded.titlePageNodeCount, 6);
      expect(decoded.document.nodeCount, 8);
      expect(
        [for (var index = 0; index < 6; index++) titlePageKeyAt(decoded.document, index)],
        ocptTitlePageFieldKeys,
      );
      for (var index = 0; index < 6; index++) {
        expect(decoded.document.getNodeAt(index)!.getMetadataValue("blockType"), ocptTitlePageFieldAttribution);
        expect((decoded.document.getNodeAt(index)! as ParagraphNode).text.toPlainText(), isEmpty);
        expect(OcptWysiwygCodec.isTitlePageNode(decoded.document.getNodeAt(index)! as ParagraphNode), isTrue);
      }

      // The body starts right where a plain `decode` of the same (title-page-free) text would
      // put it, just shifted by the six title-page nodes.
      expect(_typeAt(decoded.document, 6), FountainLineType.sceneHeading);
      expect((decoded.document.getNodeAt(6)! as ParagraphNode).text.toPlainText(), "INT. HOUSE - DAY");
      expect(_typeAt(decoded.document, 7), FountainLineType.action);
      expect(OcptWysiwygCodec.isTitlePageNode(decoded.document.getNodeAt(7)! as ParagraphNode), isFalse);
    });

    test("an existing title page decodes its present fields, absent ones stay empty", () {
      const source = "Title: My Movie\nCredit: written by\n\nINT. HOUSE - DAY";
      final decoded = OcptWysiwygCodec.decodeWithTitlePage(source);

      expect((decoded.document.getNodeAt(0)! as ParagraphNode).text.toPlainText(), "My Movie");
      expect((decoded.document.getNodeAt(1)! as ParagraphNode).text.toPlainText(), "written by");
      // Author, Draft date, Contact, Source: absent from the source, still synthesized empty.
      for (var index = 2; index < 6; index++) {
        expect((decoded.document.getNodeAt(index)! as ParagraphNode).text.toPlainText(), isEmpty);
      }
      expect(decoded.titlePagePrefixLength, source.length - "INT. HOUSE - DAY".length);
      expect(_typeAt(decoded.document, 6), FountainLineType.sceneHeading);
    });

    test("Authors: written as continuation lines decodes into one node per line", () {
      const source = "Authors:\n    Jane Doe\n    John Smith\n\nSome action.";
      final decoded = OcptWysiwygCodec.decodeWithTitlePage(source);

      // Title, Credit: empty (indices 0-1). Author spans indices 2-3 (two continuation lines).
      expect(titlePageKeyAt(decoded.document, 2), "Author");
      expect(titlePageKeyAt(decoded.document, 3), "Author");
      expect((decoded.document.getNodeAt(2)! as ParagraphNode).text.toPlainText(), "Jane Doe");
      expect((decoded.document.getNodeAt(3)! as ParagraphNode).text.toPlainText(), "John Smith");
      // Draft date, Contact, Source (indices 4-6) follow, then the body.
      expect(titlePageKeyAt(decoded.document, 6), "Source");
      expect(_typeAt(decoded.document, 7), FountainLineType.action);
    });

    test("round trip: an untouched decode/encode of a title-page-free screenplay changes nothing", () {
      const source = "INT. HOUSE - DAY\n\nSome action.\n\nJOHN\nHello.";
      final decoded = OcptWysiwygCodec.decodeWithTitlePage(source);

      final encoded = OcptWysiwygCodec.encodeWithTitlePage(
        decoded.document,
        trailingBlankLines: decoded.trailingBlankLines,
      );

      expect(encoded.text, source);
      // The document still carries six (all-empty) title-page nodes; only the *rendered* text
      // omits them, since every field is empty.
      expect(encoded.titlePageNodeCount, 6);
    });

    test("filling only the Title field of an untitled screenplay writes just a Title: line", () {
      const source = "INT. HOUSE - DAY\n\nSome action.";
      final decoded = OcptWysiwygCodec.decodeWithTitlePage(source);
      _replaceText(decoded.document, 0, "My Movie");

      final encoded = OcptWysiwygCodec.encodeWithTitlePage(
        decoded.document,
        trailingBlankLines: decoded.trailingBlankLines,
      );

      expect(encoded.text, "Title: My Movie\n\n$source");
    });

    test("Author continuation lines round-trip byte-for-byte", () {
      const source = "Author:\n    Jane Doe\n    John Smith\n\nSome action.";
      final decoded = OcptWysiwygCodec.decodeWithTitlePage(source);

      final encoded = OcptWysiwygCodec.encodeWithTitlePage(
        decoded.document,
        trailingBlankLines: decoded.trailingBlankLines,
      );

      expect(encoded.text, source);
    });

    test("emptying every field drops the title page entirely, back to a plain body", () {
      const source = "Title: My Movie\n\nSome action.";
      final decoded = OcptWysiwygCodec.decodeWithTitlePage(source);
      _replaceText(decoded.document, 0, "");

      final encoded = OcptWysiwygCodec.encodeWithTitlePage(
        decoded.document,
        trailingBlankLines: decoded.trailingBlankLines,
      );

      expect(encoded.text, "Some action.");
    });

    test("Author also matches a source written with the singular Author key on encode", () {
      // `_titlePageEntriesFromNodes` always writes the canonical singular key, regardless of
      // which of `Author`/`Authors` the source used (mirrors `editor_bloc.dart`'s dialog flow).
      final decoded = OcptWysiwygCodec.decodeWithTitlePage("Authors: Jane Doe\n\nSome action.");
      final encoded = OcptWysiwygCodec.encodeWithTitlePage(
        decoded.document,
        trailingBlankLines: decoded.trailingBlankLines,
      );

      expect(encoded.text, "Author: Jane Doe\n\nSome action.");
    });

    test("a locked/uppercased title-page field is never reclassified or uppercased by the body passes", () {
      final decoded = OcptWysiwygCodec.decodeWithTitlePage("INT. HOUSE - DAY\n\nSome action.");
      _replaceText(decoded.document, 0, "lowercase title");

      expect(OcptWysiwygCodec.reclassifyRequests(decoded.document), isEmpty);
      expect(OcptWysiwygCodec.uppercaseRequests(decoded.document), isEmpty);
      expect(OcptWysiwygCodec.sceneNumberRequests(decoded.document), isEmpty);
    });

    test("every synthesized title-page node starts marked non-deletable", () {
      final decoded = OcptWysiwygCodec.decodeWithTitlePage("INT. HOUSE - DAY");
      for (var index = 0; index < 6; index++) {
        expect(decoded.document.getNodeAt(index)!.isDeletable, isFalse, reason: "node $index");
      }
    });

    test("a metadata merge (OcptChangeNodeMetadataRequest) keeps a title-page node non-deletable", () {
      final decoded = OcptWysiwygCodec.decodeWithTitlePage("INT. HOUSE - DAY");
      final document = decoded.document;
      final creditNode = document.getNodeAt(1)!;
      final editor = Editor(
        editables: {Editor.documentKey: document, Editor.composerKey: MutableDocumentComposer()},
        requestHandlers: List<EditRequestHandler>.from(defaultRequestHandlers)
          ..add(ocptChangeNodeMetadataRequestHandler),
      );

      editor.execute([
        OcptChangeNodeMetadataRequest(nodeId: creditNode.id, metadata: {ocptTypeLockedMetadataKey: true}),
      ]);

      expect(document.getNodeById(creditNode.id)!.isDeletable, isFalse);
    });

    test("encodeWithTitlePage ignores the isDeletable flag", () {
      const source = "Title: My Movie\n\nSome action.";
      final decoded = OcptWysiwygCodec.decodeWithTitlePage(source);

      final encoded = OcptWysiwygCodec.encodeWithTitlePage(
        decoded.document,
        trailingBlankLines: decoded.trailingBlankLines,
      );

      expect(encoded.text, source);
    });
  });
}
