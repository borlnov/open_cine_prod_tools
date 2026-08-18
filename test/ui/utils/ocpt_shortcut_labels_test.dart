// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_shortcut_labels.dart';

void main() {
  group('ocptPrimaryShortcutLabel', () {
    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
    });

    test('spells the modifier out on every platform but macOS', () {
      for (final platform in [TargetPlatform.linux, TargetPlatform.windows, TargetPlatform.android]) {
        debugDefaultTargetPlatformOverride = platform;
        expect(ocptPrimaryShortcutLabel('F'), 'Ctrl+F');
      }
    });

    test('uses the command glyph on macOS', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      expect(ocptPrimaryShortcutLabel('H'), '⌘H');
    });
  });
}
