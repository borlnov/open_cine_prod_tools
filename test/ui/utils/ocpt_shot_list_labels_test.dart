// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_xlsx_labels.dart';
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

    test("m:ss round-trips through both directions", () {
      for (final milliseconds in [0, 5000, 65000, 600000, 3599000]) {
        final formatted = ocptFormatShotDuration(milliseconds);
        expect(ocptParseShotDuration(formatted), milliseconds, reason: "for $formatted");
      }
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

  group("ocptShotFieldOrDash", () {
    test("returns the dash placeholder for null or blank, the value otherwise", () {
      expect(ocptShotFieldOrDash(null), ocptShotListEmptyValue);
      expect(ocptShotFieldOrDash("   "), ocptShotListEmptyValue);
      expect(ocptShotFieldOrDash("Wide shot"), "Wide shot");
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
