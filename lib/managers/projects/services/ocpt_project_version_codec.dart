// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:collection';
import 'dart:convert';

import 'package:act_dart_result/act_dart_result.dart';
import 'package:act_global_manager/act_global_manager.dart';
import 'package:crypto/crypto.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_version_payload.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_version_payload_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_check_reason.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_status.dart';
import 'package:open_cine_prod_tools/utils/ocpt_row_stamp_key.dart';

/// The single place that knows the shape of `project_versions.payload`: it turns an
/// [OcptProjectVersionPayload] into the JSON text stored in a version's row, and back.
///
/// Reading the rows out of a project and writing them back into one is
/// `OcptProjectVersionsService`'s job; this class never touches a database. What it owns is the
/// **format**, and the format outlives the app build that wrote it: a payload sits in a user's
/// `.ocpt` for as long as the version does, so [decode] is a migration path rather than only a
/// guard —
///
/// - a payload written in an **older** format is upgraded, in memory, step by step, up to
///   [currentPayloadFormat]; the stored text is never rewritten, so a version stays byte-identical
///   to what was captured;
/// - a payload written in a **newer** format — the file has been opened by a later build of the
///   app — is refused with [OcptProjectVersionPayloadStatus.unsupportedFutureFormat] rather than
///   half-restored.
///
/// The column lists below are a **hand-written mirror of the schema**: a synchronised table gaining
/// a column means this codec, and very probably [currentPayloadFormat], need looking at. When that
/// day comes, add a named upgrade step to [_payloadUpgrades] and keep a fixture of the retired
/// format in the tests — the point of the format field is lost if nothing ever exercises the old
/// branch.
class OcptProjectVersionCodec {
  /// The payload format this build writes, and the highest one it can read.
  ///
  /// Deliberately **independent of the database's schema version**: the two evolve for different
  /// reasons and a payload is read long after the file it lives in has been migrated.
  static const currentPayloadFormat = 1;

  /// This is the key used to stringify or parse the payload's own format from a JSON object
  static const _payloadFormatKey = "payloadFormat";

  /// This is the key used to stringify or parse the `screenplays` rows from a JSON object
  static const _screenplaysKey = "screenplays";

  /// This is the key used to stringify or parse the `scenes` rows from a JSON object
  static const _scenesKey = "scenes";

  /// This is the key used to stringify or parse the `shots` rows from a JSON object
  static const _shotsKey = "shots";

  /// This is the key used to stringify or parse the `shot_characters` rows from a JSON object
  static const _shotCharactersKey = "shotCharacters";

  /// This is the key used to stringify or parse the `shot_coverages` rows from a JSON object
  static const _shotCoveragesKey = "shotCoverages";

  /// This is the key used to stringify or parse the `row_field_versions` rows from a JSON object
  static const _rowFieldVersionsKey = "rowFieldVersions";

  /// This is the key used to stringify or parse the project's own settings from a JSON object
  static const _projectSettingsKey = "projectSettings";

  /// This is the key used to stringify or parse the page margins from a JSON object
  static const _pageMarginsKey = "pageMargins";

  /// This is the key used to stringify or parse a row's `id` column from a JSON object
  static const _idKey = "id";

  /// This is the key used to stringify or parse a row's `isDeleted` column from a JSON object
  static const _isDeletedKey = "isDeleted";

  /// This is the key used to stringify or parse a row's `position` column from a JSON object
  static const _positionKey = "position";

  /// This is the key used to stringify or parse a row's `sortKey` column from a JSON object
  static const _sortKeyKey = "sortKey";

  /// This is the key used to stringify or parse a row's `screenplayId` column from a JSON object
  static const _screenplayIdKey = "screenplayId";

  /// This is the key used to stringify or parse a row's `sceneId` column from a JSON object
  static const _sceneIdKey = "sceneId";

  /// This is the key used to stringify or parse a row's `shotId` column from a JSON object
  static const _shotIdKey = "shotId";

  /// This is the key used to stringify or parse a screenplay's `title` column from a JSON object
  static const _titleKey = "title";

  /// This is the key used to stringify or parse a screenplay's `fountainText` column from a JSON
  /// object
  static const _fountainTextKey = "fountainText";

  /// This is the key used to stringify or parse a screenplay's `updatedAt` column from a JSON
  /// object
  static const _updatedAtKey = "updatedAt";

