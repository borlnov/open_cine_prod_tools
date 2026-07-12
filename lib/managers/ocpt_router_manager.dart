// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <benoit.rolandeau@allcircuits.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_global_manager/act_global_manager.dart';
import 'package:act_logger_manager/act_logger_manager.dart';
import 'package:act_router_manager/act_router_manager.dart';
import 'package:flutter/widgets.dart';
import 'package:open_cine_prod_tools/managers/ocpt_routes_helper.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/types/ocpt_route.dart';

/// Builds the [OcptRouterManager] instance registered by the global manager.
class OcptRouterManagerBuilder extends AbstractRouterBuilder<OcptRouterManager> {
  /// Creates the router manager builder.
  const OcptRouterManagerBuilder() : super(factory: OcptRouterManager.new);
}

/// Drives the navigation of the application through the [OcptRoute] enum.
///
/// Besides building the [OcptRoutesHelper], this manager guards [OcptRoute.editor]: it can only be
/// reached while [OcptProjectsManager] has a project open, otherwise navigation is redirected to
/// [OcptRoute.home].
class OcptRouterManager extends AbstractRouterManager<OcptRoute> {
  /// {@macro act_router_manager.AbstractRouterManager.createRoutesHelper}
  @override
  Future<AbstractRoutesHelper<OcptRoute>> createRoutesHelper(LogsHelper logsHelper) async =>
      OcptRoutesHelper(initialRoute: OcptRoute.home, logsHelper: logsHelper);

  /// {@macro act_life_cycle.MixinUiLifeCycle.initAfterManagersAndBeforeViews}
  ///
  /// This is also where the [OcptRoute.editor] guard is registered: it's called once every
  /// manager (including [OcptProjectsManager]) is ready, which is required for
  /// [_redirectFromEditorWhenNoProjectIsOpen] to safely query it.
  @override
  Future<void> initAfterManagersAndBeforeViews() async {
    await super.initAfterManagersAndBeforeViews();
    registerRedirect(_redirectFromEditorWhenNoProjectIsOpen);
  }

  /// Redirects [OcptRoute.editor] to [OcptRoute.home] whenever no project is currently open.
  Future<OcptRoute?> _redirectFromEditorWhenNoProjectIsOpen(
    BuildContext context,
    OcptRoute route,
    GoRouterState state,
  ) async {
    if (route == OcptRoute.editor && globalGetIt().get<OcptProjectsManager>().currentProject == null) {
      return OcptRoute.home;
    }

    return null;
  }
}
