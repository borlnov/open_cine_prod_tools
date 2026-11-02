// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_logger_manager/act_logger_manager.dart';

/// Build the [LogsHelper] a manager, a BLoC or any other class that logs owns for [category].
///
/// A class owns exactly one of these, built from its own `static const _loggerCategory`; a service
/// never calls this and is handed a sub-logger by its owner instead.
///
/// Building a [LogsHelper] needs the logger singleton, which `LoggerManager` creates when it is
/// initialised. A manager's builder depends on `LoggerManager`, so it is there by the time a
/// manager is built; a BLoC or a test can be built before any manager exists, so this first asks
/// for the safe logger, which creates the singleton when it is missing and returns the existing one
/// otherwise. That keeps building a logger from ever throwing.
LogsHelper buildOcptLogsHelper(String category) {
  LoggerManager.getSafeLogger();

  return LogsHelper(category: category);
}
