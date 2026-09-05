// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_config_manager/act_config_manager.dart';
import 'package:act_foundation/act_foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/ocpt_config_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';

void main() {
  // appLogger() (used by OcptConfigManager's own constructor) requires a global manager instance
  // to exist; merely accessing it creates the (otherwise unused) safe-logger singleton, exactly
  // the pattern OcptSpellCheckManager's own test uses.
  setUpAll(() => OcptGlobalManager.instance);

  group('OcptConfigManager.fileLogEnabled / fileLogLevel', () {
    late OcptConfigManager configManager;

    setUpAll(() async {
      configManager = OcptConfigManager();
      // Reads and merges the real assets/config/*.yaml files, exactly as the app does at start —
      // ConfigFromYamlUtility.parseFromConfigFiles loads them straight off disk through
      // rootBundle, which flutter test resolves against this repository's own assets, declared in
      // pubspec.yaml.
      await configManager.initLifeCycle();
    });

    tearDownAll(() => configManager.disposeLifeCycle());

    test('resolves to the development environment with no ENV dart-define', () {
      // No --dart-define="ENV=..." is passed to `flutter test`, so
      // Environment.fromString('') falls back to Environment.development.
      expect(configManager.env, Environment.development);
    });

    test('reads logs.file.enabled from development.yaml, merged over default.yaml', () {
      // default.yaml sets logs.file.enabled: false; development.yaml overrides it to true.
      expect(configManager.fileLogEnabled, isTrue);
    });

    test('parses logs.file.level from development.yaml, merged over default.yaml', () {
      // default.yaml sets logs.file.level: warning; development.yaml overrides it to debug.
      expect(configManager.fileLogLevel, LogsLevel.debug);
    });
  });
}
