// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_router_manager/act_router_manager.dart';
import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_settings_reveal.dart';
import 'package:open_cine_prod_tools/types/ocpt_route.dart';
import 'package:open_cine_prod_tools/ui/pages/home/home_page.dart';
import 'package:open_cine_prod_tools/ui/pages/project_settings/project_settings_page.dart';
import 'package:open_cine_prod_tools/ui/pages/settings/settings_page.dart';
import 'package:open_cine_prod_tools/ui/pages/sharing/sharing_page.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/workspace_page.dart';

/// Helper class mapping every [OcptRoute] to the page it displays
class OcptRoutesHelper extends AbstractRoutesHelper<OcptRoute> {
  /// Class constructor
  OcptRoutesHelper({required super.initialRoute, required super.logsHelper})
    : super(values: OcptRoute.values, debugLogDiagnostics: true) {
    onPage(OcptRoute.home, _createHomePage);
    onPage(OcptRoute.workspace, _createWorkspacePage);
    onPage(OcptRoute.projectSettings, _createProjectSettingsPage);
    onPage(OcptRoute.sharing, _createSharingPage);
    onPage(OcptRoute.settings, _createSettingsPage);
    onPage(OcptRoute.licenses, _createLicensesPage);
  }

  /// Callback to create the [HomePage]
  RoutePageDetails _createHomePage(BuildContext context, GoRouterState state) =>
      const RoutePageDetails(widget: HomePage());

  /// Callback to create the [WorkspacePage]
  RoutePageDetails _createWorkspacePage(BuildContext context, GoRouterState state) =>
      const RoutePageDetails(widget: WorkspacePage());

  /// Callback to create the [OcptProjectSettingsPage]
  ///
  /// The route's `extra` names the section the page scrolls to when it opens, or is null (anything
  /// that is not an [OcptProjectSettingsReveal] included) for the page opened plainly.
  RoutePageDetails _createProjectSettingsPage(BuildContext context, GoRouterState state) {
    final reveal = state.extra;

    return RoutePageDetails(
      widget: OcptProjectSettingsPage(
        reveal: reveal is OcptProjectSettingsReveal ? reveal : null,
      ),
    );
  }

  /// Callback to create the [OcptSharingPage]
  RoutePageDetails _createSharingPage(BuildContext context, GoRouterState state) =>
      const RoutePageDetails(widget: OcptSharingPage());

  /// Callback to create the [SettingsPage]
  RoutePageDetails _createSettingsPage(BuildContext context, GoRouterState state) =>
      const RoutePageDetails(widget: SettingsPage());

  /// Callback to create the third-party licenses page, listing everything
  /// [OcptGlobalManager]'s `ActLicensesManager` has fed into Flutter's `LicenseRegistry` by then.
  RoutePageDetails _createLicensesPage(BuildContext context, GoRouterState state) =>
      RoutePageDetails(
        widget: LicensePage(
          applicationName: Tr.of(context).appTitle,
          applicationVersion: OcptGlobalManager.instance.packageInfo.version,
          applicationLegalese: "Apache-2.0",
        ),
      );
}
