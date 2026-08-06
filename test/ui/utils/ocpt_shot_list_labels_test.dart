// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_xlsx_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_placement.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_xlsx_column.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_status.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_shot_list_labels.dart';

void main() {
  group("ocptParseShotDuration / ocptFormatShotDuration round trip", () {
    test("a blank input parses to null, matching the null formatting", () {
      expect(ocptParseShotDuration(""), isNull);
      expect(ocptParseShotDuration("   "), isNull);
      expect(ocptParseShotDuration(ocptFormatShotDuration(null)), isNull);
    });

    test("mm:ss round-trips through both directions", () {
      for (final milliseconds in [0, 5000, 65000, 600000, 3599000]) {
        final formatted = ocptFormatShotDuration(milliseconds);
        expect(ocptParseShotDuration(formatted), milliseconds, reason: "for $formatted");
      }
    });

    test("both halves are formatted on two digits", () {
      expect(ocptFormatShotDuration(0), "00:00");
      expect(ocptFormatShotDuration(45000), "00:45");
      expect(ocptFormatShotDuration(90000), "01:30");
      expect(ocptFormatShotDuration(4500000), "75:00");
    });

    test("leading zeroes are optional on the way in", () {
      expect(ocptParseShotDuration("1:30"), 90000);
      expect(ocptParseShotDuration("01:30"), 90000);
      expect(ocptParseShotDuration("00:05"), 5000);
    });

    test("a bare non-negative integer is read as a number of seconds", () {
      expect(ocptParseShotDuration("90"), 90000);
      expect(ocptParseShotDuration("0"), 0);
    });

    test("an unparseable value throws FormatException, leaving the caller to reject it", () {
      expect(() => ocptParseShotDuration("banana"), throwsFormatException);
      expect(() => ocptParseShotDuration("-5"), throwsFormatException);
      expect(() => ocptParseShotDuration("1:75"), throwsFormatException);
      expect(() => ocptParseShotDuration("1:2:3"), throwsFormatException);
    });
  });

  group("ocptIsShotDurationValid", () {
    test("answers what ocptParseShotDuration accepts, without throwing", () {
      expect(ocptIsShotDurationValid(""), isTrue);
      expect(ocptIsShotDurationValid("45"), isTrue);
      expect(ocptIsShotDurationValid("01:30"), isTrue);
      expect(ocptIsShotDurationValid("1:75"), isFalse);
      expect(ocptIsShotDurationValid("1:2:3"), isFalse);
      expect(ocptIsShotDurationValid(":"), isFalse);
    });
  });

  group("ocptDeduceShotAbbreviation", () {
    test("reads the initials of the shot size's words, upper cased", () {
      expect(ocptDeduceShotAbbreviation("Plan moyen"), "PM");
      expect(ocptDeduceShotAbbreviation("Gros plan"), "GP");
      expect(ocptDeduceShotAbbreviation("très gros plan"), "TGP");
      expect(ocptDeduceShotAbbreviation("Plan d'ensemble"), "PD");
    });

    test("counts a hyphenated shot size as a single word", () {
      expect(ocptDeduceShotAbbreviation("Close-up"), "C");
      expect(ocptDeduceShotAbbreviation("Extreme close-up"), "EC");
    });

    test("ignores the surrounding and repeated whitespace", () {
      expect(ocptDeduceShotAbbreviation("  Plan   moyen  "), "PM");
    });

    test("skips a word carrying no letter nor digit at all", () {
      expect(ocptDeduceShotAbbreviation("Plan — moyen"), "PM");
      expect(ocptDeduceShotAbbreviation("(gros) plan"), "GP");
    });

    test("deduces nothing from a shot size with no initial to read", () {
      expect(ocptDeduceShotAbbreviation(""), "");
      expect(ocptDeduceShotAbbreviation("   "), "");
      expect(ocptDeduceShotAbbreviation("— …"), "");
    });
  });

  group("ocptShotDurationInputFormatters", () {
    test("keeps the digits and the separator, drops everything else", () {
      var filtered = const TextEditingValue(text: "1m 30s!");
      for (final formatter in ocptShotDurationInputFormatters) {
        filtered = formatter.formatEditUpdate(TextEditingValue.empty, filtered);
      }

      expect(filtered.text, "130");
    });
  });

  group("ocptShotFieldOrDash", () {
    test("returns the dash placeholder for null or blank, the value otherwise", () {
      expect(ocptShotFieldOrDash(null), ocptShotListEmptyValue);
      expect(ocptShotFieldOrDash("   "), ocptShotListEmptyValue);
      expect(ocptShotFieldOrDash("Wide shot"), "Wide shot");
    });
  });

  group("ocptShotPlacementLabel", () {
    testWidgets("reads a placed shot's day tag and date, dashes an unplaced one", (tester) async {
      late String placedLabel;
      late String unplacedLabel;

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
              placedLabel = ocptShotPlacementLabel(
                context,
                OcptShotPlacement(
                  shotId: "shot-1",
                  dayId: "day-3",
                  dayNumber: 3,
                  date: DateTime(2026, 8, 4),
                ),
              );
              unplacedLabel = ocptShotPlacementLabel(context, null);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tuesday 4 August 2026, in the app's own en_GB locale.
      expect(placedLabel, "J3 · Tue 4 Aug");
      expect(unplacedLabel, ocptShotListEmptyValue);
    });
  });

  group("ocptShotListXlsxLabelsOf", () {
    testWidgets("names every column of the workbook and every sequence it groups by",
        (tester) async {
      final labels = await _buildXlsxLabels(
        tester,
        sequences: [
          const OcptSceneShotSequence(
            sceneId: "scene-1",
            heading: "INT. FLAT - NIGHT",
            sceneNumber: null,
            displaySceneNumber: "1",
            charStart: 0,
            charEnd: 40,
            shots: [],
          ),
          const OcptOrphanShotSequence(shots: []),
        ],
      );

      expect(labels.sheetName, "Shot list");
      // Every column is named, and the two the table has no room for take the inspector's own
      // section titles rather than going out unlabelled.
      expect(labels.columnHeaders, hasLength(OcptShotListXlsxColumn.values.length));
      expect(labels.columnHeaders.values, isNot(contains("")));
      expect(labels.headerOf(OcptShotListXlsxColumn.shot), "Shot");
      expect(labels.headerOf(OcptShotListXlsxColumn.framing), "Framing & composition");
      expect(labels.headerOf(OcptShotListXlsxColumn.notes), "Director's notes");
      expect(labels.headerOf(OcptShotListXlsxColumn.locationNotes), "Location scouting");

      expect(labels.labelOf(OcptShotStatus.retake), "Retake");

      expect(labels.titleOfSequence("scene-1"), "Sequence 1 — INT. FLAT - NIGHT");
      expect(labels.titleOfSequence(OcptOrphanShotSequence.sequenceId), "Orphaned shots");
    });
  });
}

/// Pumps a throwaway widget to get hold of a real [Tr], and builds the workbook labels of
/// [sequences] from it.
Future<OcptShotListXlsxLabels> _buildXlsxLabels(
  WidgetTester tester, {
  required List<OcptShotSequence> sequences,
}) async {
  late OcptShotListXlsxLabels labels;

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
          labels = ocptShotListXlsxLabelsOf(Tr.of(context), sequences);
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  await tester.pumpAndSettle();

  return labels;
}
