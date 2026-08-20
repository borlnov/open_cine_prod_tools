// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/types/ocpt_first_weekday.dart';
import 'package:open_cine_prod_tools/types/ocpt_scene_effect_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_day_kind.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_schedule_labels.dart';

/// Pumps [body] under the app's own localizations, so a test can read a real [Tr].
Future<void> _pumpWithTr(WidgetTester tester, void Function(Tr tr) body) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: const [
        Tr.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: Tr.delegate.supportedLocales,
      home: Builder(
        builder: (context) {
          body(Tr.of(context));
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group("ocptScheduleStartOfWeek", () {
    // Monday 3 August 2026 through Sunday 9 August 2026.
    final monday = DateTime(2026, 8, 3);
    final sunday = DateTime(2026, 8, 9);

    test("a Monday-start week runs Monday to Sunday", () {
      for (var offset = 0; offset < 7; offset++) {
        final date = monday.add(Duration(days: offset));
        expect(
          ocptScheduleStartOfWeek(date, OcptFirstWeekday.monday),
          monday,
          reason: "for $date",
        );
      }
    });

    test("a Sunday-start week puts that Sunday at the head of the week that follows it", () {
      // The one date the two conventions disagree on, and the whole reason the preference exists:
      // Sunday the 9th ends the ISO week and opens the American one.
      expect(ocptScheduleStartOfWeek(sunday, OcptFirstWeekday.monday), monday);
      expect(ocptScheduleStartOfWeek(sunday, OcptFirstWeekday.sunday), sunday);

      for (var offset = 1; offset < 7; offset++) {
        final date = sunday.add(Duration(days: offset));
        expect(
          ocptScheduleStartOfWeek(date, OcptFirstWeekday.sunday),
          sunday,
          reason: "for $date",
        );
      }
    });

    test("the time component is dropped, so the result can key a date map", () {
      final afternoon = DateTime(2026, 8, 5, 14, 37, 12);

      expect(ocptScheduleStartOfWeek(afternoon, OcptFirstWeekday.monday), monday);
    });

    test("a week crossing a month boundary steps back into the previous month", () {
      // Tuesday 1 September 2026 belongs to the week opening on Monday 31 August.
      expect(
        ocptScheduleStartOfWeek(DateTime(2026, 9), OcptFirstWeekday.monday),
        DateTime(2026, 8, 31),
      );
    });
  });

  group("ocptScheduleDayEffectTint", () {
    testWidgets("a day with nothing to say (null category) reads the theme's own outlineVariant", (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final theme = Theme.of(context);
              expect(ocptScheduleDayEffectTint(context, null), theme.colorScheme.outlineVariant);
              return const SizedBox();
            },
          ),
        ),
      );
    });

    testWidgets(
      "a mixed day reads a colour distinct from both the neutral and every category",
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                final neutral = ocptScheduleDayEffectTint(context, null);
                final mixed = ocptScheduleDayEffectTint(context, OcptSceneEffectCategory.mixed);

                expect(mixed, isNot(neutral));
                for (final category in OcptSceneEffectCategory.values) {
                  if (category == OcptSceneEffectCategory.mixed) {
                    continue;
                  }
                  expect(mixed, isNot(ocptScheduleDayEffectTint(context, category)));
                }
                return const SizedBox();
              },
            ),
          ),
        );
      },
    );

    testWidgets("switching the category switches the resolved tint", (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              // Every one of the five readings resolves to its own distinct colour — "the control
              // switches the tint" holds for every pair, not just one.
              final colors = {
                for (final category in OcptSceneEffectCategory.values)
                  category: ocptScheduleDayEffectTint(context, category),
              };
              expect(colors.values.toSet(), hasLength(OcptSceneEffectCategory.values.length));
              return const SizedBox();
            },
          ),
        ),
      );
    });
  });

  group("ocptScheduleDayTagLabel", () {
    testWidgets("a shooting day keeps the D it always wore", (tester) async {
      await _pumpWithTr(tester, (tr) {
        expect(ocptScheduleDayTagLabel(tr, OcptShootingDayKind.shoot, 3), "D3");
      });
    });

    testWidgets("each kind opens its own letter, so the same number reads three ways", (
      tester,
    ) async {
      await _pumpWithTr(tester, (tr) {
        expect(ocptScheduleDayTagLabel(tr, OcptShootingDayKind.shoot, 1), "D1");
        expect(ocptScheduleDayTagLabel(tr, OcptShootingDayKind.casting, 1), "C1");
        expect(ocptScheduleDayTagLabel(tr, OcptShootingDayKind.rehearsal, 1), "R1");
      });
    });

    testWidgets("no two kinds share a letter", (tester) async {
      await _pumpWithTr(tester, (tr) {
        final letters = {
          for (final kind in OcptShootingDayKind.values) ocptScheduleDayTagPrefix(tr, kind),
        };

        expect(letters, hasLength(OcptShootingDayKind.values.length));
      });
    });

    testWidgets("every kind reads out under a name of its own", (tester) async {
      await _pumpWithTr(tester, (tr) {
        final labels = {
          for (final kind in OcptShootingDayKind.values) ocptShootingDayKindLabel(tr, kind),
        };

        expect(labels, hasLength(OcptShootingDayKind.values.length));
        expect(labels.every((label) => label.isNotEmpty), isTrue);
      });
    });
  });

  group("ocptScheduleDayKindTint", () {
    testWidgets("a shooting day has no tint of its own, and reads through Colour by", (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              expect(ocptScheduleDayKindTint(context, OcptShootingDayKind.shoot), isNull);
              return const SizedBox();
            },
          ),
        ),
      );
    });

    testWidgets("the two non-shooting kinds each carry their own distinct colour", (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final casting = ocptScheduleDayKindTint(context, OcptShootingDayKind.casting);
              final rehearsal = ocptScheduleDayKindTint(context, OcptShootingDayKind.rehearsal);

              expect(casting, isNotNull);
              expect(rehearsal, isNotNull);
              expect(casting, isNot(rehearsal));
              // And neither borrows the neutral a day with nothing to say already wears.
              final neutral = ocptScheduleDayEffectTint(context, null);
              expect(casting, isNot(neutral));
              expect(rehearsal, isNot(neutral));
              return const SizedBox();
            },
          ),
        ),
      );
    });
  });
}
