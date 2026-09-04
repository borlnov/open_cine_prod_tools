// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_global_manager/act_global_manager.dart';
import 'package:act_life_cycle/act_life_cycle.dart';
import 'package:act_logger_manager/act_logger_manager.dart';
import 'package:open_cine_prod_tools/managers/logging/ocpt_file_external_logger.dart';
import 'package:open_cine_prod_tools/managers/ocpt_config_manager.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Builds the [OcptFileLoggingManager] instance registered by the global manager.
class OcptFileLoggingManagerBuilder extends AbsLifeCycleFactory<OcptFileLoggingManager> {
  /// Class constructor
  const OcptFileLoggingManagerBuilder() : super(OcptFileLoggingManager.new);

  /// {@macro act_life_cycle.AbsLifeCycleFactory.dependsOn}
  @override
  Iterable<Type> dependsOn() => [LoggerManager, OcptConfigManager];
}

/// The stable keys `LoggerManager.addExternalLogger`/`removeExternalLogger` take — an external
/// logger no call site other than [OcptFileLoggingManager] itself ever adds or removes.
enum OcptExternalLoggerKey {
  /// The [OcptFileExternalLogger] [OcptFileLoggingManager] may register, when `logs.file.enabled`
  /// is true.
  file,
}

/// Resolves the absolute path of the directory [OcptFileLoggingManager] writes its rotating log
/// files under, once file logging is enabled — the per-platform application support directory's
/// own `logs` subfolder by default; a test injects one pointing at a temporary directory instead.
Future<String> _defaultLogDirectoryPath() async {
  final supportDirectory = await getApplicationSupportDirectory();

  return p.join(supportDirectory.path, 'logs');
}

/// Turns the `logs.file.*` configuration read by [OcptConfigManager] into a registered
/// [OcptFileExternalLogger], so a crash still leaves a log file behind — the file itself has no
/// UI-facing affordance yet; [logFilePath] is the seam a later "open the log file" action reads.
///
/// [initLifeCycle] does nothing when `logs.file.enabled` is false. Any I/O failure while resolving
/// the log directory or setting up the file itself (a read-only file system, a sandboxed
/// environment) is caught and logged as a warning through `appLogger()` — file logging is a
/// diagnostic nicety, never something app start may fail over.
class OcptFileLoggingManager extends AbsWithLifeCycle {
  /// Creates the manager.
  ///
  /// [configManager] and [loggerManager] are stored nullable and resolved lazily through
  /// [_config]/[_logging], exactly the pattern `OcptRelayHostManager`'s own constructor documents:
  /// a test exercising the disabled path, or a failure caught before either is ever needed, does
  /// not have to register one at all, and a test exercising the enabled path hands in a spy
  /// recording `addExternalLogger` rather than the real thing. [resolveLogDirectoryPath] defaults
  /// to [_defaultLogDirectoryPath] and lets a test point it at a temporary directory instead of the
  /// real per-platform application support directory.
  OcptFileLoggingManager({
    OcptConfigManager? configManager,
    LoggerManager? loggerManager,
    Future<String> Function()? resolveLogDirectoryPath,
  }) : _configManager = configManager,
       _loggerManager = loggerManager,
       _resolveLogDirectoryPath = resolveLogDirectoryPath ?? _defaultLogDirectoryPath;

  /// The config manager this manager reads `logs.file.*` from, or null until [_config] resolves it.
  OcptConfigManager? _configManager;

  /// The config manager this manager reads `logs.file.*` from — resolved through `globalGetIt()`
  /// the first time it is actually needed, unless one was injected in the constructor.
  OcptConfigManager get _config => _configManager ??= globalGetIt().get<OcptConfigManager>();

  /// The logger manager this manager registers its file logger against, or null until [_logging]
  /// resolves it.
  LoggerManager? _loggerManager;

  /// The logger manager this manager registers its file logger against — resolved through
  /// `globalGetIt()` the first time it is actually needed, unless one was injected in the
  /// constructor.
  LoggerManager get _logging => _loggerManager ??= globalGetIt().get<LoggerManager>();

  /// The seam [initLifeCycle] resolves the log directory's own path through.
  final Future<String> Function() _resolveLogDirectoryPath;

  /// The registered file logger, or null while file logging is disabled or its setup failed.
  OcptFileExternalLogger? _fileLogger;

  /// The rotating log file's own path, once file logging is enabled and set up; null while
  /// disabled by config or after a setup failure.
  String? get logFilePath => _fileLogger?.logFilePath;

  /// {@macro act_life_cycle.MixinWithLifeCycle.initLifeCycle}
  @override
  Future<void> initLifeCycle() async {
    await super.initLifeCycle();

    if (!_config.fileLogEnabled) {
      return;
    }

    try {
      final logDirectoryPath = await _resolveLogDirectoryPath();
      final fileLogger = OcptFileExternalLogger(
        logDirectoryPath: logDirectoryPath,
        minLevel: _config.fileLogLevel,
      );

      // LoggerManager.addExternalLogger() takes ownership of the logger, including calling its
      // own initLifeCycle() since the logger manager is already initialized at this point.
      await _logging.addExternalLogger(OcptExternalLoggerKey.file, fileLogger);
      _fileLogger = fileLogger;
    } on Object catch (error, stackTrace) {
      appLogger().w(
        'File logging setup failed, continuing without a log file: $error',
        error,
        stackTrace,
      );
    }
  }

  /// {@macro act_foundation.MixinWithLifeCycleDispose.disposeLifeCycle}
  @override
  Future<void> disposeLifeCycle() async {
    if (_fileLogger != null) {
      await _logging.removeExternalLogger(OcptExternalLoggerKey.file);
      _fileLogger = null;
    }

    return super.disposeLifeCycle();
  }
}
