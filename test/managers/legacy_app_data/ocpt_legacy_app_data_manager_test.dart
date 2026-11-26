// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/legacy_app_data/ocpt_legacy_app_data_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/types/ocpt_legacy_app_data_outcome.dart';
import 'package:path/path.dart' as p;

/// Run the tests of [OcptLegacyAppDataManager].
void main() {
  // appLogger() needs a global manager instance to exist.
  setUpAll(() => OcptGlobalManager.instance);

  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('ocpt_legacy_manager_');
    final legacy = Directory(p.join(root.path, 'open_cine_prod_tools'))..createSync();
    File(p.join(legacy.path, 'flutter_secure_storage.dat')).writeAsBytesSync([1]);
  });

  tearDown(() => root.deleteSync(recursive: true));

  test('migrates from the sibling directory on Windows', () async {
    final current = Directory(p.join(root.path, 'Open Cine Prod Tools'));
    final manager = OcptLegacyAppDataManager(
      isWindows: () => true,
      getSupportDirectory: () async => current,
    );

    await manager.initLifeCycle();

    expect(manager.lastOutcome, OcptLegacyAppDataOutcome.migrated);
    expect(File(p.join(current.path, 'flutter_secure_storage.dat')).existsSync(), isTrue);
  });

  test('does nothing on another platform', () async {
    final current = Directory(p.join(root.path, 'Open Cine Prod Tools'));
    final manager = OcptLegacyAppDataManager(
      isWindows: () => false,
      getSupportDirectory: () async => current,
    );

    await manager.initLifeCycle();

    expect(manager.lastOutcome, isNull);
    expect(current.existsSync(), isFalse);
  });

  test('a failing support directory does not throw', () async {
    final manager = OcptLegacyAppDataManager(
      isWindows: () => true,
      getSupportDirectory: () async => throw const FileSystemException('boom'),
    );

    await manager.initLifeCycle();

    expect(manager.lastOutcome, isNull);
  });
}