  /// This is the key used to stringify or parse a scene's `heading` column from a JSON object
  static const _headingKey = "heading";

  /// This is the key used to stringify or parse a scene's `sceneNumber` column from a JSON object
  static const _sceneNumberKey = "sceneNumber";

  /// This is the key used to stringify or parse a scene's `charStart` column from a JSON object
  static const _charStartKey = "charStart";

  /// This is the key used to stringify or parse a scene's `charEnd` column from a JSON object
  static const _charEndKey = "charEnd";

  /// This is the key used to stringify or parse a shot's `orphanedHeading` column from a JSON
  /// object
  static const _orphanedHeadingKey = "orphanedHeading";

  /// This is the key used to stringify or parse a shot's `shotSize` column from a JSON object
  static const _shotSizeKey = "shotSize";

  /// This is the key used to stringify or parse a shot's `abbreviation` column from a JSON object
  static const _abbreviationKey = "abbreviation";

  /// This is the key used to stringify or parse a shot's `framing` column from a JSON object
  static const _framingKey = "framing";

  /// This is the key used to stringify or parse a shot's `cameraMove` column from a JSON object
  static const _cameraMoveKey = "cameraMove";

  /// This is the key used to stringify or parse a shot's `lens` column from a JSON object
  static const _lensKey = "lens";

  /// This is the key used to stringify or parse a shot's `recordingFormat` column from a JSON
  /// object
  static const _recordingFormatKey = "recordingFormat";

  /// This is the key used to stringify or parse a shot's `estimatedDurationMs` column from a JSON
  /// object
  static const _estimatedDurationMsKey = "estimatedDurationMs";

  /// This is the key used to stringify or parse a shot's `shootingDay` column from a JSON object
  static const _shootingDayKey = "shootingDay";

  /// This is the key used to stringify or parse a shot's `plannedTakes` column from a JSON object
  static const _plannedTakesKey = "plannedTakes";

  /// This is the key used to stringify or parse a shot's `sound` column from a JSON object
  static const _soundKey = "sound";

  /// This is the key used to stringify or parse a shot's `status` column from a JSON object
  static const _statusKey = "status";

  /// This is the key used to stringify or parse a shot's `difficultySet` column from a JSON object
  static const _difficultySetKey = "difficultySet";

  /// This is the key used to stringify or parse a shot's `difficultyCamera` column from a JSON
  /// object
  static const _difficultyCameraKey = "difficultyCamera";

  /// This is the key used to stringify or parse a shot's `difficultyActing` column from a JSON
  /// object
  static const _difficultyActingKey = "difficultyActing";

  /// This is the key used to stringify or parse a shot's `difficultySound` column from a JSON
  /// object
  static const _difficultySoundKey = "difficultySound";

  /// This is the key used to stringify or parse a shot's `notes` column from a JSON object
  static const _notesKey = "notes";

  /// This is the key used to stringify or parse a shot's `locationNotes` column from a JSON object
  static const _locationNotesKey = "locationNotes";

  /// This is the key used to stringify or parse a shot's `needsCheck` column from a JSON object
  static const _needsCheckKey = "needsCheck";

  /// This is the key used to stringify or parse a shot's `checkReason` column from a JSON object
  static const _checkReasonKey = "checkReason";

  /// This is the key used to stringify or parse a shot character's `characterName` column from a
  /// JSON object
  static const _characterNameKey = "characterName";

  /// This is the key used to stringify or parse a coverage's `startOffset` column from a JSON
  /// object
  static const _startOffsetKey = "startOffset";

  /// This is the key used to stringify or parse a coverage's `endOffset` column from a JSON object
  static const _endOffsetKey = "endOffset";

  /// This is the key used to stringify or parse a coverage's `coveredTextDigest` column from a JSON
  /// object
  static const _coveredTextDigestKey = "coveredTextDigest";

  /// This is the key used to stringify or parse a version stamp's `tableName` column from a JSON
  /// object
  static const _tableNameKey = "tableName";

  /// This is the key used to stringify or parse a version stamp's `rowId` column from a JSON object
  static const _rowIdKey = "rowId";

  /// This is the key used to stringify or parse a version stamp's `columnName` column from a JSON
  /// object
  static const _columnNameKey = "columnName";

  /// This is the key used to stringify or parse a version stamp's `version` column from a JSON
  /// object
  static const _versionKey = "version";

