// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:act_global_manager/act_global_manager.dart';
import 'package:act_life_cycle/act_life_cycle.dart';
import 'package:open_cine_prod_tools/managers/legacy_app_data/ocpt_legacy_app_data_migration.dart';
import 'package:open_cine_prod_tools/types/ocpt_legacy_app_data_outcome.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Build the [OcptLegacyAppDataManager] instance registered by the global manager.
class OcptLegacyAppDataManagerBuilder extends AbsLifeCycleFactory<OcptLegacyAppDataManager> {
  /// Class constructor
  const OcptLegacyAppDataManagerBuilder() : super(OcptLegacyAppDataManager.new);

  /// {@macro act_life_cycle.AbsLifeCycleFactory.dependsOn}
  @override
  Iterable<Type> dependsOn() => [];
}

/// Bring the application data of the former Windows product name over to the current one, once,
/// before anything reads it.
///
/// On Windows, `path_provider` builds the application support directory from the `CompanyName` and
/// `ProductName` of `windows/runner/Runner.rc`. Versions 0.4.0 and 0.5.0 renamed the product
/// from [legacyDirectoryName] to `Open Cine Prod Tools`, which moved the directory and left the
/// preferences and the secure storage behind. [initLifeCycle] runs
/// [OcptLegacyAppDataMigration] on that platform only; the other platforms never changed
/// directory. Any failure is logged and never blocks the start-up.
///
/// It is registered first, and the properties, secrets and file logging managers depend on it: the
/// preferences file is cached by the platform on its first read, so nothing may read it before the
/// migration has written it. The logger manager does not exist yet when it runs, so it logs
/// through `appLogger()`, the way `OcptConfigManager` does.
class OcptLegacyAppDataManager extends AbsWithLifeCycle {
  /// The name the application support directory had before the product was renamed: the sibling
  /// of the current directory the migration reads from. It is the former `ProductName` of
  /// `windows/runner/Runner.rc`, and must never change.
  static const legacyDirectoryName = 'open_cine_prod_tools';

  /// The outcome of the migration this manager ran, or null when it did not run.
  OcptLegacyAppDataOutcome? lastOutcome;

  /// The seam [initLifeCycle] reads to decide whether to migrate, true on Windows.
  final bool Function() _isWindows;

  /// The seam [initLifeCycle] resolves the current application support directory through.
  final Future<Directory> Function() _getSupportDirectory;

  /// Create the manager.
  ///
  /// [isWindows] and [getSupportDirectory] default to the real platform and
  /// `getApplicationSupportDirectory`, and let a test drive the migration on temporary
  /// directories.
  OcptLegacyAppDataManager({
    bool Function()? isWindows,
    Future<Directory> Function()? getSupportDirectory,
  }) : _isWindows = isWindows ?? (() => Platform.isWindows),
       _getSupportDirectory = getSupportDirectory ?? getApplicationSupportDirectory;

  /// {@macro act_life_cycle.MixinWithLifeCycle.initLifeCycle}
  @override
  Future<void> initLifeCycle() async {
    await super.initLifeCycle();

    if (!_isWindows()) {
      return;
    }

    final logger = appLogger();
    try {
      final currentDirectory = await _getSupportDirectory();
      final legacyDirectory = Directory(
        p.join(p.dirname(currentDirectory.path), legacyDirectoryName),
      );

      final result = await OcptLegacyAppDataMigration.run(
        legacyDirectory: legacyDirectory,
        currentDirectory: currentDirectory,
        onWarning: logger.w,
      );
      lastOutcome = result.outcome;
      logger.i('Legacy application data migration: $result');
    } on Object catch (error, stackTrace) {
      // The error of an I/O failure names a folder, which holds the user's name.
      logger.w(
        'The legacy application data migration failed: ${error.runtimeType}',
        null,
        stackTrace,
      );
    }
  }
}
