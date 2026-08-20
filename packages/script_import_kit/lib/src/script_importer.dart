// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:typed_data';

import 'package:script_import_kit/src/models/script_import_exception.dart';
import 'package:script_import_kit/src/models/script_import_format.dart';
import 'package:script_import_kit/src/models/script_import_result.dart';
import 'package:script_import_kit/src/readers/fdx_script_reader.dart';

/// Reads a foreign screenplay file and converts it to Fountain.
///
/// The one door into this package: it picks the reader a file's extension
/// names and hands back the screenplay as Fountain source text. A file it
/// cannot read raises a [ScriptImportException] rather than a half-wrong
/// screenplay.
///
/// `.fountain` is deliberately not handled here: it needs no conversion at
/// all, and reading it stays the caller's own business
/// ([ScriptImportFormat.fountain] only exists so that a caller can name
/// that case).
class ScriptImporter {
  /// Creates a [ScriptImporter].
  const ScriptImporter({this.finalDraftReader = const FdxScriptReader()});

  /// The reader used for a Final Draft file.
  final FdxScriptReader finalDraftReader;

  /// Reads the screenplay held in [bytes], picking the reader from
  /// [fileName]'s extension.
  ///
  /// [fileName] is only ever read for its extension: nothing here touches
  /// the file system, so a caller that already holds the bytes can pass
  /// whatever name they came under.
  ScriptImportResult read({
    required Uint8List bytes,
    required String fileName,
  }) {
    final extension = _extensionOf(fileName);
    return switch (extension) {
      'fdx' => ScriptImportResult(
        format: ScriptImportFormat.finalDraft,
        fountainText: finalDraftReader.read(bytes),
      ),
      _ => throw ScriptImportException(
        ScriptImportFailure.unsupportedFormat,
        details: extension.isEmpty
            ? 'the file name "$fileName" carries no extension'
            : 'no reader handles the ".$extension" extension',
      ),
    };
  }

  /// [fileName]'s extension, lower-cased and without its dot, or an empty
  /// string when the name carries none.
  String _extensionOf(String fileName) {
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == fileName.length - 1) {
      return '';
    }
    return fileName.substring(dotIndex + 1).toLowerCase();
  }
}
