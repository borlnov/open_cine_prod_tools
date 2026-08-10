// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_episode.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/ui/pages/project_settings/project_settings_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/project_settings/project_settings_event.dart';
import 'package:open_cine_prod_tools/ui/pages/project_settings/project_settings_state.dart';
import 'package:open_cine_prod_tools/ui/pages/project_settings/widgets/ocpt_project_settings_currency_section.dart';
import 'package:open_cine_prod_tools/ui/pages/project_settings/widgets/ocpt_project_settings_episodes_section.dart';
import 'package:open_cine_prod_tools/ui/pages/project_settings/widgets/ocpt_project_settings_minimum_rest_section.dart';
import 'package:open_cine_prod_tools/ui/pages/project_settings/widgets/ocpt_project_settings_page_format_section.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_workspace_episode_label.dart';
import 'package:open_cine_prod_tools/ui/widgets/ocpt_confirm_dialog.dart';

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
                      const SizedBox(height: 16),
                      OcptProjectSettingsEpisodesSection(
                        episodes: state.episodes,
                        onEpisodeAdded: () => _onEpisodeAdded(context),
                        onEpisodeTitleChanged: (screenplayId, title) =>
                            _onEpisodeTitleChanged(context, screenplayId, title),
                        onEpisodeNumberChanged: (screenplayId, number) =>
                            _onEpisodeNumberChanged(context, screenplayId, number),
                        onEpisodeMoved: (screenplayId, newPosition) =>
                            _onEpisodeMoved(context, screenplayId, newPosition),
                        onEpisodeDeletionRequested: (episode) =>
                            unawaited(_onEpisodeDeletionRequested(context, episode)),
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

  /// Dispatches the event that appends a new episode.
  void _onEpisodeAdded(BuildContext context) {
    context.read<OcptProjectSettingsBloc>().add(const OcptProjectSettingsEpisodeAddedEvent());
  }

  /// Dispatches the event that writes an episode's newly committed title.
  void _onEpisodeTitleChanged(BuildContext context, String screenplayId, String title) {
    context.read<OcptProjectSettingsBloc>().add(
      OcptProjectSettingsEpisodeTitleChangedEvent(screenplayId: screenplayId, title: title),
    );
  }

  /// Dispatches the event that writes an episode's newly committed printed number.
  void _onEpisodeNumberChanged(BuildContext context, String screenplayId, int number) {
    context.read<OcptProjectSettingsBloc>().add(
      OcptProjectSettingsEpisodeNumberChangedEvent(screenplayId: screenplayId, number: number),
    );
  }

  /// Dispatches the event that moves an episode to its newly picked position.
  void _onEpisodeMoved(BuildContext context, String screenplayId, int newPosition) {
    context.read<OcptProjectSettingsBloc>().add(
      OcptProjectSettingsEpisodeMovedEvent(screenplayId: screenplayId, newPosition: newPosition),
    );
  }

  /// Asks `OcptConfirmDialog` whether [episode] really is to be deleted, naming it and stating
  /// both what the deletion takes and what it leaves
  /// (`docs/adr/0019-one-project-several-episodes.md`), then dispatches the deletion if the user
  /// confirmed it.
  ///
  /// The card's own delete action is never shown for the project's last live episode, so this is
  /// only ever reached with at least one other episode left.
  Future<void> _onEpisodeDeletionRequested(BuildContext context, OcptEpisode episode) async {
    final bloc = context.read<OcptProjectSettingsBloc>();
    final tr = Tr.of(context);

    final confirmed = await OcptConfirmDialog.show(
      context,
      title: tr.projectSettingsDeleteEpisodeConfirmTitle(ocptWorkspaceEpisodeLabelOf(tr, episode)),
      message: tr.projectSettingsDeleteEpisodeConfirmMessage,
      cancelLabel: tr.projectSettingsDeleteEpisodeConfirmCancelAction,
      confirmLabel: tr.projectSettingsDeleteEpisodeConfirmDeleteAction,
    );
    if (confirmed != true) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    bloc.add(OcptProjectSettingsEpisodeDeletionConfirmedEvent(screenplayId: episode.id));
  }
}
