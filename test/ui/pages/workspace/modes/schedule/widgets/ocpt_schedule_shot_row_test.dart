// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:open_cine_prod_tools/constants/ocpt_localizations_delegates.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_status.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_shot_row.dart';
import 'package:open_cine_prod_tools/ui/widgets/ocpt_referenced_image.dart';

/// Wraps [child] in a [width]-wide box, with the localization delegates so [Tr.of] resolves.
Widget _wrap(Widget child, {required double width}) => MaterialApp(
  localizationsDelegates: const [Tr.delegate, ...ocptDesignLocalizationsDelegates],
  supportedLocales: Tr.delegate.supportedLocales,
  home: Scaffold(
    body: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(width: width, child: child),
    ),
  ),
);

/// Builds a shot with the few fields these tests read, everything else neutral.
OcptShot _buildShot({
  String shotSize = "Wide shot",
  String abbreviation = "",
  String framing = "",
  String cameraMove = "",
  String lens = "",
  List<String> characters = const [],
}) => OcptShot(
  id: "shot-1",
  screenplayId: "screenplay-1",
  sceneId: "scene-1",
  orphanedHeading: null,
  position: 0,
  shotSize: shotSize,
  abbreviation: abbreviation,
  framing: framing,
  cameraMove: cameraMove,
  lens: lens,
  recordingFormat: "",
  estimatedDurationMs: 150000,
  shootingDay: null,
  plannedTakes: null,
  sound: "",
  status: OcptShotStatus.toShoot,
  difficultySet: 0,
  difficultyCamera: 0,
  difficultyActing: 0,
  difficultySound: 0,
  notes: "",
  locationNotes: "",
  needsCheck: false,
  checkReason: null,
  characters: characters,
  coverageRanges: const [],
  code: "4/1",
  averageDifficulty: 0,
);

