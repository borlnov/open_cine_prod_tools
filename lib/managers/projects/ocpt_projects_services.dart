// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_global_manager/act_global_manager.dart';
import 'package:act_logger_manager/act_logger_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_assets_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_breakdown_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_budget_allowances_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_budget_financing_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_budget_journal_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_budget_quote_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_budget_sharing_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_elements_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_floor_plan_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_locations_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_people_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_project_dictionary_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_project_file_compatibility_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_project_package_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_project_version_codec.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_project_versions_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_role_candidates_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_role_index_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_row_stamp_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_scene_index_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_schedule_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_screenplay_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_coverage_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_list_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_storyboard_service.dart';

/// Every service the projects manager owns, built with a sub-logger each.
///
/// The wiring is deliberately repetitive: each service builds the collaborators it depends on
/// itself, so each owner drives the life cycle of its own. The manager owns this bundle's services
/// and runs their life cycles in its own order.
class OcptProjectsServices {
  /// The service used to load/save a screenplay's text and manage its snapshots.
  final OcptScreenplayService screenplayService;

  /// The service used to reconcile a screenplay's scene index.
  final OcptSceneIndexService sceneIndexService;

  /// The service used for CRUD over a screenplay's shot list.
  final OcptShotListService shotListService;

  /// The service used to add/remove/check a shot's scenario coverage ranges.
  final OcptShotCoverageService shotCoverageService;

  /// The service used to create, list and delete the project's named versions.
  final OcptProjectVersionsService projectVersionsService;

  /// The service used for CRUD over the address book.
  final OcptPeopleService peopleService;

  /// The service used to reconcile the cast against the screenplay's speaking characters.
  final OcptRoleIndexService roleIndexService;

  /// The service used for CRUD over a screenplay's storyboard: its shots' panels and their
  /// annotation layer.
  ///
  /// Held here as well as inside [shotListService] (the same reasoning [assetsService]'s own
  /// doc comment gives): the board view reads and writes it directly, and [shotListService] only
  /// needs it for its own `deleteShot`/`tombstoneShotsOfScreenplay` cascade.
  final OcptStoryboardService storyboardService;

  /// The service used for CRUD over a screenplay's floor plans: each Resources set's symbols and
  /// arrows.
  ///
  /// Held for the same reason [storyboardService] is.
  final OcptFloorPlanService floorPlanService;

  /// The service used for CRUD over the people seen for a part, and for the one rule saying which
  /// of them the part is cast with.
  final OcptRoleCandidatesService roleCandidatesService;

  /// The service used for CRUD over locations and their sets.
  final OcptLocationsService locationsService;

  /// The service used for CRUD over the physical elements catalogue.
  final OcptElementsService elementsService;

  /// The service used for CRUD over the budget mode's quote: the `budget_postes` catalogue and the
  /// `budget_lines` inside each one.
  final OcptBudgetQuoteService budgetQuoteService;

  /// The service used for CRUD over the budget mode's cash journal: the `budget_entries` movements
  /// and the `budget_commitments` still owed against an account.
  final OcptBudgetJournalService budgetJournalService;

  /// The service used for CRUD over the budget mode's financing plan: the `budget_resources`
  /// catalogue and the `budget_mileage_rates` a production names for itself.
  final OcptBudgetFinancingService budgetFinancingService;

  /// The service used for CRUD over the budget mode's defrayals: the `budget_allowances` a
  /// production types for itself, which nothing deduces from the schedule.
  final OcptBudgetAllowancesService budgetAllowancesService;

  /// The service used for CRUD over the budget mode's revenue sharing: the `budget_revenues`
  /// takings and the `budget_shares` splitting what they bring in.
  final OcptBudgetSharingService budgetSharingService;

  /// The service used to tag a screenplay passage against an element, a role or a set, and to
  /// track a scene's own breakdown status.
  final OcptBreakdownService breakdownService;

  /// The service used for CRUD over the shooting schedule: its days, their convocation windows and
  /// convocations, and each day's timetable.
  final OcptScheduleService scheduleService;

