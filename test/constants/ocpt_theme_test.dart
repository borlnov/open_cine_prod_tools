// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/models/ocpt_specific_colors.dart';

void main() {
  group('ocptTheme builds both brightnesses', () {
    test('the light theme is built', () {
      expect(ocptTheme.lightThemeData, isNotNull);
    });

    test('the dark theme is built', () {
      expect(ocptTheme.darkThemeData, isNotNull);
    });
  });

  group('OcptSpecificColors extension', () {
    test('is present on the light theme', () {
      expect(ocptTheme.lightThemeData!.extension<OcptSpecificColors>(), isNotNull);
    });

    test('is present on the dark theme', () {
      expect(ocptTheme.darkThemeData!.extension<OcptSpecificColors>(), isNotNull);
    });
  });

  group('the dense text theme keeps non-null colors', () {
    // The slots _buildTextTheme overrides in lib/constants/ocpt_theme.dart: every one of them
    // must keep the brightness-correct default color Material 3 derived for it, which is only
    // true if the override went through TextTheme.copyWith rather than a hand-built TextTheme.
    const overriddenSlots = [
      'headlineSmall',
      'titleMedium',
      'titleSmall',
      'bodyLarge',
      'bodyMedium',
      'bodySmall',
      'labelLarge',
      'labelMedium',
      'labelSmall',
    ];

    TextStyle? styleOf(TextTheme textTheme, String slot) => switch (slot) {
      'headlineSmall' => textTheme.headlineSmall,
      'titleMedium' => textTheme.titleMedium,
      'titleSmall' => textTheme.titleSmall,
      'bodyLarge' => textTheme.bodyLarge,
      'bodyMedium' => textTheme.bodyMedium,
      'bodySmall' => textTheme.bodySmall,
      'labelLarge' => textTheme.labelLarge,
      'labelMedium' => textTheme.labelMedium,
      'labelSmall' => textTheme.labelSmall,
      _ => throw ArgumentError('Unknown slot: $slot'),
    };

    for (final brightness in Brightness.values) {
      final themeData = brightness == Brightness.light
          ? ocptTheme.lightThemeData!
          : ocptTheme.darkThemeData!;

      test('every overridden slot has a non-null color in $brightness', () {
        for (final slot in overriddenSlots) {
          expect(styleOf(themeData.textTheme, slot)?.color, isNotNull, reason: slot);
        }
      });
    }
  });

  group('component themes read their colors from the scheme', () {
    for (final brightness in Brightness.values) {
      final themeData = brightness == Brightness.light
          ? ocptTheme.lightThemeData!
          : ocptTheme.darkThemeData!;
      final colorScheme = themeData.colorScheme;

      test('the card border color equals outlineVariant in $brightness', () {
        final shape = themeData.cardTheme.shape as RoundedRectangleBorder?;
        expect(shape?.side.color, colorScheme.outlineVariant);
      });

      test('the card fill color equals surfaceContainerLow in $brightness', () {
        expect(themeData.cardTheme.color, colorScheme.surfaceContainerLow);
      });

      test('the outlined button border color equals outline in $brightness', () {
        final side = themeData.outlinedButtonTheme.style?.side?.resolve(<WidgetState>{});
        expect(side?.color, colorScheme.outline);
      });

      test('the popup menu color equals surfaceContainerHigh in $brightness', () {
        expect(themeData.popupMenuTheme.color, colorScheme.surfaceContainerHigh);
      });

      test('the divider color equals outlineVariant in $brightness', () {
        expect(themeData.dividerTheme.color, colorScheme.outlineVariant);
      });

      test('the scrollbar thumb color equals outline in $brightness', () {
        expect(themeData.scrollbarTheme.thumbColor?.resolve(<WidgetState>{}), colorScheme.outline);
      });

      test('the selected icon button background is primary at the selected-state alpha '
          'in $brightness', () {
        final style = themeData.iconButtonTheme.style!;
        final selectedBackground = style.backgroundColor?.resolve(<WidgetState>{
          WidgetState.selected,
        });
        expect(selectedBackground, colorScheme.primary.withValues(alpha: ocptSelectedStateAlpha));

        final unselectedBackground = style.backgroundColor?.resolve(<WidgetState>{});
        expect(unselectedBackground, Colors.transparent);
      });
    }
  });
}
