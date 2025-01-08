// SPDX-FileCopyrightText: 2025 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: MIT

import 'package:bro_abstract_logger/bro_abstract_logger.dart';
import 'package:bro_firebase_crashlytics/bro_firebase_crashlytics.dart';
import 'package:bro_logger_manager/bro_logger_manager.dart';
import 'package:open_cine_prod_tools/managers/config_manager.dart';

/// This the builder of the [MultiLoggerManager]
class MultiLoggerBuilder extends AbsMultiLoggerBuilder<MultiLoggerManager> {
  /// Create the [MultiLoggerBuilder] instance
  const MultiLoggerBuilder()
      : super(
          loggersBuilders: const [
            LoggerManagerBuilder<ConfigManager>(
              registerFlutterNonManagedErrors: false,
            ),
            CrashlyticsBuilder<ConfigManager>(),
          ],
        );

  /// {@macro bro_abstract_logger.AbsMultiLoggerBuilder.createMultiLoggerManager}
  @override
  MultiLoggerManager createMultiLoggerManager(List<AbstractLoggerManager> loggerManager) =>
      MultiLoggerManager(loggerManager);
}

/// This is logger of the application
class MultiLoggerManager extends AbstractMultiLoggerManager {
  /// This is the [LoggerManager]
  final LoggerManager loggerManager;

  /// This is the [CrashlyticsLoggerManager]
  final CrashlyticsLoggerManager crashlyticsManager;

  /// Class constructor
  MultiLoggerManager(super.loggersManager)
      : loggerManager = loggersManager[0] as LoggerManager,
        crashlyticsManager = loggersManager[1] as CrashlyticsLoggerManager;
}
