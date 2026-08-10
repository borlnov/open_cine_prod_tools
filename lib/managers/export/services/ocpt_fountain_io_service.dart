// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';
import 'dart:typed_data';

import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_export_file_name.dart';
import 'package:path/path.dart' as p;

/// Converts a `.fountain` file's bytes to and from the plain Fountain text stored as a
/// screenplay's source of truth.
///
/// This is pure text/bytes logic with no I/O of its own (no dialog, no file system access): it's
/// owned by `OcptExportManager` and exposed as a public final field, reached through the manager
/// rather than through `globalGetIt()` (RFL18).
class OcptFountainIoService {
  /// The extension of a Fountain screenplay file, without its leading dot.
  static const fountainFileExtension = "fountain";

  /// The project name suggested when nothing usable can be derived from the imported file.
  static const _fallbackProjectName = "Screenplay";

  /// The characters illegal in a file name, dropped while sanitising a suggested name.
  static final _illegalNameCharacters = RegExp(r'[/\\:*?"<>|]');

  /// The parser used to read a `.fountain` file's title page, to suggest a project name from it.
  static const _fountainParser = FountainParser();

  /// Class constructor
  const OcptFountainIoService();

  /// Decodes the bytes of a `.fountain` file into its source text.
  ///
  /// Decodes as UTF-8, allowing malformed sequences rather than throwing on a file this app
  /// didn't write, strips a leading byte-order mark if present, and normalises `\r\n` and `\r`
  /// line endings to `\n`.
  String decodeFountainBytes(Uint8List bytes) {
    var text = utf8.decode(bytes, allowMalformed: true);

    if (text.startsWith("﻿")) {
      text = text.substring(1);
    }

    return text.replaceAll("\r\n", "\n").replaceAll("\r", "\n");
  }

  /// Encodes [fountainText] into the bytes of a `.fountain` file.
  ///
  /// UTF-8, with a trailing newline appended if [fountainText] doesn't already end with one.
  Uint8List encodeFountainText(String fountainText) {
    final withTrailingNewline = fountainText.endsWith("\n") ? fountainText : "$fountainText\n";
    return Uint8List.fromList(utf8.encode(withTrailingNewline));
  }

  /// The project name to suggest for a screenplay being imported from [sourceFileName].
  ///
  /// Uses [fountainText]'s title page `Title:` entry when there is one, the base name of
  /// [sourceFileName] otherwise; either way, the result is sanitised into a legal file name,
  /// falling back to `"Screenplay"` if nothing usable is left.
  String suggestedProjectName({required String fountainText, required String sourceFileName}) {
    final title = _fountainParser.parse(fountainText).titlePage?.title;
    if (title != null) {
      final sanitizedTitle = _sanitize(title);
      if (sanitizedTitle != null) {
        return sanitizedTitle;
      }
    }

    final sanitizedBaseName = _sanitize(p.basenameWithoutExtension(sourceFileName));
    return sanitizedBaseName ?? _fallbackProjectName;
  }

  /// The `.fountain` file name to suggest when exporting the project named [projectName].
  /// [episodeTag] is the selected episode's own tag, present only while the open project holds more
  /// than one episode — see `ocptExportFileNameOf`'s own doc comment.
  String fountainFileName({required String projectName, String? episodeTag}) => ocptExportFileNameOf(
    projectName: projectName,
    episodeTag: episodeTag,
    extension: fountainFileExtension,
  );

  /// Trims [value], collapses internal whitespace, and drops characters illegal in file names.
  ///
  /// Returns null if nothing usable is left, so the caller can fall back to
  /// [_fallbackProjectName].
  String? _sanitize(String value) {
    final withoutIllegalCharacters = value.replaceAll(_illegalNameCharacters, "");
    final collapsed = withoutIllegalCharacters.trim().replaceAll(RegExp(r"\s+"), " ");

    return collapsed.isEmpty ? null : collapsed;
  }
}