  /// This is the key used to stringify or parse a version stamp's `deviceId` column from a JSON
  /// object
  static const _deviceIdKey = "deviceId";

  /// This is the key used to stringify or parse the project's `pageFormat` from a JSON object
  static const _pageFormatKey = "pageFormat";

  /// This is the key used to stringify or parse the project's `settingsJson` from a JSON object
  static const _settingsJsonKey = "settingsJson";

  /// This is the key used to stringify or parse the left page margin from a JSON object
  static const _marginLeftKey = "leftInches";

  /// This is the key used to stringify or parse the right page margin from a JSON object
  static const _marginRightKey = "rightInches";

  /// This is the key used to stringify or parse the top page margin from a JSON object
  static const _marginTopKey = "topInches";

  /// This is the key used to stringify or parse the bottom page margin from a JSON object
  static const _marginBottomKey = "bottomInches";

  /// The upgrade steps [decode] replays, keyed by the format each one upgrades **from**: the entry
  /// at `n` turns a format `n` JSON object into a format `n + 1` one.
  ///
  /// Empty while [currentPayloadFormat] is the only format that has ever existed. The map has to
  /// cover every format from the oldest readable one up to `currentPayloadFormat - 1`, without a
  /// hole, or [decode] refuses the payload rather than guessing.
  static const _payloadUpgrades = <int, Map<String, dynamic> Function(Map<String, dynamic> json)>{};

  /// Class constructor
  const OcptProjectVersionCodec();

  /// Serializes [payload] into the JSON text stored in `project_versions.payload`, stamped with
  /// [currentPayloadFormat].
  String encode(OcptProjectVersionPayload payload) => jsonEncode({
    _payloadFormatKey: currentPayloadFormat,
    _screenplaysKey: [for (final row in payload.screenplays) _screenplayToJson(row)],
    _scenesKey: [for (final row in payload.scenes) _sceneToJson(row)],
    _shotsKey: [for (final row in payload.shots) _shotToJson(row)],
    _shotCharactersKey: [for (final row in payload.shotCharacters) _shotCharacterToJson(row)],
    _shotCoveragesKey: [for (final row in payload.shotCoverages) _shotCoverageToJson(row)],
    _rowFieldVersionsKey: [for (final row in payload.rowFieldVersions) _rowFieldVersionToJson(row)],
    _projectSettingsKey: {
      _pageFormatKey: payload.pageSetup.format.name,
      _settingsJsonKey: payload.settingsJson,
    },
    _pageMarginsKey: {
      _marginLeftKey: payload.pageSetup.margins.leftInches,
      _marginRightKey: payload.pageSetup.margins.rightInches,
      _marginTopKey: payload.pageSetup.margins.topInches,
      _marginBottomKey: payload.pageSetup.margins.bottomInches,
    },
  });

  /// Parses [payloadJson], the text stored in `project_versions.payload`, upgrading it from an
  /// older format when needed.
  ///
  /// Never throws: every failure comes back as an [OcptProjectVersionPayloadStatus], because the
  /// caller of a decode is always about to tell the user why a version can't be opened.
  ResultWithStatus<OcptProjectVersionPayloadStatus, OcptProjectVersionPayload> decode(
    String payloadJson,
  ) {
    try {
      final decoded = jsonDecode(payloadJson);
      if (decoded is! Map<String, dynamic>) {
        throw const _OcptPayloadFormatError("the payload isn't a JSON object");
      }

      final payloadFormat = _int(decoded, _payloadFormatKey);
      if (payloadFormat > currentPayloadFormat) {
        appLogger().w("The project version payload is written in the format $payloadFormat, while "
            "this build of the app only knows up to $currentPayloadFormat: it was created by a "
            "later version of Open Cine Prod Tools");
        return const ResultWithStatus(
          status: OcptProjectVersionPayloadStatus.unsupportedFutureFormat,
        );
      }

      return ResultWithStatus(
        status: OcptProjectVersionPayloadStatus.ok,
        value: _payloadFromJson(_upgraded(decoded, payloadFormat)),
      );
    } on _OcptPayloadFormatError catch (error) {
      appLogger().e("The project version payload can't be read: ${error.reason}");
      return const ResultWithStatus(status: OcptProjectVersionPayloadStatus.malformedPayload);
    } on FormatException catch (error) {
      appLogger().e("The project version payload isn't valid JSON: $error");
      return const ResultWithStatus(status: OcptProjectVersionPayloadStatus.malformedPayload);
    }
  }

