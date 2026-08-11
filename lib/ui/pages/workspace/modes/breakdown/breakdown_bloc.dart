// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:act_global_manager/act_global_manager.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_breakdown_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_elements_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_locations_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_people_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_role_index_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_scene.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_tag.dart';
import 'package:open_cine_prod_tools/models/ocpt_open_project_model.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_centre_view.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_right_dock_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_target_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_source_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/mixin_ocpt_project_versions_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_versions_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/breakdown_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/breakdown_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock.dart';
import 'package:open_cine_prod_tools/utils/ocpt_breakdown_legend.dart';
import 'package:open_cine_prod_tools/utils/ocpt_breakdown_tag_span.dart';
import 'package:open_cine_prod_tools/utils/ocpt_scene_display_number.dart';

/// This is the bloc class for the breakdown production mode (dépouillement du scénario).
///
/// It loads the current project's title, the two dock fractions, the last right dock tab, and the
/// mode's own read on entry — the screenplay's Fountain text (kept in state for
/// `OcptBreakdownScriptView` to slice scene by scene), the page setup the script view is typeset
/// with, and one [OcptBreakdownSnapshot] joining [_breakdownService]'s scenes and tags with
/// [_elementsService]/[_roleIndexService]/[_locationsService]/[_peopleService]'s four catalogues, the
/// way `OcptResourcesBloc` builds its own `OcptResourcesSnapshot` — and holds the selected scene, the
/// selected target, the legend's hidden keys, the left dock's visibility, the right dock tab and the
/// two fractions on top of it. Selecting a target or a scene, and hiding a legend key, write nothing
/// to the project database, so none of the three is ever flushed by [flushPendingProjectWrites] and
/// all three live only in this bloc's own state.
///
/// The selected target's four free-text fields (`OcptElementField.name`/`.subCategory`/`.quantity`/
/// `.notes`) and the selected scene's own breakdown notes are what write here through typing, and
/// they ride the same debounce idiom `OcptResourcesBloc`'s five `pending…FieldEdits` maps do: an
/// edit is held in [OcptBreakdownState.pendingElementFieldEdits] or
/// [OcptBreakdownState.pendingSceneNotesEdits] and written [_fieldEditDebounce] after the last
/// keystroke, flushed immediately by [_flushPendingFieldEdits] on a target or scene selection
/// change, a right dock tab change, a version preview ([flushPendingProjectWrites]) and the mode
/// leaving the tree ([flushPendingFieldEdits], called by the mode's own `deactivate()`). Every other
/// write the target inspector or the scene inspector offers — the target's status, its category,
/// its owner, who brings it and its tag removal, and the scene's own breakdown status — is a single
/// pick rather than typing, so it is written immediately by its own event.
///
/// [_onWordClicked] owns the script view's range interaction: a first click opens
/// [OcptBreakdownState.pendingTagAnchor], a second one in the same scene closes it into
/// [OcptBreakdownState.pendingTagRange] — the script view's own cue to open the tag popover — and
/// [_onPopoverTargetLinked]/[_onPopoverElementCreationRequested] are the popover's two ways of
/// answering it, both going through [_breakdownService] (`createTag`/`createElementAndTag`) and both
/// ending the same way: the popover closes, the anchor clears, the snapshot reloads and the linked
/// or newly created target is selected on the `Inspector` tab.
///
/// It also mixes in [MixinOcptProjectVersionsBloc], which owns everything the right dock's
/// `Versions` tab does. The two hooks the mixin needs are answered by [flushPendingProjectWrites]
/// and [reloadFromProjectDatabase]. [_onRightDockTabSelected] dispatches
/// [OcptProjectWorkingCopyRefreshRequestedEvent] on opening the `Versions` tab, exactly as the other
/// two modes do, and so does [_flushPendingFieldEdits] when a field edit lands while that tab
/// is already open — the two moments the mixin's working-copy card is worth a fresh, throttled read.
class OcptBreakdownBloc extends BlocForMixin<OcptBreakdownState>
    with MixinOcptProjectVersionsBloc<OcptBreakdownState> {
  /// The default delay between the last field edit and its autosave write.
  static const defaultFieldEditDebounce = Duration(seconds: 2);

  /// The manager used to access the project currently open.
  final OcptProjectsManager _projectsManager;

  /// The manager used to load and persist the mode's dock fractions and last right dock tab.
  final OcptPropertiesManager _propertiesManager;

  /// The router manager used to navigate back to the home page when leaving the workspace.
  final OcptRouterManager _routerManager;

  /// The manager the breakdown sheets export goes through.
  final OcptExportManager _exportManager;

  /// The service used to read the breakdown scenes and tags, and to remove one.
  final OcptBreakdownService _breakdownService;

  /// The service used to read the physical elements catalogue, and to write the selected target's
  /// own fields.
  final OcptElementsService _elementsService;

  /// The service used to read the cast, reconciled against the project's episodes.
  final OcptRoleIndexService _roleIndexService;

  /// The service used to read locations and their sets.
  final OcptLocationsService _locationsService;

  /// The service used to read the address book the target inspector's owner and who-brings-it
  /// pickers offer.
  final OcptPeopleService _peopleService;

  /// The delay between the last field edit and its autosave write.
  final Duration _fieldEditDebounce;

  /// The running field-edit debounce timer, if any.
  Timer? _fieldEditTimer;

  /// The episode this bloc reads and writes, handed down by `OcptBreakdownMode` from
  /// `OcptWorkspaceBloc.state.selectedEpisodeId` at construction time — safe to capture once
  /// rather than watch, since `WorkspacePage` remounts this whole bloc on every episode switch (see
  /// `WorkspacePage._buildActiveMode`'s own doc comment), so the field can never go stale.
  ///
  /// Null only for a project holding no episode at all: `OcptWorkspaceBloc` lands on the first one
  /// before it clears `isLoading`, and a mode is never built before that, so [_screenplayIdOf]'s
  /// fallback to [OcptOpenProjectModel.primaryScreenplayId] is the honest last resort rather than a
  /// routine path.
  final String? _selectedEpisodeId;

  /// Class constructor
  ///
  /// Every dependency can be overridden, which is what the tests do; in the app they all resolve
  /// through [globalGetIt]. [fieldEditDebounce] is only meant to be overridden by tests, to keep it
  /// fast and deterministic.
  OcptBreakdownBloc({
    OcptProjectsManager? projectsManager,
    OcptPropertiesManager? propertiesManager,
    OcptRouterManager? routerManager,
    OcptExportManager? exportManager,
    OcptBreakdownService? breakdownService,
    OcptElementsService? elementsService,
    OcptRoleIndexService? roleIndexService,
    OcptLocationsService? locationsService,
    OcptPeopleService? peopleService,
    Duration fieldEditDebounce = defaultFieldEditDebounce,
    String? selectedEpisodeId,
  }) : _selectedEpisodeId = selectedEpisodeId,
       _projectsManager = projectsManager ?? globalGetIt().get<OcptProjectsManager>(),
       _propertiesManager = propertiesManager ?? globalGetIt().get<OcptPropertiesManager>(),
       _routerManager = routerManager ?? globalGetIt().get<OcptRouterManager>(),
       _exportManager = exportManager ?? globalGetIt().get<OcptExportManager>(),
       _breakdownService =
           breakdownService ??
           (projectsManager ?? globalGetIt().get<OcptProjectsManager>()).breakdownService,
       _elementsService =
           elementsService ??
           (projectsManager ?? globalGetIt().get<OcptProjectsManager>()).elementsService,
       _roleIndexService =
           roleIndexService ??
           (projectsManager ?? globalGetIt().get<OcptProjectsManager>()).roleIndexService,
       _locationsService =
           locationsService ??
           (projectsManager ?? globalGetIt().get<OcptProjectsManager>()).locationsService,
       _peopleService =
           peopleService ??
           (projectsManager ?? globalGetIt().get<OcptProjectsManager>()).peopleService,
       _fieldEditDebounce = fieldEditDebounce,
       super(OcptBreakdownState.init()) {
    add(const OcptBreakdownLoadRequestedEvent());
  }

  /// {@macro act_flutter_utility.BlocForMixin.registerMixinEvents}
  @override
  void registerMixinEvents() {
    super.registerMixinEvents();
    on<OcptBreakdownLoadRequestedEvent>(_onLoadRequested);
    on<OcptBreakdownBackRequestedEvent>(_onBackRequested);
    on<OcptBreakdownProjectSettingsChangedEvent>(_onProjectSettingsChanged);
    on<OcptBreakdownSheetsExportRequestedEvent>(_onSheetsExportRequested);
    on<OcptBreakdownXlsxExportRequestedEvent>(_onXlsxExportRequested);
    on<OcptBreakdownIoNoticeDismissedEvent>(_onIoNoticeDismissed);
    on<OcptBreakdownSceneSelectedEvent>(_onSceneSelected);
    on<OcptBreakdownSceneHeadingSelectedEvent>(_onSceneHeadingSelected);
    on<OcptBreakdownLeftPanelToggledEvent>(_onLeftPanelToggled);
    on<OcptBreakdownRightDockTabSelectedEvent>(_onRightDockTabSelected);
    on<OcptBreakdownRightDockToggledEvent>(_onRightDockToggled);
    on<OcptBreakdownRightDockClosedEvent>(_onRightDockClosed);
    on<OcptBreakdownDockFractionsChangedEvent>(_onDockFractionsChanged);
    on<OcptBreakdownDockLayoutResetEvent>(_onDockLayoutReset);
    on<OcptBreakdownLegendEntryToggledEvent>(_onLegendEntryToggled);
    on<OcptBreakdownLegendShowAllRequestedEvent>(_onLegendShowAllRequested);
    on<OcptBreakdownCentreViewSelectedEvent>(_onCentreViewSelected);
    on<OcptBreakdownSearchQueryChangedEvent>(_onSearchQueryChanged);
    on<OcptBreakdownTargetSelectedEvent>(_onTargetSelected);
    on<OcptBreakdownTargetSelectionClearedEvent>(_onTargetSelectionCleared);
    on<OcptBreakdownWordClickedEvent>(_onWordClicked);
    on<OcptBreakdownSceneStatusChangedEvent>(_onSceneStatusChanged);
    on<OcptBreakdownSceneSetLinkedEvent>(_onSceneSetLinked);
    on<OcptBreakdownSceneSetUnlinkedEvent>(_onSceneSetUnlinked);
    on<OcptBreakdownSceneSetCreationRequestedEvent>(_onSceneSetCreationRequested);
    on<OcptBreakdownSceneNotesChangedEvent>(_onSceneNotesChanged);
    on<OcptBreakdownElementStatusChangedEvent>(_onElementStatusChanged);
    on<OcptBreakdownElementCategoryChangedEvent>(_onElementCategoryChanged);
    on<OcptBreakdownElementFieldChangedEvent>(_onElementFieldChanged);
    on<OcptBreakdownSetNameChangedEvent>(_onSetNameChanged);
    on<OcptBreakdownFieldEditFlushRequestedEvent>(_onFieldEditFlushRequested);
    on<OcptBreakdownElementOwnerChangedEvent>(_onElementOwnerChanged);
    on<OcptBreakdownElementBringerChangedEvent>(_onElementBringerChanged);
    on<OcptBreakdownOccurrenceSelectedEvent>(_onOccurrenceSelected);
    on<OcptBreakdownTagRemovalConfirmedEvent>(_onTagRemovalConfirmed);
    on<OcptBreakdownTagRangeCancelledEvent>(_onTagRangeCancelled);
    on<OcptBreakdownPopoverTargetLinkedEvent>(_onPopoverTargetLinked);
    on<OcptBreakdownPopoverElementCreationRequestedEvent>(_onPopoverElementCreationRequested);
    on<OcptBreakdownPopoverSetCreationRequestedEvent>(_onPopoverSetCreationRequested);
    on<OcptBreakdownTagWriteErrorDismissedEvent>(_onTagWriteErrorDismissed);
    on<OcptBreakdownTagNeedsCheckClearedEvent>(_onTagNeedsCheckCleared);
    on<OcptBreakdownFlaggedTagRemovedEvent>(_onFlaggedTagRemoved);
    on<OcptBreakdownSuggestionAcceptedEvent>(_onSuggestionAccepted);
  }

  /// {@macro open_cine_prod_tools.MixinOcptProjectVersionsBloc.projectsManager}
  @protected
  @override
  OcptProjectsManager get projectsManager => _projectsManager;

  /// The screenplay this bloc reads and writes: [_selectedEpisodeId], or [project]'s own
  /// [OcptOpenProjectModel.primaryScreenplayId] on the one path that can reach here with none
  /// selected (see [_selectedEpisodeId]'s own doc comment).
  String _screenplayIdOf(OcptOpenProjectModel project) =>
      _selectedEpisodeId ?? project.primaryScreenplayId;

  /// Writes whatever target field edit or scene notes edit is still sitting in the field-edit
  /// debounce, so a preview about to swap the database can't send it into the previewed version
  /// instead.
  @protected
  @override
  Future<void> flushPendingProjectWrites(Emitter<OcptBreakdownState> emitter) =>
      _flushPendingFieldEdits(emitter);

  /// {@macro open_cine_prod_tools.MixinOcptProjectVersionsBloc.reloadFromProjectDatabase}
  @protected
  @override
  Future<void> reloadFromProjectDatabase(Emitter<OcptBreakdownState> emitter) =>
      _onLoadRequested(const OcptBreakdownLoadRequestedEvent(), emitter);

  /// Loads the persisted dock fractions and the current project's whole breakdown read.
  ///
  /// The workspace route is guarded by the router manager, so a project is normally always open
  /// here; if none is (e.g. the bloc is built directly in a test), the state simply stops loading
  /// with no snapshot at all.
  ///
  /// This is also [MixinOcptProjectVersionsBloc]'s [reloadFromProjectDatabase] hook, so it emits
  /// which version is being previewed alongside the read it just performed: what it read comes from
  /// that very version's in-memory database, and the two must reach the mode together (see the
  /// hook's own doc comment). The selected scene and the selected target are always cleared on a
  /// (re)load, mirroring `OcptResourcesBloc`'s own selection reset: a preview or a restore changes
  /// the whole database underneath, so a stale selection is dropped rather than trusted to still
  /// mean the same thing — and so is any tag-removal confirmation the previous selection was asking
  /// for, and any element field edit or scene notes edit still sitting in the debounce (the caller
  /// flushes it through [flushPendingProjectWrites] first whenever losing it here would matter; a
  /// bare page-format reload never reaches this method at all, see [_onProjectSettingsChanged]).
  Future<void> _onLoadRequested(
    OcptBreakdownLoadRequestedEvent event,
    Emitter<OcptBreakdownState> emitter,
  ) async {
    final leftDockFraction =
        await _propertiesManager.breakdownLeftDockFraction.load() ??
        OcptWorkspaceDock.leftDefaultFraction;
    final rightDockFraction =
        await _propertiesManager.breakdownRightDockFraction.load() ??
        OcptWorkspaceDock.rightDefaultFraction;
    final lastRightDockTab =
        await _propertiesManager.breakdownLastRightDockTab.load() ??
        OcptBreakdownRightDockTab.inspector;

    final project = _projectsManager.currentProject;
    if (project == null) {
      emitter(
        state.copyWith(
          isLoading: false,
          leftDockFraction: leftDockFraction,
          rightDockFraction: rightDockFraction,
          lastRightDockTab: lastRightDockTab,
          clearPreviewedVersionId: true,
          clearPendingTagAnchor: true,
          clearPendingTagRange: true,
          hasTagWriteError: false,
        ),
      );
      return;
    }

    final previewedVersion = project.previewedVersion;
    final screenplayText = await _loadScreenplayText(project);
    final pageSetup = await _loadPageSetup(project);
    final snapshot = await _loadSnapshot(project);

    emitter(
      state.copyWith(
        isLoading: false,
        title: project.name,
        previewedVersionId: previewedVersion?.id,
        clearPreviewedVersionId: previewedVersion == null,
        screenplayText: screenplayText,
        pageSetup: pageSetup,
        snapshot: snapshot,
        clearSelectedSceneId: true,
        clearSelectedTargetRef: true,
        leftDockFraction: leftDockFraction,
        rightDockFraction: rightDockFraction,
        lastRightDockTab: lastRightDockTab,
        pendingElementFieldEdits: const {},
        pendingSceneNotesEdits: const {},
        pendingSetNameEdits: const {},
        clearPendingTagAnchor: true,
        clearPendingTagRange: true,
        hasTagWriteError: false,
      ),
    );
  }

  /// Reads the selected episode's current Fountain source text, kept in
  /// `OcptBreakdownState.screenplayText` for the script view to slice scene by scene.
  Future<String> _loadScreenplayText(OcptOpenProjectModel project) =>
      _projectsManager.screenplayService.loadScreenplayText(
        database: project.database,
        screenplayId: _screenplayIdOf(project),
      );

  /// Reads the page setup the script view is typeset with: the open project's own page format,
  /// paired with the app-wide margins preference, exactly as `OcptShotListBloc`'s own scenario
  /// coverage dialog pairs them.
  ///
  /// A version being previewed is laid out with the setup it was written against instead, which
  /// travels on the open project model and is never written anywhere.
  Future<OcptPageSetup> _loadPageSetup(OcptOpenProjectModel project) async =>
      project.previewedPageSetup ??
      OcptPageSetup(
        format: await _projectsManager.loadCurrentProjectPageFormat() ?? OcptPageFormat.usLetter,
        margins: await _propertiesManager.pageMargins.load() ?? const FountainPageMargins.standard(),
      );

  /// Reads the whole breakdown of the selected episode's screenplay, joining
  /// [_breakdownService]'s scenes and tags with [_elementsService]/[_roleIndexService]/
  /// [_locationsService]/[_peopleService]'s four catalogues into one [OcptBreakdownSnapshot].
  ///
  /// The scenes are numbered with their episode's own prefix: this bloc reads the project's live
  /// episodes through [_projectsManager]'s own `screenplayService` (never through
  /// [_breakdownService], which `OcptScreenplayService` already depends on) and resolves the
  /// selected episode's number with `ocptEpisodePrefixNumberOf`, null on a single-episode project.
  Future<OcptBreakdownSnapshot> _loadSnapshot(OcptOpenProjectModel project) async {
    final database = project.database;
    final screenplayId = _screenplayIdOf(project);

    final episodes = await _projectsManager.screenplayService.loadEpisodes(database: database);
    final episodeNumber = ocptEpisodePrefixNumberOf(episodes: episodes, screenplayId: screenplayId);

    final scenes = await _breakdownService.loadScenes(
      database: database,
      screenplayId: screenplayId,
      episodeNumber: episodeNumber,
    );
    final tagRows = await _breakdownService.loadTags(
      database: database,
      screenplayId: screenplayId,
    );
    final elements = await _elementsService.loadElements(database: database);
    final roles = await _roleIndexService.loadRoles(database: database);
    final locations = await _locationsService.loadLocations(database: database);
    final people = await _peopleService.loadPeople(database: database);

    return OcptBreakdownSnapshot.build(
      screenplayId: screenplayId,
      scenes: scenes,
      tags: [for (final row in tagRows) OcptBreakdownTag.fromRow(row)],
      elements: elements,
      roles: roles,
      sets: [for (final location in locations) ...location.sets],
      locations: locations,
      people: people,
    );
  }

  /// Leaves the workspace: closes the current project and navigates back to the home page.
  Future<void> _onBackRequested(
    OcptBreakdownBackRequestedEvent event,
    Emitter<OcptBreakdownState> emitter,
  ) async {
    await _projectsManager.closeCurrentProject();
    _routerManager.pop();
  }

  /// Re-reads the page setup after the project settings page changed something.
  ///
  /// Nothing in the snapshot itself depends on the page format, but reloading it here too is what
  /// keeps this mode from being the one place a change made on the project settings page is
  /// silently missed, mirroring `OcptShotListBloc._onProjectSettingsChanged`.
  Future<void> _onProjectSettingsChanged(
    OcptBreakdownProjectSettingsChangedEvent event,
    Emitter<OcptBreakdownState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final pageSetup = await _loadPageSetup(project);
    emitter(state.copyWith(pageSetup: pageSetup));
  }

  /// Exports one breakdown sheet per scene, as a PDF.
  ///
  /// Built exactly as the other two modes' own export handlers are: flush whatever is still pending
  /// — that flush re-reads the snapshot, so a sheet holds the name or the note the user typed
  /// seconds ago — then hand what the state now carries to
  /// [OcptExportManager.exportBreakdownSheets]. A cancelled save dialog is a silent no-op; a
  /// failure raises the transient export-failed notice.
  ///
  /// [OcptBreakdownState.screenplayText] is parsed here rather than kept parsed in the state: the
  /// document is only needed by this export, and only for each scene's own length.
  Future<void> _onSheetsExportRequested(
    OcptBreakdownSheetsExportRequestedEvent event,
    Emitter<OcptBreakdownState> emitter,
  ) async {
    await _flushPendingFieldEdits(emitter);

    final snapshot = state.snapshot;
    if (snapshot == null) {
      return;
    }

    try {
      final options = event.options;
      final path = await _exportManager.exportBreakdownSheets(
        document: const FountainParser().parse(state.screenplayText),
        snapshot: snapshot,
        pageSetup: OcptPageSetup(format: options.format, margins: options.margins),
        labels: event.labels,
        projectName: state.title,
        onlyDoneScenes: options.onlyDoneScenes,
        includeNotes: options.includeNotes,
        includeToFindList: options.includeToFindList,
        fileTypeLabel: event.fileTypeLabel,
        episodeTag: event.episodeTag,
      );
      if (path == null) {
        // The user cancelled the save dialog.
        return;
      }

      emitter(
        state.copyWith(
          ioNotice: OcptBreakdownIoNotice(
            kind: OcptBreakdownIoNoticeKind.sheetsExportSucceeded,
            path: path,
          ),
        ),
      );
    } catch (error) {
      appLogger().e("A problem occurred when tried to export the breakdown sheets of the project "
          "at ${_projectsManager.currentProject?.path}: $error");
      emitter(
        state.copyWith(
          ioNotice: const OcptBreakdownIoNotice(
            kind: OcptBreakdownIoNoticeKind.sheetsExportFailed,
          ),
        ),
      );
    }
  }

  /// Exports the whole breakdown as a two-sheet XLSX workbook.
  ///
  /// Built exactly as [_onSheetsExportRequested] is: flush whatever is still pending, then hand
  /// what the state now carries to [OcptExportManager.exportBreakdownXlsx]. There is no options
  /// dialog to read first — this export takes none.
  Future<void> _onXlsxExportRequested(
    OcptBreakdownXlsxExportRequestedEvent event,
    Emitter<OcptBreakdownState> emitter,
  ) async {
    await _flushPendingFieldEdits(emitter);

    final snapshot = state.snapshot;
    if (snapshot == null) {
      return;
    }

    try {
      final path = await _exportManager.exportBreakdownXlsx(
        document: const FountainParser().parse(state.screenplayText),
        snapshot: snapshot,
        pageSetup: state.pageSetup,
        labels: event.labels,
        projectName: state.title,
        fileTypeLabel: event.fileTypeLabel,
        episodeTag: event.episodeTag,
      );
      if (path == null) {
        // The user cancelled the save dialog.
        return;
      }

      emitter(
        state.copyWith(
          ioNotice: OcptBreakdownIoNotice(
            kind: OcptBreakdownIoNoticeKind.xlsxExportSucceeded,
            path: path,
          ),
        ),
      );
    } catch (error) {
      appLogger().e("A problem occurred when tried to export the breakdown workbook of the project "
          "at ${_projectsManager.currentProject?.path}: $error");
      emitter(
        state.copyWith(
          ioNotice: const OcptBreakdownIoNotice(kind: OcptBreakdownIoNoticeKind.xlsxExportFailed),
        ),
      );
    }
  }

  /// Clears the transient export notice currently shown, if any.
  Future<void> _onIoNoticeDismissed(
    OcptBreakdownIoNoticeDismissedEvent event,
    Emitter<OcptBreakdownState> emitter,
  ) async {
    emitter(state.copyWith(clearIoNotice: true));
  }

  /// Selects scene `event.sceneId`, touching neither the selected target nor the right dock — the
  /// left dock's own list, and the target inspector's occurrence jump, both mean only this much.
  /// [_onSceneHeadingSelected] is the louder sibling the script view's headings use.
  ///
  /// A scene id that no longer exists in the current snapshot (a stale click on a panel rebuilt
  /// underneath) is ignored rather than selecting nothing. Flushes any pending field edit
  /// first, and drops whatever tag-removal confirmation the previous selection was showing: both
  /// belonged to the sheet this selection is about to replace.
  Future<void> _onSceneSelected(
    OcptBreakdownSceneSelectedEvent event,
    Emitter<OcptBreakdownState> emitter,
  ) async {
    await _flushPendingFieldEdits(emitter);

    final exists = state.scenes.any((scene) => scene.id == event.sceneId);
    if (!exists) {
      return;
    }

    emitter(state.copyWith(selectedSceneId: event.sceneId));
  }

  /// Selects scene `event.sceneId` **and shows its own breakdown sheet**, dispatched by a click on
  /// one of the script view's heading rows.
  ///
  /// Everything [_onSceneSelected] does, plus the two things that make the sheet actually appear:
  /// the selected target is dropped — the scene inspector is what the `Inspector` tab shows
  /// precisely while none is selected — and the right dock is opened on that tab, a closed one
  /// opening there and one already showing `Versions` switching. This is
  /// [_onTargetSelected]'s own hand-off, applied to a scene: a click in the centre lands the user
  /// on the sheet of whatever they clicked. The left dock's scene list deliberately keeps the
  /// quieter [_onSceneSelected] instead.
  Future<void> _onSceneHeadingSelected(
    OcptBreakdownSceneHeadingSelectedEvent event,
    Emitter<OcptBreakdownState> emitter,
  ) async {
    await _flushPendingFieldEdits(emitter);

    final exists = state.scenes.any((scene) => scene.id == event.sceneId);
    if (!exists) {
      return;
    }

    await _persistLastRightDockTab(OcptBreakdownRightDockTab.inspector);

    emitter(
      state.copyWith(
        selectedSceneId: event.sceneId,
        clearSelectedTargetRef: true,
        rightDockTab: OcptBreakdownRightDockTab.inspector,
        lastRightDockTab: OcptBreakdownRightDockTab.inspector,
      ),
    );
  }

  /// Selects the scene of one of the selected target's occurrences, dispatched by a row of
  /// `OcptBreakdownTargetInspector`'s own occurrences section.
  ///
  /// Delegates straight to [_onSceneSelected]: an occurrence's click means the same thing a scene
  /// panel row's does, jumping the script view and the left dock to that scene, and it is kept as
  /// its own event only because it is asked from a different place — there is no scroll-to-passage
  /// yet, so the target inspector itself stays exactly where it was.
  Future<void> _onOccurrenceSelected(
    OcptBreakdownOccurrenceSelectedEvent event,
    Emitter<OcptBreakdownState> emitter,
  ) => _onSceneSelected(OcptBreakdownSceneSelectedEvent(sceneId: event.sceneId), emitter);

  /// Toggles the left (scene) dock's visibility.
  Future<void> _onLeftPanelToggled(
    OcptBreakdownLeftPanelToggledEvent event,
    Emitter<OcptBreakdownState> emitter,
  ) async {
    emitter(state.copyWith(isListPanelVisible: !state.isListPanelVisible));
  }

  /// Selects a tab of the right dock (the already-active tab closes the dock, any other one opens
  /// or switches to it) and records it as the tab the toolbar's toggle reopens the dock on.
  ///
  /// Flushes any pending field edit first — the inspector tab this may be leaving is the
  /// one place they are shown — mirroring `OcptShotListBloc._onRightDockTabSelected`. Opening the
  /// `Versions` tab is one of the two moments `MixinOcptProjectVersionsBloc`'s working-copy card
  /// needs a fresh read for: the other is a field edit flushing while it is already the one showing
  /// (see [_flushPendingFieldEdits]).
  Future<void> _onRightDockTabSelected(
    OcptBreakdownRightDockTabSelectedEvent event,
    Emitter<OcptBreakdownState> emitter,
  ) async {
    await _flushPendingFieldEdits(emitter);

    final isAlreadyActive = state.rightDockTab == event.tab;
    await _persistLastRightDockTab(event.tab);

    emitter(
      state.copyWith(
        rightDockTab: isAlreadyActive ? null : event.tab,
        clearRightDockTab: isAlreadyActive,
        lastRightDockTab: event.tab,
      ),
    );

    if (!isAlreadyActive && event.tab == OcptBreakdownRightDockTab.versions) {
      add(const OcptProjectWorkingCopyRefreshRequestedEvent());
    }
  }

  /// Toggles the right dock from the workspace toolbar: an open dock closes, a closed one reopens on
  /// [OcptBreakdownState.lastRightDockTab], and that reopening is the moment the working-copy card
  /// needs a fresh read for whenever it lands on `Versions`.
  Future<void> _onRightDockToggled(
    OcptBreakdownRightDockToggledEvent event,
    Emitter<OcptBreakdownState> emitter,
  ) async {
    if (state.rightDockTab != null) {
      emitter(state.copyWith(clearRightDockTab: true));
      return;
    }

    emitter(state.copyWith(rightDockTab: state.lastRightDockTab));

    if (state.lastRightDockTab == OcptBreakdownRightDockTab.versions) {
      add(const OcptProjectWorkingCopyRefreshRequestedEvent());
    }
  }

  /// Closes the right dock via its own × close button.
  Future<void> _onRightDockClosed(
    OcptBreakdownRightDockClosedEvent event,
    Emitter<OcptBreakdownState> emitter,
  ) async {
    emitter(state.copyWith(clearRightDockTab: true));
  }

  /// Persists [tab] as the mode's last right dock tab, unless it already is.
  Future<void> _persistLastRightDockTab(OcptBreakdownRightDockTab tab) async {
    if (state.lastRightDockTab == tab) {
      return;
    }

    await _propertiesManager.breakdownLastRightDockTab.store(tab);
  }

  /// Applies and persists whichever dock fraction the ended drag gesture reports.
  Future<void> _onDockFractionsChanged(
    OcptBreakdownDockFractionsChangedEvent event,
    Emitter<OcptBreakdownState> emitter,
  ) async {
    final left = event.left;
    final right = event.right;

    if (left != null) {
      await _propertiesManager.breakdownLeftDockFraction.store(left);
    }
    if (right != null) {
      await _propertiesManager.breakdownRightDockFraction.store(right);
    }

    emitter(state.copyWith(leftDockFraction: left, rightDockFraction: right));
  }

  /// Restores both dock fractions to their defaults, persisting them.
  Future<void> _onDockLayoutReset(
    OcptBreakdownDockLayoutResetEvent event,
    Emitter<OcptBreakdownState> emitter,
  ) async {
    await _propertiesManager.breakdownLeftDockFraction.store(OcptWorkspaceDock.leftDefaultFraction);
    await _propertiesManager.breakdownRightDockFraction.store(
      OcptWorkspaceDock.rightDefaultFraction,
    );

    emitter(
      state.copyWith(
        leftDockFraction: OcptWorkspaceDock.leftDefaultFraction,
        rightDockFraction: OcptWorkspaceDock.rightDefaultFraction,
      ),
    );
  }

  /// Toggles whether `event.key` is hidden from the script view's own highlighting.
  Future<void> _onLegendEntryToggled(
    OcptBreakdownLegendEntryToggledEvent event,
    Emitter<OcptBreakdownState> emitter,
  ) async {
    final hiddenLegendKeys = Set<OcptBreakdownLegendKey>.from(state.hiddenLegendKeys);
    if (!hiddenLegendKeys.remove(event.key)) {
      hiddenLegendKeys.add(event.key);
    }

    emitter(state.copyWith(hiddenLegendKeys: hiddenLegendKeys));
  }

  /// Reveals every legend key currently hidden from the script view's own highlighting.
  Future<void> _onLegendShowAllRequested(
    OcptBreakdownLegendShowAllRequestedEvent event,
    Emitter<OcptBreakdownState> emitter,
  ) async {
    emitter(state.copyWith(hiddenLegendKeys: const {}));
  }

  /// Selects which of the two views (script or recap) the centre shows, dispatched by the header's
  /// own `Script`/`Recap` switch.
  ///
  /// Clears any pending tag anchor and pending range: the popover they might be driving has no
  /// script sheet left to close over once the centre leaves it, mirroring [_onTagRangeCancelled]'s
  /// own clearing.
  Future<void> _onCentreViewSelected(
    OcptBreakdownCentreViewSelectedEvent event,
    Emitter<OcptBreakdownState> emitter,
  ) async {
    emitter(
      state.copyWith(
        centreView: event.view,
        clearPendingTagAnchor: true,
        clearPendingTagRange: true,
      ),
    );
  }

  /// Records the header's own search field text as typed.
  ///
  /// The moment `event.query` turns non-empty while the script view is active, switches the centre
  /// to the recap in the same emitted state — carrying the just-typed text into the view that
  /// actually answers it — and clears any pending tag anchor and pending range for the same reason
  /// [_onCentreViewSelected] does. Clearing the field back to empty afterward does **not** switch
  /// back to the script view, per [OcptBreakdownSearchQueryChangedEvent]'s own doc comment.
  Future<void> _onSearchQueryChanged(
    OcptBreakdownSearchQueryChangedEvent event,
    Emitter<OcptBreakdownState> emitter,
  ) async {
    final switchesToRecap =
        event.query.isNotEmpty && state.centreView == OcptBreakdownCentreView.script;

    emitter(
      state.copyWith(
        searchQuery: event.query,
        centreView: switchesToRecap ? OcptBreakdownCentreView.recap : state.centreView,
        clearPendingTagAnchor: switchesToRecap,
        clearPendingTagRange: switchesToRecap,
      ),
    );
  }

  /// Selects target `event.targetKind`/`event.targetId`, and the scene the click happened in — so
  /// the left dock and the sheet stay in step, exactly as a click on a scene panel row already does
  /// on its own — and opens the right dock on the `Inspector` tab: a closed dock opens there, one
  /// already showing `Versions` switches, so a tagged word's click always lands the user on its
  /// sheet without a second gesture. Mirrors [_onSceneSelected]'s own defensive check: a scene id no
  /// longer in the current snapshot (a stale click on a sheet rebuilt underneath) is ignored for the
  /// scene selection alone, the target selection itself is still applied.
  ///
  /// Flushes any pending field edit first, and drops whatever tag-removal confirmation the
  /// previous selection was showing, exactly as [_onSceneSelected] does.
  Future<void> _onTargetSelected(
    OcptBreakdownTargetSelectedEvent event,
    Emitter<OcptBreakdownState> emitter,
  ) async {
    await _flushPendingFieldEdits(emitter);
    await _persistLastRightDockTab(OcptBreakdownRightDockTab.inspector);

    final sceneExists = state.scenes.any((scene) => scene.id == event.sceneId);

    emitter(
      state.copyWith(
        selectedTargetRef: (event.targetKind, event.targetId),
        selectedSceneId: sceneExists ? event.sceneId : null,
        clearSelectedSceneId: !sceneExists,
        rightDockTab: OcptBreakdownRightDockTab.inspector,
        lastRightDockTab: OcptBreakdownRightDockTab.inspector,
      ),
    );
  }

  /// Clears the currently selected target. Flushes any pending field edit first, and drops
  /// whatever tag-removal confirmation was showing, exactly as [_onSceneSelected] does.
  Future<void> _onTargetSelectionCleared(
    OcptBreakdownTargetSelectionClearedEvent event,
    Emitter<OcptBreakdownState> emitter,
  ) async {
    await _flushPendingFieldEdits(emitter);
    emitter(state.copyWith(clearSelectedTargetRef: true));
  }

  /// Records a click on a plain word of the script view — one that overlaps no live tag, or one
  /// whose tag's target has been dropped from the snapshot — driving the range interaction:
  ///
  /// - **no pending anchor, or one belonging to another scene**: this word becomes the (new)
  ///   anchor, and its scene becomes the selected one — a tag belongs to one scene, so an anchor
  ///   spanning two would mean nothing;
  /// - **an anchor already open in this very scene**: the range closes on the two words,
  ///   order-insensitive exactly as `OcptScriptWordLayout.rangeBetween` is (the smaller start, the
  ///   larger end), unless it would overlap a live tag of the scene — the script view already greys
  ///   such a word out of the click target it builds, but a click that reaches here regardless (a
  ///   stale one, or a direct test) is refused the same way `OcptBreakdownService.createTag` itself
  ///   would refuse it, and the anchor is kept rather than cleared, so the user can try a different
  ///   second click without starting over. Otherwise the range is recorded as
  ///   [OcptBreakdownState.pendingTagRange] — narrowed by [ocptBreakdownTaggedSpanOf] to the words
  ///   themselves, the punctuation a clicked word is written against being the sentence's rather
  ///   than the tagged thing's, then sliced verbatim out of the scene's own text — which is the
  ///   script view's cue to open the popover, anchored under this very word.
  ///
  /// The overlap above is checked on the clicked words' own bounds rather than on that narrowed
  /// span, exactly as the script view greys a word out on them: the span can only ever be narrower,
  /// so a range this refuses is one `OcptBreakdownService.createTag` would refuse too.
  ///
  /// Ignored outright while a version is being previewed (the mode never wires this callback then,
  /// so this only guards a direct call reaching past that) or while a range is already closed and
  /// awaiting the popover's own answer: a further click on the sheet behind an open popover means
  /// nothing until that popover is resolved or cancelled.
  ///
  /// Flushes any pending field edit first, mirroring every other selection-changing
  /// handler, and drops whatever tag-removal confirmation the previous selection was showing.
  Future<void> _onWordClicked(
    OcptBreakdownWordClickedEvent event,
    Emitter<OcptBreakdownState> emitter,
  ) async {
    if (state.isPreviewingVersion || state.pendingTagRange != null) {
      return;
    }

    final anchor = state.pendingTagAnchor;

    if (anchor == null || anchor.sceneId != event.sceneId) {
      await _flushPendingFieldEdits(emitter);

      final sceneExists = state.scenes.any((scene) => scene.id == event.sceneId);
      emitter(
        state.copyWith(
          pendingTagAnchor: (
            sceneId: event.sceneId,
            wordStartOffset: event.wordStartOffset,
            wordEndOffset: event.wordEndOffset,
          ),
          selectedSceneId: sceneExists ? event.sceneId : null,
          clearSelectedSceneId: !sceneExists,
        ),
      );
      return;
    }

    OcptBreakdownScene? scene;
    for (final candidate in state.scenes) {
      if (candidate.id == event.sceneId) {
        scene = candidate;
        break;
      }
    }
    if (scene == null) {
      // Stale click: the anchor's own scene disappeared from a snapshot rebuilt underneath.
      emitter(state.copyWith(clearPendingTagAnchor: true));
      return;
    }

    final startOffset = anchor.wordStartOffset <= event.wordStartOffset
        ? anchor.wordStartOffset
        : event.wordStartOffset;
    final endOffset = anchor.wordEndOffset >= event.wordEndOffset
        ? anchor.wordEndOffset
        : event.wordEndOffset;

    final overlapsLiveTag = scene.tags.any(
      (tag) => startOffset < tag.endOffset && tag.startOffset < endOffset,
    );
    if (overlapsLiveTag) {
      return;
    }

    final sceneStart = scene.charStart.clamp(0, state.screenplayText.length);
    final sceneEnd = scene.charEnd.clamp(sceneStart, state.screenplayText.length);
    final sceneText = state.screenplayText.substring(sceneStart, sceneEnd);
    final tagged = ocptBreakdownTaggedSpanOf(
      sceneText: sceneText,
      startOffset: startOffset,
      endOffset: endOffset,
    );

    await _flushPendingFieldEdits(emitter);
    emitter(
      state.copyWith(
        clearPendingTagAnchor: true,
        pendingTagRange: (
          sceneId: event.sceneId,
          startOffset: tagged.startOffset,
          endOffset: tagged.endOffset,
          taggedText: sceneText.substring(tagged.startOffset, tagged.endOffset),
          closingWordStartOffset: event.wordStartOffset,
          closingWordEndOffset: event.wordEndOffset,
        ),
        hasTagWriteError: false,
      ),
    );
  }

  /// Clears the pending anchor and the closed range alike, dispatched by the popover's own × close
  /// button, `Escape`, or a tap outside it: the user changed their mind about the passage, not just
  /// about where it should go.
  Future<void> _onTagRangeCancelled(
    OcptBreakdownTagRangeCancelledEvent event,
    Emitter<OcptBreakdownState> emitter,
  ) async {
    emitter(
      state.copyWith(clearPendingTagAnchor: true, clearPendingTagRange: true, hasTagWriteError: false),
    );
  }

  /// Links [OcptBreakdownState.pendingTagRange]'s own passage to the existing `event.targetKind`/
  /// `event.targetId`, dispatched by a click on one of the popover's own match rows.
  ///
  /// A stale click (no pending range, or a previewed version — the popover never withstands either)
  /// is ignored. On success — `OcptBreakdownService.createTag` returning a tag id — closes the
  /// popover, clears the anchor, reloads the snapshot and selects the linked target on the `Inspector`
  /// tab, exactly what selecting a tagged word already does (see [_onTargetSelected]): linking *is*
  /// what makes this passage a tagged word. A refusal (the overlap, or a preview database that
  /// slipped past the guard above) leaves the range and the popover exactly as they were, surfacing
  /// [OcptBreakdownState.hasTagWriteError] instead of silently closing on the user.
  Future<void> _onPopoverTargetLinked(
    OcptBreakdownPopoverTargetLinkedEvent event,
    Emitter<OcptBreakdownState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    final range = state.pendingTagRange;
    if (project == null || range == null || state.isPreviewingVersion) {
      return;
    }

    await _flushPendingFieldEdits(emitter);

    final tagId = await _breakdownService.createTag(
      database: project.database,
      sceneId: range.sceneId,
      startOffset: range.startOffset,
      endOffset: range.endOffset,
      taggedText: range.taggedText,
      targetKind: event.targetKind,
      targetId: event.targetId,
    );

    if (tagId == null) {
      emitter(state.copyWith(hasTagWriteError: true));
      return;
    }

    await _persistLastRightDockTab(OcptBreakdownRightDockTab.inspector);
    emitter(
      state.copyWith(
        clearPendingTagAnchor: true,
        clearPendingTagRange: true,
        snapshot: await _loadSnapshot(project),
        selectedTargetRef: (event.targetKind, event.targetId),
        selectedSceneId: range.sceneId,
        rightDockTab: OcptBreakdownRightDockTab.inspector,
        lastRightDockTab: OcptBreakdownRightDockTab.inspector,
        hasTagWriteError: false,
      ),
    );
  }

  /// Creates a new `event.category` element named `event.name` and tags
  /// [OcptBreakdownState.pendingTagRange]'s own passage with it, in one write
  /// (`OcptBreakdownService.createElementAndTag`), dispatched by a click on one of the popover's own
  /// category chips.
  ///
  /// Mirrors [_onPopoverTargetLinked] in every other respect: a stale call is ignored, success closes
  /// the popover and hands the new element off to the `Inspector` tab, and a refusal keeps the range
  /// and the popover, surfacing [OcptBreakdownState.hasTagWriteError]. `OcptElementSourceKind.owned`
  /// is the same default the resources mode's own element sheet creates with, so the two modes mint
  /// an element identically.
  Future<void> _onPopoverElementCreationRequested(
    OcptBreakdownPopoverElementCreationRequestedEvent event,
    Emitter<OcptBreakdownState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    final range = state.pendingTagRange;
    if (project == null || range == null || state.isPreviewingVersion) {
      return;
    }

    await _flushPendingFieldEdits(emitter);

    final trimmedName = event.name.trim();
    final result = await _breakdownService.createElementAndTag(
      database: project.database,
      sceneId: range.sceneId,
      startOffset: range.startOffset,
      endOffset: range.endOffset,
      taggedText: range.taggedText,
      name: trimmedName.isEmpty ? range.taggedText : trimmedName,
      category: event.category,
      sourceKind: OcptElementSourceKind.owned,
    );

    if (result == null) {
      emitter(state.copyWith(hasTagWriteError: true));
      return;
    }

    await _persistLastRightDockTab(OcptBreakdownRightDockTab.inspector);
    emitter(
      state.copyWith(
        clearPendingTagAnchor: true,
        clearPendingTagRange: true,
        snapshot: await _loadSnapshot(project),
        selectedTargetRef: (OcptBreakdownTargetKind.element, result.elementId),
        selectedSceneId: range.sceneId,
        rightDockTab: OcptBreakdownRightDockTab.inspector,
        lastRightDockTab: OcptBreakdownRightDockTab.inspector,
        hasTagWriteError: false,
      ),
    );
  }

  /// Creates a new set named `event.name` — inside `event.locationId`, or inside a location minted
  /// along with it when that is null — and tags [OcptBreakdownState.pendingTagRange]'s own passage
  /// with it, in one write (`OcptBreakdownService.createSetAndTag`), dispatched by the popover's own
  /// `Create a set` control.
  ///
  /// The exact mirror of [_onPopoverElementCreationRequested], down to the selection it lands on:
  /// the new set's own sheet, on the `Inspector` tab.
  Future<void> _onPopoverSetCreationRequested(
    OcptBreakdownPopoverSetCreationRequestedEvent event,
    Emitter<OcptBreakdownState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    final range = state.pendingTagRange;
    if (project == null || range == null || state.isPreviewingVersion) {
      return;
    }

    await _flushPendingFieldEdits(emitter);

    final trimmedName = event.name.trim();
    final result = await _breakdownService.createSetAndTag(
      database: project.database,
      sceneId: range.sceneId,
      startOffset: range.startOffset,
      endOffset: range.endOffset,
      taggedText: range.taggedText,
      name: trimmedName.isEmpty ? range.taggedText : trimmedName,
      locationId: event.locationId,
    );

    if (result == null) {
      emitter(state.copyWith(hasTagWriteError: true));
      return;
    }

    await _persistLastRightDockTab(OcptBreakdownRightDockTab.inspector);
    emitter(
      state.copyWith(
        clearPendingTagAnchor: true,
        clearPendingTagRange: true,
        snapshot: await _loadSnapshot(project),
        selectedTargetRef: (OcptBreakdownTargetKind.set, result.setId),
        selectedSceneId: range.sceneId,
        rightDockTab: OcptBreakdownRightDockTab.inspector,
        lastRightDockTab: OcptBreakdownRightDockTab.inspector,
        hasTagWriteError: false,
      ),
    );
  }

  /// Tags one of the selected target's own suggested occurrences, dispatched by a click on the add
  /// control of one of `OcptBreakdownTargetInspector`'s own "Suggested occurrences" rows — the
  /// writer's second route onto `OcptBreakdownService.createTag`, [_onPopoverTargetLinked] being
  /// the first, and it mirrors that handler in every respect but two: the range comes from
  /// `event`'s own fields rather than [OcptBreakdownState.pendingTagRange] (there is no popover open
  /// here), and **the selection does not change** — accepting one row of a list is meant to leave
  /// the user on that very list, ready for the next row, rather than bouncing them to the newly
  /// tagged passage's own scene.
  ///
  /// A stale call (no project open, or a preview database that slipped past the mode's own gating)
  /// is ignored. A refusal (the range now overlaps a live tag, most likely one just written by an
  /// earlier accepted suggestion) surfaces [OcptBreakdownState.hasTagWriteError], exactly as
  /// [_onPopoverTargetLinked]'s own refusal does.
  Future<void> _onSuggestionAccepted(
    OcptBreakdownSuggestionAcceptedEvent event,
    Emitter<OcptBreakdownState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null || state.isPreviewingVersion) {
      return;
    }

    await _flushPendingFieldEdits(emitter);

    final tagId = await _breakdownService.createTag(
      database: project.database,
      sceneId: event.sceneId,
      startOffset: event.startOffset,
      endOffset: event.endOffset,
      taggedText: event.taggedText,
      targetKind: event.targetKind,
      targetId: event.targetId,
    );

    if (tagId == null) {
      emitter(state.copyWith(hasTagWriteError: true));
      return;
    }

    emitter(state.copyWith(snapshot: await _loadSnapshot(project), hasTagWriteError: false));
  }

  /// Dismisses the transient notice that the last tag write — the popover's own link or element
  /// creation, or a suggestion accepted from the target inspector — was refused.
  Future<void> _onTagWriteErrorDismissed(
    OcptBreakdownTagWriteErrorDismissedEvent event,
    Emitter<OcptBreakdownState> emitter,
  ) async {
    emitter(state.copyWith(hasTagWriteError: false));
  }

  /// Writes the selected scene's new breakdown status immediately — a single pick, not typing, so
  /// it rides no debounce — then reloads the snapshot: a scene's status feeds the left dock's own
  /// rows, the scene inspector's chips and the snapshot's `doneSceneCount`, all of which must be
  /// read back from the database rather than patched in place, exactly as an element's status or
  /// category change already is.
  Future<void> _onSceneStatusChanged(
    OcptBreakdownSceneStatusChangedEvent event,
    Emitter<OcptBreakdownState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    await _breakdownService.updateSceneBreakdown(
      database: project.database,
      sceneId: event.sceneId,
      status: Value(event.status),
    );

    emitter(state.copyWith(snapshot: await _loadSnapshot(project)));
  }

  /// Says scene `event.sceneId` is shot in set `event.setId`, written immediately through the very
  /// service the resources mode writes that link with, then reloads the snapshot — the sets a scene
  /// is shot in are read off `OcptSet.sceneIds`, so the row has to come back from the database.
  ///
  /// Writes no tag: linking a scene to a set is a fact about the scene, not a passage of the script.
  Future<void> _onSceneSetLinked(
    OcptBreakdownSceneSetLinkedEvent event,
    Emitter<OcptBreakdownState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    await _locationsService.assignSceneToSet(
      database: project.database,
      sceneId: event.sceneId,
      setId: event.setId,
    );

    emitter(state.copyWith(snapshot: await _loadSnapshot(project)));
  }

  /// Creates a set named `event.name` — inside `event.locationId`, or inside a location minted along
  /// with it when that is null — and says scene `event.sceneId` is shot in it, in one write
  /// (`OcptLocationsService.createSetLinkedToScene`), dispatched by the scene inspector's own
  /// `Create a set…` control.
  ///
  /// Writes no tag, exactly as [_onSceneSetLinked] doesn't: this is the sheet naming its décor, not
  /// a passage of the script being tagged. The selection is left where it is for the same reason —
  /// the user is filling in this scene's sheet, and the set they just created is already on it as a
  /// chip.
  Future<void> _onSceneSetCreationRequested(
    OcptBreakdownSceneSetCreationRequestedEvent event,
    Emitter<OcptBreakdownState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null || state.isPreviewingVersion) {
      return;
    }

    final trimmedName = event.name.trim();
    await _locationsService.createSetLinkedToScene(
      database: project.database,
      sceneId: event.sceneId,
      name: trimmedName.isEmpty ? event.name : trimmedName,
      locationId: event.locationId,
    );

    emitter(state.copyWith(snapshot: await _loadSnapshot(project)));
  }

  /// Says scene `event.sceneId` is no longer shot in set `event.setId`, the mirror of
  /// [_onSceneSetLinked]. Leaves every tag pointing at that set untouched, for the reason
  /// `OcptBreakdownService.deleteTag` gives from the other side.
  Future<void> _onSceneSetUnlinked(
    OcptBreakdownSceneSetUnlinkedEvent event,
    Emitter<OcptBreakdownState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    await _locationsService.removeSceneFromSet(
      database: project.database,
      sceneId: event.sceneId,
      setId: event.setId,
    );

    emitter(state.copyWith(snapshot: await _loadSnapshot(project)));
  }

  /// Records the raw text just typed into scene `event.sceneId`'s own breakdown notes as a pending
  /// edit, visible immediately, and (re)starts the same field-edit debounce
  /// [_onElementFieldChanged] does — one debounce timer for the whole mode.
  Future<void> _onSceneNotesChanged(
    OcptBreakdownSceneNotesChangedEvent event,
    Emitter<OcptBreakdownState> emitter,
  ) async {
    final pending = Map<String, String>.of(state.pendingSceneNotesEdits)
      ..[event.sceneId] = event.rawValue;
    emitter(state.copyWith(pendingSceneNotesEdits: pending));

    _fieldEditTimer?.cancel();
    _fieldEditTimer = Timer(_fieldEditDebounce, () {
      if (!isClosed) {
        add(const OcptBreakdownFieldEditFlushRequestedEvent());
      }
    });
  }

  /// Writes the selected element's new status immediately — a single pick, not typing, so it rides
  /// no debounce — then reloads the snapshot so the script view's colours, the legend, the scene
  /// panel and the status bar all follow it exactly as they follow a category change.
  Future<void> _onElementStatusChanged(
    OcptBreakdownElementStatusChangedEvent event,
    Emitter<OcptBreakdownState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    await _elementsService.updateElement(
      database: project.database,
      elementId: event.elementId,
      status: Value(event.status),
    );

    emitter(state.copyWith(snapshot: await _loadSnapshot(project)));
  }

  /// Writes the selected element's new category immediately, then reloads the snapshot for the same
  /// reason [_onElementStatusChanged] does — a category change moves the element's own colour, so
  /// every surface painting it must be redrawn from the database rather than patched in place.
  Future<void> _onElementCategoryChanged(
    OcptBreakdownElementCategoryChangedEvent event,
    Emitter<OcptBreakdownState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    await _elementsService.updateElement(
      database: project.database,
      elementId: event.elementId,
      category: Value(event.category),
    );

    emitter(state.copyWith(snapshot: await _loadSnapshot(project)));
  }

  /// Records the raw text just typed into `event.field` of element `event.elementId` as a pending
  /// edit, visible immediately, and (re)starts the field-edit debounce that eventually writes it.
  Future<void> _onElementFieldChanged(
    OcptBreakdownElementFieldChangedEvent event,
    Emitter<OcptBreakdownState> emitter,
  ) async {
    final pending = Map<(String, OcptElementField), String>.of(state.pendingElementFieldEdits)
      ..[(event.elementId, event.field)] = event.rawValue;
    emitter(state.copyWith(pendingElementFieldEdits: pending));

    _fieldEditTimer?.cancel();
    _fieldEditTimer = Timer(_fieldEditDebounce, () {
      if (!isClosed) {
        add(const OcptBreakdownFieldEditFlushRequestedEvent());
      }
    });
  }

  /// Records the raw text just typed into the title of set `event.setId` as a pending rename,
  /// visible immediately, and (re)starts the same field-edit debounce [_onElementFieldChanged] does.
  Future<void> _onSetNameChanged(
    OcptBreakdownSetNameChangedEvent event,
    Emitter<OcptBreakdownState> emitter,
  ) async {
    final pending = Map<String, String>.of(state.pendingSetNameEdits)
      ..[event.setId] = event.rawValue;
    emitter(state.copyWith(pendingSetNameEdits: pending));

    _fieldEditTimer?.cancel();
    _fieldEditTimer = Timer(_fieldEditDebounce, () {
      if (!isClosed) {
        add(const OcptBreakdownFieldEditFlushRequestedEvent());
      }
    });
  }

  /// Writes every pending element field edit and every pending scene notes edit once the
  /// field-edit debounce elapses with no further typing.
  Future<void> _onFieldEditFlushRequested(
    OcptBreakdownFieldEditFlushRequestedEvent event,
    Emitter<OcptBreakdownState> emitter,
  ) => _flushPendingFieldEdits(emitter);

  /// Writes every pending element field edit and every pending scene notes edit immediately:
  /// cancels the debounce timer (a no-op if it already fired or there was none), writes each one
  /// through `OcptElementsService.updateElement`/`OcptBreakdownService.updateSceneBreakdown`, then
  /// reloads the snapshot once so every derived aggregate reflects what the database now says. A
  /// no-op while neither map holds anything.
  ///
  /// Used from inside an event handler, with that handler's own [emitter]: called by
  /// [_onFieldEditFlushRequested] (the debounce firing), and up front by every handler that changes
  /// the selected target, the selected scene, or the right dock tab, and by [flushPendingProjectWrites]
  /// (a version preview about to swap the database), so a pending edit is never silently dropped.
  /// [flushPendingFieldEdits] is the sibling of this method used outside of an event handler.
  Future<void> _flushPendingFieldEdits(Emitter<OcptBreakdownState> emitter) async {
    _fieldEditTimer?.cancel();
    _fieldEditTimer = null;

    final pendingElementFields = state.pendingElementFieldEdits;
    final pendingSceneNotes = state.pendingSceneNotesEdits;
    final pendingSetNames = state.pendingSetNameEdits;
    if (pendingElementFields.isEmpty && pendingSceneNotes.isEmpty && pendingSetNames.isEmpty) {
      return;
    }

    final project = _projectsManager.currentProject;
    if (project == null) {
      emitter(
        state.copyWith(
          pendingElementFieldEdits: const {},
          pendingSceneNotesEdits: const {},
          pendingSetNameEdits: const {},
        ),
      );
      return;
    }

    try {
      await _writeAllPendingFields(
        database: project.database,
        elementFields: pendingElementFields,
        sceneNotes: pendingSceneNotes,
        setNames: pendingSetNames,
      );
      final snapshot = await _loadSnapshot(project);
      emitter(
        state.copyWith(
          snapshot: snapshot,
          pendingElementFieldEdits: const {},
          pendingSceneNotesEdits: const {},
          pendingSetNameEdits: const {},
        ),
      );

      // The other of the two moments the working-copy card needs a fresh read for (see
      // `_onRightDockTabSelected`): a field edit landing while the tab showing it is already open.
      if (state.rightDockTab == OcptBreakdownRightDockTab.versions) {
        add(const OcptProjectWorkingCopyRefreshRequestedEvent());
      }
    } catch (error) {
      appLogger().e("A problem occurred when tried to flush a pending breakdown field edit of the "
          "project at ${project.path}: $error");
      emitter(
        state.copyWith(
          pendingElementFieldEdits: const {},
          pendingSceneNotesEdits: const {},
          pendingSetNameEdits: const {},
        ),
      );
    }
  }

  /// Writes every pending element field edit and every pending scene notes edit directly to the
  /// database, bypassing both the debounce timer and the bloc's own event queue.
  ///
  /// Called by the mode's own `deactivate()`, mirroring `OcptShotListBloc.flushPendingFieldEdits`:
  /// `deactivate()` runs before `dispose()` for every removal from the tree (a mode switch swaps
  /// this whole subtree out, and so does the workspace's own back navigation), so triggering the
  /// write here — rather than dispatching an event, which would only be processed on a later
  /// microtask this widget might not survive to see — is what guarantees the last
  /// [_fieldEditDebounce] worth of typing isn't lost.
  ///
  /// Unlike [_flushPendingFieldEdits], this never touches [state]: `emit` may only be called
  /// from inside a registered `on<Event>` handler, and by the time this runs the widget tree that
  /// would show a fresh state is already gone anyway. A failure here is only logged.
  Future<void> flushPendingFieldEdits() async {
    _fieldEditTimer?.cancel();
    _fieldEditTimer = null;

    final pendingElementFields = state.pendingElementFieldEdits;
    final pendingSceneNotes = state.pendingSceneNotesEdits;
    final pendingSetNames = state.pendingSetNameEdits;
    if (pendingElementFields.isEmpty && pendingSceneNotes.isEmpty && pendingSetNames.isEmpty) {
      return;
    }

    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    try {
      await _writeAllPendingFields(
        database: project.database,
        elementFields: pendingElementFields,
        sceneNotes: pendingSceneNotes,
        setNames: pendingSetNames,
      );
    } catch (error) {
      appLogger().e("A problem occurred when tried to flush a pending breakdown field edit of the "
          "project at ${project.path}: $error");
    }
  }

  /// Writes every entry of [elementFields] through `OcptElementsService.updateElement`, translating
  /// each (only `name`, `subCategory`, `quantity` and `notes` ever land here — the target
  /// inspector's other fields are single picks written immediately by their own event, see this
  /// bloc's own doc comment) into the matching named argument, then every entry of [sceneNotes]
  /// through `OcptBreakdownService.updateSceneBreakdown`, then every entry of [setNames] through
  /// `OcptLocationsService.updateSet`.
  Future<void> _writeAllPendingFields({
    required OcptProjectDatabase database,
    required Map<(String, OcptElementField), String> elementFields,
    required Map<String, String> sceneNotes,
    required Map<String, String> setNames,
  }) async {
    for (final entry in elementFields.entries) {
      final (elementId, field) = entry.key;
      final rawValue = entry.value;

      switch (field) {
        case OcptElementField.name:
          await _elementsService.updateElement(
            database: database,
            elementId: elementId,
            name: Value(rawValue),
          );
        case OcptElementField.subCategory:
          await _elementsService.updateElement(
            database: database,
            elementId: elementId,
            subCategory: Value(rawValue),
          );
        case OcptElementField.quantity:
          await _elementsService.updateElement(
            database: database,
            elementId: elementId,
            quantity: Value(rawValue),
          );
        case OcptElementField.notes:
          await _elementsService.updateElement(
            database: database,
            elementId: elementId,
            notes: Value(rawValue),
          );
        case OcptElementField.ownerNotes ||
            OcptElementField.storageNotes ||
            OcptElementField.cost ||
            OcptElementField.purposeNotes:
          appLogger().w(
            "The breakdown mode's target inspector never edits OcptElementField.${field.name}; "
            "ignoring the pending edit for element $elementId",
          );
      }
    }

    for (final entry in sceneNotes.entries) {
      await _breakdownService.updateSceneBreakdown(
        database: database,
        sceneId: entry.key,
        notes: Value(entry.value),
      );
    }

    for (final entry in setNames.entries) {
      await _locationsService.updateSet(
        database: database,
        setId: entry.key,
        name: Value(entry.value),
      );
    }
  }

  /// Writes the selected element's new owner immediately — a pick, not typing — then reloads the
  /// snapshot so the inspector shows the newly named person.
  Future<void> _onElementOwnerChanged(
    OcptBreakdownElementOwnerChangedEvent event,
    Emitter<OcptBreakdownState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    await _elementsService.updateElement(
      database: project.database,
      elementId: event.elementId,
      ownerPersonId: Value(event.personId),
    );

    emitter(state.copyWith(snapshot: await _loadSnapshot(project)));
  }

  /// Writes the selected element's new who-brings-it immediately, mirroring
  /// [_onElementOwnerChanged].
  Future<void> _onElementBringerChanged(
    OcptBreakdownElementBringerChangedEvent event,
    Emitter<OcptBreakdownState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    await _elementsService.updateElement(
      database: project.database,
      elementId: event.elementId,
      broughtByPersonId: Value(event.personId),
    );

    emitter(state.copyWith(snapshot: await _loadSnapshot(project)));
  }

  /// Removes the selected target's tags from the selected scene for good — every live tag of
  /// [OcptBreakdownState.selectedTarget] within [OcptBreakdownState.selectedScene], tombstoned one
  /// by one through `OcptBreakdownService.deleteTag`, which never removes the `scene_elements`/
  /// `scene_sets` link a tag once ensured — see that method's own doc comment: the resources mode
  /// lets a user make that link by hand, and dropping it silently here would destroy work the
  /// breakdown pass never did.
  ///
  /// A no-op when either half of the selection is gone (a stale click on a sheet the snapshot
  /// already rebuilt without it). Reloads the snapshot afterwards: the target may disappear from it
  /// outright if this scene held its only tag.
  Future<void> _onTagRemovalConfirmed(
    OcptBreakdownTagRemovalConfirmedEvent event,
    Emitter<OcptBreakdownState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    final target = state.selectedTarget;
    final scene = state.selectedScene;
    if (project == null || target == null || scene == null) {
      return;
    }

    final tagIds = [
      for (final tag in scene.tags)
        if (tag.targetKind == target.kind && tag.targetId == target.id) tag.id,
    ];
    for (final tagId in tagIds) {
      await _breakdownService.deleteTag(database: project.database, tagId: tagId);
    }

    emitter(state.copyWith(snapshot: await _loadSnapshot(project)));
  }

  /// Clears tag `event.tagId`'s own `needsCheck` flag through
  /// `OcptBreakdownService.clearTagNeedsCheck`, then reloads the snapshot: the flag feeds the scene
  /// panel's own warning mark and the status bar's "to check" counter, both of which must be read
  /// back from the database rather than patched in place.
  ///
  /// A no-op while no project is open, mirroring [_onTagRemovalConfirmed]'s own defensive check.
  Future<void> _onTagNeedsCheckCleared(
    OcptBreakdownTagNeedsCheckClearedEvent event,
    Emitter<OcptBreakdownState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    await _breakdownService.clearTagNeedsCheck(database: project.database, tagId: event.tagId);

    emitter(state.copyWith(snapshot: await _loadSnapshot(project)));
  }

  /// Removes tag `event.tagId` for good through `OcptBreakdownService.deleteTag`, then reloads the
  /// snapshot, mirroring [_onTagNeedsCheckCleared] in every respect but the write it performs.
  ///
  /// A no-op while no project is open, mirroring [_onTagRemovalConfirmed]'s own defensive check.
  Future<void> _onFlaggedTagRemoved(
    OcptBreakdownFlaggedTagRemovedEvent event,
    Emitter<OcptBreakdownState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    await _breakdownService.deleteTag(database: project.database, tagId: event.tagId);

    emitter(state.copyWith(snapshot: await _loadSnapshot(project)));
  }
}
