// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';

/// A `.fountain` file picked and decoded by `OcptExportManager.pickAndReadFountain`.
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