  /// The SHA-256 hex digest of [payload]'s canonical *content* — the primitive
  /// `OcptProjectVersionsService` builds both "is the working copy the same as this version?" and
  /// a restore's deduplicated safety version on top of. Stored on the row as
  /// `project_versions.contentDigest`, never inside [payload] itself: it describes the payload
  /// rather than being part of it, so keeping a second copy of it in the JSON would only be one
  /// more place for the two to drift apart.
  ///
  /// What goes in and what is left out, and why — matching `OcptProjectVersionsTable.contentDigest`
  /// exactly:
  ///
  /// - **in**: `screenplays`, `scenes`, `shots`, `shotCharacters`, `shotCoverages` — every column
  ///   of each — plus `pageSetup.format` and `settingsJson`. This is "the project", as a user
  ///   would describe it;
  /// - **out**: `rowFieldVersions`, whose per-column stamps change on every restore without the
  ///   content changing, and `pageSetup.margins`, an app-wide rendering preference rather than
  ///   project state.
  ///
  /// **Canonical.** `OcptProjectVersionsService._capturePayload` issues its `select`s with no
  /// `orderBy`, so SQLite's row order is never something either side of a comparison may rely on —
  /// and sorting happens here, rather than in that capture, precisely so the bytes actually stored
  /// in `project_versions.payload` stay untouched. Each table's rows are sorted by primary key (a
  /// composite one, `shotCharacters`', joined the same way [ocptCompositeRowStampKey] joins a
  /// version stamp's `rowId`), and each row's own JSON map has its keys sorted too, so two
  /// captures of the same state always hash the same regardless of the order SQLite happened to
  /// return rows in.
  String contentDigest(OcptProjectVersionPayload payload) {
    final canonical = <String, Object?>{
      _screenplaysKey: _canonicalRows(
        payload.screenplays,
        primaryKeyOf: (row) => row.id,
        toJson: _screenplayToJson,
      ),
      _scenesKey: _canonicalRows(payload.scenes, primaryKeyOf: (row) => row.id, toJson: _sceneToJson),
      _shotsKey: _canonicalRows(payload.shots, primaryKeyOf: (row) => row.id, toJson: _shotToJson),
      _shotCharactersKey: _canonicalRows(
        payload.shotCharacters,
        primaryKeyOf: (row) => ocptCompositeRowStampKey([row.shotId, row.characterName]),
        toJson: _shotCharacterToJson,
      ),
      _shotCoveragesKey: _canonicalRows(
        payload.shotCoverages,
        primaryKeyOf: (row) => row.id,
        toJson: _shotCoverageToJson,
      ),
      _pageFormatKey: payload.pageSetup.format.name,
      _settingsJsonKey: payload.settingsJson,
    };

    return sha256.convert(utf8.encode(jsonEncode(canonical))).toString();
  }

  /// [rows], sorted by [primaryKeyOf] and each turned into a JSON map (through the same
  /// `_screenplayToJson`-shaped serializer [encode] itself uses, so an enum column comes out as
  /// the plain string `jsonEncode` can write rather than the `TypeConverter`'s own Dart value)
  /// whose keys are themselves sorted — the two orderings [contentDigest] needs to be canonical.
  static List<Map<String, dynamic>> _canonicalRows<D>(
    List<D> rows, {
    required String Function(D row) primaryKeyOf,
    required Map<String, dynamic> Function(D row) toJson,
  }) {
    final sortedRows = [...rows]..sort((a, b) => primaryKeyOf(a).compareTo(primaryKeyOf(b)));

    return [for (final row in sortedRows) SplayTreeMap<String, dynamic>.of(toJson(row))];
  }

  /// Replays the [_payloadUpgrades] steps that take [json], written in [payloadFormat], up to
  /// [currentPayloadFormat].
  ///
  /// Returns [json] itself when it is already current, which is the only case that exists so far.
  static Map<String, dynamic> _upgraded(Map<String, dynamic> json, int payloadFormat) {
    var upgraded = json;

    for (var format = payloadFormat; format < currentPayloadFormat; format++) {
      final upgrade = _payloadUpgrades[format];
      if (upgrade == null) {
        throw _OcptPayloadFormatError("no upgrade step knows how to read the format $format");
      }

      upgraded = upgrade(upgraded);
    }

    return upgraded;
  }

