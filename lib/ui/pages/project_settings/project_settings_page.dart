// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/ui/pages/project_settings/project_settings_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/project_settings/project_settings_event.dart';
import 'package:open_cine_prod_tools/ui/pages/project_settings/project_settings_state.dart';
import 'package:open_cine_prod_tools/ui/pages/project_settings/widgets/ocpt_project_settings_currency_section.dart';
import 'package:open_cine_prod_tools/ui/pages/project_settings/widgets/ocpt_project_settings_minimum_rest_section.dart';
import 'package:open_cine_prod_tools/ui/pages/project_settings/widgets/ocpt_project_settings_page_format_section.dart';

/// The maximum width of the project settings page's content, matching the app-wide settings page.
const _maxContentWidth = 720.0;

/// Displays the settings of the currently open project: its currency and its screenplay page
/// format.
///
/// Reached from every production mode's own toolbar (`OcptWorkspaceShell.onProjectSettingsRequested`)
/// rather than a dialog: each field writes to the project the moment it changes, exactly like the
/// app-wide `SettingsPage`'s appearance and language sections, so there is no separate save step
/// and nothing to cancel. `OcptRouterManager.pop<bool>` hands the caller whether anything actually
/// changed, so a mode with something to repaginate (the screenplay, on a page-format change) knows
/// whether it is worth reloading.
///
/// Reachable only while a project is open (`OcptRouterManager`'s guard, mirroring the workspace
/// route's own), and withheld entirely while a project version is being previewed — a preview has
/// nothing here that may be written, so the mode that would open this page shows no button at all
/// rather than a disabled one.
class OcptProjectSettingsPage extends StatelessWidget {
  /// Creates the project settings page.
  const OcptProjectSettingsPage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (context) => OcptProjectSettingsBloc(),
    child: const OcptProjectSettingsView(),
  );
}

/// The content of [OcptProjectSettingsPage], separated from it so [OcptProjectSettingsPage] only
/// wires the [OcptProjectSettingsBloc] up (RFL3).
///
/// Unlike sibling pages' private `_XxxView`, this one is public: it lets widget tests pump it
/// directly with a `BlocProvider.value` wrapping an [OcptProjectSettingsBloc] built with an
/// injected `OcptProjectsManager`, the same reason `OcptSettingsView` is public.
class OcptProjectSettingsView extends StatelessWidget {
  /// Class constructor
  const OcptProjectSettingsView({super.key});

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<OcptProjectSettingsBloc, OcptProjectSettingsState>(
        builder: (context, state) {
          if (state.isLoading) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }

          return Scaffold(
            appBar: AppBar(
              leading: BackButton(onPressed: () => _pop(state)),
              title: Text(Tr.of(context).projectSettingsPageTitle),
            ),
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _maxContentWidth),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      OcptProjectSettingsCurrencySection(
                        currencyCode: state.currencyCode,
                        onCurrencyCodeChanged: (code) => _onCurrencyChanged(context, code),
                      ),
                      const SizedBox(height: 16),
                      OcptProjectSettingsPageFormatSection(
                        pageFormat: state.pageFormat,
                        onPageFormatChanged: (format) => _onPageFormatChanged(context, format),
                      ),
                      const SizedBox(height: 16),
                      OcptProjectSettingsMinimumRestSection(
                        minimumRestMinutes: state.minimumRestMinutes,
                        onMinimumRestMinutesChanged: (minutes) =>
                            _onMinimumRestMinutesChanged(context, minutes),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );

  /// Pops the page, handing [OcptProjectSettingsState.hasChanged] back to whichever mode pushed
  /// it.
  void _pop(OcptProjectSettingsState state) =>
      globalGetIt().get<OcptRouterManager>().pop<bool>(state.hasChanged);

  /// Dispatches the event that writes the newly picked currency to the project.
  void _onCurrencyChanged(BuildContext context, String currencyCode) {
    context.read<OcptProjectSettingsBloc>().add(
      OcptProjectSettingsCurrencyChangedEvent(currencyCode: currencyCode),
    );
  }

  /// Dispatches the event that writes the newly picked page format to the project.
  void _onPageFormatChanged(BuildContext context, OcptPageFormat pageFormat) {
    context.read<OcptProjectSettingsBloc>().add(
      OcptProjectSettingsPageFormatChangedEvent(pageFormat: pageFormat),
    );
  }

  /// Dispatches the event that writes the newly committed minimum rest to the project.
  void _onMinimumRestMinutesChanged(BuildContext context, int? minutes) {
    context.read<OcptProjectSettingsBloc>().add(
      OcptProjectSettingsMinimumRestMinutesChangedEvent(minutes: minutes),
    );
  }
}
