// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:typed_data';

import 'package:act_dart_result/act_dart_result.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_fountain_io_service.dart';
import 'package:open_cine_prod_tools/types/ocpt_screenplay_import_status.dart';
import 'package:script_import_kit/script_import_kit.dart';

/// Turns the bytes of a picked screenplay file into the Fountain text the app stores, whichever of
/// the three formats it came in as.
///
/// A `.fountain` file needs no conversion and goes straight to [fountainIoService]; an `.fdx` and a
/// `.celtx` go through `script_import_kit`, which converts them one-way (see that package's
/// `README.md` for what each conversion loses). This is also where a [ScriptImportException] — the
/// only thing that package knows how to say — becomes an [OcptScreenplayImportStatus]: the kit
/// knows nothing about ACT nor about `Tr`, so naming the failure to a user starts here.
///
/// This is pure bytes/text logic with no I/O of its own — no dialog, no file system access, not
/// even a logger: the developer-facing detail of a refusal travels back as the result's own
/// `extraInfo`, for the manager to log. It's owned by `OcptExportManager` and exposed as a public
/// final field, reached through the manager rather than through `globalGetIt()` (RFL18).
class OcptScriptImportService {
  /// The extension of a Final Draft screenplay file, without its leading dot.
  static const finalDraftFileExtension = "fdx";

  /// The extension of a legacy Celtx project file, without its leading dot.
  static const celtxFileExtension = "celtx";

  /// Every extension the two import gestures accept, in the order the native dialog lists them.
  ///
  /// Fountain comes first: it is the app's own source of truth, the two others being doors into it.
  static const importableExtensions = [
    OcptFountainIoService.fountainFileExtension,
    finalDraftFileExtension,
    celtxFileExtension,
  ];

  /// The reader converting a foreign screenplay file to Fountain.
  static const _importer = ScriptImporter();

  /// The service decoding a `.fountain` file's own bytes, which need no conversion at all.
  final OcptFountainIoService fountainIoService;

  /// Class constructor
  const OcptScriptImportService({this.fountainIoService = const OcptFountainIoService()});

  /// Reads [bytes] as a screenplay, picking what to do with them from [fileName]'s extension.
  ///
  /// Returns [OcptScreenplayImportStatus.ok] with the Fountain text, or
  /// [OcptScreenplayImportStatus.unreadableFile] when the file is not the screenplay its name
  /// claims — carrying the [ScriptImportException] as the result's `extraInfo`, which is where a
  /// caller with a logger finds what exactly was refused. An extension this app doesn't import is
  /// that same refusal: the native dialog filters them out, so one reaching here is a file the
  /// user renamed by hand.
  ResultWithStatus<OcptScreenplayImportStatus, String> readScreenplay({
    required Uint8List bytes,
    required String fileName,
  }) {
    if (_isFountainFile(fileName)) {
      return ResultWithStatus(
        status: OcptScreenplayImportStatus.ok,
        value: fountainIoService.decodeFountainBytes(bytes),
      );
    }

    try {
      final result = _importer.read(bytes: bytes, fileName: fileName);
      return ResultWithStatus(
        status: OcptScreenplayImportStatus.ok,
        value: result.fountainText,
      );
    } on ScriptImportException catch (error) {
      return ResultWithStatus(
        status: OcptScreenplayImportStatus.unreadableFile,
        extraInfo: error,
      );
    }
  }

  /// Whether [fileName]'s extension names a plain Fountain file, the one format read without any
  /// conversion.
  bool _isFountainFile(String fileName) {
    final dotIndex = fileName.lastIndexOf(".");
    if (dotIndex == -1) {
      return false;
    }

    return fileName.substring(dotIndex + 1).toLowerCase() ==
        OcptFountainIoService.fountainFileExtension;
  }
}
