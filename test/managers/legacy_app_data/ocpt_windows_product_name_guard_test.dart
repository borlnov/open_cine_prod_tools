// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/legacy_app_data/ocpt_legacy_app_data_manager.dart';

/// Read the string value of a VERSIONINFO entry of `windows/runner/Runner.rc`.
String _versionInfoValue(String resource, String name) {
  final match = RegExp('VALUE "$name", "([^"]*)"').firstMatch(resource);
  expect(match, isNotNull, reason: 'Runner.rc has no $name entry');

  return match!.group(1)!;
}

/// Run the guard on the Windows application data directory name.
void main() {
  const renameReason =
      'Renaming CompanyName or ProductName moves the Windows application data directory '
      r'(%APPDATA%\<CompanyName>\<ProductName>) and leaves the preferences and secrets behind: '
      'it needs a migration, see OcptLegacyAppDataManager.';

  test('the product identity of Runner.rc is the one the migration expects', () {
    final resource = File('windows/runner/Runner.rc').readAsStringSync();

    expect(_versionInfoValue(resource, 'CompanyName'), 'com.borlnov', reason: renameReason);
    expect(
      _versionInfoValue(resource, 'ProductName'),
      'Open Cine Prod Tools',
      reason: renameReason,
    );
  });

  test('the legacy directory name is the former product name', () {
    expect(OcptLegacyAppDataManager.legacyDirectoryName, 'open_cine_prod_tools');
  });
}
