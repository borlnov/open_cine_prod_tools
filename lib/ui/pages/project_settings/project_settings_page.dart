// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_mileage_rate.dart';
import 'package:open_cine_prod_tools/models/ocpt_episode.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_settings_reveal.dart';
import 'package:open_cine_prod_tools/types/ocpt_screenplay_language.dart';
import 'package:open_cine_prod_tools/ui/pages/project_settings/project_settings_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/project_settings/project_settings_event.dart';
import 'package:open_cine_prod_tools/ui/pages/project_settings/project_settings_state.dart';
import 'package:open_cine_prod_tools/ui/pages/project_settings/widgets/ocpt_project_dictionary_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/project_settings/widgets/ocpt_project_settings_budget_section.dart';
import 'package:open_cine_prod_tools/ui/pages/project_settings/widgets/ocpt_project_settings_currency_section.dart';
import 'package:open_cine_prod_tools/ui/pages/project_settings/widgets/ocpt_project_settings_dictionary_section.dart';
import 'package:open_cine_prod_tools/ui/pages/project_settings/widgets/ocpt_project_settings_episodes_section.dart';
import 'package:open_cine_prod_tools/ui/pages/project_settings/widgets/ocpt_project_settings_mileage_rates_section.dart';
import 'package:open_cine_prod_tools/ui/pages/project_settings/widgets/ocpt_project_settings_minimum_rest_section.dart';
import 'package:open_cine_prod_tools/ui/pages/project_settings/widgets/ocpt_project_settings_page_format_section.dart';
import 'package:open_cine_prod_tools/ui/pages/project_settings/widgets/ocpt_project_settings_screenplay_language_section.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_workspace_episode_label.dart';
import 'package:open_cine_prod_tools/ui/widgets/ocpt_confirm_dialog.dart';

/// The maximum width of the project settings page's content, matching the app-wide settings page.
const _maxContentWidth = 720.0;

/// Displays the settings of the currently open project: its currency, its screenplay page format
/// and the language its screenplays are written in.
///
/// Reached from every production mode's own toolbar (`OcptWorkspaceShell.onProjectSettingsRequested`)
/// rather than a dialog: each field writes to the project the moment it changes, exactly like the
/// app-wide `SettingsPage`'s appearance and language sections, so there is no separate save step
/// and nothing to cancel. `OcptRouterManager.pop<bool>` hands the caller whether anything actually
/// changed, so a mode with something to repaginate (the screenplay, on a page-format change) knows
/// whether it is worth reloading.
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

  /// Creates the project settings page.
  const OcptProjectSettingsPage({this.reveal, super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (context) => OcptProjectSettingsBloc(),
    child: OcptProjectSettingsView(reveal: reveal),
  );
}

/// The content of [OcptProjectSettingsPage], separated from it so [OcptProjectSettingsPage] only
/// wires the [OcptProjectSettingsBloc] up (RFL3).
///
/// Unlike sibling pages' private `_XxxView`, this one is public: it lets widget tests pump it
/// directly with a `BlocProvider.value` wrapping an [OcptProjectSettingsBloc] built with an
/// injected `OcptProjectsManager`, the same reason `OcptSettingsView` is public.
class OcptProjectSettingsView extends StatefulWidget {
  /// The section to scroll to once the project's settings have loaded, or null to scroll nowhere.
  final OcptProjectSettingsReveal? reveal;

  /// Class constructor
  const OcptProjectSettingsView({this.reveal, super.key});

  @override
  State<OcptProjectSettingsView> createState() => _OcptProjectSettingsViewState();
}

/// The state of [OcptProjectSettingsView]: it exists for the reveal alone (every field of the page
/// writes through the bloc), holding the key the scroll targets and the guard making it happen
/// exactly once.
class _OcptProjectSettingsViewState extends State<OcptProjectSettingsView> {
  /// The key the `Episodes` card is built with, so [_reveal] has a render object to scroll to.
  final GlobalKey _episodesSectionKey = GlobalKey();

