// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:act_global_manager/act_global_manager.dart';
import 'package:drift/drift.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/managers/sync/ocpt_relay_host_manager.dart';
import 'package:open_cine_prod_tools/managers/sync/ocpt_sync_manager.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_project_info_table.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_relay_host_state.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/ui/pages/project_settings/project_settings_event.dart';
import 'package:open_cine_prod_tools/ui/pages/project_settings/project_settings_state.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

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
///
/// The `Project file` card is the one exception to "writes the moment it changes": `Show in
/// folder` only ever reads the current path, and `Move…` ([_onMoveRequested]) goes through a
/// native save-file dialog first, exactly like a project's own creation
/// (`OcptHomeBloc._onCreateProjectRequested`) — dialogs are a page/bloc concern throughout this
/// app, never a manager's. `Move…` is withheld on mobile (no such dialog there) and while an
/// in-app-hosted relay is online for this very project
/// ([_isHostingOnlineForCurrentProject]) — the second check has to live here rather than inside
/// `OcptProjectsManager.moveCurrentProject` itself: that manager is a dependency of both
/// `OcptSyncManager` and, through it, `OcptRelayHostManager`, and may never import either
/// (`AGENTS.md`, "Dependencies never reference their dependents"). This bloc also stops and
/// restarts the sync session around the move for the very same reason
/// (`OcptProjectsManager.moveCurrentProject`'s own doc comment).
class OcptProjectSettingsBloc extends BlocForMixin<OcptProjectSettingsState> {
  /// The manager used to read and write the current project's settings.
  final OcptProjectsManager _projectsManager;

  /// The manager used to show the `Move…` action's native save-file dialog, and to tell desktop
  /// from mobile ([OcptExportManager.isMobile]) — resolved lazily and tolerant of its absence, see
  /// [_exportManager]'s own doc comment.
  final OcptExportManager? _exportManagerOverride;

  /// The manager owning the sync session [_onMoveRequested] stops before the swap and
  /// [_restartSyncSessionIfPaired] restarts afterwards, and that [_isHostingOnlineForCurrentProject]
  /// reads the currently open project's own relay-side id through — resolved lazily and tolerant of
  /// its absence, see [_syncManager]'s own doc comment.
  final OcptSyncManager? _syncManagerOverride;

  /// The manager [_isHostingOnlineForCurrentProject] reads to decide whether `Move…` is withheld —
  /// resolved lazily and tolerant of its absence, see [_hostManager]'s own doc comment.
  final OcptRelayHostManager? _hostManagerOverride;

  /// The manager [_restartSyncSessionIfPaired] reads this replica's own device id through —
  /// resolved lazily and tolerant of its absence, see [_propertiesManager]'s own doc comment.
  final OcptPropertiesManager? _propertiesManagerOverride;

  /// Class constructor
  OcptProjectSettingsBloc({
    OcptProjectsManager? projectsManager,
    OcptExportManager? exportManager,
    OcptSyncManager? syncManager,
    OcptRelayHostManager? hostManager,
    OcptPropertiesManager? propertiesManager,
  }) : _projectsManager = projectsManager ?? globalGetIt().get<OcptProjectsManager>(),
       _exportManagerOverride = exportManager,
       _syncManagerOverride = syncManager,
       _hostManagerOverride = hostManager,
       _propertiesManagerOverride = propertiesManager,
       super(const OcptProjectSettingsState.init()) {
    add(const OcptProjectSettingsLoadRequestedEvent());
  }

  /// The current project's database. The route that reaches this page is guarded exactly like the
  /// workspace's own, so a project is always open by the time an episode mutation runs.
  OcptProjectDatabase get _database => _projectsManager.currentProject!.database;

  /// [_exportManagerOverride], or the one `globalGetIt()` holds when an app-wide manager
  /// environment actually registered one, or null otherwise — resolved lazily on every access
  /// rather than eagerly in the constructor, exactly as `OcptWorkspaceBloc._syncManager` is and for
  /// the same reason: this page's own widget tests build a bare `OcptProjectSettingsBloc()` with no
  /// reason to ever register an export manager, and [_onLoadRequested]/[_onMoveRequested] simply
  /// treat its absence as "desktop, nothing hosted" rather than crash.
  OcptExportManager? get _exportManager {
    final override = _exportManagerOverride;
    if (override != null) {
      return override;
    }
    if (AbsGlobalManager.instance == null) {
      return null;
    }

    final managers = globalGetIt();
    return managers.isRegistered<OcptExportManager>() ? managers.get<OcptExportManager>() : null;
  }

