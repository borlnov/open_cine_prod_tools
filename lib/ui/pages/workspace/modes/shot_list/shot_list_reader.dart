// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:meta/meta.dart' show useResult;
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_floor_plan_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_locations_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_role_index_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_schedule_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_list_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_storyboard_service.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_symbol.dart';
import 'package:open_cine_prod_tools/models/ocpt_location.dart';
import 'package:open_cine_prod_tools/models/ocpt_open_project_model.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_field_suggestions.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_storyboard_snapshot.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_scene_display_number.dart';
import 'package:open_cine_prod_tools/types/ocpt_database_status.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_page_setup_loading.dart';

/// The reads `OcptShotListBloc` makes of the data its mode shows: the shot list joined with the
/// schedule, the storyboard, the floor plans, the Resources locations and their set-scope symbols,
/// the cast, the screenplay text, the page setup and the field suggestions.
///
/// Each read takes the open project and answers the data as it stands in the working copy; the
/// bloc decides when to read, what to keep and what to emit.
class OcptShotListReader {
  /// The manager used to access the project currently open.
  final OcptProjectsManager _projectsManager;

  /// The manager the page margins preference is read from.
  final OcptPropertiesManager _propertiesManager;

  /// The service used to read the shot list.
  final OcptShotListService _shotListService;

  /// The service used to read the production's whole cast (for the character chips and the shared
  /// role alert banner).
  final OcptRoleIndexService _roleIndexService;

  /// The service used to read a shot's placement in the schedule — its `Jour de tournage` read-out,
  /// see [loadSnapshot].
  final OcptScheduleService _scheduleService;

  /// The service used to read the board's panels.
  final OcptStoryboardService _storyboardService;

  /// The service used to read the floor plans.
  final OcptFloorPlanService _floorPlanService;

  /// The service used to read the project's Resources locations and their sets.
  final OcptLocationsService _locationsService;

  /// The episode's screenplay id the reads are scoped to, resolved from the open project.
  final String Function(OcptOpenProjectModel project) _screenplayIdOf;

  /// Class constructor
  const OcptShotListReader({
    required OcptProjectsManager projectsManager,
    required OcptPropertiesManager propertiesManager,
    required OcptShotListService shotListService,
    required OcptRoleIndexService roleIndexService,
    required OcptScheduleService scheduleService,
    required OcptStoryboardService storyboardService,
    required OcptFloorPlanService floorPlanService,
    required OcptLocationsService locationsService,
    required String Function(OcptOpenProjectModel project) screenplayIdOf,
  }) : _projectsManager = projectsManager,
       _propertiesManager = propertiesManager,
       _shotListService = shotListService,
       _roleIndexService = roleIndexService,
       _scheduleService = scheduleService,
       _storyboardService = storyboardService,
       _floorPlanService = floorPlanService,
       _locationsService = locationsService,
       _screenplayIdOf = screenplayIdOf;

  /// Read the whole shot list of the selected episode's screenplay, joined with where each of its
  /// shots sits in the schedule (`OcptScheduleService.loadShotPlacements`), keyed by shot id — what
  /// the `Jour de tournage` read-out is built from. A project with no schedule joins an empty map.
  ///
  /// The scenes are numbered with their episode's own prefix: the live episodes are read through
  /// [_projectsManager]'s `screenplayService` (never through [_shotListService], which
  /// `OcptScreenplayService` already depends on), null prefix on a single-episode project.
  ///
  /// Answers the failure of the episodes read, of the shot list read or of the placements read, in
  /// place of the snapshot, when the database could not be read.
  @useResult
  Future<OcptDatabaseResult<OcptShotListSnapshot>> loadSnapshot(
    OcptOpenProjectModel project,
  ) async {
    final database = project.database;
    final screenplayId = _screenplayIdOf(project);

    final episodesRead = await _projectsManager.screenplayService.loadEpisodes(database: database);
    if (episodesRead.isError) {
      return OcptDatabaseResult(status: episodesRead.status, extraInfo: episodesRead.extraInfo);
    }

    final snapshotRead = await _shotListService.loadShotList(
      database: database,
      screenplayId: screenplayId,
      episodeNumber: ocptEpisodePrefixNumberOf(
        episodes: episodesRead.value!,
        screenplayId: screenplayId,
      ),
    );
    if (snapshotRead.isError) {
      return OcptDatabaseResult(status: snapshotRead.status, extraInfo: snapshotRead.extraInfo);
    }

    final placementsRead = await _scheduleService.loadShotPlacements(database: database);
    if (placementsRead.isError) {
      return OcptDatabaseResult(status: placementsRead.status, extraInfo: placementsRead.extraInfo);
    }

    return OcptDatabaseResult(
      status: OcptDatabaseStatus.ok,
      value: snapshotRead.value!.copyWithPlacements(placementsRead.value!),
    );
  }

