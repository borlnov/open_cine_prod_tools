// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_settings_reveal.dart';
import 'package:open_cine_prod_tools/ui/pages/project_settings/project_settings_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/project_settings/project_settings_view.dart';

/// Display the settings of the currently open project: its currency, its screenplay page format
/// and the language its screenplays are written in.
///
/// Reached from every production mode's own toolbar
/// (`OcptWorkspaceShell.onProjectSettingsRequested`) rather than a dialog: each field writes to the
/// project the moment it changes, exactly like the app-wide `OcptSettingsPage`'s appearance and
/// language sections, so there is no separate save step and nothing to cancel.
/// `OcptRouterManager.pop<bool>` hands the caller whether anything actually changed, so a mode with
/// something to repaginate (the screenplay, on a page-format change) knows whether it is worth
/// reloading.
///
/// A caller that opened this page for one of its cards in particular says so through [reveal], and
/// the page scrolls there once the settings have loaded — the screenplay mode's `Add an episode…`
/// button is the one that does, and landing at the top of four stacked cards would break the very
/// promise its label makes.
///
/// Reachable only while a project is open (`OcptRouterManager`'s guard, mirroring the workspace
/// route's own), and withheld entirely while a project version is being previewed — a preview has
/// nothing here that may be written, so the mode that would open this page shows no button at all
/// rather than a disabled one.
class OcptProjectSettingsPage extends StatelessWidget {
  /// The section to scroll to the moment the page opens, or null when it was opened plainly — see
  /// [OcptProjectSettingsReveal].
  final OcptProjectSettingsReveal? reveal;

  /// Create the project settings page.
  const OcptProjectSettingsPage({this.reveal, super.key});

  /// Build the project settings page as a [BlocProvider].
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (context) => OcptProjectSettingsBloc(),
    child: OcptProjectSettingsView(reveal: reveal),
  );
}
