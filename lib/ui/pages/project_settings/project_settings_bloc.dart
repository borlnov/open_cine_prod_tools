// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:act_global_manager/act_global_manager.dart';
import 'package:drift/drift.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_project_info_table.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/ui/pages/project_settings/project_settings_event.dart';
import 'package:open_cine_prod_tools/ui/pages/project_settings/project_settings_state.dart';

/// This is the bloc class for the project settings page.
///
/// It loads the current project's currency, page format and episodes from [OcptProjectsManager]
/// on entry, and writes each field back to the project the moment it changes — there is no
/// separate save step, exactly like the appearance and language sections of the app-wide settings
/// page. The page format is written through the very same
/// `OcptProjectsManager.saveCurrentProjectPageFormat` the screenplay editor's own page-setup
/// dialog uses, so the two can never disagree. The episode CRUD is reached through
/// `OcptProjectsManager.screenplayService` — there is no twelfth service
/// (`docs/adr/0019-one-project-several-episodes.md`) — passing [_database] exactly as
/// `OcptResourcesBloc._loadSnapshot` already does.
class OcptProjectSettingsBloc extends BlocForMixin<OcptProjectSettingsState> {
  /// The manager used to read and write the current project's settings.
  final OcptProjectsManager _projectsManager;

  /// Class constructor
  OcptProjectSettingsBloc({OcptProjectsManager? projectsManager})
    : _projectsManager = projectsManager ?? globalGetIt().get<OcptProjectsManager>(),
      super(const OcptProjectSettingsState.init()) {
    add(const OcptProjectSettingsLoadRequestedEvent());
  }

  /// The current project's database. The route that reaches this page is guarded exactly like the
  /// workspace's own, so a project is always open by the time an episode mutation runs.
  OcptProjectDatabase get _database => _projectsManager.currentProject!.database;

  /// {@macro act_flutter_utility.BlocForMixin.registerMixinEvents}
  @override
  void registerMixinEvents() {
    super.registerMixinEvents();
    on<OcptProjectSettingsLoadRequestedEvent>(_onLoadRequested);
    on<OcptProjectSettingsCurrencyChangedEvent>(_onCurrencyChanged);
    on<OcptProjectSettingsPageFormatChangedEvent>(_onPageFormatChanged);
    on<OcptProjectSettingsMinimumRestMinutesChangedEvent>(_onMinimumRestMinutesChanged);
    on<OcptProjectSettingsEpisodeAddedEvent>(_onEpisodeAdded);
    on<OcptProjectSettingsEpisodeTitleChangedEvent>(_onEpisodeTitleChanged);
    on<OcptProjectSettingsEpisodeNumberChangedEvent>(_onEpisodeNumberChanged);
    on<OcptProjectSettingsEpisodeMovedEvent>(_onEpisodeMoved);
    on<OcptProjectSettingsEpisodeDeletionConfirmedEvent>(_onEpisodeDeletionConfirmed);
  }

  /// Loads the current project's currency, page format and episodes.
  ///
  /// The route that reaches this page is guarded exactly like the workspace's own: a project is
  /// always open by the time this runs. The fallbacks below only ever matter if that guard were
  /// ever bypassed, and mirror the ones every other reader of these two properties already uses.
  Future<void> _onLoadRequested(
    OcptProjectSettingsLoadRequestedEvent event,
    Emitter<OcptProjectSettingsState> emitter,
  ) async {
    final currencyCode = await _projectsManager.loadCurrentProjectCurrencyCode();
    final pageFormat = await _projectsManager.loadCurrentProjectPageFormat();
    final minimumRestMinutes = await _projectsManager.loadCurrentProjectMinimumRestMinutes();
    final episodes = await _projectsManager.screenplayService.loadEpisodes(database: _database);

    emitter(
      state.copyWith(
        isLoading: false,
        currencyCode: currencyCode ?? ocptDefaultCurrencyCode,
        pageFormat: pageFormat ?? OcptPageFormat.usLetter,
        minimumRestMinutes: minimumRestMinutes,
        clearMinimumRestMinutes: minimumRestMinutes == null,
        episodes: episodes,
      ),
    );
  }

  /// Writes the newly picked currency to the project, then reflects it in the state.
  Future<void> _onCurrencyChanged(
    OcptProjectSettingsCurrencyChangedEvent event,
    Emitter<OcptProjectSettingsState> emitter,
  ) async {
    await _projectsManager.saveCurrentProjectCurrencyCode(event.currencyCode);
    emitter(state.copyWith(currencyCode: event.currencyCode, hasChanged: true));
  }

