// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The file names of a bloc, or of a mixin that holds one's handlers.
final _blocFile = RegExp(r"^(.+_bloc|mixin_.*bloc.*)\.dart$");

/// The generic copies a bloc must not call.
final _genericCopy = RegExp(r"\.(copyWith|copy\w+State)\s*\(");

/// A bloc changes its state through a named method of that state (`copyWith<Intent>`,
/// `copyTo<State>`), so a reader of the handler sees the change it makes rather than a bag of
/// fields, and so the fields a change affects are set in one place. The generic `copyWith`, and
/// the generic copy a state mixin declares, are the building blocks of those methods and nothing
/// else.
///
/// This reads the source of every bloc under `lib/` (each `*_bloc.dart` and `mixin_*bloc*.dart`)
/// and fails on a call to either generic copy. It is a source scan: a call hidden behind another
/// name is not seen.
void main() {
  final files = Directory("lib")
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => _blocFile.hasMatch(file.uri.pathSegments.last))
      .toList();

  test("the blocs were found", () {
    expect(files, isNotEmpty);
  });

  for (final file in files) {
    test("${file.path} calls no generic copy", () {
      final offences = <String>[];
      final lines = file.readAsLinesSync();
      for (var index = 0; index < lines.length; index++) {
        final line = lines[index];
        if (line.trimLeft().startsWith("//")) {
          continue;
        }
        if (_genericCopy.hasMatch(line)) {
          offences.add("line ${index + 1}: ${line.trim()}");
        }
      }
      expect(offences, isEmpty, reason: "A bloc calls a named copy method of its state instead.");
    });
  }
}
