// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The framework libraries Flutter publishes out of the framework since 3.47, each with the
/// package that replaces it.
///
/// The two copies of a library declare distinct types, so a widget built from the framework's copy
/// silently misses the theme and the localisations the app installs from the package's copy, and
/// the analyzer says nothing: only `dart fix` knows about the migration.
const _replacedLibraries = <String, String>{
  "package:flutter/material.dart": "package:material_ui/material_ui.dart",
  "package:flutter/cupertino.dart": "package:cupertino_ui/cupertino_ui.dart",
  "package:flutter_localizations/flutter_localizations.dart":
      "ocptDesignLocalizationsDelegates from lib/constants/ocpt_localizations_delegates.dart",
};

/// The one file allowed to import the framework's localisations, for super_editor's sake.
const _localizationsDelegatesPath = "lib/constants/ocpt_localizations_delegates.dart";

/// The matcher of an `import` or `export` directive, capturing its URI.
final _directive = RegExp(r"""^\s*(?:import|export)\s+['"]([^'"]+)['"]""");

/// Guard the design libraries: this fails on a Dart file of `lib/` or `test/` that imports the
/// framework's Material, Cupertino or localisations instead of the packages that replace them,
/// except for the shared localisation delegates.
void main() {
  final files = [
    for (final root in [Directory("lib"), Directory("test")])
      ...root
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith(".dart") && !file.path.endsWith(".g.dart"))
          .where((file) => !file.path.contains("/generated/")),
  ]..sort((a, b) => a.path.compareTo(b.path));

  test("no file imports a design library from the framework", () {
    final offences = <String>[];
    for (final file in files) {
      final lines = file.readAsLinesSync();
      for (var index = 0; index < lines.length; index++) {
        final uri = _directive.firstMatch(lines[index])?.group(1);
        final replacement = _replacedLibraries[uri];
        if (replacement != null && file.path != _localizationsDelegatesPath) {
          offences.add("${file.path}:${index + 1} imports $uri, use $replacement");
        }
      }
    }

    expect(offences, isEmpty, reason: offences.join("\n"));
  });
}