  /// [_syncManagerOverride], or the one `globalGetIt()` holds when an app-wide manager environment
  /// actually registered one, or null otherwise — resolved lazily for the very same reason
  /// [_exportManager] is.
  OcptSyncManager? get _syncManager {
    final override = _syncManagerOverride;
    if (override != null) {
      return override;
    }
    if (AbsGlobalManager.instance == null) {
      return null;
    }

    final managers = globalGetIt();
    return managers.isRegistered<OcptSyncManager>() ? managers.get<OcptSyncManager>() : null;
  }

  /// [_hostManagerOverride], or the one `globalGetIt()` holds when an app-wide manager environment
  /// actually registered one, or null otherwise — resolved lazily for the very same reason
  /// [_exportManager] is.
  OcptRelayHostManager? get _hostManager {
    final override = _hostManagerOverride;
    if (override != null) {
      return override;
    }
    if (AbsGlobalManager.instance == null) {
      return null;
    }

    final managers = globalGetIt();
    return managers.isRegistered<OcptRelayHostManager>()
        ? managers.get<OcptRelayHostManager>()
        : null;
  }

  /// [_propertiesManagerOverride], or the one `globalGetIt()` holds when an app-wide manager
  /// environment actually registered one, or null otherwise — resolved lazily for the very same
  /// reason [_exportManager] is.
  OcptPropertiesManager? get _propertiesManager {
    final override = _propertiesManagerOverride;
    if (override != null) {
      return override;
    }
    if (AbsGlobalManager.instance == null) {
      return null;
    }

    final managers = globalGetIt();
    return managers.isRegistered<OcptPropertiesManager>()
        ? managers.get<OcptPropertiesManager>()
        : null;
  }