  /// The service used to mint and tombstone the `assets` rows referencing a file — a headshot, a
  /// scouting photo, an element's photo, a signed release.
  ///
  /// Held here as well as inside the three services that compose it, because the resources mode
  /// drops a reference without caring what owns it: the row is the same row whoever it belongs to,
  /// so "remove this file" has one answer rather than three.
  final OcptAssetsService assetsService;

  /// The service used to learn, unlearn and read back the words this project's writer has taught
  /// the spell checker.
  final OcptProjectDictionaryService projectDictionaryService;

  /// The service used to write the project out as a portable package, and to read one back.
  ///
  /// Unlike every other service here it takes **paths** rather than an open database: a package is
  /// written from a project file, which is how the same code serves a project open in the workspace
  /// and a project card on the home page, and why exporting never migrates what it copies.
  final OcptProjectPackageService projectPackageService;

  /// The service reading a project file's own format before anything opens it, and keeping the
  /// copy a migration is answered with.
  ///
  /// Like [projectPackageService] it takes **paths** rather than an open database, and for a
  /// sharper reason: what it exists to prevent is precisely a project file being opened before its
  /// format is known.
  final OcptProjectFileCompatibilityService projectFileCompatibilityService;

  /// Class constructor, building every service with a sub-logger of [logger].
  ///
  /// [propertiesManager] is the one the services read the device identity from; when it is null
  /// the registered one is resolved on demand.
  OcptProjectsServices({
    required LogsHelper logger,
    required OcptPropertiesManager? propertiesManager,
  }) : sceneIndexService = OcptSceneIndexService(logger: _sub(logger, 'scene_index')),
       shotListService = OcptShotListService(
         logger: _sub(logger, 'shot_list'),
         roleIndexService: OcptRoleIndexService(
           logger: _sub(logger, 'role_index'),
           elementsService: OcptElementsService(
             logger: _sub(logger, 'elements'),
             assetsService: OcptAssetsService(
               logger: _sub(logger, 'assets'),
               deviceId: _resolveDeviceId(propertiesManager),
             ),
             deviceId: _resolveDeviceId(propertiesManager),
           ),
           roleCandidatesService: OcptRoleCandidatesService(
             logger: _sub(logger, 'role_candidates'),
             deviceId: _resolveDeviceId(propertiesManager),
           ),
           deviceId: _resolveDeviceId(propertiesManager),
         ),
         storyboardService: _buildStoryboardService(propertiesManager, logger),
         floorPlanService: _buildFloorPlanService(propertiesManager, logger),
         deviceId: _resolveDeviceId(propertiesManager),
       ),
       shotCoverageService = OcptShotCoverageService(
         logger: _sub(logger, 'shot_coverage'),
         deviceId: _resolveDeviceId(propertiesManager),
       ),
       projectVersionsService = OcptProjectVersionsService(
         logger: _sub(logger, 'project_versions'),
         codec: OcptProjectVersionCodec(logger: _sub(logger, 'project_version_codec')),
         screenplayService: OcptScreenplayService(
           logger: _sub(logger, 'screenplay'),
           sceneIndexService: OcptSceneIndexService(logger: _sub(logger, 'scene_index')),
           shotListService: OcptShotListService(
             logger: _sub(logger, 'shot_list'),
             roleIndexService: OcptRoleIndexService(
               logger: _sub(logger, 'role_index'),
               elementsService: OcptElementsService(
                 logger: _sub(logger, 'elements'),
                 assetsService: OcptAssetsService(
                   logger: _sub(logger, 'assets'),
                   deviceId: _resolveDeviceId(propertiesManager),
                 ),
                 deviceId: _resolveDeviceId(propertiesManager),
               ),
               roleCandidatesService: OcptRoleCandidatesService(
                 logger: _sub(logger, 'role_candidates'),
                 deviceId: _resolveDeviceId(propertiesManager),
               ),
               deviceId: _resolveDeviceId(propertiesManager),
             ),
             storyboardService: _buildStoryboardService(propertiesManager, logger),
             floorPlanService: _buildFloorPlanService(propertiesManager, logger),
             deviceId: _resolveDeviceId(propertiesManager),
           ),
           shotCoverageService: OcptShotCoverageService(
             logger: _sub(logger, 'shot_coverage'),
             deviceId: _resolveDeviceId(propertiesManager),
           ),
           roleIndexService: OcptRoleIndexService(
             logger: _sub(logger, 'role_index'),
             elementsService: OcptElementsService(
               logger: _sub(logger, 'elements'),
               assetsService: OcptAssetsService(
                 logger: _sub(logger, 'assets'),
                 deviceId: _resolveDeviceId(propertiesManager),
               ),
               deviceId: _resolveDeviceId(propertiesManager),
             ),
             roleCandidatesService: OcptRoleCandidatesService(
               logger: _sub(logger, 'role_candidates'),
               deviceId: _resolveDeviceId(propertiesManager),
             ),
             deviceId: _resolveDeviceId(propertiesManager),
           ),
           breakdownService: OcptBreakdownService(
             logger: _sub(logger, 'breakdown'),
             elementsService: OcptElementsService(
               logger: _sub(logger, 'elements'),
               assetsService: OcptAssetsService(
                 logger: _sub(logger, 'assets'),
                 deviceId: _resolveDeviceId(propertiesManager),
               ),
               deviceId: _resolveDeviceId(propertiesManager),
             ),
             locationsService: OcptLocationsService(
               logger: _sub(logger, 'locations'),
               floorPlanService: _buildFloorPlanService(propertiesManager, logger),
               assetsService: OcptAssetsService(
                 logger: _sub(logger, 'assets'),
                 deviceId: _resolveDeviceId(propertiesManager),
               ),
               deviceId: _resolveDeviceId(propertiesManager),
             ),
             deviceId: _resolveDeviceId(propertiesManager),
           ),
           scheduleService: OcptScheduleService(
             logger: _sub(logger, 'schedule'),
             deviceId: _resolveDeviceId(propertiesManager),
           ),
           deviceId: _resolveDeviceId(propertiesManager),
         ),
       ),
       screenplayService = OcptScreenplayService(
         logger: _sub(logger, 'screenplay'),
         sceneIndexService: OcptSceneIndexService(logger: _sub(logger, 'scene_index')),
         shotListService: OcptShotListService(
           logger: _sub(logger, 'shot_list'),
           roleIndexService: OcptRoleIndexService(
             logger: _sub(logger, 'role_index'),
             elementsService: OcptElementsService(
               logger: _sub(logger, 'elements'),
               assetsService: OcptAssetsService(
                 logger: _sub(logger, 'assets'),
                 deviceId: _resolveDeviceId(propertiesManager),
               ),
               deviceId: _resolveDeviceId(propertiesManager),
             ),
             roleCandidatesService: OcptRoleCandidatesService(
               logger: _sub(logger, 'role_candidates'),
               deviceId: _resolveDeviceId(propertiesManager),
             ),
             deviceId: _resolveDeviceId(propertiesManager),
           ),
           storyboardService: _buildStoryboardService(propertiesManager, logger),
           floorPlanService: _buildFloorPlanService(propertiesManager, logger),
           deviceId: _resolveDeviceId(propertiesManager),
         ),
         shotCoverageService: OcptShotCoverageService(
           logger: _sub(logger, 'shot_coverage'),
           deviceId: _resolveDeviceId(propertiesManager),
         ),
         roleIndexService: OcptRoleIndexService(
           logger: _sub(logger, 'role_index'),
           elementsService: OcptElementsService(
             logger: _sub(logger, 'elements'),
             assetsService: OcptAssetsService(
               logger: _sub(logger, 'assets'),
               deviceId: _resolveDeviceId(propertiesManager),
             ),
             deviceId: _resolveDeviceId(propertiesManager),
           ),
           roleCandidatesService: OcptRoleCandidatesService(
             logger: _sub(logger, 'role_candidates'),
             deviceId: _resolveDeviceId(propertiesManager),
           ),
           deviceId: _resolveDeviceId(propertiesManager),
         ),
         breakdownService: OcptBreakdownService(
           logger: _sub(logger, 'breakdown'),
           elementsService: OcptElementsService(
             logger: _sub(logger, 'elements'),
             assetsService: OcptAssetsService(
               logger: _sub(logger, 'assets'),
               deviceId: _resolveDeviceId(propertiesManager),
             ),
             deviceId: _resolveDeviceId(propertiesManager),
           ),
           locationsService: OcptLocationsService(
             logger: _sub(logger, 'locations'),
             floorPlanService: _buildFloorPlanService(propertiesManager, logger),
             assetsService: OcptAssetsService(
               logger: _sub(logger, 'assets'),
               deviceId: _resolveDeviceId(propertiesManager),
             ),
             deviceId: _resolveDeviceId(propertiesManager),
           ),
           deviceId: _resolveDeviceId(propertiesManager),
         ),
         scheduleService: OcptScheduleService(
           logger: _sub(logger, 'schedule'),
           deviceId: _resolveDeviceId(propertiesManager),
         ),
         deviceId: _resolveDeviceId(propertiesManager),
       ),
       peopleService = OcptPeopleService(
         logger: _sub(logger, 'people'),
         deviceId: _resolveDeviceId(propertiesManager),
         assetsService: OcptAssetsService(
           logger: _sub(logger, 'assets'),
           deviceId: _resolveDeviceId(propertiesManager),
         ),
         roleCandidatesService: OcptRoleCandidatesService(
           logger: _sub(logger, 'role_candidates'),
           deviceId: _resolveDeviceId(propertiesManager),
         ),
       ),
       roleIndexService = OcptRoleIndexService(
         logger: _sub(logger, 'role_index'),
         elementsService: OcptElementsService(
           logger: _sub(logger, 'elements'),
           assetsService: OcptAssetsService(
             logger: _sub(logger, 'assets'),
             deviceId: _resolveDeviceId(propertiesManager),
           ),
           deviceId: _resolveDeviceId(propertiesManager),
         ),
         roleCandidatesService: OcptRoleCandidatesService(
           logger: _sub(logger, 'role_candidates'),
           deviceId: _resolveDeviceId(propertiesManager),
         ),
         deviceId: _resolveDeviceId(propertiesManager),
       ),
       roleCandidatesService = OcptRoleCandidatesService(
         logger: _sub(logger, 'role_candidates'),
         deviceId: _resolveDeviceId(propertiesManager),
       ),
       locationsService = OcptLocationsService(
         logger: _sub(logger, 'locations'),
         floorPlanService: _buildFloorPlanService(propertiesManager, logger),
         assetsService: OcptAssetsService(
           logger: _sub(logger, 'assets'),
           deviceId: _resolveDeviceId(propertiesManager),
         ),
         deviceId: _resolveDeviceId(propertiesManager),
       ),
       elementsService = OcptElementsService(
         logger: _sub(logger, 'elements'),
         assetsService: OcptAssetsService(
           logger: _sub(logger, 'assets'),
           deviceId: _resolveDeviceId(propertiesManager),
         ),
         deviceId: _resolveDeviceId(propertiesManager),
       ),
       budgetQuoteService = OcptBudgetQuoteService(
         logger: _sub(logger, 'budget_quote'),
         deviceId: _resolveDeviceId(propertiesManager),
       ),
       budgetJournalService = OcptBudgetJournalService(
         logger: _sub(logger, 'budget_journal'),
         assetsService: OcptAssetsService(
           logger: _sub(logger, 'assets'),
           deviceId: _resolveDeviceId(propertiesManager),
         ),
         deviceId: _resolveDeviceId(propertiesManager),
       ),
       budgetFinancingService = OcptBudgetFinancingService(
         logger: _sub(logger, 'budget_financing'),
         deviceId: _resolveDeviceId(propertiesManager),
         quoteService: OcptBudgetQuoteService(
           logger: _sub(logger, 'budget_quote'),
           deviceId: _resolveDeviceId(propertiesManager),
         ),
       ),
       budgetAllowancesService = OcptBudgetAllowancesService(
         logger: _sub(logger, 'budget_allowances'),
         deviceId: _resolveDeviceId(propertiesManager),
       ),
       budgetSharingService = OcptBudgetSharingService(
         logger: _sub(logger, 'budget_sharing'),
         deviceId: _resolveDeviceId(propertiesManager),
       ),
       assetsService = OcptAssetsService(
         logger: _sub(logger, 'assets'),
         deviceId: _resolveDeviceId(propertiesManager),
       ),
       storyboardService = _buildStoryboardService(propertiesManager, logger),
       floorPlanService = _buildFloorPlanService(propertiesManager, logger),
       projectDictionaryService = OcptProjectDictionaryService(
         logger: _sub(logger, 'project_dictionary'),
         deviceId: _resolveDeviceId(propertiesManager),
       ),
       projectPackageService = OcptProjectPackageService(logger: _sub(logger, 'project_package')),
       projectFileCompatibilityService = OcptProjectFileCompatibilityService(
         logger: _sub(logger, 'project_file_compatibility'),
       ),
       breakdownService = OcptBreakdownService(
         logger: _sub(logger, 'breakdown'),
         elementsService: OcptElementsService(
           logger: _sub(logger, 'elements'),
           assetsService: OcptAssetsService(
             logger: _sub(logger, 'assets'),
             deviceId: _resolveDeviceId(propertiesManager),
           ),
           deviceId: _resolveDeviceId(propertiesManager),
         ),
         locationsService: OcptLocationsService(
           logger: _sub(logger, 'locations'),
           floorPlanService: _buildFloorPlanService(propertiesManager, logger),
           assetsService: OcptAssetsService(
             logger: _sub(logger, 'assets'),
             deviceId: _resolveDeviceId(propertiesManager),
           ),
           deviceId: _resolveDeviceId(propertiesManager),
         ),
         deviceId: _resolveDeviceId(propertiesManager),
       ),
       scheduleService = OcptScheduleService(
         logger: _sub(logger, 'schedule'),
         deviceId: _resolveDeviceId(propertiesManager),
       );