  /// Whether the reveal has already been scheduled.
  ///
  /// Flipped from `build` rather than through `setState`: it drives nothing that is drawn, it only
  /// keeps the scroll from being scheduled again on every later rebuild (a currency picked, a title
  /// committed). The reveal cannot be scheduled any earlier than that — the section it targets is
  /// not in the tree while [OcptProjectSettingsState.isLoading].
  bool _hasScheduledReveal = false;

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<OcptProjectSettingsBloc, OcptProjectSettingsState>(
        builder: (context, state) {
          if (state.isLoading) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }

          _scheduleReveal();

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
                      OcptProjectSettingsBudgetSection(
                        defaultVatRateBasisPoints: state.defaultVatRateBasisPoints,
                        onDefaultVatRateBasisPointsChanged: (basisPoints) =>
                            _onDefaultVatRateBasisPointsChanged(context, basisPoints),
                        mealPriceCents: state.mealPriceCents,
                        onMealPriceCentsChanged: (cents) => _onMealPriceCentsChanged(context, cents),
                        snackPriceCents: state.snackPriceCents,
                        onSnackPriceCentsChanged: (cents) =>
                            _onSnackPriceCentsChanged(context, cents),
                        currencyCode: state.currencyCode,
                      ),
                      const SizedBox(height: 16),
                      OcptProjectSettingsMileageRatesSection(
                        mileageRates: state.mileageRates,
                        currencyCode: state.currencyCode,
                        onRateAdded: () => _onMileageRateAdded(context),
                        onRateLabelChanged: (rateId, label) =>
                            _onMileageRateLabelChanged(context, rateId, label),
                        onRateAmountChanged: (rateId, ratePerKmMilliCents) =>
                            _onMileageRateAmountChanged(context, rateId, ratePerKmMilliCents),
                        onRateDeletionRequested: (rate) =>
                            unawaited(_onMileageRateDeletionRequested(context, rate)),
                      ),
                      const SizedBox(height: 16),
                      OcptProjectSettingsPageFormatSection(
                        pageFormat: state.pageFormat,
                        onPageFormatChanged: (format) => _onPageFormatChanged(context, format),
                      ),
                      const SizedBox(height: 16),
                      OcptProjectSettingsScreenplayLanguageSection(
                        screenplayLanguage: state.screenplayLanguage,
                        onScreenplayLanguageChanged: (language) =>
                            _onScreenplayLanguageChanged(context, language),
                      ),
                      const SizedBox(height: 16),
                      OcptProjectSettingsDictionarySection(
                        words: state.dictionaryWords,
                        onEditRequested: () =>
                            unawaited(_onDictionaryEditRequested(context, state.dictionaryWords)),
                      ),
                      const SizedBox(height: 16),
                      OcptProjectSettingsMinimumRestSection(
                        minimumRestMinutes: state.minimumRestMinutes,
                        onMinimumRestMinutesChanged: (minutes) =>
                            _onMinimumRestMinutesChanged(context, minutes),
                      ),
                      const SizedBox(height: 16),
                      OcptProjectSettingsEpisodesSection(
                        key: _episodesSectionKey,
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

  /// Schedules the scroll bringing [OcptProjectSettingsView.reveal]'s own section into view, once
  /// the frame showing it has been laid out — nothing before that has a render object to scroll to.
  ///
  /// Does nothing at all for a page opened plainly, and never runs twice.
  void _scheduleReveal() {
    if (_hasScheduledReveal || widget.reveal == null) {
      return;
    }

    _hasScheduledReveal = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _reveal());
  }

  /// Scrolls [OcptProjectSettingsView.reveal]'s own section to the top of the page.
  ///
  /// A section already fully on screen — the whole page fits a tall enough window — is left where
  /// it is by `ensureVisible` itself, which is the wanted answer: it is being looked at already.
  void _reveal() {
    final sectionContext = switch (widget.reveal) {
      OcptProjectSettingsReveal.episodes => _episodesSectionKey.currentContext,
      null => null,
    };
    if (sectionContext == null) {
      return;
    }

    unawaited(
      Scrollable.ensureVisible(
        sectionContext,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      ),
    );
  }

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

  /// Dispatches the event that writes the newly picked screenplay language to the project,
  /// including "None" (null).
  void _onScreenplayLanguageChanged(BuildContext context, OcptScreenplayLanguage? language) {
    context.read<OcptProjectSettingsBloc>().add(
      OcptProjectSettingsScreenplayLanguageChangedEvent(screenplayLanguage: language),
    );
  }

  /// Opens `OcptProjectDictionaryDialog` over [words], then dispatches whatever diff it reports —
  /// the dialog only asks, this page applies it (`docs/architecture/foundations.md`),
  /// exactly the shape [_onEpisodeDeletionRequested] already follows for `OcptConfirmDialog`.
  ///
  /// The bloc is read before the `await`, and `context.mounted` is checked after it, for the same
  /// reason [_onEpisodeDeletionRequested] does both: a `BuildContext` is not safe to reach for
  /// once an asynchronous gap — the dialog itself, here — has had a chance to unmount the page.
  ///
  /// A null report should never happen (the dialog's own `PopScope` routes every exit through its
  /// diff-reporting close), but dispatches nothing rather than risk a phantom edit if it ever did.
  Future<void> _onDictionaryEditRequested(BuildContext context, List<String> words) async {
    final bloc = context.read<OcptProjectSettingsBloc>();

    final report = await OcptProjectDictionaryDialog.show(context, words: words);
    if (report == null) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    bloc.add(
      OcptProjectSettingsDictionaryEditedEvent(
        addedWords: report.added,
        removedWords: report.removed,
      ),
    );
  }

  /// Dispatches the event that writes the newly committed minimum rest to the project.
  void _onMinimumRestMinutesChanged(BuildContext context, int? minutes) {
    context.read<OcptProjectSettingsBloc>().add(
      OcptProjectSettingsMinimumRestMinutesChangedEvent(minutes: minutes),
    );
  }

  /// Dispatches the event that writes the newly committed default VAT rate to the project, or
  /// clears it — whether that comes from the field's own submission or the card's `No rate` button.
  void _onDefaultVatRateBasisPointsChanged(BuildContext context, int? basisPoints) {
    context.read<OcptProjectSettingsBloc>().add(
      OcptProjectSettingsDefaultVatRateBasisPointsChangedEvent(basisPoints: basisPoints),
    );
  }

  /// Dispatches the event that writes the newly committed meal price to the project.
  void _onMealPriceCentsChanged(BuildContext context, int? cents) {
    context.read<OcptProjectSettingsBloc>().add(
      OcptProjectSettingsMealPriceCentsChangedEvent(cents: cents),
    );
  }

  /// Dispatches the event that writes the newly committed snack price to the project.
  void _onSnackPriceCentsChanged(BuildContext context, int? cents) {
    context.read<OcptProjectSettingsBloc>().add(
      OcptProjectSettingsSnackPriceCentsChangedEvent(cents: cents),
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

  /// Dispatches the event that appends a new, blank mileage rate.
  void _onMileageRateAdded(BuildContext context) {
    context.read<OcptProjectSettingsBloc>().add(const OcptProjectSettingsMileageRateAddedEvent());
  }

  /// Dispatches the event that writes a mileage rate's newly committed label.
  void _onMileageRateLabelChanged(BuildContext context, String rateId, String label) {
    context.read<OcptProjectSettingsBloc>().add(
      OcptProjectSettingsMileageRateLabelChangedEvent(rateId: rateId, label: label),
    );
  }

  /// Dispatches the event that writes a mileage rate's newly committed per-kilometre amount.
  void _onMileageRateAmountChanged(BuildContext context, String rateId, int ratePerKmMilliCents) {
    context.read<OcptProjectSettingsBloc>().add(
      OcptProjectSettingsMileageRateAmountChangedEvent(
        rateId: rateId,
        ratePerKmMilliCents: ratePerKmMilliCents,
      ),
    );
  }

  /// Asks `OcptConfirmDialog` whether [rate] really is to be deleted, naming it and stating that a
  /// person who already names it will simply read no rate at all, then dispatches the deletion if
  /// the user confirmed it.
  Future<void> _onMileageRateDeletionRequested(
    BuildContext context,
    OcptBudgetMileageRate rate,
  ) async {
    final bloc = context.read<OcptProjectSettingsBloc>();
    final tr = Tr.of(context);
    final label = rate.label.isEmpty ? tr.projectSettingsUnnamedMileageRate : rate.label;

    final confirmed = await OcptConfirmDialog.show(
      context,
      title: tr.projectSettingsDeleteMileageRateConfirmTitle(label),
      message: tr.projectSettingsDeleteMileageRateConfirmMessage,
      cancelLabel: tr.projectSettingsDeleteMileageRateConfirmCancelAction,
      confirmLabel: tr.projectSettingsDeleteMileageRateConfirmDeleteAction,
    );
    if (confirmed != true) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    bloc.add(OcptProjectSettingsMileageRateDeletionConfirmedEvent(rateId: rate.id));
  }
}
