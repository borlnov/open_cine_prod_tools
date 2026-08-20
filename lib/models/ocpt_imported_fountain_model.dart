// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';

/// A screenplay file picked and read as Fountain text by
/// `OcptExportManager.pickAndReadScreenplay`.
///
/// Named after Fountain rather than after the file it came from on purpose: whether the picked
/// file was a `.fountain`, an `.fdx` or a `.celtx`, [fountainText] is Fountain by the time it
/// lands here — the conversion happens as the file is read.
class OcptImportedFountainModel extends Equatable {
  /// The decoded source text of the picked file.
  final String fountainText;

  /// The base name (with extension) of the picked file, used to suggest a project name when the
  /// file has no title page.
  final String sourceFileName;

  /// Class constructor
  const OcptImportedFountainModel({required this.fountainText, required this.sourceFileName});

  /// Object properties
  @override
  List<Object?> get props => [fountainText, sourceFileName];
}
