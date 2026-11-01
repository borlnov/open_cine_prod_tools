// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';
import 'dart:typed_data';

import 'package:act_test_utility/act_test_utility.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:ocpt_sync_protocol/ocpt_sync_protocol.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_snapshot_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_status.dart';
import 'package:path/path.dart' as p;

/// Run the tests of [OcptSnapshotService].
void main() {
  // OcptProjectPackageService reports its soft failures through appLogger(), which requires a
  // global manager instance to be set; merely accessing it creates the (otherwise unused)
  // singleton, exactly as the package service's own test does.
  setUpAll(() => OcptGlobalManager.instance);

  final service = OcptSnapshotService(logger: const SilentLogger());

  late Directory workspace;
  late String projectPath;

  setUp(() async {
    workspace = Directory.systemTemp.createTempSync('ocpt_snapshot_service_test_');
    projectPath = p.join(workspace.path, 'project.ocpt');

    final database = OcptProjectDatabase(File(projectPath));
    await database
        .into(database.ocptProjectInfoTable)
        .insert(
          OcptProjectInfoTableCompanion.insert(
            name: 'Les Vagues',
            createdAt: DateTime.utc(2026),
            appVersionAtCreation: '0.1.0',
            pageFormat: OcptPageFormat.a4,
          ),
        );
    await database
        .into(database.ocptScreenplaysTable)
        .insert(
          OcptScreenplaysTableCompanion.insert(
            id: 'screenplay-1',
            title: 'Draft',
            fountainText: const Value('INT. HOUSE - DAY\n\nA quiet morning.'),
            updatedAt: DateTime.utc(2026),
          ),
        );
    await database.close();
  });

  tearDown(() async {
    workspace.deleteSync(recursive: true);
  });

  Future<(OcptSnapshotDescriptor, Uint8List)> build() async {
    final built = await service.buildSnapshot(
      projectFilePath: projectPath,
      projectName: 'Les Vagues',
      appVersion: '0.1.0',
      sequenceUpTo: const OcptSequenceNumber(4),
      exportedAt: DateTime.utc(2026, 8, 19, 14),
    );
    expect(built.status, OcptSnapshotStatus.ok);

    return built.value!;
  }

  group('buildSnapshot', () {
    test('describes the bytes it returns', () async {
      final (descriptor, bytes) = await build();

      expect(descriptor.sequenceUpTo, const OcptSequenceNumber(4));
      expect(descriptor.byteLength, bytes.length);
      expect(descriptor.contentDigest, sha256.convert(bytes).toString());
      expect(descriptor.snapshotId, isNotEmpty);
    });

    test('mints a fresh snapshot id on every call, even for identical content', () async {
      final (first, _) = await build();
      final (second, _) = await build();

      expect(first.snapshotId, isNot(second.snapshotId));
    });

    test('answers a packaging failure as a status when the project file is missing', () async {
      final built = await service.buildSnapshot(
        projectFilePath: p.join(workspace.path, 'missing.ocpt'),
        projectName: 'Les Vagues',
        appVersion: '0.1.0',
        sequenceUpTo: const OcptSequenceNumber(4),
      );

      expect(built.status, OcptSnapshotStatus.packageFailed);
      expect(built.value, isNull);
    });

    test('leaves no scratch file behind', () async {
      await build();

      expect(workspace.listSync(recursive: true).whereType<File>().map((f) => p.basename(f.path)), [
        'project.ocpt',
      ]);
    });
  });

  group('applySnapshot', () {
    test(
      'materialises a project carrying the same content, under a fresh parent directory',
      () async {
        final (descriptor, bytes) = await build();
        final parentDirectory = Directory(p.join(workspace.path, 'joined'))..createSync();

        final applied = await service.applySnapshot(
          bytes: bytes,
          parentDirectoryPath: parentDirectory.path,
          descriptor: descriptor,
        );
        expect(applied.status, OcptSnapshotStatus.ok);
        final materialisedPath = applied.value!;

        expect(File(materialisedPath).existsSync(), isTrue);
        expect(materialisedPath, isNot(projectPath));

        final materialised = OcptProjectDatabase(File(materialisedPath));
        addTearDown(materialised.close);
        final info = await materialised.select(materialised.ocptProjectInfoTable).getSingle();
        expect(info.name, 'Les Vagues');
        final screenplay = await materialised.select(materialised.ocptScreenplaysTable).getSingle();
        expect(screenplay.fountainText, 'INT. HOUSE - DAY\n\nA quiet morning.');
      },
    );

    test('accepts bytes with no descriptor to verify against', () async {
      final (_, bytes) = await build();
      final parentDirectory = Directory(p.join(workspace.path, 'joined-no-descriptor'))
        ..createSync();

      final applied = await service.applySnapshot(
        bytes: bytes,
        parentDirectoryPath: parentDirectory.path,
      );

      expect(applied.status, OcptSnapshotStatus.ok);
      expect(File(applied.value!).existsSync(), isTrue);
    });

    test('refuses bytes that do not match the given descriptor', () async {
      final (descriptor, bytes) = await build();
      final tamperedDescriptor = OcptSnapshotDescriptor(
        snapshotId: descriptor.snapshotId,
        sequenceUpTo: descriptor.sequenceUpTo,
        byteLength: descriptor.byteLength,
        contentDigest: 'not-the-real-digest',
      );
      final parentDirectory = Directory(p.join(workspace.path, 'tampered'))..createSync();

      final applied = await service.applySnapshot(
        bytes: bytes,
        parentDirectoryPath: parentDirectory.path,
        descriptor: tamperedDescriptor,
      );

      expect(applied.status, OcptSnapshotStatus.digestMismatch);
      expect(applied.value, isNull);
      expect(parentDirectory.listSync(), isEmpty);
    });

    test('answers an unreadable package as a status', () async {
      final garbage = Uint8List.fromList([1, 2, 3, 4]);
      final parentDirectory = Directory(p.join(workspace.path, 'garbage'))..createSync();

      final applied = await service.applySnapshot(
        bytes: garbage,
        parentDirectoryPath: parentDirectory.path,
      );

      expect(applied.status, OcptSnapshotStatus.packageFailed);
      expect(parentDirectory.listSync(), isEmpty);
    });
  });
}
