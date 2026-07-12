// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <benoit.rolandeau@allcircuits.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_global_manager/act_global_manager.dart';
import 'package:act_logger_manager/act_logger_manager.dart';
import 'package:flutter/widgets.dart';
import 'package:open_cine_prod_tools/managers/ocpt_config_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/ui/pages/fatal_error_page.dart';

/// Owns every manager registered in the app and drives their life cycle.
class OcptGlobalManager extends AbsUiGlobalManager {
  /// Returns the singleton instance, creating it on first access.
  static OcptGlobalManager get instance {
    if (AbsGlobalManager.instance == null) {
      AbsGlobalManager.setInstance = OcptGlobalManager._create();
    }

    return AbsGlobalManager.instance! as OcptGlobalManager;
  }

  /// Creates the singleton instance.
  OcptGlobalManager._create() : super.create();

  /// {@macro act_global_manager.AbsGlobalManager.registerManagers}
  @override
  Future<void> registerManagers() async {
    registerManagerAsync<OcptConfigManager>(const OcptConfigManagerBuilder());
    registerManagerAsync<LoggerManager>(ExtDefaultLoggerBuilder<OcptConfigManager>());
    registerManagerAsync<OcptRouterManager>(const OcptRouterManagerBuilder());
  }

  /// {@macro act_global_manager.MixinUiGlobalManager.buildFatalErrorPage}
  @override
  Widget? buildFatalErrorPage(Object error) => FatalErrorPage(error: error);
}
