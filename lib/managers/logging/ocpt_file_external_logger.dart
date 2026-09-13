// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_foundation/act_foundation.dart';
import 'package:act_life_cycle/act_life_cycle.dart';
import 'package:act_logger_manager/act_logger_manager.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;

/// The rotating log file's own name inside [OcptFileExternalLogger.logDirectoryPath] — the file
/// `AdvancedFileOutput` keeps appending to until it rotates, and the one
/// [OcptFileExternalLogger.logFilePath] always points at.
const _latestLogFileName = 'ocpt.log';

/// Converts a [LogsLevel] to the `logger` package's own [Level].
///
/// Mirrors `act_logger_manager`'s own `ExtLogsLevel.toLoggerLevel` extension, which is not part of
/// that package's public API (its barrel file does not export `ext_logs_level.dart`), so the
/// conversion is duplicated here rather than reaching into its `src/`.
extension _ToLoggerLevel on LogsLevel {
  /// The `logger` package [Level] equivalent to this [LogsLevel].
  Level get toLoggerLevel => switch (this) {
    LogsLevel.all => Level.all,
    LogsLevel.trace => Level.trace,
    LogsLevel.debug => Level.debug,
    LogsLevel.info => Level.info,
    LogsLevel.warn => Level.warning,
    LogsLevel.error => Level.error,
    LogsLevel.fatal => Level.fatal,
    LogsLevel.off => Level.off,
  };
}

/// Converts a `logger` package [Level] back to a [LogsLevel] — the reverse of [_ToLoggerLevel],
/// used only to format a line's level marker. [OcptFileExternalLogger] never itself hands the
/// `logger` package a deprecated [Level] (`verbose`, `wtf`, `nothing`), so those fall through to
/// the wildcard rather than being matched by name.
LogsLevel _logsLevelFromLoggerLevel(Level level) => switch (level) {
  Level.all => LogsLevel.all,
  Level.trace => LogsLevel.trace,
  Level.debug => LogsLevel.debug,
  Level.info => LogsLevel.info,
  Level.warning => LogsLevel.warn,
  Level.error => LogsLevel.error,
  Level.fatal => LogsLevel.fatal,
  Level.off => LogsLevel.off,
  _ => LogsLevel.all,
};

/// One line queued for [OcptFileExternalLogger]'s own printer — carries the categories
/// `LogFormatUtility.formatLogMessages` prints alongside the message, exactly what
/// `act_logger_manager`'s own (package-private) `LogMessage` carries for the console logger.
class _OcptFileLogMessage {
  /// The message itself, as handed to [OcptFileExternalLogger.log].
  // We don't know the type of the objects we pass to the log messages
  // ignore: avoid_annotating_with_dynamic
  final dynamic message;

  /// The categories, as handed to [OcptFileExternalLogger.log].
  final List<String> categories;

  /// Class constructor
  const _OcptFileLogMessage({required this.message, required this.categories});
}

/// Filters by [minLevel] alone, with no release-mode gating unlike the console logger's own
/// filter: a crash-survivable file is exactly what a release build most needs.
class _OcptFileLogFilter extends LogFilter {
  /// Class constructor
  _OcptFileLogFilter({LogsLevel minLevel = LogsLevel.all}) {
    level = minLevel.toLoggerLevel;
  }

  /// The minimum [LogsLevel] this filter lets through.
  LogsLevel get minLevel => _logsLevelFromLoggerLevel(level ?? Level.all);

  /// Sets the minimum [LogsLevel] this filter lets through.
  set minLevel(LogsLevel value) => level = value.toLoggerLevel;

  /// {@macro logger.LogFilter.shouldLog}
  @override
  bool shouldLog(LogEvent event) => level == null || event.level.index >= level!.index;
}

/// Formats each line the same way `act_logger_manager`'s own `DefaultLogPrinter` formats a
/// console line, through the public `LogFormatUtility.formatLogMessages`.
class _OcptFileLogPrinter extends LogPrinter {
  /// {@macro logger.LogPrinter.log}
  @override
  List<String> log(LogEvent event) {
    var messageContent = event.message;
    final categories = <String>[];
    if (messageContent is _OcptFileLogMessage) {
      categories.addAll(messageContent.categories);
      messageContent = messageContent.message;
    }

    return LogFormatUtility.formatLogMessages(
      message: messageContent,
      exception: event.error,
      stackTrace: event.stackTrace,
      categories: categories,
      level: _logsLevelFromLoggerLevel(event.level),
      time: event.time,
    );
  }
}

