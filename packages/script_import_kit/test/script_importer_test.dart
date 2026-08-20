// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';
import 'dart:typed_data';

import 'package:script_import_kit/script_import_kit.dart';
import 'package:test/test.dart';

/// A minimal, well-formed Final Draft document holding one line of action.
const String _finalDraftDocument = '''
<?xml version="1.0" encoding="UTF-8" standalone="no" ?>
<FinalDraft DocumentType="Script" Template="No" Version="1">
<Content>
<Paragraph Type="Action"><Text>She waits.</Text></Paragraph>
</Content>
</FinalDraft>
''';

/// Reads [text] under [fileName] with a fresh [ScriptImporter].
ScriptImportResult _read(String text, String fileName) =>
    const ScriptImporter().read(
      bytes: Uint8List.fromList(utf8.encode(text)),
      fileName: fileName,
    );

/// The [ScriptImportFailure] reading [text] under [fileName] throws.
ScriptImportFailure _failureOf(String text, String fileName) {
  try {
    _read(text, fileName);
  } on ScriptImportException catch (exception) {
    return exception.failure;
  }
  fail('reading the file was expected to throw');
}

void main() {
  group('dispatch by extension', () {
    test('a ".fdx" file is read as Final Draft', () {
      final result = _read(_finalDraftDocument, 'the-last-kettle.fdx');

      expect(result.format, ScriptImportFormat.finalDraft);
      expect(result.fountainText, 'She waits.\n');
    });

    test('the extension is matched whatever its case', () {
      expect(
        _read(_finalDraftDocument, 'THE-LAST-KETTLE.FDX').format,
        ScriptImportFormat.finalDraft,
      );
    });

    test('a full path is matched on its extension alone', () {
      expect(
        _read(_finalDraftDocument, '/home/jane/My.Scripts/kettle.fdx').format,
        ScriptImportFormat.finalDraft,
      );
    });

    test('a ".fountain" file is refused: it needs no conversion at all', () {
      expect(
        _failureOf('She waits.\n', 'the-last-kettle.fountain'),
        ScriptImportFailure.unsupportedFormat,
      );
    });

    test('an extension no reader handles is unsupported', () {
      expect(
        _failureOf('She waits.\n', 'the-last-kettle.pdf'),
        ScriptImportFailure.unsupportedFormat,
      );
    });

    test('a file name with no extension is unsupported', () {
      expect(
        _failureOf('She waits.\n', 'the-last-kettle'),
        ScriptImportFailure.unsupportedFormat,
      );
    });
  });

  group('failures the reader raises', () {
    test('a reader failure reaches the caller unchanged', () {
      expect(
        _failureOf('<FinalDraft><Content>', 'the-last-kettle.fdx'),
        ScriptImportFailure.malformedFile,
      );
    });
  });

  group('the result', () {
    test('two results holding the same screenplay are equal', () {
      expect(
        _read(_finalDraftDocument, 'a.fdx'),
        _read(_finalDraftDocument, 'b.fdx'),
      );
    });
  });
}
