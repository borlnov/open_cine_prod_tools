// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_config_manager/act_config_manager.dart';
import 'package:act_foundation/act_foundation.dart';
import 'package:act_global_manager/act_global_manager.dart';
import 'package:act_intl/act_intl.dart';
import 'package:act_licenses_manager/act_licenses_manager.dart';
import 'package:act_local_storage_manager/act_local_storage_manager.dart';
import 'package:act_themes_manager/act_themes_manager.dart';

/// Builds the [OcptConfigManager] instance registered by the global manager.
class OcptConfigManagerBuilder extends AbstractConfigBuilder<OcptConfigManager> {
  /// Creates the config manager builder.
  const OcptConfigManagerBuilder() : super(OcptConfigManager.new);
}

/// Reads and exposes the configuration variables of the application.
///
/// Besides the [MixinLocaleConfig] and [MixinThemesConfig] variables required by the locale and
/// themes managers, the [MixinLicensesConfig] variables required by the licenses manager, and the
/// [MixinStoresConf] variable the secrets manager reads, this also owns the `logs.file.*` section:
/// `act_logger_manager` reads `logs.level`/`logs.console.*` itself (through
/// [AbsUsualConfigManager]'s own `MixinLoggerConfig`/`MixinCslLoggerConfig`) but knows nothing of a
/// file sink, so the app reads its settings here, for `OcptFileLoggingManager` to act on. Add
/// [ConfigVar] fields here as the app grows, following RFL24: no configuration value must be
/// hardcoded outside of this manager and its bundled YAML files.
class OcptConfigManager extends AbsUsualConfigManager
    with MixinLocaleConfig, MixinThemesConfig, MixinLicensesConfig, MixinStoresConf {
  /// Creates the config manager with the app's default logger.
  OcptConfigManager() : super(logger: appLogger());

  /// Whether app logs are also written to a rotating file (`logs.file.enabled`), read by
  /// `OcptFileLoggingManager`.
  final _fileLogEnabledVar = const NotNullableConfigVar<bool>(
    'logs.file.enabled',
    defaultValue: false,
  );

  /// The minimum level a line must reach to be written to that file (`logs.file.level`), read by
  /// `OcptFileLoggingManager`.
  final _fileLogLevelVar = const NotNullParserConfigVar<LogsLevel, String>(
    'logs.file.level',
    defaultValue: LogsLevel.info,
    parser: LogsLevel.parseFromString,
  );

  /// Whether app logs are also written to a rotating file.
  bool get fileLogEnabled => _fileLogEnabledVar.load();

  /// The minimum level a line must reach to be written to that file.
  LogsLevel get fileLogLevel => _fileLogLevelVar.load();
}
