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
/// It loads the current project's currency, page format, minimum rest, default VAT rate, meal and
/// buffet prices, screenplay language, episodes and learned dictionary words from
/// [OcptProjectsManager] on entry, and writes each field back to the project the moment it changes
/// — there is no
/// separate save step, exactly like the appearance and language sections of the app-wide settings
/// page. The page format is written through the very same
/// `OcptProjectsManager.saveCurrentProjectPageFormat` the screenplay editor's own page-setup
/// dialog uses, so the two can never disagree. The episode CRUD is reached through
/// `OcptProjectsManager.screenplayService` — there is no twelfth service
/// (`docs/adr/0019-one-project-several-episodes.md`) — passing [_database] exactly as
/// `OcptResourcesBloc._loadSnapshot` already does. The dictionary's own CRUD is reached through
/// `OcptProjectsManager.projectDictionaryService` the identical way, but only ever from
/// [_onDictionaryEdited]: unlike every other field here, the dictionary is *read* by
/// `OcptProjectSettingsDictionarySection` but *edited* in `OcptProjectDictionaryDialog`, which
/// only reports its diff back for this bloc to apply. The mileage rates' own CRUD is reached
/// through `OcptProjectsManager.budgetFinancingService`, the very service the budget mode's own
/// financing plan will read from later — this page is simply where a production types the rates
/// into it.
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
    on<OcptProjectSettingsDefaultVatRateBasisPointsChangedEvent>(
      _onDefaultVatRateBasisPointsChanged,
    );
    on<OcptProjectSettingsMealPriceCentsChangedEvent>(_onMealPriceCentsChanged);
    on<OcptProjectSettingsBuffetPriceCentsChangedEvent>(_onBuffetPriceCentsChanged);
    on<OcptProjectSettingsScreenplayLanguageChangedEvent>(_onScreenplayLanguageChanged);
    on<OcptProjectSettingsDictionaryEditedEvent>(_onDictionaryEdited);
    on<OcptProjectSettingsEpisodeAddedEvent>(_onEpisodeAdded);
    on<OcptProjectSettingsEpisodeTitleChangedEvent>(_onEpisodeTitleChanged);
    on<OcptProjectSettingsEpisodeNumberChangedEvent>(_onEpisodeNumberChanged);
    on<OcptProjectSettingsEpisodeMovedEvent>(_onEpisodeMoved);
    on<OcptProjectSettingsEpisodeDeletionConfirmedEvent>(_onEpisodeDeletionConfirmed);
    on<OcptProjectSettingsMileageRateAddedEvent>(_onMileageRateAdded);
    on<OcptProjectSettingsMileageRateLabelChangedEvent>(_onMileageRateLabelChanged);
    on<OcptProjectSettingsMileageRateAmountChangedEvent>(_onMileageRateAmountChanged);
    on<OcptProjectSettingsMileageRateDeletionConfirmedEvent>(_onMileageRateDeletionConfirmed);
  }

  /// Loads the current project's currency, page format, minimum rest, screenplay language,
  /// episodes and learned dictionary words.
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
    final defaultVatRateBasisPoints = await _projectsManager
        .loadCurrentProjectDefaultVatRateBasisPoints();
    final mealPriceCents = await _projectsManager.loadCurrentProjectMealPriceCents();
    // `project_info.snackPriceCents` under its user-facing name — the column keeps the schema's
    // own name, but what it prices is the buffet, never a snack in the trade's own words.
    final buffetPriceCents = await _projectsManager.loadCurrentProjectSnackPriceCents();
    final screenplayLanguage = await _projectsManager.loadCurrentProjectScreenplayLanguage();
    final episodes = await _projectsManager.screenplayService.loadEpisodes(database: _database);
    final mileageRates = await _projectsManager.budgetFinancingService.loadMileageRates(
      database: _database,
    );
    final dictionaryWords = await _projectsManager.projectDictionaryService.loadWords(
      database: _database,
    );

    emitter(
      state.copyWith(
        isLoading: false,
        currencyCode: currencyCode ?? ocptDefaultCurrencyCode,
        pageFormat: pageFormat ?? OcptPageFormat.usLetter,
        minimumRestMinutes: minimumRestMinutes,
        clearMinimumRestMinutes: minimumRestMinutes == null,
        defaultVatRateBasisPoints: defaultVatRateBasisPoints,
        clearDefaultVatRateBasisPoints: defaultVatRateBasisPoints == null,
        mealPriceCents: mealPriceCents,
        clearMealPriceCents: mealPriceCents == null,
        buffetPriceCents: buffetPriceCents,
        clearBuffetPriceCents: buffetPriceCents == null,
        screenplayLanguage: screenplayLanguage,
        clearScreenplayLanguage: screenplayLanguage == null,
        episodes: episodes,
        mileageRates: mileageRates,
        dictionaryWords: dictionaryWords,
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

  /// Writes the newly committed default VAT rate to the project, then reflects it in the state.
  ///
  /// `event.basisPoints` is written whichever it is, including null and including `0` — the same
  /// reasoning [_onMinimumRestMinutesChanged] already follows for its own field, `0` being as real a
  /// figure here as any other (`OcptProjectSettingsBudgetSection`'s own doc comment).
  Future<void> _onDefaultVatRateBasisPointsChanged(
    OcptProjectSettingsDefaultVatRateBasisPointsChangedEvent event,
    Emitter<OcptProjectSettingsState> emitter,
  ) async {
    await _projectsManager.saveCurrentProjectDefaultVatRateBasisPoints(event.basisPoints);
    emitter(
      state.copyWith(
        defaultVatRateBasisPoints: event.basisPoints,
        clearDefaultVatRateBasisPoints: event.basisPoints == null,
        hasChanged: true,
      ),
    );
  }

  /// Writes the newly committed meal price to the project, then reflects it in the state.
  Future<void> _onMealPriceCentsChanged(
    OcptProjectSettingsMealPriceCentsChangedEvent event,
    Emitter<OcptProjectSettingsState> emitter,
  ) async {
    await _projectsManager.saveCurrentProjectMealPriceCents(event.cents);
    emitter(
      state.copyWith(
        mealPriceCents: event.cents,
        clearMealPriceCents: event.cents == null,
        hasChanged: true,
      ),
    );
  }

  /// Writes the newly committed buffet price to the project, then reflects it in the state —
  /// [_onMealPriceCentsChanged]'s sibling. Still written through
  /// `saveCurrentProjectSnackPriceCents`, the schema column's own name.
  Future<void> _onBuffetPriceCentsChanged(
    OcptProjectSettingsBuffetPriceCentsChangedEvent event,
    Emitter<OcptProjectSettingsState> emitter,
  ) async {
    await _projectsManager.saveCurrentProjectSnackPriceCents(event.cents);
    emitter(
      state.copyWith(
        buffetPriceCents: event.cents,
        clearBuffetPriceCents: event.cents == null,
        hasChanged: true,
      ),
    );
  }

  /// Writes the newly picked screenplay language to the project, then reflects it in the state.
  ///
  /// `event.screenplayLanguage` is written whichever it is, "None" (null) included: it is what
  /// makes the checker's off switch for this screenplay actually reach the project file, the same
  /// reasoning [_onMinimumRestMinutesChanged] already follows for its own field.
  Future<void> _onScreenplayLanguageChanged(
    OcptProjectSettingsScreenplayLanguageChangedEvent event,
    Emitter<OcptProjectSettingsState> emitter,
  ) async {
    await _projectsManager.saveCurrentProjectScreenplayLanguage(event.screenplayLanguage);
    emitter(
      state.copyWith(
        screenplayLanguage: event.screenplayLanguage,
        clearScreenplayLanguage: event.screenplayLanguage == null,
        hasChanged: true,
      ),
    );
  }

  /// Applies `OcptProjectDictionaryDialog`'s reported diff to the project's dictionary, then
  /// re-reads the live word list so the section's count reflects what the database now holds.
  ///
  /// Every removed word is unlearned **before** any added word is learned — the ordering
  /// `OcptProjectDictionaryDialog._close`'s own doc comment relies on: it is what turns a
  /// case-only re-spelling (`marie` removed, `Marie` added) into
  /// `OcptProjectDictionaryService.learnWord` reviving the very row `unlearnWord` just
  /// tombstoned, rather than leaving a duplicate.
  ///
  /// A no-op, emitting nothing, when the dialog reported no change at all: closing it without
  /// touching anything must not mark the page changed.
  Future<void> _onDictionaryEdited(
    OcptProjectSettingsDictionaryEditedEvent event,
    Emitter<OcptProjectSettingsState> emitter,
  ) async {
    if (event.addedWords.isEmpty && event.removedWords.isEmpty) {
      return;
    }

    for (final word in event.removedWords) {
      await _projectsManager.projectDictionaryService.unlearnWord(database: _database, word: word);
    }
    for (final word in event.addedWords) {
      await _projectsManager.projectDictionaryService.learnWord(database: _database, word: word);
    }

    final dictionaryWords = await _projectsManager.projectDictionaryService.loadWords(
      database: _database,
    );
    emitter(state.copyWith(dictionaryWords: dictionaryWords, hasChanged: true));
  }

  /// Appends a new episode, numbered "last + 1" by `OcptScreenplayService.createEpisode` itself,
  /// then re-reads the project's episodes so the card shows what the database now holds.
  ///
  /// The home card's episode badge is told about it right away
  /// ([OcptProjectsManager.recordCurrentProjectEpisodeCount]) rather than left to the project's
  /// close: an app quit from here would never reach that close, and the badge would go on saying
  /// what the project held when it was opened.
  Future<void> _onEpisodeAdded(
    OcptProjectSettingsEpisodeAddedEvent event,
    Emitter<OcptProjectSettingsState> emitter,
  ) async {
    final id = await _projectsManager.screenplayService.createEpisode(database: _database);
    final episodes = await _projectsManager.screenplayService.loadEpisodes(database: _database);
    await _projectsManager.recordCurrentProjectEpisodeCount();
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
  ///
  /// The home card's episode badge is told about it right away, exactly as [_onEpisodeAdded] does.
  Future<void> _onEpisodeDeletionConfirmed(
    OcptProjectSettingsEpisodeDeletionConfirmedEvent event,
    Emitter<OcptProjectSettingsState> emitter,
  ) async {
    final deleted = await _projectsManager.screenplayService.deleteEpisode(
      database: _database,
      screenplayId: event.screenplayId,
    );
    final episodes = await _projectsManager.screenplayService.loadEpisodes(database: _database);
    await _projectsManager.recordCurrentProjectEpisodeCount();
    emitter(state.copyWith(episodes: episodes, hasChanged: deleted ? true : null));
  }

  /// Appends a new, blank mileage rate, then re-reads the project's rates so the card shows what
  /// the database now holds.
  Future<void> _onMileageRateAdded(
    OcptProjectSettingsMileageRateAddedEvent event,
    Emitter<OcptProjectSettingsState> emitter,
  ) async {
    final id = await _projectsManager.budgetFinancingService.createMileageRate(
      database: _database,
      label: "",
    );
    final mileageRates = await _projectsManager.budgetFinancingService.loadMileageRates(
      database: _database,
    );
    emitter(state.copyWith(mileageRates: mileageRates, hasChanged: id != null ? true : null));
  }

  /// Writes the newly committed label of mileage rate `event.rateId`, then re-reads the project's
  /// rates.
  Future<void> _onMileageRateLabelChanged(
    OcptProjectSettingsMileageRateLabelChangedEvent event,
    Emitter<OcptProjectSettingsState> emitter,
  ) async {
    await _projectsManager.budgetFinancingService.updateMileageRate(
      database: _database,
      rateId: event.rateId,
      label: Value(event.label),
    );
    final mileageRates = await _projectsManager.budgetFinancingService.loadMileageRates(
      database: _database,
    );
    emitter(state.copyWith(mileageRates: mileageRates, hasChanged: true));
  }

  /// Writes the newly committed per-kilometre rate of mileage rate `event.rateId`, then re-reads
  /// the project's rates.
  Future<void> _onMileageRateAmountChanged(
    OcptProjectSettingsMileageRateAmountChangedEvent event,
    Emitter<OcptProjectSettingsState> emitter,
  ) async {
    await _projectsManager.budgetFinancingService.updateMileageRate(
      database: _database,
      rateId: event.rateId,
      ratePerKmMilliCents: Value(event.ratePerKmMilliCents),
    );
    final mileageRates = await _projectsManager.budgetFinancingService.loadMileageRates(
      database: _database,
    );
    emitter(state.copyWith(mileageRates: mileageRates, hasChanged: true));
  }

  /// Deletes `event.rateId`, once the page's own `OcptConfirmDialog` confirmed it, then re-reads
  /// the project's remaining rates.
  ///
  /// `OcptBudgetFinancingService.deleteMileageRate` tombstones the row rather than erasing it
  /// (ADR 0010): a live person may still name it through `people.mileageRateId`, and that foreign
  /// key stays satisfied either way, since the row itself is still there — only marked deleted.
  Future<void> _onMileageRateDeletionConfirmed(
    OcptProjectSettingsMileageRateDeletionConfirmedEvent event,
    Emitter<OcptProjectSettingsState> emitter,
  ) async {
    await _projectsManager.budgetFinancingService.deleteMileageRate(
      database: _database,
      rateId: event.rateId,
    );
    final mileageRates = await _projectsManager.budgetFinancingService.loadMileageRates(
      database: _database,
    );
    emitter(state.copyWith(mileageRates: mileageRates, hasChanged: true));
  }
}
