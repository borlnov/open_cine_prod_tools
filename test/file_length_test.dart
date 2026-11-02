// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The number of lines a source file stays under.
const _maxLines = 1000;

/// List the files of [roots] whose name ends in `.dart`, leaving out generated code and the build
/// folders.
List<File> _dartFilesIn(Iterable<Directory> roots) => [
  for (final root in roots.where((directory) => directory.existsSync()))
    ...root
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith(".dart") && !file.path.endsWith(".g.dart"))
        .where((file) => !file.path.contains("/generated/"))
        .where((file) => !file.path.contains("/.dart_tool/"))
        .where((file) => !file.path.contains("/build/")),
]..sort((a, b) => a.path.compareTo(b.path));

/// Guard the length of the Dart sources: this fails on a file of 1000 lines or more, naming it, in
/// `lib/`, `test/`, `tool/` and `packages/`. A file that long is doing several jobs and is split by
/// responsibility.
void main() {
  final folders = <String, List<File>>{
    "lib": _dartFilesIn([Directory("lib")]),
    "test": _dartFilesIn([Directory("test")]),
    "tool": _dartFilesIn([Directory("tool")]),
    "packages": _dartFilesIn([Directory("packages")]),
  };

  folders.forEach((folder, files) {
    test("the sources of $folder were found", () {
      expect(files, isNotEmpty);
    });

    test("$folder keeps every file under $_maxLines lines", () {
      final offences = [
        for (final file in files)
          if (file.readAsLinesSync().length >= _maxLines)
            "${file.path} is ${file.readAsLinesSync().length} lines long",
      ];

      expect(
        offences,
        isEmpty,
        reason: "A source file stays under $_maxLines lines: split it by responsibility.",
      );
    });
  });
}