  /// Builds the payload described by [json], already upgraded to [currentPayloadFormat].
  static OcptProjectVersionPayload _payloadFromJson(Map<String, dynamic> json) {
    final projectSettings = _object(json, _projectSettingsKey);
    final pageMargins = _object(json, _pageMarginsKey);

    return OcptProjectVersionPayload(
      screenplays: [for (final row in _rows(json, _screenplaysKey)) _screenplayFromJson(row)],
      scenes: [for (final row in _rows(json, _scenesKey)) _sceneFromJson(row)],
      shots: [for (final row in _rows(json, _shotsKey)) _shotFromJson(row)],
      shotCharacters: [
        for (final row in _rows(json, _shotCharactersKey)) _shotCharacterFromJson(row),
      ],
      shotCoverages: [for (final row in _rows(json, _shotCoveragesKey)) _shotCoverageFromJson(row)],
      rowFieldVersions: [
        for (final row in _rows(json, _rowFieldVersionsKey)) _rowFieldVersionFromJson(row),
      ],
      pageSetup: OcptPageSetup(
        format: _enum(projectSettings, _pageFormatKey, OcptPageFormat.values.asNameMap()),
        margins: FountainPageMargins(
          leftInches: _double(pageMargins, _marginLeftKey),
          rightInches: _double(pageMargins, _marginRightKey),
          topInches: _double(pageMargins, _marginTopKey),
          bottomInches: _double(pageMargins, _marginBottomKey),
        ),
      ),
      settingsJson: _nullableString(projectSettings, _settingsJsonKey),
    );
  }

  /// Serializes one `screenplays` row.
  static Map<String, dynamic> _screenplayToJson(OcptScreenplayRow row) => {
    _idKey: row.id,
    _titleKey: row.title,
    _fountainTextKey: row.fountainText,
    _updatedAtKey: row.updatedAt.toIso8601String(),
    _isDeletedKey: row.isDeleted,
  };

  /// Parses one `screenplays` row.
  static OcptScreenplayRow _screenplayFromJson(Map<String, dynamic> json) => OcptScreenplayRow(
    id: _string(json, _idKey),
    title: _string(json, _titleKey),
    fountainText: _string(json, _fountainTextKey),
    updatedAt: _dateTime(json, _updatedAtKey),
    isDeleted: _bool(json, _isDeletedKey),
  );

  /// Serializes one `scenes` row.
  static Map<String, dynamic> _sceneToJson(OcptSceneRow row) => {
    _idKey: row.id,
    _screenplayIdKey: row.screenplayId,
    _positionKey: row.position,
    _headingKey: row.heading,
    _sceneNumberKey: row.sceneNumber,
    _charStartKey: row.charStart,
    _charEndKey: row.charEnd,
    _isDeletedKey: row.isDeleted,
  };

  /// Parses one `scenes` row.
  static OcptSceneRow _sceneFromJson(Map<String, dynamic> json) => OcptSceneRow(
    id: _string(json, _idKey),
    screenplayId: _string(json, _screenplayIdKey),
    position: _int(json, _positionKey),
    heading: _string(json, _headingKey),
    sceneNumber: _nullableString(json, _sceneNumberKey),
    charStart: _int(json, _charStartKey),
    charEnd: _int(json, _charEndKey),
    isDeleted: _bool(json, _isDeletedKey),
  );

  /// Serializes one `shots` row.
  static Map<String, dynamic> _shotToJson(OcptShotRow row) => {
    _idKey: row.id,
    _screenplayIdKey: row.screenplayId,
    _sceneIdKey: row.sceneId,
    _orphanedHeadingKey: row.orphanedHeading,
    _positionKey: row.position,
    _sortKeyKey: row.sortKey,
    _shotSizeKey: row.shotSize,
    _abbreviationKey: row.abbreviation,
    _framingKey: row.framing,
    _cameraMoveKey: row.cameraMove,
    _lensKey: row.lens,
    _recordingFormatKey: row.recordingFormat,
    _estimatedDurationMsKey: row.estimatedDurationMs,
    _shootingDayKey: row.shootingDay,
    _plannedTakesKey: row.plannedTakes,
    _soundKey: row.sound,
    _statusKey: row.status.name,
    _difficultySetKey: row.difficultySet,
    _difficultyCameraKey: row.difficultyCamera,
    _difficultyActingKey: row.difficultyActing,
    _difficultySoundKey: row.difficultySound,
    _notesKey: row.notes,
    _locationNotesKey: row.locationNotes,
    _needsCheckKey: row.needsCheck,
    _checkReasonKey: row.checkReason?.name,
    _isDeletedKey: row.isDeleted,
  };