  /// Writes the newly picked page format to the project, then reflects it in the state.
  Future<void> _onPageFormatChanged(
    OcptProjectSettingsPageFormatChangedEvent event,
    Emitter<OcptProjectSettingsState> emitter,
  ) async {
    await _projectsManager.saveCurrentProjectPageFormat(event.pageFormat);
    emitter(state.copyWith(pageFormat: event.pageFormat, hasChanged: true));
  }

  /// Writes the newly committed minimum rest to the project, then reflects it in the state.
  ///
  /// `hasChanged` is set here exactly as every other field of this page sets it: the schedule
  /// mode's own re-read of this figure (`OcptScheduleProjectSettingsChangedEvent`, fired when this
  /// page pops with it true) depends on that, not on a special case for this one field.
  Future<void> _onMinimumRestMinutesChanged(
    OcptProjectSettingsMinimumRestMinutesChangedEvent event,
    Emitter<OcptProjectSettingsState> emitter,
  ) async {
    await _projectsManager.saveCurrentProjectMinimumRestMinutes(event.minutes);
    emitter(
      state.copyWith(
        minimumRestMinutes: event.minutes,
        clearMinimumRestMinutes: event.minutes == null,
        hasChanged: true,
      ),
    );
  }

  /// Appends a new episode, numbered "last + 1" by `OcptScreenplayService.createEpisode` itself,
  /// then re-reads the project's episodes so the card shows what the database now holds.
  Future<void> _onEpisodeAdded(
    OcptProjectSettingsEpisodeAddedEvent event,
    Emitter<OcptProjectSettingsState> emitter,
  ) async {
    final id = await _projectsManager.screenplayService.createEpisode(database: _database);
    final episodes = await _projectsManager.screenplayService.loadEpisodes(database: _database);
    emitter(state.copyWith(episodes: episodes, hasChanged: id != null ? true : null));
  }

  /// Writes the newly committed title of `event.screenplayId`, then re-reads the project's
  /// episodes.
  Future<void> _onEpisodeTitleChanged(
    OcptProjectSettingsEpisodeTitleChangedEvent event,
    Emitter<OcptProjectSettingsState> emitter,
  ) async {
    await _projectsManager.screenplayService.updateEpisode(
      database: _database,
      screenplayId: event.screenplayId,
      title: Value(event.title),
    );
    final episodes = await _projectsManager.screenplayService.loadEpisodes(database: _database);
    emitter(state.copyWith(episodes: episodes, hasChanged: true));
  }

  /// Writes the newly committed printed number of `event.screenplayId`, then re-reads the
  /// project's episodes.
  Future<void> _onEpisodeNumberChanged(
    OcptProjectSettingsEpisodeNumberChangedEvent event,
    Emitter<OcptProjectSettingsState> emitter,
  ) async {
    await _projectsManager.screenplayService.updateEpisode(
      database: _database,
      screenplayId: event.screenplayId,
      number: Value(event.number),
    );
    final episodes = await _projectsManager.screenplayService.loadEpisodes(database: _database);
    emitter(state.copyWith(episodes: episodes, hasChanged: true));
  }

  /// Moves `event.screenplayId` to [OcptProjectSettingsEpisodeMovedEvent.newPosition], then
  /// re-reads the project's episodes in their freshly ordered `sortKey` order.
  Future<void> _onEpisodeMoved(
    OcptProjectSettingsEpisodeMovedEvent event,
    Emitter<OcptProjectSettingsState> emitter,
  ) async {
    await _projectsManager.screenplayService.reorderEpisode(
      database: _database,
      screenplayId: event.screenplayId,
      newPosition: event.newPosition,
    );
    final episodes = await _projectsManager.screenplayService.loadEpisodes(database: _database);
    emitter(state.copyWith(episodes: episodes, hasChanged: true));
  }

  /// Deletes `event.screenplayId` and its cascade, once the page's own `OcptConfirmDialog`
  /// confirmed it, then re-reads the project's remaining episodes.
  ///
  /// `hasChanged` is only set when the deletion actually happened: the card already withholds the
  /// delete affordance on a project's last live episode, but `OcptScreenplayService.deleteEpisode`
  /// itself refuses that write too, and there is nothing to reload for a mode were this to somehow
  /// be reached anyway.
  Future<void> _onEpisodeDeletionConfirmed(
    OcptProjectSettingsEpisodeDeletionConfirmedEvent event,
    Emitter<OcptProjectSettingsState> emitter,
  ) async {
    final deleted = await _projectsManager.screenplayService.deleteEpisode(
      database: _database,
      screenplayId: event.screenplayId,
    );
    final episodes = await _projectsManager.screenplayService.loadEpisodes(database: _database);
    emitter(state.copyWith(episodes: episodes, hasChanged: deleted ? true : null));
  }
}
