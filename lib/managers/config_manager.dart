// SPDX-FileCopyrightText: 2025 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: MIT

import 'package:bro_config_manager/bro_config_manager.dart';
import 'package:bro_firebase_crashlytics/bro_firebase_crashlytics.dart';
import 'package:bro_logger_manager/bro_logger_manager.dart';

/// This is the builder of the [ConfigManager]
class ConfigManagerBuilder extends AbsConfigBuilder<ConfigManager> {
  /// Create the [ConfigManagerBuilder] instance
  const ConfigManagerBuilder() : super();

  /// {@macro bro_abstract_manager.AbsManagerBuilder.create}
  @override
  ConfigManager create() => ConfigManager();

  /// {@macro bro_abstract_manager.AbsManagerBuilder.getDependencies}
  @override
  Iterable<Type> getDependencies() => [];
}

/// This is the config manager of the application
class ConfigManager extends AbstractConfigManager
    with MixinLoggerConfigs, MixinCrashlyticsConfigs {}