  /// Get the [OcptDeviceIdGetter] every stamping service this manager builds is given:
  /// [propertiesManager] when the constructor received one (a test's own double), [globalGetIt]'s
  /// singleton otherwise — the same fallback `_propertiesManager` itself resolves, repeated here
  /// rather than read off that field because a constructor initializer list cannot see `this`.
  static OcptDeviceIdGetter _resolveDeviceId(OcptPropertiesManager? propertiesManager) =>
      (propertiesManager ?? globalGetIt().get<OcptPropertiesManager>()).loadOrCreateDeviceId;

  /// Get the [OcptStoryboardService] every place this manager builds one needs, built fresh each
  /// time
  /// for the same reason [_resolveDeviceId] is repeated rather than read off a field: a constructor
  /// initializer list cannot see `this`, so nothing already being initialized can be shared.
  static OcptStoryboardService _buildStoryboardService(
    OcptPropertiesManager? propertiesManager,
    LogsHelper logger,
  ) => OcptStoryboardService(
    logger: _sub(logger, 'storyboard'),
    assetsService: OcptAssetsService(
      logger: _sub(logger, 'assets'),
      deviceId: _resolveDeviceId(propertiesManager),
    ),
    deviceId: _resolveDeviceId(propertiesManager),
  );

  /// Get the [OcptFloorPlanService] every place this manager builds one needs. See
  /// [_buildStoryboardService]'s own doc comment for why this is a static factory rather than a
  /// shared field.
  static OcptFloorPlanService _buildFloorPlanService(
    OcptPropertiesManager? propertiesManager,
    LogsHelper logger,
  ) => OcptFloorPlanService(
    logger: _sub(logger, 'floor_plan'),
    assetsService: OcptAssetsService(
      logger: _sub(logger, 'assets'),
      deviceId: _resolveDeviceId(propertiesManager),
    ),
    deviceId: _resolveDeviceId(propertiesManager),
  );

  /// Get the sub-logger named [category] of [logger]: the one logger each service this manager
  /// builds
  /// is handed.
  static LogsHelper _sub(LogsHelper logger, String category) =>
      logger.createSubLogger(subCategory: category);
}
