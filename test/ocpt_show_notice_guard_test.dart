// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The one file of `lib/` allowed to show a SnackBar.
const _helperPath = "lib/ui/widgets/helpers/ocpt_show_notice.dart";

/// Guard the notices: this fails on a `showSnackBar(` call in `lib/` outside the shared helper,
/// since a notice built on its own would not tell a failure from a success.
void main() {
  test("only the shared helper shows a SnackBar", () {
    final offences = <String>[];

    for (final entity in Directory("lib").listSync(recursive: true)) {
      if (entity is! File ||
          !entity.path.endsWith(".dart") ||
          entity.path.startsWith("lib/generated/") ||
          entity.path == _helperPath) {
        continue;
      }

      final lines = entity.readAsLinesSync();
      for (var index = 0; index < lines.length; index++) {
        if (lines[index].contains("showSnackBar(")) {
          offences.add("${entity.path}:${index + 1}");
        }
      }
    }

    expect(offences, isEmpty, reason: "Use ocptShowNotice instead of showSnackBar");
  });
}
