// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';
import 'dart:io';

import 'package:act_dart_result/act_dart_result.dart';
import 'package:archive/archive_io.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_project_package_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_project_version_codec.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_package_report.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_version_payload.dart';
import 'package:open_cine_prod_tools/types/ocpt_asset_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_image_rights_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_package_status.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

void main() {
  // The service reports its soft failures through appLogger(), which requires a global manager
  // instance to be set; merely accessing it creates the (otherwise unused) singleton.
  setUpAll(() => OcptGlobalManager.instance);

  const service = OcptProjectPackageService();
  const codec = OcptProjectVersionCodec();

  late Directory workspace;
  late String projectPath;
  late String packagePath;
  late OcptProjectDatabase database;

  /// Writes [contents] to a file called [name] in the workspace, and returns its absolute path.
  String writeReferencedFile(String name, String contents) {
    final file = File(p.join(workspace.path, "files", name))..createSync(recursive: true);
    file.writeAsStringSync(contents);
    return file.path;
  }

  /// A payload holding the one person [personId], with everything they carry.
  String encodedPayloadHolding(String personId) => codec.encode(
    OcptProjectVersionPayload(
      screenplays: const [],
      scenes: const [],
      shots: const [],
      shotCharacters: const [],
      shotCoverages: const [],
      people: [
        OcptPersonRow(
          id: personId,
          sortKey: "V",
          isDeleted: false,
          firstName: "Clara",
          lastName: "Martin",
          email: "clara@example.com",
          phone: "0102030405",
          addressLine1: "12 rue des Lilas",
          addressLine2: "",
          postalCode: "75011",
          city: "Paris",
          region: "",
          country: "France",
          colorIndex: 2,
          minorNotes: "",
          accommodationNotes: "",
          travelNotes: "",
          dietaryNotes: "",
          allergies: "Peanuts",
          measurementHeight: "",
          measurementChest: "",
          measurementWaist: "",
          measurementHips: "",
          sizeTop: "",
          sizeBottom: "",
          sizeShoes: "",
          hmcNotes: "",
          imageRightsStatus: OcptImageRightsStatus.signed,
          notes: "Lead actress",
        ),
      ],
      personPositions: const [],
      personSkills: const [],
      personUnavailabilities: const [],
      roles: const [],
      roleEpisodes: const [],
      locations: const [],
      locationAvailabilities: const [],
      sets: const [],
      sceneSets: const [],
      elements: const [],
      sceneElements: const [],
      roleElements: const [],
      assets: const [],
      breakdownTags: const [],
      sceneBreakdowns: const [],
      shootingDays: const [],
      shootingSlots: const [],
      shootingSlotCrew: const [],
      shootingSlotCast: const [],
      shootingDayBlocks: const [],
      shootingSlotGuests: const [],
      shootingDayEvents: const [],
      projectDictionaryWords: const [],
      rowFieldVersions: const [],
      pageSetup: const OcptPageSetup(
        format: OcptPageFormat.a4,
        margins: FountainPageMargins(
          leftInches: 1.5,
          rightInches: 1,
          topInches: 0.75,
          bottomInches: 1.25,
        ),
      ),
      settingsJson: null,
      currencyCode: "EUR",
      minimumRestMinutes: null,
      screenplayLanguage: null,
    ),
  );

  setUp(() async {
    workspace = Directory.systemTemp.createTempSync("ocpt_package_test_");
    projectPath = p.join(workspace.path, "project.ocpt");
    packagePath = p.join(workspace.path, "sent", "Les Vagues.ocptz");

    database = OcptProjectDatabase(File(projectPath));
    await database
        .into(database.ocptProjectInfoTable)
        .insert(
          OcptProjectInfoTableCompanion.insert(
            name: "Les Vagues",
            createdAt: DateTime.utc(2026),
            appVersionAtCreation: "0.1.0",
            pageFormat: OcptPageFormat.a4,
          ),
        );
  });

  tearDown(() async {
    await database.close();
    workspace.deleteSync(recursive: true);
  });

  /// The bytes of the entry [name] of the package at [packagePath].
  List<int> packagedEntryBytes(String name) {
    final archive = ZipDecoder().decodeStream(InputFileStream(packagePath));
    return archive.files.firstWhere((file) => file.name == name).readBytes()!;
  }

  /// Opens the `.ocpt` the package at [packagePath] carries, unpacked into its own folder.
  ///
  /// The archive is read entry by entry rather than through `extractFileToDisk`, which refuses a
  /// path it cannot recognise by extension — and `.ocptz` is exactly that.
  Database packagedDatabase() {
    final unpacked = Directory(p.join(workspace.path, "unpacked"))..createSync(recursive: true);
    final databasePath = p.join(unpacked.path, "project.ocpt");
    File(databasePath).writeAsBytesSync(packagedEntryBytes("project.ocpt"));
    return sqlite3.open(databasePath, mode: OpenMode.readOnly);
  }

  /// The manifest the package at [packagePath] carries.
  Map<String, dynamic> packagedManifest() =>
      jsonDecode(utf8.decode(packagedEntryBytes("manifest.json"))) as Map<String, dynamic>;

  /// Every entry name the package at [packagePath] holds.
  Set<String> packagedEntries() =>
      ZipDecoder().decodeStream(InputFileStream(packagePath)).files.map((f) => f.name).toSet();

  /// Adds an asset row referencing [path].
  Future<void> addAsset({
    required String id,
    required String path,
    String label = "",
    String? personId,
    String? locationId,
    bool isDeleted = false,
  }) => database
      .into(database.ocptAssetsTable)
      .insert(
        OcptAssetsTableCompanion.insert(
          id: id,
          kind: personId != null ? OcptAssetKind.document : OcptAssetKind.locationPhoto,
          path: path,
          label: Value(label),
          addedAt: DateTime.utc(2026, 2, 2),
          personId: Value(personId),
          locationId: Value(locationId),
          isDeleted: Value(isDeleted),
        ),
      );

  /// Adds the person [id], so an `assets.personId` has something to point at.
  Future<void> addPerson(String id) =>
      database.into(database.ocptPeopleTable).insert(OcptPeopleTableCompanion.insert(id: id));

  /// Writes the package, and returns what the service reported about it.
  Future<ResultWithStatus<OcptProjectPackageStatus, OcptProjectPackageExportReport>> export() =>
      service.writePackage(
        projectFilePath: projectPath,
        packageFilePath: packagePath,
        projectName: "Les Vagues",
        appVersion: "0.1.0",
        exportedAt: DateTime.utc(2026, 8, 19, 14),
      );

  group("scanning before writing", () {
    test("reports a referenced file that is gone, and counts the ones that are not", () async {
      await addPerson("person-1");
      await addAsset(id: "asset-1", path: writeReferencedFile("headshot.jpg", "photo"));
      await addAsset(
        id: "asset-2",
        path: p.join(workspace.path, "files", "gone.pdf"),
        label: "Autorisation mairie",
        personId: "person-1",
      );

      final preflight = service.scanAssets(projectFilePath: projectPath)!;

      expect(preflight.referencedAssetCount, 2);
      expect(preflight.isComplete, isFalse);
      expect(preflight.missingAssets.map((asset) => asset.assetId), ["asset-2"]);
      expect(preflight.missingAssets.single.label, "Autorisation mairie");
    });

    test("says nothing is missing when every reference resolves", () async {
      await addAsset(id: "asset-1", path: writeReferencedFile("headshot.jpg", "photo"));

      final preflight = service.scanAssets(projectFilePath: projectPath)!;

      expect(preflight.isComplete, isTrue);
      expect(preflight.referencedAssetCount, 1);
    });

    test("ignores a tombstoned row, which references nothing any more", () async {
      await addAsset(
        id: "asset-1",
        path: p.join(workspace.path, "files", "gone.pdf"),
        isDeleted: true,
      );

      final preflight = service.scanAssets(projectFilePath: projectPath)!;

      expect(preflight.referencedAssetCount, 0);
      expect(preflight.isComplete, isTrue);
    });

    test("returns null for a file that is not a project at all", () {
      final notAProject = p.join(workspace.path, "notes.txt");
      File(notAProject).writeAsStringSync("this is not a database");

      expect(service.scanAssets(projectFilePath: notAProject), isNull);
    });
  });

  group("writing a package", () {
    test("carries the database and every file that still exists", () async {
      await addAsset(id: "asset-1", path: writeReferencedFile("headshot.jpg", "the photo bytes"));
      await addAsset(id: "asset-2", path: writeReferencedFile("permit.pdf", "the permit bytes"));

      final exported = await export();

      expect(exported.status, OcptProjectPackageStatus.ok);
      expect(File(packagePath).existsSync(), isTrue);
      expect(exported.value!.packagedAssetCount, 2);
      expect(exported.value!.skippedAssets, isEmpty);
      expect(
        packagedEntries(),
        containsAll(<String>[
          "manifest.json",
          "project.ocpt",
          "assets/asset-1/headshot.jpg",
          "assets/asset-2/permit.pdf",
        ]),
      );
    });

    test("rewrites a packaged asset onto its entry inside the package", () async {
      final originalPath = writeReferencedFile("headshot.jpg", "the photo bytes");
      await addAsset(id: "asset-1", path: originalPath);

      await export();

      final packaged = packagedDatabase();
      addTearDown(packaged.dispose);
      final path = packaged.select("SELECT path FROM assets WHERE id = 'asset-1'").first["path"];

      // A path travelling verbatim would leak the exporter's home directory layout, and would
      // resolve to nothing on the other machine anyway.
      expect(path, "assets/asset-1/headshot.jpg");
      expect(path, isNot(contains(workspace.path)));
    });

    test("skips a missing file, reports it, and leaves its row naming what is gone", () async {
      final missingPath = p.join(workspace.path, "files", "gone.pdf");
      await addAsset(id: "asset-1", path: writeReferencedFile("headshot.jpg", "photo"));
      await addAsset(id: "asset-2", path: missingPath, label: "Autorisation mairie");

      final exported = await export();

      expect(exported.status, OcptProjectPackageStatus.ok);
      expect(exported.value!.packagedAssetCount, 1);
      expect(exported.value!.skippedAssets.single.assetId, "asset-2");
      expect(packagedManifest()["skippedAssets"], hasLength(1));

      final packaged = packagedDatabase();
      addTearDown(packaged.dispose);
      // The report has to be able to name *which* file is missing, on either machine.
      expect(
        packaged.select("SELECT path FROM assets WHERE id = 'asset-2'").first["path"],
        missingPath,
      );
    });

    test("states its own format, the app version and the schema the file is in", () async {
      await export();

      final manifest = packagedManifest();

      expect(manifest["packageFormat"], 1);
      expect(manifest["appVersion"], "0.1.0");
      expect(manifest["projectName"], "Les Vagues");
      expect(manifest["schemaVersion"], database.schemaVersion);
      expect(manifest["exportedAt"], DateTime.utc(2026, 8, 19, 14).toIso8601String());
    });

    test("carries the database at the schema version it was in, unmigrated", () async {
      await export();

      final packaged = packagedDatabase();
      addTearDown(packaged.dispose);

      expect(packaged.select("PRAGMA user_version").first.values.first, database.schemaVersion);
    });

    test("never writes to the project it copies", () async {
      await addAsset(id: "asset-1", path: writeReferencedFile("headshot.jpg", "photo"));
      // Force whatever the drift connection still holds out to the file, so the comparison is
      // about the export rather than about a pending write landing mid-test.
      await database.customStatement("PRAGMA wal_checkpoint(TRUNCATE)");
      final before = File(projectPath).readAsBytesSync();

      await export();

      expect(File(projectPath).readAsBytesSync(), before);
    });

    test("refuses a source that is not there", () async {
      final result = await service.writePackage(
        projectFilePath: p.join(workspace.path, "nowhere.ocpt"),
        packageFilePath: packagePath,
        projectName: "Les Vagues",
        appVersion: "0.1.0",
        exportedAt: DateTime.utc(2026, 8, 19),
      );

      expect(result.status, OcptProjectPackageStatus.sourceNotFound);
      expect(File(packagePath).existsSync(), isFalse);
    });
  });

  group("what an erased person leaves behind", () {
    /// Erases [personId], and seals a version whose payload still holds them in full.
    Future<void> sealVersionThenErase(String personId) async {
      await addPerson(personId);
      await database
          .into(database.ocptProjectVersionsTable)
          .insert(
            OcptProjectVersionsTableCompanion.insert(
              id: "version-1",
              name: "Before the shoot",
              createdAt: DateTime.utc(2026, 3),
              appVersion: "0.1.0",
              payloadFormat: OcptProjectVersionCodec.currentPayloadFormat,
              payload: encodedPayloadHolding(personId),
              summaryJson: "{}",
              createdByDeviceId: "device-1",
              contentDigest: const Value("a-digest-of-the-payload-as-it-was"),
            ),
          );
      await database
          .into(database.ocptLocalErasuresTable)
          .insert(
            OcptLocalErasuresTableCompanion.insert(
              personId: personId,
              erasedAt: DateTime.utc(2026, 4),
            ),
          );
    }

    test("the packaged database carries no erasure list at all", () async {
      await sealVersionThenErase("person-1");

      await export();

      final packaged = packagedDatabase();
      addTearDown(packaged.dispose);
      expect(packaged.select("SELECT * FROM local_erasures"), isEmpty);
    });

    test("a version sealed before the erasure travels with the person taken out of it", () async {
      await sealVersionThenErase("person-1");

      await export();

      final packaged = packagedDatabase();
      addTearDown(packaged.dispose);
      final row = packaged.select("SELECT payload FROM project_versions").first;
      final payload = jsonDecode(row["payload"] as String) as Map<String, dynamic>;
      final person = (payload["people"] as List<dynamic>).first as Map<String, dynamic>;

      // Shipping the erasure list instead of applying it would leave the phone number, the address
      // and the allergies of somebody who asked to be removed one sqlite3 prompt away.
      expect(person["firstName"], "");
      expect(person["lastName"], "");
      expect(person["phone"], "");
      expect(person["allergies"], "");
      expect(person["isDeleted"], isTrue);
      expect(row["payload"] as String, isNot(contains("Clara")));
      expect(row["payload"] as String, isNot(contains("Peanuts")));
    });

    test("a rewritten version loses its digest, which no longer describes it", () async {
      await sealVersionThenErase("person-1");

      await export();

      final packaged = packagedDatabase();
      addTearDown(packaged.dispose);

      expect(
        packaged.select("SELECT content_digest FROM project_versions").first["content_digest"],
        isNull,
      );
    });

    test("a project nobody was erased from travels with its digests intact", () async {
      await addPerson("person-1");
      await database
          .into(database.ocptProjectVersionsTable)
          .insert(
            OcptProjectVersionsTableCompanion.insert(
              id: "version-1",
              name: "Before the shoot",
              createdAt: DateTime.utc(2026, 3),
              appVersion: "0.1.0",
              payloadFormat: OcptProjectVersionCodec.currentPayloadFormat,
              payload: encodedPayloadHolding("person-1"),
              summaryJson: "{}",
              createdByDeviceId: "device-1",
              contentDigest: const Value("a-digest-of-the-payload-as-it-was"),
            ),
          );

      await export();

      final packaged = packagedDatabase();
      addTearDown(packaged.dispose);
      final row = packaged.select("SELECT payload, content_digest FROM project_versions").first;

      expect(row["content_digest"], "a-digest-of-the-payload-as-it-was");
      expect(row["payload"] as String, contains("Clara"));
    });
  });
}
