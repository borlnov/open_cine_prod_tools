// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:act_foundation/act_foundation.dart';
import 'package:act_logger_manager/act_logger_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/logging/ocpt_file_external_logger.dart';
import 'package:open_cine_prod_tools/managers/logging/ocpt_file_logging_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_config_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';

/// A fake [OcptConfigManager] whose `logs.file.*` getters are overridden directly rather than
/// loaded from real config assets — [OcptFileLoggingManager]'s own tests only care about how it
/// reacts to those two values, not how they get parsed (`ocpt_config_manager_test.dart` covers
/// that).
class _FakeConfigManager extends OcptConfigManager {
  /// Class constructor
  _FakeConfigManager({required bool fileLogEnabled, LogsLevel fileLogLevel = LogsLevel.info})
    : _fileLogEnabled = fileLogEnabled,
      _fileLogLevel = fileLogLevel;

  final bool _fileLogEnabled;
  final LogsLevel _fileLogLevel;

  @override
  bool get fileLogEnabled => _fileLogEnabled;

  @override
  LogsLevel get fileLogLevel => _fileLogLevel;
}

/// A [LoggerManager] recording every `addExternalLogger`/`removeExternalLogger` call instead of
/// reaching into the real `LoggerSingleton`, so [OcptFileLoggingManager] can be exercised without a
/// fully booted logging stack underneath it. Mirrors `MultiExternalLogger`'s own contract just
/// enough for these tests: adding calls the logger's own `initLifeCycle`, removing disposes it —
/// the [OcptFileExternalLogger] under test starts real timers that must be cancelled before a
/// test's temporary directory is deleted underneath them.
class _RecordingLoggerManager extends LoggerManager {
  /// Class constructor
  ///
  /// [loggerConfigGetter] is never actually called: this class overrides every method of
  /// [LoggerManager] that would otherwise reach for it (`initLifeCycle` is never invoked on this
  /// fake by these tests).
  _RecordingLoggerManager() : super(loggerConfigGetter: () => throw UnimplementedError());

  /// Every logger added so far, keyed by the key it was added under.
  final Map<Enum, MixinExternalLogger> added = {};

  /// Every key a logger was removed from.
  final List<Enum> removed = [];

  @override
  Future<void> addExternalLogger(Enum loggerKey, MixinExternalLogger externalLogger) async {
    await removeExternalLogger(loggerKey);
    await externalLogger.initLifeCycle();
    added[loggerKey] = externalLogger;
  }

  @override
  Future<void> removeExternalLogger(Enum loggerKey) async {
    removed.add(loggerKey);
    await added.remove(loggerKey)?.disposeLifeCycle();
  }
}

void main() {
  // appLogger() (used on a caught setup failure) requires a global manager instance to exist;
  // merely accessing it creates the (otherwise unused) safe-logger singleton, exactly the pattern
  // OcptSpellCheckManager's own test uses.
  setUpAll(() => OcptGlobalManager.instance);

  group('OcptFileLoggingManager, config enabled', () {
    late Directory tempDir;
    late _RecordingLoggerManager loggerManager;
    late OcptFileLoggingManager manager;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('ocpt_file_logging_manager_test_');
      loggerManager = _RecordingLoggerManager();
      manager = OcptFileLoggingManager(
        configManager: _FakeConfigManager(fileLogEnabled: true, fileLogLevel: LogsLevel.debug),
        loggerManager: loggerManager,
        resolveLogDirectoryPath: () async => tempDir.path,
      );
      await manager.initLifeCycle();
    });

    tearDown(() async {
      await manager.disposeLifeCycle();
      await tempDir.delete(recursive: true);
    });

    test('registers a file external logger under the file key', () {
      expect(loggerManager.added.keys, contains(OcptExternalLoggerKey.file));
      expect(loggerManager.added[OcptExternalLoggerKey.file], isA<OcptFileExternalLogger>());
    });

    test('the registered logger writes under the resolved directory, at the configured level', () {
      final fileLogger =
          loggerManager.added[OcptExternalLoggerKey.file]! as OcptFileExternalLogger;

      expect(fileLogger.logDirectoryPath, tempDir.path);
      expect(fileLogger.minLevel, LogsLevel.debug);
    });

    test('exposes the resolved log file path', () {
      expect(manager.logFilePath, isNotNull);
      expect(manager.logFilePath, contains(tempDir.path));
    });

    test('disposeLifeCycle removes the registered logger', () async {
      await manager.disposeLifeCycle();

      expect(loggerManager.removed, contains(OcptExternalLoggerKey.file));
    });
  });

  group('OcptFileLoggingManager, config disabled', () {
    test('registers no logger and exposes no log file path', () async {
      final loggerManager = _RecordingLoggerManager();
      final manager = OcptFileLoggingManager(
        configManager: _FakeConfigManager(fileLogEnabled: false),
        loggerManager: loggerManager,
        resolveLogDirectoryPath: () async => throw StateError('should not be reached'),
      );

      await manager.initLifeCycle();

      expect(loggerManager.added, isEmpty);
      expect(manager.logFilePath, isNull);

      await manager.disposeLifeCycle();
    });
  });

  group('OcptFileLoggingManager, config enabled on a mobile platform', () {
    test('registers no logger: a phone never writes a log file even where config enables it', () async {
      final loggerManager = _RecordingLoggerManager();
      final manager = OcptFileLoggingManager(
        configManager: _FakeConfigManager(fileLogEnabled: true, fileLogLevel: LogsLevel.debug),
        loggerManager: loggerManager,
        resolveLogDirectoryPath: () async => throw StateError('should not be reached'),
        isDesktopPlatform: () => false,
      );

      await manager.initLifeCycle();

      expect(loggerManager.added, isEmpty);
      expect(manager.logFilePath, isNull);

      await manager.disposeLifeCycle();
    });
  });

  group('OcptFileLoggingManager, log directory resolution failure', () {
    test('is swallowed: no logger is registered and initLifeCycle does not throw', () async {
      final loggerManager = _RecordingLoggerManager();
      final manager = OcptFileLoggingManager(
        configManager: _FakeConfigManager(fileLogEnabled: true),
        loggerManager: loggerManager,
        resolveLogDirectoryPath: () async => throw const FileSystemException('read-only file system'),
      );

      await manager.initLifeCycle();

      expect(loggerManager.added, isEmpty);
      expect(manager.logFilePath, isNull);

      await manager.disposeLifeCycle();
    });
  });
}
