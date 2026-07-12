// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <benoit.rolandeau@allcircuits.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_logger_manager/act_logger_manager.dart';
import 'package:act_router_manager/act_router_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_routes_helper.dart';
import 'package:open_cine_prod_tools/types/ocpt_route.dart';

/// Builds the [OcptRouterManager] instance registered by the global manager.
class OcptRouterManagerBuilder extends AbstractRouterBuilder<OcptRouterManager> {
  /// Creates the router manager builder.
  const OcptRouterManagerBuilder() : super(factory: OcptRouterManager.new);
}

/// Drives the navigation of the application through the [OcptRoute] enum.
class OcptRouterManager extends AbstractRouterManager<OcptRoute> {
  /// {@macro act_router_manager.AbstractRouterManager.createRoutesHelper}
  @override
  Future<AbstractRoutesHelper<OcptRoute>> createRoutesHelper(LogsHelper logsHelper) async =>
      OcptRoutesHelper(initialRoute: OcptRoute.home, logsHelper: logsHelper);
}
