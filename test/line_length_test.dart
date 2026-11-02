// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The longest line, in characters, a source file may hold.
const _maxLineLength = 100;

/// The file whose multi-line literal holds a Fountain screenplay, which is prose a line break
/// would change.
const _fountainSeedPath = "test/seed_demo_project_data.dart";

/// The delimiter of the multi-line literal [_fountainSeedPath] holds.
const _fountainLiteralDelimiter = "'''";

/// The matcher of a comment that holds nothing but a URL, which cannot be broken.
final _urlOnlyComment = RegExp(r"^\s*///?\s*(<)?https?://\S+(>)?\s*$");

/// Tell whether the line is one that cannot be broken: a directive, a doc template (its name has to
/// stay on the line that opens it), or a URL alone in a comment.
bool _isUnbreakable(String line) {
  final trimmed = line.trimLeft();
  return trimmed.startsWith("import ") ||
      trimmed.startsWith("export ") ||
      trimmed.startsWith("part ") ||
      trimmed.startsWith("/// {@template ") ||
      _urlOnlyComment.hasMatch(line);
}

/// List the lines of [file] that run past the limit, leaving out the ones the project allows.
List<String> _offencesOf(File file) {
  final lines = file.readAsLinesSync();
  final offences = <String>[];
  var inFountainLiteral = false;

  for (var index = 0; index < lines.length; index++) {
    final line = lines[index];
    final isSeed = file.path == _fountainSeedPath;
    if (isSeed && _fountainLiteralDelimiter.allMatches(line).length.isOdd) {
      inFountainLiteral = !inFountainLiteral;
      continue;
    }

    // A String's length counts UTF-16 units, so the characters are counted by rune.
    if (line.runes.length > _maxLineLength && !_isUnbreakable(line) && !inFountainLiteral) {
      offences.add("${file.path}:${index + 1} is ${line.runes.length} characters long");
    }
  }

  return offences;
}

/// Guard the line length of the Dart sources: this fails on a line of more than 100 characters,
/// naming it, in `lib/`, `test/`, `tool/` and each package's `lib/`, `test/`, `bin/` and `tool/`.
void main() {
  final roots = [
    Directory("lib"),
    Directory("test"),
    Directory("tool"),
    for (final package in Directory("packages").listSync().whereType<Directory>())
      for (final folder in ["lib", "test", "bin", "tool"]) Directory("${package.path}/$folder"),
  ].where((directory) => directory.existsSync());

  final files = [
    for (final root in roots)
      ...root
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith(".dart") && !file.path.endsWith(".g.dart"))
          .where((file) => !file.path.contains("/generated/")),
  ]..sort((a, b) => a.path.compareTo(b.path));

  // One test per folder: the first two segments of a path, as "lib/ui" or "packages/spell_kit".
  final folders = <String, List<File>>{};
  for (final file in files) {
    final segments = file.path.split("/");
    final key = segments.length > 2 ? segments.take(2).join("/") : segments.first;
    folders.putIfAbsent(key, () => []).add(file);
  }

  test("the sources were found", () {
    expect(files, isNotEmpty);
  });

  folders.forEach((folder, folderFiles) {
    test("$folder keeps its lines within $_maxLineLength characters", () {
      final offences = [for (final file in folderFiles) ..._offencesOf(file)];

      expect(
        offences,
        isEmpty,
        reason:
            "A line holds at most $_maxLineLength characters: only a directive, a doc template, a "
            "URL alone in a comment and the Fountain text of the demo screenplay may run past it.",
      );
    });
  });
}
