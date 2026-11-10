// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Run the guard keeping the version JSON readers from looking an enum up with `byName`.
void main() {
  test('no version JSON reader calls byName, which throws on an unknown name', () {
    final readers = Directory('lib/managers/projects/services').listSync().whereType<File>().where((
      file,
    ) {
      final name = file.uri.pathSegments.last;
      return name.startsWith('ocpt_version_') && name.endsWith('_json.dart');
    });

    expect(readers, isNotEmpty);
    final offenders = [
      for (final file in readers)
        if (file.readAsStringSync().contains('.byName(')) file.path,
    ];

    // An unknown name has to answer `malformedPayload` through `OcptVersionJsonReader.readEnum`.
    expect(offenders, isEmpty);
  });
}