/// Run the tests of [OcptScheduleShotRow].
void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp("ocpt_schedule_shot_row_test_");
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  /// Pumps a row for [shot] in a [width]-wide box.
  Future<void> pumpRow(
    WidgetTester tester,
    OcptShot shot, {
    String? thumbnailPath,
    double width = 400,
    bool isFramed = false,
    VoidCallback? onTap,
  }) async {
    await tester.pumpWidget(
      _wrap(
        OcptScheduleShotRow(
          shot: shot,
          thumbnailPath: thumbnailPath,
          dayNumbers: null,
          isFramed: isFramed,
          onTap: onTap ?? () {},
        ),
        width: width,
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Finds the semantic label of the placeholder frame.
  Finder findPlaceholder(WidgetTester tester) {
    final label = Tr.of(tester.element(find.byType(OcptScheduleShotRow)))
        .scheduleShotRowNoStoryboardLabel;

    return find.byWidgetPredicate(
      (widget) => widget is Semantics && widget.properties.label == label,
    );
  }

  group("thumbnail", () {
    testWidgets("a null path draws the dashed placeholder", (tester) async {
      await pumpRow(tester, _buildShot());

      expect(findPlaceholder(tester), findsOneWidget);
      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
    });

    testWidgets("a path naming no file draws the dashed placeholder", (tester) async {
      await tester.runAsync(() async {
        await pumpRow(tester, _buildShot(), thumbnailPath: "${tempDir.path}/missing.png");
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();

      expect(findPlaceholder(tester), findsOneWidget);
    });

    testWidgets("an existing file draws the image, not the placeholder", (tester) async {
      final file = File("${tempDir.path}/frame.png")..writeAsBytesSync(_redPng);

      await tester.runAsync(() async {
        await pumpRow(tester, _buildShot(), thumbnailPath: file.path);
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();

      expect(find.byType(OcptReferencedImage), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      expect(find.byIcon(Icons.image_outlined), findsNothing);
    });

    testWidgets("a row narrower than the threshold drops the thumbnail", (tester) async {
      // 200 px of content, below the 220 px threshold.
      await pumpRow(tester, _buildShot(), width: 200);

      expect(find.byType(OcptReferencedImage), findsNothing);
      expect(find.byIcon(Icons.image_outlined), findsNothing);
    });

    testWidgets("a framed row counts its padding and border against the threshold", (tester) async {
      // 230 px wide minus 18 px of frame leaves 212 px of content: dropped.
      await pumpRow(tester, _buildShot(), width: 230, isFramed: true);

      expect(find.byType(OcptReferencedImage), findsNothing);
    });
  });

  group("lines", () {
    testWidgets("the framing line is absent without a framing", (tester) async {
      await pumpRow(tester, _buildShot());

      expect(find.text("Over the shoulder"), findsNothing);
      final height = tester.getSize(find.byType(OcptScheduleShotRow)).height;

      await pumpRow(tester, _buildShot(framing: "Over the shoulder"));

      expect(find.text("Over the shoulder"), findsOneWidget);
      expect(tester.getSize(find.byType(OcptScheduleShotRow)).height, greaterThanOrEqualTo(height));
    });

    testWidgets("the third line is absent without move, lens or characters", (tester) async {
      await pumpRow(tester, _buildShot());

      expect(find.textContaining("·"), findsNothing);
      expect(find.text("MARTHE"), findsNothing);
    });

    testWidgets("the separator only appears when both the move and the lens are there", (
      tester,
    ) async {
      await pumpRow(tester, _buildShot(cameraMove: "Dolly in", lens: "35mm"));
      expect(find.text("Dolly in · 35mm"), findsOneWidget);

      await pumpRow(tester, _buildShot(cameraMove: "Dolly in"));
      expect(find.text("Dolly in"), findsOneWidget);

      await pumpRow(tester, _buildShot(lens: "35mm"));
      expect(find.text("35mm"), findsOneWidget);
    });

    testWidgets("the characters are joined and sit on the third line", (tester) async {
      await pumpRow(tester, _buildShot(characters: const ["MARTHE", "JEAN"]));

      expect(find.text("MARTHE, JEAN"), findsOneWidget);
    });

    testWidgets("the abbreviation is a badge only when there is one", (tester) async {
      await pumpRow(tester, _buildShot(abbreviation: "GP"));
      expect(find.text("GP"), findsOneWidget);

      await pumpRow(tester, _buildShot());
      expect(find.text("GP"), findsNothing);
    });

    testWidgets("the framing stops at two lines", (tester) async {
      final framing = List.filled(40, "framing").join(" ");

      await pumpRow(tester, _buildShot(framing: framing), width: 300);

      final text = tester.widget<Text>(find.text(framing));
      expect(text.maxLines, 2);
      expect(text.overflow, TextOverflow.ellipsis);
    });
  });

  group("tooltips", () {
    testWidgets("a truncated framing carries a tooltip with its full text", (tester) async {
      final framing = List.filled(40, "framing").join(" ");

      await pumpRow(tester, _buildShot(framing: framing), width: 300);

      final tooltip = tester.widget<Tooltip>(
        find.ancestor(of: find.text(framing), matching: find.byType(Tooltip)),
      );
      expect(tooltip.message, framing);
    });

    testWidgets("a text that fits has no tooltip", (tester) async {
      await pumpRow(
        tester,
        _buildShot(framing: "Short", cameraMove: "Pan", characters: const ["JEAN"]),
      );

      for (final text in const ["Short", "Pan", "JEAN", "Wide shot"]) {
        expect(
          find.ancestor(of: find.text(text), matching: find.byType(Tooltip)),
          findsNothing,
          reason: text,
        );
      }
    });

    testWidgets("a move longer than half the line is not cut beside short characters", (
      tester,
    ) async {
      const move = "Travelling avant";

      await pumpRow(tester, _buildShot(cameraMove: move, characters: const ["JO"]));

      final rowWidth = tester.getSize(find.byType(OcptScheduleShotRow)).width;
      expect(tester.getSize(find.text(move)).width, greaterThan((rowWidth - 88) / 2));
      expect(find.ancestor(of: find.text(move), matching: find.byType(Tooltip)), findsNothing);
    });
  });

  testWidgets("no overflow at the dock's minimum width with very long texts", (tester) async {
    final long = List.filled(30, "extraordinarily").join(" ");
    final shot = _buildShot(
      shotSize: long,
      abbreviation: "GP",
      framing: long,
      cameraMove: long,
      lens: long,
      characters: [long, long],
    );

    for (final isFramed in [true, false]) {
      await pumpRow(tester, shot, width: 180, isFramed: isFramed);

      expect(tester.takeException(), isNull, reason: "framed: $isFramed");
    }
  });

  testWidgets("tapping the row calls onTap", (tester) async {
    var taps = 0;

    await pumpRow(tester, _buildShot(), onTap: () => taps++);
    await tester.tap(find.text("4/1"));

    expect(taps, 1);
  });
}

/// A valid 1x1 red PNG.
final List<int> _redPng = [
  0x89,
  0x50,
  0x4e,
  0x47,
  0x0d,
  0x0a,
  0x1a,
  0x0a,
  0x00,
  0x00,
  0x00,
  0x0d,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1f,
  0x15,
  0xc4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0d,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9c,
  0x63,
  0xf8,
  0xcf,
  0xc0,
  0xf0,
  0x1f,
  0x00,
  0x05,
  0x00,
  0x01,
  0xff,
  0x89,
  0x99,
  0x3d,
  0x1d,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4e,
  0x44,
  0xae,
  0x42,
  0x60,
  0x82,
];
