// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_project_version_codec.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_version_payload.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_version_payload_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_check_reason.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_status.dart';

void main() {
  // The codec logs through appLogger(), which requires a global manager instance to be set; merely
  // accessing it creates the (otherwise unused) singleton.
  setUpAll(() => OcptGlobalManager.instance);

  const codec = OcptProjectVersionCodec();

  /// A payload covering everything the format has to survive: a live row and a tombstoned one in
  /// every table, both nullable and non-null columns, both enum columns, the fractional sort keys,
  /// and the version stamps of the rows it carries.
  ///
  /// The second row of each table leaves every nullable column at its null default — a scene with
  /// no number, an orphaned shot with no scene, no duration, no shooting day, no planned takes and
  /// no check reason — so the round trip is exercised on null values as well as on set ones.
  OcptProjectVersionPayload buildRichPayload() => OcptProjectVersionPayload(
    screenplays: [
      OcptScreenplayRow(
        id: "screenplay-1",
        title: "My Movie",
        fountainText: "INT. HOUSE - DAY\n\nCLARA enters.",
        updatedAt: DateTime.utc(2026, 3, 4, 15, 42, 12, 345),
        isDeleted: false,
      ),
      OcptScreenplayRow(
        id: "screenplay-2",
        title: "Abandoned draft",
        fountainText: "",
        updatedAt: DateTime.utc(2026, 2, 2),
        isDeleted: true,
      ),
    ],
    scenes: const [
      OcptSceneRow(
        id: "scene-1",
        screenplayId: "screenplay-1",
        position: 0,
        heading: "INT. HOUSE - DAY",
        sceneNumber: "4A",
        charStart: 0,
        charEnd: 18,
        isDeleted: false,
      ),
      OcptSceneRow(
        id: "scene-2",
        screenplayId: "screenplay-1",
        position: 1,
        heading: "EXT. STREET - NIGHT",
        charStart: 18,
        charEnd: 40,
        isDeleted: true,
      ),
    ],
    shots: const [
      OcptShotRow(
        id: "shot-1",
        screenplayId: "screenplay-1",
        sceneId: "scene-1",
        position: 0,
        sortKey: "V",
        shotSize: "Wide",
        framing: "Low angle",
        cameraMove: "Dolly in",
        lens: "35mm",
        recordingFormat: "4K · 25 fps",
        estimatedDurationMs: 12500,
        shootingDay: "Day 3",
        plannedTakes: 4,
        sound: "Direct",
        status: OcptShotStatus.shot,
        difficultySet: 2,
        difficultyCamera: 4,
        difficultyActing: 1,
        difficultySound: 3,
        notes: "Hold on CLARA's hands.",
        locationNotes: "Kitchen, north window",
        needsCheck: true,
        checkReason: OcptShotCheckReason.coveredTextChanged,
        isDeleted: false,
      ),
      OcptShotRow(
        id: "shot-2",
        screenplayId: "screenplay-1",
        orphanedHeading: "EXT. STREET - NIGHT",
        position: 1,
        sortKey: "k",
        shotSize: "",
        framing: "",
        cameraMove: "",
        lens: "",
        recordingFormat: "",
        sound: "",
        status: OcptShotStatus.toShoot,
        difficultySet: 1,
        difficultyCamera: 1,
        difficultyActing: 1,
        difficultySound: 1,
        notes: "",
        locationNotes: "",
        needsCheck: false,
        isDeleted: true,
      ),
    ],
    shotCharacters: const [
      OcptShotCharacterRow(
        shotId: "shot-1",
        characterName: "CLARA",
        position: 0,
        sortKey: "V",
        isDeleted: false,
      ),
      OcptShotCharacterRow(
        shotId: "shot-1",
        characterName: "THÉO",
        position: 1,
        sortKey: "k",
        isDeleted: true,
      ),
    ],
    shotCoverages: const [
      OcptShotCoverageRow(
        id: "coverage-1",
        shotId: "shot-1",
        sceneId: "scene-1",
        startOffset: 0,
        endOffset: 12,
        coveredTextDigest: "digest-1",
        isDeleted: false,
      ),
      OcptShotCoverageRow(
        id: "coverage-2",
        shotId: "shot-1",
        sceneId: "scene-2",
        startOffset: 3,
        endOffset: 9,
        coveredTextDigest: "digest-2",
        isDeleted: true,
      ),
    ],
    rowFieldVersions: const [
      OcptRowFieldVersionRow(
        targetTableName: "shots",
        rowId: "shot-1",
        columnName: "framing",
        version: 7,
        deviceId: "device-1",
      ),
      OcptRowFieldVersionRow(
        targetTableName: "shot_characters",
        rowId: "shot-1/THÉO",
        columnName: "isDeleted",
        version: 2,
        deviceId: "device-2",
      ),
    ],
    pageSetup: const OcptPageSetup(
      format: OcptPageFormat.a4,
      margins: FountainPageMargins(
        leftInches: 1.5,
        rightInches: 1,
        topInches: 0.75,
        bottomInches: 1.25,
      ),
    ),
    settingsJson: '{"someSetting":true}',
  );

  /// [buildRichPayload] serialized and read back.
  OcptProjectVersionPayload roundTrip(OcptProjectVersionPayload payload) {
    final result = codec.decode(codec.encode(payload));

    expect(result.status, OcptProjectVersionPayloadStatus.ok);
    return result.value!;
  }

  group('OcptProjectVersionCodec round trip', () {
    test('decode(encode(payload)) returns an equal payload', () {
      final payload = buildRichPayload();

      expect(roundTrip(payload), payload);
    });

    test('tombstones, sort keys and version stamps all survive', () {
      final roundTripped = roundTrip(buildRichPayload());

      // Tombstones are rows: a payload that dropped them would resurrect, on restore, everything
      // the user had deleted since.
      expect(roundTripped.screenplays.map((row) => row.isDeleted), [false, true]);
      expect(roundTripped.scenes.map((row) => row.isDeleted), [false, true]);
      expect(roundTripped.shots.map((row) => row.isDeleted), [false, true]);
      expect(roundTripped.shotCharacters.map((row) => row.isDeleted), [false, true]);
      expect(roundTripped.shotCoverages.map((row) => row.isDeleted), [false, true]);

      // sortKey, not position, is what orders a group after ADR 0010.
      expect(roundTripped.shots.map((row) => row.sortKey), ["V", "k"]);
      expect(roundTripped.shotCharacters.map((row) => row.sortKey), ["V", "k"]);

      // The per-column stamps travel with the rows they describe: this is the assertion that
      // catches a codec silently dropping the sidecar.
      expect(roundTripped.rowFieldVersions, hasLength(2));
      expect(roundTripped.rowFieldVersions.first.targetTableName, "shots");
      expect(roundTripped.rowFieldVersions.first.version, 7);
      expect(roundTripped.rowFieldVersions.last.rowId, "shot-1/THÉO");
      expect(roundTripped.rowFieldVersions.last.deviceId, "device-2");
    });

    test('scene ids come back identical, and every reference to them still resolves', () {
      final roundTripped = roundTrip(buildRichPayload());

      // Re-deriving the scene index on restore would mint fresh UUIDs and break every reference
      // carried by the very same payload.
      expect(roundTripped.scenes.map((row) => row.id), ["scene-1", "scene-2"]);

      final sceneIds = {for (final scene in roundTripped.scenes) scene.id};
      for (final shot in roundTripped.shots) {
        expect(shot.sceneId == null || sceneIds.contains(shot.sceneId), isTrue);
      }
      for (final coverage in roundTripped.shotCoverages) {
        expect(sceneIds, contains(coverage.sceneId));
      }
    });

    test('the whole page setup comes back, margins included', () {
      final roundTripped = roundTrip(buildRichPayload());

      expect(roundTripped.pageSetup.format, OcptPageFormat.a4);
      expect(roundTripped.pageSetup.margins.leftInches, 1.5);
      expect(roundTripped.pageSetup.margins.rightInches, 1);
      expect(roundTripped.pageSetup.margins.topInches, 0.75);
      expect(roundTripped.pageSetup.margins.bottomInches, 1.25);
      expect(roundTripped.settingsJson, '{"someSetting":true}');
    });

    test('a project with no shot list at all round trips as an empty one', () {
      const payload = OcptProjectVersionPayload(
        screenplays: [],
        scenes: [],
        shots: [],
        shotCharacters: [],
        shotCoverages: [],
        rowFieldVersions: [],
        pageSetup: OcptPageSetup.standard(),
        settingsJson: null,
      );

      expect(roundTrip(payload), payload);
    });

    test('the encoded text declares the format it was written in', () {
      final encoded = jsonDecode(codec.encode(buildRichPayload())) as Map<String, dynamic>;

      expect(encoded["payloadFormat"], OcptProjectVersionCodec.currentPayloadFormat);
    });
  });

  group('OcptProjectVersionCodec format handling', () {
    /// The encoded rich payload, with its declared format replaced by [payloadFormat].
    String encodedWithFormat(int payloadFormat) {
      final encoded = jsonDecode(codec.encode(buildRichPayload())) as Map<String, dynamic>;
      encoded["payloadFormat"] = payloadFormat;

      return jsonEncode(encoded);
    }

    test('a payload written by a later build of the app is refused, not half-read', () {
      final result = codec.decode(
        encodedWithFormat(OcptProjectVersionCodec.currentPayloadFormat + 1),
      );

      expect(result.status, OcptProjectVersionPayloadStatus.unsupportedFutureFormat);
      expect(result.value, isNull);
    });

    test('a payload written in the current format needs no upgrade step', () {
      final result = codec.decode(
        encodedWithFormat(OcptProjectVersionCodec.currentPayloadFormat),
      );

      expect(result.status, OcptProjectVersionPayloadStatus.ok);
      expect(result.value, buildRichPayload());
    });

    test('an older format with no upgrade step is refused rather than guessed', () {
      // No format older than the current one has ever shipped, so no upgrade step is registered:
      // the replay loop must refuse the payload instead of reading it as if it were current.
      final result = codec.decode(
        encodedWithFormat(OcptProjectVersionCodec.currentPayloadFormat - 1),
      );

      expect(result.status, OcptProjectVersionPayloadStatus.malformedPayload);
      expect(result.value, isNull);
    });
  });

  group('OcptProjectVersionCodec malformed payloads', () {
    test("text that isn't JSON at all is refused", () {
      final result = codec.decode("not json");

      expect(result.status, OcptProjectVersionPayloadStatus.malformedPayload);
    });

    test("a JSON value that isn't an object is refused", () {
      final result = codec.decode("[1, 2, 3]");

      expect(result.status, OcptProjectVersionPayloadStatus.malformedPayload);
    });

    test('a payload with no format at all is refused', () {
      final encoded = jsonDecode(codec.encode(buildRichPayload())) as Map<String, dynamic>
        ..remove("payloadFormat");

      expect(
        codec.decode(jsonEncode(encoded)).status,
        OcptProjectVersionPayloadStatus.malformedPayload,
      );
    });

    test('a payload missing one of its row sections is refused', () {
      final encoded = jsonDecode(codec.encode(buildRichPayload())) as Map<String, dynamic>
        ..remove("rowFieldVersions");

      expect(
        codec.decode(jsonEncode(encoded)).status,
        OcptProjectVersionPayloadStatus.malformedPayload,
      );
    });

    test('a row missing one of its columns is refused', () {
      final encoded = jsonDecode(codec.encode(buildRichPayload())) as Map<String, dynamic>;
      ((encoded["shots"] as List).first as Map<String, dynamic>).remove("sortKey");

      expect(
        codec.decode(jsonEncode(encoded)).status,
        OcptProjectVersionPayloadStatus.malformedPayload,
      );
    });

    test('a column holding the wrong type is refused', () {
      final encoded = jsonDecode(codec.encode(buildRichPayload())) as Map<String, dynamic>;
      ((encoded["scenes"] as List).first as Map<String, dynamic>)["charStart"] = "zero";

      expect(
        codec.decode(jsonEncode(encoded)).status,
        OcptProjectVersionPayloadStatus.malformedPayload,
      );
    });

    test('an enum column holding an unknown value is refused', () {
      final encoded = jsonDecode(codec.encode(buildRichPayload())) as Map<String, dynamic>;
      ((encoded["shots"] as List).first as Map<String, dynamic>)["status"] = "teleported";

      expect(
        codec.decode(jsonEncode(encoded)).status,
        OcptProjectVersionPayloadStatus.malformedPayload,
      );
    });
  });
}