  /// Parses one `shots` row.
  static OcptShotRow _shotFromJson(Map<String, dynamic> json) => OcptShotRow(
    id: _string(json, _idKey),
    screenplayId: _string(json, _screenplayIdKey),
    sceneId: _nullableString(json, _sceneIdKey),
    orphanedHeading: _nullableString(json, _orphanedHeadingKey),
    position: _int(json, _positionKey),
    sortKey: _string(json, _sortKeyKey),
    shotSize: _string(json, _shotSizeKey),
    abbreviation: _string(json, _abbreviationKey),
    framing: _string(json, _framingKey),
    cameraMove: _string(json, _cameraMoveKey),
    lens: _string(json, _lensKey),
    recordingFormat: _string(json, _recordingFormatKey),
    estimatedDurationMs: _nullableInt(json, _estimatedDurationMsKey),
    shootingDay: _nullableString(json, _shootingDayKey),
    plannedTakes: _nullableInt(json, _plannedTakesKey),
    sound: _string(json, _soundKey),
    status: _enum(json, _statusKey, OcptShotStatus.values.asNameMap()),
    difficultySet: _int(json, _difficultySetKey),
    difficultyCamera: _int(json, _difficultyCameraKey),
    difficultyActing: _int(json, _difficultyActingKey),
    difficultySound: _int(json, _difficultySoundKey),
    notes: _string(json, _notesKey),
    locationNotes: _string(json, _locationNotesKey),
    needsCheck: _bool(json, _needsCheckKey),
    checkReason: _nullableEnum(json, _checkReasonKey, OcptShotCheckReason.values.asNameMap()),
    isDeleted: _bool(json, _isDeletedKey),
  );

  /// Serializes one `shot_characters` row.
  static Map<String, dynamic> _shotCharacterToJson(OcptShotCharacterRow row) => {
    _shotIdKey: row.shotId,
    _characterNameKey: row.characterName,
    _positionKey: row.position,
    _sortKeyKey: row.sortKey,
    _isDeletedKey: row.isDeleted,
  };

  /// Parses one `shot_characters` row.
  static OcptShotCharacterRow _shotCharacterFromJson(Map<String, dynamic> json) =>
      OcptShotCharacterRow(
        shotId: _string(json, _shotIdKey),
        characterName: _string(json, _characterNameKey),
        position: _int(json, _positionKey),
        sortKey: _string(json, _sortKeyKey),
        isDeleted: _bool(json, _isDeletedKey),
      );

  /// Serializes one `shot_coverages` row.
  static Map<String, dynamic> _shotCoverageToJson(OcptShotCoverageRow row) => {
    _idKey: row.id,
    _shotIdKey: row.shotId,
    _sceneIdKey: row.sceneId,
    _startOffsetKey: row.startOffset,
    _endOffsetKey: row.endOffset,
    _coveredTextDigestKey: row.coveredTextDigest,
    _isDeletedKey: row.isDeleted,
  };

  /// Parses one `shot_coverages` row.
  static OcptShotCoverageRow _shotCoverageFromJson(Map<String, dynamic> json) =>
      OcptShotCoverageRow(
        id: _string(json, _idKey),
        shotId: _string(json, _shotIdKey),
        sceneId: _string(json, _sceneIdKey),
        startOffset: _int(json, _startOffsetKey),
        endOffset: _int(json, _endOffsetKey),
        coveredTextDigest: _string(json, _coveredTextDigestKey),
        isDeleted: _bool(json, _isDeletedKey),
      );

  /// Serializes one `row_field_versions` row.
  static Map<String, dynamic> _rowFieldVersionToJson(OcptRowFieldVersionRow row) => {
    _tableNameKey: row.targetTableName,
    _rowIdKey: row.rowId,
    _columnNameKey: row.columnName,
    _versionKey: row.version,
    _deviceIdKey: row.deviceId,
  };

