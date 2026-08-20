// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:script_import_kit/src/models/script_import_format.dart';

/// The screenplay that was read, expressed in Fountain.
///
/// The conversion is one-way and knowingly lossy (see this package's
/// `README.md` for what each format loses): [format] is kept only so that a
/// caller can tell a user which door the screenplay came in through, never
/// to convert it back.
class ScriptImportResult extends Equatable {
  /// Creates a [ScriptImportResult].
  const ScriptImportResult({required this.format, required this.fountainText});

  /// The format [fountainText] was converted from.
  final ScriptImportFormat format;

  /// The screenplay as Fountain source text, ready to be parsed by
  /// `FountainParser` or stored as a screenplay's text.
  final String fountainText;

  @override
  List<Object?> get props => [format, fountainText];

  @override
  String toString() =>
      'ScriptImportResult(${format.name}, ${fountainText.length} chars)';
}
