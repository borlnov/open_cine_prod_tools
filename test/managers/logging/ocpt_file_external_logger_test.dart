// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:act_foundation/act_foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/logging/ocpt_file_external_logger.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('ocpt_file_external_logger_test_');
  });

  tearDown(() => tempDir.delete(recursive: true));

  /// Builds an [OcptFileExternalLogger] writing under [tempDir], initialised and registered to be
  /// disposed at the end of the running test — every test needs this pairing, since the
  /// `AdvancedFileOutput` behind it starts real timers that must be cancelled (by
  /// `disposeLifeCycle`) before `tearDown` deletes [tempDir] out from under a still-live one.
  Future<OcptFileExternalLogger> buildAndInitLogger({LogsLevel minLevel = LogsLevel.info}) async {
    final logger = OcptFileExternalLogger(logDirectoryPath: tempDir.path, minLevel: minLevel);
    await logger.initLifeCycle();
    addTearDown(logger.disposeLifeCycle);

    return logger;
  }

  group('OcptFileExternalLogger.logFilePath / logDirectoryPath', () {
    test('exposes the resolved path of the file it writes to', () async {
      final logger = await buildAndInitLogger();

      expect(logger.logDirectoryPath, tempDir.path);
      expect(logger.logFilePath, p.join(tempDir.path, 'ocpt.log'));
    });
  });

  group('OcptFileExternalLogger.minLevel', () {
    test('starts at the level passed to the constructor', () async {
      final logger = await buildAndInitLogger(minLevel: LogsLevel.warn);

      expect(logger.minLevel, LogsLevel.warn);
    });

    test('can be changed after construction', () async {
      final logger = await buildAndInitLogger(minLevel: LogsLevel.warn);

      logger.minLevel = LogsLevel.error;

      expect(logger.minLevel, LogsLevel.error);
    });
  });

  group('OcptFileExternalLogger.wouldBeLogged', () {
    test('is true at or above minLevel, false below it', () async {
      final logger = await buildAndInitLogger(minLevel: LogsLevel.warn);

      expect(logger.wouldBeLogged(level: LogsLevel.warn), isTrue);
      expect(logger.wouldBeLogged(level: LogsLevel.error), isTrue);
      expect(logger.wouldBeLogged(level: LogsLevel.debug), isFalse);
    });
  });

  group('OcptFileExternalLogger.log', () {
    test('writes an at-or-above-minLevel line, and skips a below-minLevel one', () async {
      final logger = await buildAndInitLogger(minLevel: LogsLevel.warn);

      // The default writeImmediately levels of the underlying AdvancedFileOutput include warning,
      // so this line reaches disk without waiting on its buffered flush timer.
      logger.log(message: 'a warning line', level: LogsLevel.warn);
      logger.log(message: 'a debug line', level: LogsLevel.debug);

      await logger.disposeLifeCycle();

      final content = await File(logger.logFilePath).readAsString();
      expect(content, contains('a warning line'));
      expect(content, isNot(contains('a debug line')));
    });

    test('formats the line with the level and the categories', () async {
      final logger = await buildAndInitLogger(minLevel: LogsLevel.all);

      logger.log(message: 'online', level: LogsLevel.error, categories: ['hosting']);

      await logger.disposeLifeCycle();

      final content = await File(logger.logFilePath).readAsString();
      expect(content, contains('[error]'));
      expect(content, contains('[hosting]'));
      expect(content, contains('online'));
    });
  });
}
