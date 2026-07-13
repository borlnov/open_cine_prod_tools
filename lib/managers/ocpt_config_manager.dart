// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_config_manager/act_config_manager.dart';
import 'package:act_global_manager/act_global_manager.dart';
import 'package:act_intl/act_intl.dart';
import 'package:act_themes_manager/act_themes_manager.dart';

/// Builds the [OcptConfigManager] instance registered by the global manager.
class OcptConfigManagerBuilder extends AbstractConfigBuilder<OcptConfigManager> {
  /// Creates the config manager builder.
  const OcptConfigManagerBuilder() : super(OcptConfigManager.new);
}

/// Reads and exposes the configuration variables of the application.
///
/// Besides the [MixinLocaleConfig] and [MixinThemesConfig] variables required by the locale and
/// themes managers, this is a placeholder for future configuration options. Add [ConfigVar]
/// fields here as the app grows, following RFL24: no configuration value must be hardcoded
/// outside of this manager and its bundled YAML files.
class OcptConfigManager extends AbsUsualConfigManager with MixinLocaleConfig, MixinThemesConfig {
  /// Creates the config manager with the app's default logger.
  OcptConfigManager() : super(logger: appLogger());
}
