// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_router_manager/act_router_manager.dart';

/// The application routes
enum OcptRoute with MixinRoute {
  /// The home page, the initial route of the application
  home,

  /// The workspace page, hosting whichever production mode is active
  workspace,

  /// The settings page
  settings,

  /// The third-party licenses page
  licenses;

  /// {@macro act_router_manager.MixinRoute.parent}
  @override
  final OcptRoute? parent;

  /// {@macro act_router_manager.MixinRoute.transition}
  @override
  final RouteTransition? transition;

  /// {@macro act_router_manager.MixinRoute.screenOrientation}
  @override
  final ScreenOrientationOption? screenOrientation;

  /// [OcptRoute] constructor
  // We ignore the unused parameters as they are required by the MixinRoute but not used in this
  // project for now.
  // ignore: unused_element_parameter
  const OcptRoute({this.parent, this.transition, this.screenOrientation});
}