  /// {@macro act_flutter_utility.BlocForMixin.registerMixinEvents}
  @override
  void registerMixinEvents() {
    super.registerMixinEvents();
    on<OcptProjectSettingsLoadRequestedEvent>(_onLoadRequested);
    on<OcptProjectSettingsShowInFolderRequestedEvent>(_onShowInFolderRequested);
    on<OcptProjectSettingsMoveRequestedEvent>(_onMoveRequested);
    on<OcptProjectSettingsMoveErrorDismissedEvent>(_onMoveErrorDismissed);
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
    final projectFilePath = _projectsManager.currentProject!.path;
    final isMobile = _exportManager?.isMobile ?? false;
    final isMoveWithheldByHosting = await _isHostingOnlineForCurrentProject();

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
        projectFilePath: projectFilePath,
        isShowInFolderAvailable: !isMobile,
        isMoveAvailable: !isMobile && !isMoveWithheldByHosting,
        isMoveWithheldByHosting: isMoveWithheldByHosting,
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

  /// Whether an in-app-hosted relay is currently online for the very project this page is open on
  /// — what [_onLoadRequested] withholds `Move…` for, since a hosted relay keeps this project's
  /// `.relay.sqlite` sidecar open (`OcptProjectsManager.moveCurrentProject`'s own doc comment
  /// explains why the manager itself cannot check this).
  ///
  /// False whenever [_hostManager] or [_syncManager] isn't registered (every widget test that
  /// doesn't exercise this), whenever nothing is hosted at all, and whenever something is hosted
  /// but it is a *different* project than this one — the hosted relay-side id
  /// ([OcptRelayHostManager.hostedProjectId]) is compared against this project's own
  /// ([OcptSyncManager.loadPairedProjectId]), since hosting outlives the workspace bloc across a
  /// navigation to a different project (`docs/architecture/sync.md`).
  Future<bool> _isHostingOnlineForCurrentProject() async {
    final hostManager = _hostManager;
    final syncManager = _syncManager;
    final project = _projectsManager.currentProject;
    if (hostManager == null || syncManager == null || project == null) {
      return false;
    }
    if (hostManager.state is! OcptRelayHostOnline) {
      return false;
    }

    final projectId = await syncManager.loadPairedProjectId(project.fileDatabase);
    return projectId != null && projectId == hostManager.hostedProjectId;
  }

  /// Opens the current project's file in the platform's own file manager — the `Project file`
  /// card's own `Show in folder` action. A failure (no file manager registered to handle a
  /// `file://` URI, most likely) is only ever logged: there is nothing here worth interrupting the
  /// user for.
  Future<void> _onShowInFolderRequested(
    OcptProjectSettingsShowInFolderRequestedEvent event,
    Emitter<OcptProjectSettingsState> emitter,
  ) async {
    final projectFilePath = _projectsManager.currentProject?.path;
    if (projectFilePath == null) {
      return;
    }

    try {
      await launchUrl(Uri.directory(p.dirname(projectFilePath)));
    } catch (error) {
      appLogger().w("Could not open the project's own folder: $error");
    }
  }

  /// Shows the native save-file dialog, suggesting the project's current file name inside its
  /// current folder, and moves the project's file there once the user picks a destination — the
  /// `Project file` card's own `Move…` action. A cancelled dialog is a silent no-op.
  ///
  /// A sync session running against the project is stopped before the move and restarted against
  /// the moved database afterwards ([_restartSyncSessionIfPaired]) — `OcptProjectsManager` cannot
  /// do this itself (see [OcptProjectsManager.moveCurrentProject]'s own doc comment), and a session
  /// left running across the swap would find its database connection closed under it.
  ///
  /// A failure is left in [OcptProjectSettingsState.moveError] for the page to word; on success the
  /// state's own [OcptProjectSettingsState.projectFilePath] reflects the new location.
  Future<void> _onMoveRequested(
    OcptProjectSettingsMoveRequestedEvent event,
    Emitter<OcptProjectSettingsState> emitter,
  ) async {
    final exportManager = _exportManager;
    final currentPath = _projectsManager.currentProject?.path;
    if (exportManager == null || currentPath == null) {
      return;
    }

    final newFilePath = await exportManager.saveLocationService.pickSaveLocation(
      suggestedFileName: p.basename(currentPath),
      fileTypeLabel: event.fileTypeLabel,
      extensions: [OcptProjectsManager.projectFileExtension],
      initialDirectory: p.dirname(currentPath),
    );
    if (newFilePath == null) {
      // The user cancelled the save-file dialog.
      return;
    }

    final syncManager = _syncManager;
    final hadSyncSession = syncManager?.syncSession != null;
    if (hadSyncSession) {
      await syncManager!.stopSyncSession();
    }

    final result = await _projectsManager.moveCurrentProject(newFilePath: newFilePath);

    if (hadSyncSession) {
      await _restartSyncSessionIfPaired();
    }

    if (!result.status.isSuccess) {
      emitter(state.copyWith(moveError: result.status));
      return;
    }

    emitter(state.copyWith(projectFilePath: result.value!.path, clearMoveError: true));
  }

  /// Restarts the sync session [_onMoveRequested] stopped before the move, now against the moved
  /// project's own (freshly opened) database — mirrors `OcptWorkspaceBloc._startSyncSessionIfPaired`
  /// step for step, reading the very same `sync_pairings` row and starting the very same way, since
  /// the move touched nothing about the pairing itself, only which file and connection it lives on.
  ///
  /// A project counts as paired only when both halves of its pairing are still there, exactly as
  /// `OcptWorkspaceBloc._startSyncSessionIfPaired`'s own doc comment explains; any failure along the
  /// way is swallowed rather than left to escape as an unhandled error, for the very same reason.
  Future<void> _restartSyncSessionIfPaired() async {
    final syncManager = _syncManager;
    final propertiesManager = _propertiesManager;
    final project = _projectsManager.currentProject;
    if (syncManager == null || propertiesManager == null || project == null) {
      return;
    }

    try {
      final database = project.fileDatabase;
      final row = await database.select(database.ocptSyncPairingsTable).getSingleOrNull();
      if (row == null) {
        return;
      }

      final pairing = await syncManager.pairingService.loadPairing(
        database: database,
        projectId: row.projectId,
      );
      if (pairing == null) {
        return;
      }

      final deviceId = await propertiesManager.loadOrCreateDeviceId();
      await syncManager.startSyncSession(
        projectId: row.projectId,
        database: database,
        deviceId: deviceId,
        relayId: OcptSyncManager.relayIdFor(pairing),
        storage: syncManager.openRelayRemoteStorage(pairing, row.projectId),
      );
    } catch (error) {
      appLogger().w("Could not restart the sync session after moving the project: $error");
    }
  }

  /// Clears the transient move error currently shown, if any.
  Future<void> _onMoveErrorDismissed(
    OcptProjectSettingsMoveErrorDismissedEvent event,
    Emitter<OcptProjectSettingsState> emitter,
  ) async {
    emitter(state.copyWith(clearMoveError: true));
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
