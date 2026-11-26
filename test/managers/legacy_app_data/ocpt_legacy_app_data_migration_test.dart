// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/legacy_app_data/ocpt_legacy_app_data_migration.dart';
import 'package:open_cine_prod_tools/models/ocpt_legacy_app_data_migration_result.dart';
import 'package:open_cine_prod_tools/types/ocpt_legacy_app_data_outcome.dart';
import 'package:open_cine_prod_tools/types/ocpt_legacy_file_action.dart';
import 'package:path/path.dart' as p;

/// Build the JSON-encoded recent projects value stored by the app.
String _projects(List<(String, String)> entries) => jsonEncode([
  for (final (path, date) in entries)
    {'path': path, 'name': p.basename(path), 'lastOpenedAt': date},
]);

/// Run the tests of [OcptLegacyAppDataMigration].
void main() {
  late Directory root;
  late Directory legacy;
  late Directory current;
  late List<String> warnings;

  File legacyPrefs() => File(p.join(legacy.path, 'shared_preferences.json'));
  File currentPrefs() => File(p.join(current.path, 'shared_preferences.json'));
  File legacySecrets() => File(p.join(legacy.path, 'flutter_secure_storage.dat'));
  File currentSecrets() => File(p.join(current.path, 'flutter_secure_storage.dat'));

  Map<String, Object?> readCurrent() =>
      jsonDecode(currentPrefs().readAsStringSync()) as Map<String, Object?>;

  Future<void> writeJson(File file, Map<String, Object?> content) async {
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(content));
  }

  Future<OcptLegacyAppDataMigrationResult> run() => OcptLegacyAppDataMigration.run(
    legacyDirectory: legacy,
    currentDirectory: current,
    onWarning: warnings.add,
  );

  setUp(() {
    root = Directory.systemTemp.createTempSync('ocpt_legacy_');
    legacy = Directory(p.join(root.path, 'open_cine_prod_tools'));
    current = Directory(p.join(root.path, 'Open Cine Prod Tools'));
    warnings = [];
  });

  tearDown(() => root.deleteSync(recursive: true));

  test('does nothing when the legacy directory is absent', () async {
    final result = await run();

    expect(result.outcome, OcptLegacyAppDataOutcome.nothingToMigrate);
    expect(current.existsSync(), isFalse);
  });

  test('does nothing when the marker is already stored', () async {
    await writeJson(legacyPrefs(), {'THEME': 'dark'});
    await writeJson(currentPrefs(), {OcptLegacyAppDataMigration.markerKey: true});

    final result = await run();

    expect(result.outcome, OcptLegacyAppDataOutcome.alreadyMigrated);
    expect(readCurrent().containsKey('THEME'), isFalse);
  });

  test('copies the legacy preferences and writes the marker', () async {
    await writeJson(legacyPrefs(), {'THEME': 'dark', 'ZOOM': 1.5});

    final result = await run();

    expect(result.outcome, OcptLegacyAppDataOutcome.migrated);
    expect(result.preferences, OcptLegacyFileAction.copied);
    expect(result.secrets, OcptLegacyFileAction.absent);
    expect(readCurrent(), {
      'THEME': 'dark',
      'ZOOM': 1.5,
      OcptLegacyAppDataMigration.markerKey: true,
    });
  });

  test('is not repeated once done', () async {
    await writeJson(legacyPrefs(), {'THEME': 'dark'});
    await run();
    await writeJson(legacyPrefs(), {'THEME': 'light'});

    final result = await run();

    expect(result.outcome, OcptLegacyAppDataOutcome.alreadyMigrated);
    expect(readCurrent()['THEME'], 'dark');
  });

  test('merges: the current value wins, the legacy only keys are added', () async {
    await writeJson(legacyPrefs(), {'THEME': 'dark', 'LANG': 'fr', 'ZOOM': 2});
    await writeJson(currentPrefs(), {'THEME': 'light', 'DEVICE_ID': 'abc'});

    final result = await run();

    expect(result.preferences, OcptLegacyFileAction.merged);
    expect(readCurrent(), {
      'THEME': 'light',
      'LANG': 'fr',
      'ZOOM': 2,
      'DEVICE_ID': 'abc',
      OcptLegacyAppDataMigration.markerKey: true,
    });
  });

  test('merges the recent projects by path, newest first, current wins', () async {
    await writeJson(legacyPrefs(), {
      'RECENT_PROJECTS': _projects([
        ('/a', '2026-01-01T00:00:00.000'),
        ('/b', '2026-03-01T00:00:00.000'),
      ]),
    });
    await writeJson(currentPrefs(), {
      'RECENT_PROJECTS': _projects([
        ('/b', '2026-02-01T00:00:00.000'),
        ('/c', '2026-04-01T00:00:00.000'),
      ]),
    });

    await run();

    final merged = jsonDecode(readCurrent()['RECENT_PROJECTS']! as String) as List<dynamic>;
    expect(merged.map((e) => (e as Map)['path']), ['/c', '/b', '/a']);
    expect((merged[1] as Map)['lastOpenedAt'], '2026-02-01T00:00:00.000');
  });

  test('caps the merged recent projects at ten', () async {
    await writeJson(legacyPrefs(), {
      'RECENT_PROJECTS': _projects([
        for (var i = 0; i < 8; i++) ('/l$i', '2026-01-0${i + 1}T00:00:00.000'),
      ]),
    });
    await writeJson(currentPrefs(), {
      'RECENT_PROJECTS': _projects([
        for (var i = 0; i < 8; i++) ('/c$i', '2026-02-0${i + 1}T00:00:00.000'),
      ]),
    });

    await run();

    final merged = jsonDecode(readCurrent()['RECENT_PROJECTS']! as String) as List<dynamic>;
    expect(merged, hasLength(10));
    expect((merged.first as Map)['path'], '/c7');
    expect((merged.last as Map)['path'], '/l6');
  });

  test('keeps the current recent projects when the legacy value is not a list', () async {
    await writeJson(legacyPrefs(), {'RECENT_PROJECTS': 'not json'});
    final value = _projects([('/c', '2026-02-01T00:00:00.000')]);
    await writeJson(currentPrefs(), {'RECENT_PROJECTS': value});

    final result = await run();

    expect(result.outcome, OcptLegacyAppDataOutcome.migrated);
    expect(readCurrent()['RECENT_PROJECTS'], value);
  });

  test('copies the secure storage when the current directory has none', () async {
    await legacySecrets().parent.create(recursive: true);
    await legacySecrets().writeAsBytes([1, 2, 3]);

    final result = await run();

    expect(result.secrets, OcptLegacyFileAction.copied);
    expect(currentSecrets().readAsBytesSync(), [1, 2, 3]);
    expect(result.preferences, OcptLegacyFileAction.absent);
    expect(readCurrent()[OcptLegacyAppDataMigration.markerKey], true);
  });

  test('keeps the current secure storage and warns when both exist', () async {
    await legacySecrets().parent.create(recursive: true);
    await legacySecrets().writeAsBytes([1, 2, 3]);
    await current.create(recursive: true);
    await currentSecrets().writeAsBytes([9]);

    final result = await run();

    expect(result.secrets, OcptLegacyFileAction.keptCurrent);
    expect(currentSecrets().readAsBytesSync(), [9]);
    expect(warnings, hasLength(1));
  });

  test('a malformed legacy preferences file writes nothing, marker included', () async {
    await legacyPrefs().parent.create(recursive: true);
    await legacyPrefs().writeAsString('{ nope');
    await legacySecrets().writeAsBytes([7]);

    final result = await run();

    expect(result.outcome, OcptLegacyAppDataOutcome.failed);
    expect(result.preferences, OcptLegacyFileAction.unreadable);
    expect(currentPrefs().existsSync(), isFalse);
    expect(result.secrets, OcptLegacyFileAction.copied);
    expect(warnings, isNotEmpty);
  });

  test('a malformed current preferences file is left as it is', () async {
    await writeJson(legacyPrefs(), {'THEME': 'dark'});
    await current.create(recursive: true);
    await currentPrefs().writeAsString('[1, 2]');

    final result = await run();

    expect(result.outcome, OcptLegacyAppDataOutcome.failed);
    expect(currentPrefs().readAsStringSync(), '[1, 2]');
  });

  test('never modifies the legacy directory', () async {
    await writeJson(legacyPrefs(), {'THEME': 'dark'});
    await legacySecrets().writeAsBytes([1]);
    final before = legacyPrefs().readAsStringSync();

    await run();

    expect(legacyPrefs().readAsStringSync(), before);
    expect(legacySecrets().readAsBytesSync(), [1]);
    expect(legacy.listSync(), hasLength(2));
  });
}
