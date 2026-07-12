// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <benoit.rolandeau@allcircuits.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_router_manager/act_router_manager.dart';
import 'package:flutter/widgets.dart';
import 'package:open_cine_prod_tools/types/ocpt_route.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_page.dart';
import 'package:open_cine_prod_tools/ui/pages/home/home_page.dart';
import 'package:open_cine_prod_tools/ui/pages/settings/settings_page.dart';

/// Helper class mapping every [OcptRoute] to the page it displays
class OcptRoutesHelper extends AbstractRoutesHelper<OcptRoute> {
  /// Class constructor
  OcptRoutesHelper({required super.initialRoute, required super.logsHelper})
    : super(values: OcptRoute.values, debugLogDiagnostics: true) {
    onPage(OcptRoute.home, _createHomePage);
    onPage(OcptRoute.editor, _createEditorPage);
    onPage(OcptRoute.settings, _createSettingsPage);
  }

  /// Callback to create the [HomePage]
  RoutePageDetails _createHomePage(BuildContext context, GoRouterState state) =>
      const RoutePageDetails(widget: HomePage());

  /// Callback to create the [EditorPage]
  RoutePageDetails _createEditorPage(BuildContext context, GoRouterState state) =>
      const RoutePageDetails(widget: EditorPage());

  /// Callback to create the [SettingsPage]
  RoutePageDetails _createSettingsPage(BuildContext context, GoRouterState state) =>
      const RoutePageDetails(widget: SettingsPage());
}
