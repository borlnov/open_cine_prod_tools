// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_script_import_service.dart';
import 'package:open_cine_prod_tools/types/ocpt_screenplay_import_status.dart';

/// A minimal, well-formed Final Draft document holding one scene and one line of action.
const _finalDraftDocument = '''
<?xml version="1.0" encoding="UTF-8" standalone="no" ?>
<FinalDraft DocumentType="Script" Template="No" Version="1">
<Content>
<Paragraph Type="Scene Heading"><Text>INT. OFFICE - DAY</Text></Paragraph>
<Paragraph Type="Action"><Text>She waits.</Text></Paragraph>
</Content>
</FinalDraft>
''';

/// A minimal, well-formed legacy Celtx project holding one scene and one line of action.
final _celtxProject = _zip({
  "project.rdf": '''
<?xml version="1.0"?>
<RDF:RDF xmlns:RDF="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
         xmlns:cx="http://celtx.com/NS/v1/"
         xmlns:dc="http://purl.org/dc/elements/1.1/">
  <cx:Project RDF:about="urn:x-celtx:project"/>
  <cx:Document RDF:about="urn:x-celtx:doc-1" cx:type="ScriptDocument"
               cx:localFile="script-1.html"/>
</RDF:RDF>
''',
  "script-1.html":
      '<html><body><p class="sceneheading">INT. OFFICE - DAY</p>'
      ' <p class="action">She waits.</p></body></html>',
});

/// Packs [entries] into a zip container.
Uint8List _zip(Map<String, String> entries) {
  final archive = Archive();
  for (final entry in entries.entries) {
    archive.add(ArchiveFile.string(entry.key, entry.value));
  }

  return ZipEncoder().encodeBytes(archive);
}

/// The bytes of [text], as a picked file's would be read.
Uint8List _bytesOf(String text) => Uint8List.fromList(utf8.encode(text));

void main() {
  const service = OcptScriptImportService();

  group('importableExtensions', () {
    test('lists the three formats the two import gestures accept, Fountain first', () {
      expect(OcptScriptImportService.importableExtensions, ["fountain", "fdx", "celtx"]);
    });
  });

  group('readScreenplay', () {
    test("returns a .fountain file's own text, converted by nobody", () {
      const text = "Title: My Movie\n\nINT. OFFICE - DAY\n\nShe waits.\n";

      final result = service.readScreenplay(bytes: _bytesOf(text), fileName: "draft.fountain");

      expect(result.status, OcptScreenplayImportStatus.ok);
      expect(result.value, text);
    });

    test('normalises a .fountain file the way the Fountain I/O service does', () {
      final result = service.readScreenplay(
        bytes: Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode("INT. OFFICE - DAY\r\n")]),
        fileName: "draft.fountain",
      );

      expect(result.status, OcptScreenplayImportStatus.ok);
      expect(result.value, "INT. OFFICE - DAY\n");
    });

    test('converts an .fdx file to Fountain', () {
      final result = service.readScreenplay(
        bytes: _bytesOf(_finalDraftDocument),
        fileName: "draft.fdx",
      );

      expect(result.status, OcptScreenplayImportStatus.ok);
      expect(result.value, contains("INT. OFFICE - DAY"));
      expect(result.value, contains("She waits."));
    });

    test('converts a .celtx file to Fountain', () {
      final result = service.readScreenplay(bytes: _celtxProject, fileName: "draft.celtx");

      expect(result.status, OcptScreenplayImportStatus.ok);
      expect(result.value, contains("INT. OFFICE - DAY"));
      expect(result.value, contains("She waits."));
    });

    test('matches an extension whatever its case', () {
      final result = service.readScreenplay(
        bytes: _bytesOf(_finalDraftDocument),
        fileName: "DRAFT.FDX",
      );

      expect(result.status, OcptScreenplayImportStatus.ok);
      expect(result.value, contains("She waits."));
    });

    test('turns a broken file into unreadableFile rather than throwing', () {
      final result = service.readScreenplay(
        bytes: _bytesOf('<FinalDraft DocumentType="Script"><Content>'),
        fileName: "truncated.fdx",
      );

      expect(result.status, OcptScreenplayImportStatus.unreadableFile);
      expect(result.value, isNull);
    });

    test('refuses a file whose extension names no format this app imports', () {
      final result = service.readScreenplay(bytes: _bytesOf("Anything"), fileName: "notes.txt");

      expect(result.status, OcptScreenplayImportStatus.unreadableFile);
      expect(result.value, isNull);
    });
  });
}