  /// Read the whole storyboard of the selected episode's screenplay — every live shot's panels,
  /// keyed by shot id — what the board reads through `OcptShotListState.panelsOfShot`.
  ///
  /// Answers the failure of the read when the database could not be read.
  @useResult
  Future<OcptDatabaseResult<OcptStoryboardSnapshot>> loadStoryboard(OcptOpenProjectModel project) =>
      _storyboardService.loadStoryboard(
        database: project.database,
        screenplayId: _screenplayIdOf(project),
      );

  /// Read the whole floor plans of the selected episode's screenplay — every live set of every
  /// sequence, keyed by scene id — what the floor plans view reads through
  /// `OcptShotListState.setsOfSelectedSequence`.
  ///
  /// Answers the failure of the read when the database could not be read.
  @useResult
  Future<OcptDatabaseResult<OcptFloorPlanSnapshot>> loadFloorPlans(OcptOpenProjectModel project) =>
      _floorPlanService.loadFloorPlans(
        database: project.database,
        screenplayId: _screenplayIdOf(project),
      );

  /// Read the project's whole Resources catalogue — every location and its own sets, each
  /// carrying the scenes it is linked to — what the set tabs' `＋ Set` menu groups by, and what
  /// `ocptSceneSetSuggestionOf` reads. Project-wide, unlike [loadFloorPlans]: a set the gallery
  /// offers to link may already be linked to another episode's sequence.
  ///
  /// Answers the failure of the read when the database could not be read.
  @useResult
  Future<OcptDatabaseResult<List<OcptLocation>>> loadLocations(OcptOpenProjectModel project) =>
      _locationsService.loadLocations(database: project.database);

  /// Read the set-scope symbols of every live Resources set of the project, keyed by set id — the
  /// gallery thumbnails' content, which draw a set's own décor alone. Project-wide, like
  /// [loadLocations].
  ///
  /// Answers the failure of the read when the database could not be read.
  @useResult
  Future<OcptDatabaseResult<Map<String, List<OcptFloorPlanSymbol>>>> loadSetScopeSymbolsBySetId(
    OcptOpenProjectModel project,
  ) => _floorPlanService.loadSetScopeSymbolsByProjectSetId(database: project.database);

  /// Read the production's whole cast — every live role, in `sortKey` order — what the character
  /// chips and the shared role alert banner are derived from.
  ///
  /// Answers the failure of the read when the database could not be read.
  @useResult
  Future<OcptDatabaseResult<List<OcptRole>>> loadRoles(OcptOpenProjectModel project) =>
      _roleIndexService.loadRoles(database: project.database);

  /// Read the selected episode's current Fountain source text, kept in
  /// `OcptShotListState.screenplayText` for `ocptScreenplayCharactersOf` and the scenario coverage.
  ///
  /// Answers the failure of the read when the database could not be read.
  @useResult
  Future<OcptDatabaseResult<String>> loadScreenplayText(OcptOpenProjectModel project) =>
      _projectsManager.screenplayService.loadScreenplayText(
        database: project.database,
        screenplayId: _screenplayIdOf(project),
      );

  /// Read the page setup the screenplay is typeset with: the open project's own page format,
  /// paired with the app-wide margins preference, exactly as the screenplay editor's own bloc
  /// pairs them. The scenario coverage dialog's simulated paper sheet is laid out with it.
  ///
  /// A version being previewed is laid out with the setup it was written against instead, which
  /// travels on the open project model and is never written anywhere — again exactly as the
  /// screenplay editor's own bloc does it.
  ///
  /// Answers the failure of the read of the page format as it came.
  @useResult
  Future<OcptDatabaseResult<OcptPageSetup>> loadPageSetup(OcptOpenProjectModel project) =>
      ocptLoadPageSetup(
        project: project,
        projectsManager: _projectsManager,
        propertiesManager: _propertiesManager,
      );

  /// Read every free-text field's suggestion list, scoped to the selected episode.
  ///
  /// Answers the failure of the read when the database could not be read.
  @useResult
  Future<OcptDatabaseResult<OcptShotFieldSuggestions>> loadSuggestions(
    OcptOpenProjectModel project,
  ) => _shotListService.loadFieldSuggestions(
    database: project.database,
    screenplayId: _screenplayIdOf(project),
  );
}
