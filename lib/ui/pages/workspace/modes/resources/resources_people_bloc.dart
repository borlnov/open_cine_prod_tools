// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:act_global_manager/act_global_manager.dart';
import 'package:act_logger_manager/act_logger_manager.dart';
import 'package:drift/drift.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/constants/ocpt_asset_file_types.dart';
import 'package:open_cine_prod_tools/managers/logging/ocpt_logs_helper_builder.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_people_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_open_project_model.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_max_daily_presence.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_pending_edits.dart';
import 'package:open_cine_prod_tools/types/ocpt_person_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_resources_reload_scope.dart';
import 'package:open_cine_prod_tools/types/ocpt_resources_right_dock_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_resources_tab.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/abs_ocpt_view_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_versions_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_view_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_people_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_state.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_budget_labels.dart';

/// This is the bloc class for the resources mode's people tab: the address book's person sheet.
///
/// The catalogue is the mode's data, in `OcptResourcesState.snapshot`, and which person is selected
/// is the mode's too. This bloc owns what the person sheet does with them: every write (the
/// service, then `await modeBloc.reload(…)` for the snapshot, and only then the selection of the
/// person it created) and the edits typed into the sheet's free-text fields and not yet written
/// ([OcptResourcesPeopleState.pendingFieldEdits]), which it writes
/// [OcptResourcesBloc.defaultFieldEditDebounce] after the last keystroke, on a timer of its own; the
/// mode flushes them ahead of anything that needs the database to be up to date.
///
/// A person's discrete fields (colour, birth date, transport autonomy, mileage rate, image rights
/// status and date), every sub-list (positions, skills, unavailabilities) and the photo and signed
/// release it references are written the moment they change. Referencing a file is a native dialog
/// and a path, with no bytes to read: see [_pickFilePath].
///
/// **Failing.** A write that fails raises the mode's write error (`OcptResourcesWriteFailedEvent`).
/// A flush that fails drops every edit typed into **any** sheet, not only this one's, through
/// `OcptResourcesPendingEditsLostEvent`: the mode shows the one error, and every view reacts by
/// emptying what it holds ([onModeStateChanged]).
class OcptResourcesPeopleBloc
    extends AbsOcptViewBloc<OcptResourcesPeopleState, OcptResourcesState, OcptResourcesBloc> {
  /// The logger category linked to this BLoC.
  static const _loggerCategory = "resources_people_bloc";

  /// The logger this BLoC writes to.
  final LogsHelper _logger;

  /// The manager used to access the project currently open.
  final OcptProjectsManager _projectsManager;

  /// The service used to read and write the address book.
  final OcptPeopleService _peopleService;

  /// The manager used to show the native "open" dialog when a photo or a document is referenced,
  /// or null to resolve it through [globalGetIt] the first time one actually is.
  final FileSelectorManager? _fileSelectorManager;

  /// The delay between the last field edit and its autosave write.
  final Duration _fieldEditDebounce;

  /// Class constructor
  ///
  /// Every dependency but [modeBloc] can be overridden, which is what the tests do; in the app they
  /// all resolve through [globalGetIt]. [fieldEditDebounce] is only meant to be overridden by
  /// tests, to keep it fast and deterministic.
  OcptResourcesPeopleBloc({
    required OcptResourcesBloc modeBloc,
    OcptProjectsManager? projectsManager,
    OcptPeopleService? peopleService,
    FileSelectorManager? fileSelectorManager,
    Duration fieldEditDebounce = OcptResourcesBloc.defaultFieldEditDebounce,
  }) : _logger = buildOcptLogsHelper(_loggerCategory),
       _projectsManager = projectsManager ?? globalGetIt().get<OcptProjectsManager>(),
       _peopleService =
           peopleService ??
           (projectsManager ?? globalGetIt().get<OcptProjectsManager>()).peopleService,
       _fileSelectorManager = fileSelectorManager,
       _fieldEditDebounce = fieldEditDebounce,
       super(
         OcptResourcesPeopleState.init(lastLostEditsEpoch: modeBloc.state.lostEditsEpoch),
         modeBloc: modeBloc,
       );

  /// {@macro act_flutter_utility.BlocForMixin.registerMixinEvents}
  @override
  void registerMixinEvents() {
    super.registerMixinEvents();
    on<OcptResourcesPersonCreationRequestedEvent>(_onPersonCreationRequested);
    on<OcptResourcesPersonDeletionRequestedEvent>(_onPersonDeletionRequested);
    on<OcptResourcesPersonFieldChangedEvent>(_onPersonFieldChanged);
    on<OcptResourcesPeopleFieldEditFlushRequestedEvent>(_onFieldEditFlushRequested);
    on<OcptResourcesPersonColorChangedEvent>(_onPersonColorChanged);
    on<OcptResourcesPersonBirthDateChangedEvent>(_onPersonBirthDateChanged);
    on<OcptResourcesPersonTransportAutonomyChangedEvent>(_onPersonTransportAutonomyChanged);
    on<OcptResourcesPersonImageRightsStatusChangedEvent>(_onPersonImageRightsStatusChanged);
    on<OcptResourcesPersonImageRightsDateChangedEvent>(_onPersonImageRightsDateChanged);
    on<OcptResourcesPersonMileageRateChangedEvent>(_onPersonMileageRateChanged);
    on<OcptResourcesPositionAddedEvent>(_onPositionAdded);
    on<OcptResourcesPositionUpdatedEvent>(_onPositionUpdated);
    on<OcptResourcesPositionRemovedEvent>(_onPositionRemoved);
    on<OcptResourcesSkillAddedEvent>(_onSkillAdded);
    on<OcptResourcesSkillUpdatedEvent>(_onSkillUpdated);
    on<OcptResourcesSkillRemovedEvent>(_onSkillRemoved);
    on<OcptResourcesUnavailabilityAddedEvent>(_onUnavailabilityAdded);
    on<OcptResourcesUnavailabilityUpdatedEvent>(_onUnavailabilityUpdated);
    on<OcptResourcesUnavailabilityRemovedEvent>(_onUnavailabilityRemoved);
    on<OcptResourcesPersonPhotoPickRequestedEvent>(_onPersonPhotoPickRequested);
    on<OcptResourcesPersonPhotoClearedEvent>(_onPersonPhotoCleared);
    on<OcptResourcesImageRightsDocumentPickRequestedEvent>(_onImageRightsDocumentPickRequested);
    on<OcptResourcesImageRightsDocumentClearedEvent>(_onImageRightsDocumentCleared);
  }

  /// Drops the edits this bloc holds when the mode says writing them failed somewhere (see
  /// `OcptResourcesPendingEditsLostEvent`): the fields fall back to the stored values.
  ///
  /// Nothing else is scoped to the selection or to the data here: a pending edit survives the user
  /// selecting another person, since it is written by its own debounce or by the flush the
  /// selection starts, and the mode reading the catalogue again after a write changes nothing about
  /// what was typed. Waits for nothing, as the mode's change and this reaction must land in the
  /// same turn of the event loop.
  @override
  Future<void> onModeStateChanged(
    OcptViewModeStateChangedEvent<OcptResourcesState> event,
    Emitter<OcptResourcesPeopleState> emitter,
  ) async {
    final lostEditsEpoch = event.modeState.lostEditsEpoch;
    if (lostEditsEpoch <= state.lastLostEditsEpoch) {
      return;
    }

    cancelDebounce();
    emitter(state.copyWithFieldEditsLost(lostEditsEpoch: lostEditsEpoch));
  }

  /// Creates a new, blank person at the end of the address book, reads the catalogue again and
  /// selects the new person.
  ///
  /// The freshly created person is immediately given an avatar colour derived from their rank in
  /// the address book — `peopleCount` read *before* the insert, so the first person is 0, the second
  /// 1, and so on — rather than being left at `people.colorIndex`'s own table default of 0, which
  /// would otherwise make every new person share the same avatar tint. `OcptPerson.colorIndex` is
  /// read back through `ocptCoverageColorAt` wherever a person's avatar is painted
  /// (`OcptPeopleList`, `OcptPersonSheet`), the same way a shot's colour is derived from its rank
  /// within its sequence.
  ///
  /// Writes whatever is pending first, so adding a person right after typing never loses it.
  Future<void> _onPersonCreationRequested(
    OcptResourcesPersonCreationRequestedEvent event,
    Emitter<OcptResourcesPeopleState> emitter,
  ) async {
    if (!await modeBloc.flushAllPendingWrites()) {
      return;
    }

    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    try {
      final rank = modeBloc.state.peopleCount;
      final personId = await _peopleService.createPerson(database: project.database);
      // The write was refused (a version is being previewed read-only); the shell already
      // withholds the button that dispatches this event, so this is only ever a race.
      if (personId != null) {
        await _peopleService.updatePerson(
          database: project.database,
          personId: personId,
          colorIndex: Value(rank),
        );

        if (await modeBloc.reload({OcptResourcesReloadScope.snapshot})) {
          await addToModeAndWait(
            OcptResourcesRecordCreatedEvent(tab: OcptResourcesTab.people, recordId: personId),
          );
        }
      }
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to create a person in project "
        "${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
      addToMode(const OcptResourcesWriteFailedEvent());
    }
  }

  /// Erases person `event.personId`, clearing the selection when it was the selected person, and
  /// dropping any pending field edit that still targeted it (the person it would have written to
  /// no longer holds any personal data).
  Future<void> _onPersonDeletionRequested(
    OcptResourcesPersonDeletionRequestedEvent event,
    Emitter<OcptResourcesPeopleState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    if (_pendingWithoutPerson(event.personId).isEmpty) {
      cancelDebounce();
    }

    try {
      await _peopleService.deletePerson(database: project.database, personId: event.personId);
      if (await modeBloc.reload({OcptResourcesReloadScope.snapshot})) {
        emitter(
          state.copyWithPersonErased(pendingFieldEdits: _pendingWithoutPerson(event.personId)),
        );
        await addToModeAndWait(
          OcptResourcesRecordDroppedEvent(tab: OcptResourcesTab.people, recordId: event.personId),
        );
      }
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to erase person ${event.personId} of project "
        "${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
      addToMode(const OcptResourcesWriteFailedEvent());
    }
  }

  /// The pending field edits of this bloc without those that target person [personId].
  Map<(String, OcptPersonField), String> _pendingWithoutPerson(String personId) =>
      Map<(String, OcptPersonField), String>.of(state.pendingFieldEdits)
        ..removeWhere((key, _) => key.$1 == personId);

  /// Records the raw text just typed into `event.field` of person `event.personId` as a pending
  /// edit, visible immediately, and (re)starts the field-edit debounce that eventually writes it.
  Future<void> _onPersonFieldChanged(
    OcptResourcesPersonFieldChangedEvent event,
    Emitter<OcptResourcesPeopleState> emitter,
  ) async {
    final pending = Map<(String, OcptPersonField), String>.of(state.pendingFieldEdits)
      ..[(event.personId, event.field)] = event.rawValue;
    emitter(state.copyWithFieldEditTyped(pendingFieldEdits: pending));

    restartDebounce(_fieldEditDebounce, const OcptResourcesPeopleFieldEditFlushRequestedEvent());
  }

  /// Fired by the field-edit debounce timer: writes every pending field edit.
  Future<void> _onFieldEditFlushRequested(
    OcptResourcesPeopleFieldEditFlushRequestedEvent event,
    Emitter<OcptResourcesPeopleState> emitter,
  ) async {
    await onFlushRequested(emitter);
  }

  /// Writes every pending field edit immediately: cancels the debounce timer (a no-op if it already
  /// fired or there was none), writes each one through `OcptPeopleService.updatePerson`, then has
  /// the mode read the catalogue again so every derived aggregate reflects what the database now
  /// says, and only then forgets what it wrote, so what a field shows never falls back to a stale
  /// stored value between the two. A no-op while nothing is pending. Answers whether there was
  /// anything pending.
  ///
  /// A write that fails drops **every** edit of the mode and raises the one write error (see
  /// [_loseEdits]); the snapshot is not read again, so the fields show the value they had. A read
  /// after a write that landed which fails only raises the write error: what was written is
  /// forgotten and the other views keep what they hold, to be written in their turn. When the write landed and the `Versions` tab is the one showing, also asks the mode
  /// to refresh its working-copy card.
  ///
  /// Called by the debounce firing, and by the mode ahead of every action that needs the database
  /// to be up to date.
  @override
  Future<bool> onFlushRequested(Emitter<OcptResourcesPeopleState> emitter) async {
    cancelDebounce();

    final pending = state.pendingFieldEdits;
    if (pending.isEmpty) {
      return false;
    }

    final project = _projectsManager.currentProject;
    if (project == null) {
      emitter(state.copyWithFieldEditsCleared());
      return true;
    }

    var isWritten = false;
    try {
      await _writeAllPendingFields(database: project.database, pending: pending);
      isWritten = true;
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to flush a pending resources field edit of project "
        "${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
      await _loseEdits(emitter);
    }

    if (!isWritten) {
      return true;
    }

    // A read that fails changes nothing here: the write landed, so what was written is forgotten
    // all the same, and the mode has already raised the write error. Dropping the edits of the
    // other views as well would lose what no write failure has touched.
    await modeBloc.reload({OcptResourcesReloadScope.snapshot});

    emitter(
      state.copyWithFieldEditsWritten(
        pendingFieldEdits: ocptPendingEditsAfterWrite(
          current: state.pendingFieldEdits,
          written: pending,
        ),
      ),
    );

    // The other of the two moments the working-copy card needs a fresh read for (see
    // `OcptResourcesBloc._onRightDockTabSelected`): a field edit landing while the tab showing it
    // is already open.
    if (modeBloc.state.rightDockTab == OcptResourcesRightDockTab.versions) {
      addToMode(const OcptProjectWorkingCopyRefreshRequestedEvent());
    }

    return true;
  }

  /// Tells the mode that writing the typed edits failed, which raises its write error and makes
  /// every view drop what it holds, this one included; waits for that, so the flush goes on to the
  /// other views with nothing left for them to write.
  ///
  /// This bloc empties its own map as well, for the mode that is closing and no longer answers.
  Future<void> _loseEdits(Emitter<OcptResourcesPeopleState> emitter) async {
    await addToModeAndWait(const OcptResourcesPendingEditsLostEvent());
    emitter(state.copyWithFieldEditsCleared());
  }

  /// Writes every pending field edit directly to the database, bypassing the debounce timer, the
  /// bloc's own event queue and its state.
  ///
  /// Called by the mode's own `deactivate()` (through the flushers it registered), mirroring
  /// `OcptShotListBloc.flushPendingFieldEdits`: `deactivate()` runs before `dispose()` for every
  /// removal from the tree (a mode switch swaps this whole subtree out, and so does the workspace's
  /// own back navigation), so triggering the write here — rather than dispatching an event, which
  /// would only be processed on a later microtask this widget might not survive to see — is what
  /// guarantees the last [OcptResourcesBloc.defaultFieldEditDebounce] worth of typing isn't lost.
  ///
  /// Unlike [onFlushRequested], this never touches [state]: `emit` may only be called from inside
  /// a registered `on<Event>` handler, and by the time this runs the widget tree that would show a
  /// fresh state is already gone anyway. A failure here is only logged.
  @override
  Future<void> flushPendingWritesWithoutState() async {
    cancelDebounce();

    final pending = state.pendingFieldEdits;
    if (pending.isEmpty) {
      return;
    }

    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    try {
      await flushEditsWithoutState(
        pending,
        (edits) => _writeAllPendingFields(database: project.database, pending: edits),
      );
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to flush a pending resources field edit of project "
        "${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
    }
  }

  /// Writes a discrete change to the address book through [action] and has the mode read the
  /// catalogue again, so every derived aggregate (a person's positions summary, the status bar's
  /// counts) reflects what the database now says. A no-op while no project is open; a failure
  /// raises the mode's write error.
  Future<void> _writeCatalogueChange({
    required String logContext,
    required Future<void> Function(OcptOpenProjectModel project) action,
  }) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    try {
      await action(project);
      await modeBloc.reload({OcptResourcesReloadScope.snapshot});
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to $logContext of project "
        "${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
      addToMode(const OcptResourcesWriteFailedEvent());
    }
  }

  /// Shows the native "open" dialog and returns the path of the file picked, or null when the user
  /// cancelled it, when it failed, or when the platform gave a file with no path at all.
  ///
  /// **The file itself is never read here** (see
  /// `docs/adr/0013-binary-assets-referenced-by-path.md`) — unlike an import, which is exactly why
  /// this goes to [FileSelectorManager] directly rather than through `OcptExportManager`: there is
  /// nothing to decode, only a path to keep.
  Future<String?> _pickFilePath({
    required List<String> allowedExtensions,
    required String fileTypeLabel,
  }) async {
    final fileSelectorManager = _fileSelectorManager ?? globalGetIt().get<FileSelectorManager>();

    final selection = await fileSelectorManager.openSelector(
      allowedExtensions: allowedExtensions,
      label: fileTypeLabel,
    );

    final file = selection.value;
    if (!selection.status.isSuccess || file == null) {
      // The user cancelled the dialog, or the selection failed; the latter is a soft failure
      // deliberately not surfaced as an error, since the OS dialog itself already reported it.
      return null;
    }

    return file.path.isEmpty ? null : file.path;
  }

  /// Sets person `event.personId`'s avatar colour index, written immediately.
  Future<void> _onPersonColorChanged(
    OcptResourcesPersonColorChangedEvent event,
    Emitter<OcptResourcesPeopleState> emitter,
  ) => _writeCatalogueChange(
    logContext: "change the colour of person ${event.personId}",
    action: (project) => _peopleService.updatePerson(
      database: project.database,
      personId: event.personId,
      colorIndex: Value(event.colorIndex),
    ),
  );

  /// Sets person `event.personId`'s date of birth, written immediately.
  Future<void> _onPersonBirthDateChanged(
    OcptResourcesPersonBirthDateChangedEvent event,
    Emitter<OcptResourcesPeopleState> emitter,
  ) => _writeCatalogueChange(
    logContext: "change the date of birth of person ${event.personId}",
    action: (project) => _peopleService.updatePerson(
      database: project.database,
      personId: event.personId,
      birthDate: Value(event.date),
    ),
  );

  /// Sets whether person `event.personId` can travel to set on their own, written immediately.
  Future<void> _onPersonTransportAutonomyChanged(
    OcptResourcesPersonTransportAutonomyChangedEvent event,
    Emitter<OcptResourcesPeopleState> emitter,
  ) => _writeCatalogueChange(
    logContext: "change the transport autonomy of person ${event.personId}",
    action: (project) => _peopleService.updatePerson(
      database: project.database,
      personId: event.personId,
      isTransportAutonomous: Value(event.isTransportAutonomous),
    ),
  );

  /// Sets person `event.personId`'s image rights status, written immediately.
  Future<void> _onPersonImageRightsStatusChanged(
    OcptResourcesPersonImageRightsStatusChangedEvent event,
    Emitter<OcptResourcesPeopleState> emitter,
  ) => _writeCatalogueChange(
    logContext: "change the image rights status of person ${event.personId}",
    action: (project) => _peopleService.updatePerson(
      database: project.database,
      personId: event.personId,
      imageRightsStatus: Value(event.status),
    ),
  );

  /// Sets the date person `event.personId`'s image rights status last changed, written
  /// immediately.
  Future<void> _onPersonImageRightsDateChanged(
    OcptResourcesPersonImageRightsDateChangedEvent event,
    Emitter<OcptResourcesPeopleState> emitter,
  ) => _writeCatalogueChange(
    logContext: "change the image rights date of person ${event.personId}",
    action: (project) => _peopleService.updatePerson(
      database: project.database,
      personId: event.personId,
      imageRightsDate: Value(event.date),
    ),
  );

  /// Sets person `event.personId`'s mileage rate, written immediately.
  Future<void> _onPersonMileageRateChanged(
    OcptResourcesPersonMileageRateChangedEvent event,
    Emitter<OcptResourcesPeopleState> emitter,
  ) => _writeCatalogueChange(
    logContext: "change the mileage rate of person ${event.personId}",
    action: (project) => _peopleService.updatePerson(
      database: project.database,
      personId: event.personId,
      mileageRateId: Value(event.mileageRateId),
    ),
  );

  /// Adds a crew position assignment to person `event.personId`, written immediately.
  Future<void> _onPositionAdded(
    OcptResourcesPositionAddedEvent event,
    Emitter<OcptResourcesPeopleState> emitter,
  ) => _writeCatalogueChange(
    logContext: "add a position to person ${event.personId}",
    action: (project) async {
      await _peopleService.addPosition(
        database: project.database,
        personId: event.personId,
        positionId: event.positionId,
        customLabel: event.customLabel,
      );
    },
  );

  /// Updates position assignment `event.id`, written immediately.
  Future<void> _onPositionUpdated(
    OcptResourcesPositionUpdatedEvent event,
    Emitter<OcptResourcesPeopleState> emitter,
  ) => _writeCatalogueChange(
    logContext: "update position ${event.id}",
    action: (project) => _peopleService.updatePosition(
      database: project.database,
      id: event.id,
      positionId: Value(event.positionId),
      customLabel: Value(event.customLabel),
    ),
  );

  /// Removes position assignment `event.id`, written immediately.
  Future<void> _onPositionRemoved(
    OcptResourcesPositionRemovedEvent event,
    Emitter<OcptResourcesPeopleState> emitter,
  ) => _writeCatalogueChange(
    logContext: "remove position ${event.id}",
    action: (project) => _peopleService.removePosition(database: project.database, id: event.id),
  );

  /// Adds a skill to person `event.personId`, written immediately.
  Future<void> _onSkillAdded(
    OcptResourcesSkillAddedEvent event,
    Emitter<OcptResourcesPeopleState> emitter,
  ) => _writeCatalogueChange(
    logContext: "add a skill to person ${event.personId}",
    action: (project) async {
      await _peopleService.addSkill(
        database: project.database,
        personId: event.personId,
        label: event.label,
      );
    },
  );

  /// Updates skill `event.id`'s label, written immediately.
  Future<void> _onSkillUpdated(
    OcptResourcesSkillUpdatedEvent event,
    Emitter<OcptResourcesPeopleState> emitter,
  ) => _writeCatalogueChange(
    logContext: "update skill ${event.id}",
    action: (project) =>
        _peopleService.updateSkill(database: project.database, id: event.id, label: event.label),
  );

  /// Removes skill `event.id`, written immediately.
  Future<void> _onSkillRemoved(
    OcptResourcesSkillRemovedEvent event,
    Emitter<OcptResourcesPeopleState> emitter,
  ) => _writeCatalogueChange(
    logContext: "remove skill ${event.id}",
    action: (project) => _peopleService.removeSkill(database: project.database, id: event.id),
  );

  /// Adds an unavailability to person `event.personId`, written immediately.
  Future<void> _onUnavailabilityAdded(
    OcptResourcesUnavailabilityAddedEvent event,
    Emitter<OcptResourcesPeopleState> emitter,
  ) => _writeCatalogueChange(
    logContext: "add an unavailability to person ${event.personId}",
    action: (project) async {
      await _peopleService.addUnavailability(
        database: project.database,
        personId: event.personId,
        startDate: event.startDate,
        endDate: event.endDate,
        slot: event.slot,
        startMinute: event.startMinute,
        endMinute: event.endMinute,
        reason: event.reason,
      );
    },
  );

  /// Updates unavailability `event.id`, written immediately.
  Future<void> _onUnavailabilityUpdated(
    OcptResourcesUnavailabilityUpdatedEvent event,
    Emitter<OcptResourcesPeopleState> emitter,
  ) => _writeCatalogueChange(
    logContext: "update unavailability ${event.id}",
    action: (project) => _peopleService.updateUnavailability(
      database: project.database,
      id: event.id,
      startDate: Value(event.startDate),
      endDate: Value(event.endDate),
      slot: Value(event.slot),
      startMinute: Value(event.startMinute),
      endMinute: Value(event.endMinute),
      reason: Value(event.reason),
    ),
  );

  /// Removes unavailability `event.id`, written immediately.
  Future<void> _onUnavailabilityRemoved(
    OcptResourcesUnavailabilityRemovedEvent event,
    Emitter<OcptResourcesPeopleState> emitter,
  ) => _writeCatalogueChange(
    logContext: "remove unavailability ${event.id}",
    action: (project) =>
        _peopleService.removeUnavailability(database: project.database, id: event.id),
  );

  /// Asks for person `event.personId`'s photo through the native picker and references the file
  /// picked, written immediately. A cancelled dialog leaves the photo already referenced alone.
  Future<void> _onPersonPhotoPickRequested(
    OcptResourcesPersonPhotoPickRequestedEvent event,
    Emitter<OcptResourcesPeopleState> emitter,
  ) async {
    final path = await _pickFilePath(
      allowedExtensions: ocptImageFileExtensions,
      fileTypeLabel: event.fileTypeLabel,
    );
    if (path == null) {
      return;
    }

    await _writeCatalogueChange(
      logContext: "reference the photo of person ${event.personId}",
      action: (project) async {
        await _peopleService.setPersonPhoto(
          database: project.database,
          personId: event.personId,
          path: path,
        );
      },
    );
  }

  /// Drops person `event.personId`'s reference to their photo, written immediately.
  Future<void> _onPersonPhotoCleared(
    OcptResourcesPersonPhotoClearedEvent event,
    Emitter<OcptResourcesPeopleState> emitter,
  ) => _writeCatalogueChange(
    logContext: "drop the photo of person ${event.personId}",
    action: (project) =>
        _peopleService.clearPersonPhoto(database: project.database, personId: event.personId),
  );

  /// Asks for person `event.personId`'s signed image rights release through the native picker and
  /// references the file picked, written immediately. A cancelled dialog leaves the document
  /// already referenced alone, and neither outcome touches `imageRightsStatus`.
  Future<void> _onImageRightsDocumentPickRequested(
    OcptResourcesImageRightsDocumentPickRequestedEvent event,
    Emitter<OcptResourcesPeopleState> emitter,
  ) async {
    final path = await _pickFilePath(
      allowedExtensions: ocptDocumentFileExtensions,
      fileTypeLabel: event.fileTypeLabel,
    );
    if (path == null) {
      return;
    }

    await _writeCatalogueChange(
      logContext: "reference the image rights document of person ${event.personId}",
      action: (project) async {
        await _peopleService.setImageRightsDocument(
          database: project.database,
          personId: event.personId,
          path: path,
        );
      },
    );
  }

  /// Drops person `event.personId`'s reference to their signed image rights release, written
  /// immediately.
  Future<void> _onImageRightsDocumentCleared(
    OcptResourcesImageRightsDocumentClearedEvent event,
    Emitter<OcptResourcesPeopleState> emitter,
  ) => _writeCatalogueChange(
    logContext: "drop the image rights document of person ${event.personId}",
    action: (project) => _peopleService.clearImageRightsDocument(
      database: project.database,
      personId: event.personId,
    ),
  );

  /// Writes every entry of [pending] through [_writeField].
  Future<void> _writeAllPendingFields({
    required OcptProjectDatabase database,
    required Map<(String, OcptPersonField), String> pending,
  }) async {
    for (final entry in pending.entries) {
      final (personId, field) = entry.key;
      await _writeField(
        database: database,
        personId: personId,
        field: field,
        rawValue: entry.value,
      );
    }
  }

  /// Writes a single field edit through `OcptPeopleService.updatePerson`, translating [field] into
  /// the matching named argument (see `OcptPersonField`'s own doc comment for the mapping).
  Future<void> _writeField({
    required OcptProjectDatabase database,
    required String personId,
    required OcptPersonField field,
    required String rawValue,
  }) async {
    switch (field) {
      case OcptPersonField.firstName:
        await _peopleService.updatePerson(
          database: database,
          personId: personId,
          firstName: Value(rawValue),
        );
      case OcptPersonField.lastName:
        await _peopleService.updatePerson(
          database: database,
          personId: personId,
          lastName: Value(rawValue),
        );
      case OcptPersonField.email:
        await _peopleService.updatePerson(
          database: database,
          personId: personId,
          email: Value(rawValue),
        );
      case OcptPersonField.phone:
        await _peopleService.updatePerson(
          database: database,
          personId: personId,
          phone: Value(rawValue),
        );
      case OcptPersonField.addressLine1:
        await _peopleService.updatePerson(
          database: database,
          personId: personId,
          addressLine1: Value(rawValue),
        );
      case OcptPersonField.addressLine2:
        await _peopleService.updatePerson(
          database: database,
          personId: personId,
          addressLine2: Value(rawValue),
        );
      case OcptPersonField.postalCode:
        await _peopleService.updatePerson(
          database: database,
          personId: personId,
          postalCode: Value(rawValue),
        );
      case OcptPersonField.city:
        await _peopleService.updatePerson(
          database: database,
          personId: personId,
          city: Value(rawValue),
        );
      case OcptPersonField.region:
        await _peopleService.updatePerson(
          database: database,
          personId: personId,
          region: Value(rawValue),
        );
      case OcptPersonField.country:
        await _peopleService.updatePerson(
          database: database,
          personId: personId,
          country: Value(rawValue),
        );
      case OcptPersonField.minorNotes:
        await _peopleService.updatePerson(
          database: database,
          personId: personId,
          minorNotes: Value(rawValue),
        );
      case OcptPersonField.maxDailyPresenceMinutes:
        await _peopleService.updatePerson(
          database: database,
          personId: personId,
          maxDailyPresenceMinutes: Value(ocptMaxDailyPresenceMinutesOf(rawValue)),
        );
      case OcptPersonField.commuteKmMilli:
        await _peopleService.updatePerson(
          database: database,
          personId: personId,
          commuteKmMilli: Value(ocptBudgetQuantityMilliOf(rawValue)),
        );
      case OcptPersonField.accommodationNotes:
        await _peopleService.updatePerson(
          database: database,
          personId: personId,
          accommodationNotes: Value(rawValue),
        );
      case OcptPersonField.travelNotes:
        await _peopleService.updatePerson(
          database: database,
          personId: personId,
          travelNotes: Value(rawValue),
        );
      case OcptPersonField.dietaryNotes:
        await _peopleService.updatePerson(
          database: database,
          personId: personId,
          dietaryNotes: Value(rawValue),
        );
      case OcptPersonField.allergies:
        await _peopleService.updatePerson(
          database: database,
          personId: personId,
          allergies: Value(rawValue),
        );
      case OcptPersonField.measurementHeight:
        await _peopleService.updatePerson(
          database: database,
          personId: personId,
          measurementHeight: Value(rawValue),
        );
      case OcptPersonField.measurementChest:
        await _peopleService.updatePerson(
          database: database,
          personId: personId,
          measurementChest: Value(rawValue),
        );
      case OcptPersonField.measurementWaist:
        await _peopleService.updatePerson(
          database: database,
          personId: personId,
          measurementWaist: Value(rawValue),
        );
      case OcptPersonField.measurementHips:
        await _peopleService.updatePerson(
          database: database,
          personId: personId,
          measurementHips: Value(rawValue),
        );
      case OcptPersonField.sizeTop:
        await _peopleService.updatePerson(
          database: database,
          personId: personId,
          sizeTop: Value(rawValue),
        );
      case OcptPersonField.sizeBottom:
        await _peopleService.updatePerson(
          database: database,
          personId: personId,
          sizeBottom: Value(rawValue),
        );
      case OcptPersonField.sizeShoes:
        await _peopleService.updatePerson(
          database: database,
          personId: personId,
          sizeShoes: Value(rawValue),
        );
      case OcptPersonField.hmcNotes:
        await _peopleService.updatePerson(
          database: database,
          personId: personId,
          hmcNotes: Value(rawValue),
        );
      case OcptPersonField.notes:
        await _peopleService.updatePerson(
          database: database,
          personId: personId,
          notes: Value(rawValue),
        );
    }
  }
}