/// A [MixinExternalLogger] that writes every logged line at or above [minLevel] to a small
/// rotating file under [logDirectoryPath] — the crash-survivable log `OcptFileLoggingManager`
/// registers when `logs.file.enabled` is true, modelled on `act_logger_manager`'s own
/// `ConsoleExternalLogger`.
///
/// Backed by the `logger` package's own `AdvancedFileOutput`, which buffers writes and rotates the
/// file once it exceeds [maxFileSizeKB], keeping at most [maxRotatedFilesCount] rotated files on
/// top of the one still being written to ([logFilePath]). Never write secrets or tokens through
/// this logger — the call sites that log today already avoid them, and this logger adds none of
/// its own.
class OcptFileExternalLogger
    with MixinWithLifeCycleDispose, MixinWithLifeCycle, MixinExternalLogger {
  /// The directory holding the rotating log files.
  final String logDirectoryPath;

  /// The size, in kilobytes, a log file may reach before it is rotated.
  final int maxFileSizeKB;

  /// The number of rotated files kept on top of the one still being written to.
  final int maxRotatedFilesCount;

  /// The `logger` package instance actually writing the file.
  late final Logger _logger;

  /// The log filter used to filter the log messages based on their level.
  late final _OcptFileLogFilter _logFilter;

  /// Creates a file external logger writing under [logDirectoryPath], starting at [minLevel].
  ///
  /// [logDirectoryPath] is injectable so a test can point it at a temporary directory instead of
  /// the real per-platform application support directory `OcptFileLoggingManager` resolves it
  /// from.
  OcptFileExternalLogger({
    required this.logDirectoryPath,
    LogsLevel minLevel = LogsLevel.info,
    this.maxFileSizeKB = 512,
    this.maxRotatedFilesCount = 3,
  }) {
    _logFilter = _OcptFileLogFilter(minLevel: minLevel);
    _logger = Logger(
      filter: _logFilter,
      printer: _OcptFileLogPrinter(),
      output: AdvancedFileOutput(
        path: logDirectoryPath,
        latestFileName: _latestLogFileName,
        maxFileSizeKB: maxFileSizeKB,
        maxRotatedFilesCount: maxRotatedFilesCount,
      ),
    );
  }

  /// The path of the file currently being written to — what an "open the log file" affordance
  /// would open.
  String get logFilePath => p.join(logDirectoryPath, _latestLogFileName);

  /// {@macro act_logger_manager.MixinExternalLogger.minLevel.getter}
  @override
  LogsLevel get minLevel => _logFilter.minLevel;

  /// {@macro act_logger_manager.MixinExternalLogger.minLevel.setter}
  @override
  set minLevel(LogsLevel value) => _logFilter.minLevel = value;

  /// {@macro act_life_cycle.MixinWithLifeCycle.initLifeCycle}
  ///
  /// Waits for `AdvancedFileOutput`'s own asynchronous setup (creating [logDirectoryPath] when
  /// missing) to finish, so a line logged right after this call is never lost to a directory that
  /// does not exist yet.
  @override
  Future<void> initLifeCycle() async {
    await super.initLifeCycle();

    await _logger.init;
  }

  /// {@macro act_logger_manager.MixinExternalLogger.log}
  @override
  void log({
    // We don't know the type of the objects we pass to the log messages
    // ignore: avoid_annotating_with_dynamic
    required dynamic message,
    required LogsLevel level,
    // We don't know the type of the objects we pass to the log messages
    // ignore: avoid_annotating_with_dynamic
    dynamic error,
    StackTrace? stackTrace,
    List<String>? categories,
    DateTime? time,
  }) {
    _logger.log(
      level.toLoggerLevel,
      _OcptFileLogMessage(message: message, categories: categories ?? const []),
      error: error,
      stackTrace: stackTrace,
      time: time,
    );
  }

  /// {@macro act_logger_manager.MixinExternalLogger.wouldBeLogged}
  @override
  bool wouldBeLogged({required LogsLevel level, List<String>? categories}) =>
      _logFilter.shouldLog(LogEvent(level.toLoggerLevel, null));

  /// {@macro act_foundation.MixinWithLifeCycleDispose.disposeLifeCycle}
  @override
  Future<void> disposeLifeCycle() async {
    await _logger.close();

    return super.disposeLifeCycle();
  }
}