  /// Parses one `row_field_versions` row.
  static OcptRowFieldVersionRow _rowFieldVersionFromJson(Map<String, dynamic> json) =>
      OcptRowFieldVersionRow(
        targetTableName: _string(json, _tableNameKey),
        rowId: _string(json, _rowIdKey),
        columnName: _string(json, _columnNameKey),
        version: _int(json, _versionKey),
        deviceId: _string(json, _deviceIdKey),
      );

  /// The list of JSON objects stored at [key] in [json].
  static List<Map<String, dynamic>> _rows(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! List) {
      throw _OcptPayloadFormatError("'$key' isn't a list");
    }

    return [
      for (final element in value)
        if (element is Map<String, dynamic>)
          element
        else
          throw _OcptPayloadFormatError("an element of '$key' isn't a JSON object"),
    ];
  }

  /// The JSON object stored at [key] in [json].
  static Map<String, dynamic> _object(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! Map<String, dynamic>) {
      throw _OcptPayloadFormatError("'$key' isn't a JSON object");
    }

    return value;
  }

  /// The non-null string stored at [key] in [json].
  static String _string(Map<String, dynamic> json, String key) =>
      _nullableString(json, key) ?? (throw _OcptPayloadFormatError("'$key' is missing"));

  /// The string stored at [key] in [json], or null when the column it mirrors was null.
  static String? _nullableString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) {
      return null;
    }

    if (value is! String) {
      throw _OcptPayloadFormatError("'$key' isn't a string");
    }

    return value;
  }

  /// The non-null integer stored at [key] in [json].
  static int _int(Map<String, dynamic> json, String key) =>
      _nullableInt(json, key) ?? (throw _OcptPayloadFormatError("'$key' is missing"));

  /// The integer stored at [key] in [json], or null when the column it mirrors was null.
  static int? _nullableInt(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) {
      return null;
    }

    if (value is! int) {
      throw _OcptPayloadFormatError("'$key' isn't an integer");
    }

    return value;
  }

  /// The non-null boolean stored at [key] in [json].
  static bool _bool(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! bool) {
      throw _OcptPayloadFormatError("'$key' isn't a boolean");
    }

    return value;
  }

  /// The non-null number stored at [key] in [json], as a double.
  ///
  /// A whole margin written as `1` by an older build (or by a hand-edited file) reads back as an
  /// `int`, so this accepts any [num] rather than only what `jsonEncode` writes for a double.
  static double _double(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! num) {
      throw _OcptPayloadFormatError("'$key' isn't a number");
    }

    return value.toDouble();
  }

  /// The non-null date and time stored at [key] in [json], as an ISO 8601 string.
  static DateTime _dateTime(Map<String, dynamic> json, String key) =>
      DateTime.tryParse(_string(json, key)) ??
      (throw _OcptPayloadFormatError("'$key' isn't an ISO 8601 date"));

  /// The non-null enum value stored at [key] in [json], looked up by name in [valuesByName].
  static T _enum<T extends Enum>(
    Map<String, dynamic> json,
    String key,
    Map<String, T> valuesByName,
  ) =>
      _nullableEnum(json, key, valuesByName) ??
      (throw _OcptPayloadFormatError("'$key' is missing"));

  /// The enum value stored at [key] in [json], or null when the column it mirrors was null.
  static T? _nullableEnum<T extends Enum>(
    Map<String, dynamic> json,
    String key,
    Map<String, T> valuesByName,
  ) {
    final name = _nullableString(json, key);
    if (name == null) {
      return null;
    }

    return valuesByName[name] ?? (throw _OcptPayloadFormatError("'$key' holds the unknown value "
        "'$name'"));
  }
}

/// Thrown, and caught, inside [OcptProjectVersionCodec] alone: a payload field is missing or holds
/// something other than what the format says it holds.
///
/// This never escapes [OcptProjectVersionCodec.decode], which turns it into
/// [OcptProjectVersionPayloadStatus.malformedPayload]: it exists only so the dozens of field reads
/// building a payload can stay expressions instead of each checking a result.
class _OcptPayloadFormatError implements Exception {
  /// What was wrong with the payload, for the log.
  final String reason;

  /// Class constructor
  const _OcptPayloadFormatError(this.reason);

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() => "_OcptPayloadFormatError($reason)";
}
