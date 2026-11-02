// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:ui';

import 'package:act_dart_result/act_dart_result.dart';
import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:act_global_manager/act_global_manager.dart';
import 'package:act_life_cycle/act_life_cycle.dart';
import 'package:act_logger_manager/act_logger_manager.dart';
import 'package:act_platform_manager/act_platform_manager.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_budget_export_ops.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_document_export_ops.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_schedule_export_ops.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_breakdown_sheets_pdf_service.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_breakdown_xlsx_export_service.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_budget_cash_journal_xlsx_export_service.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_budget_financial_report_pdf_service.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_budget_financing_plan_pdf_service.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_budget_quote_pdf_service.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_call_sheet_pdf_service.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_contact_list_pdf_service.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_courier_prime_fonts_loader.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_day_out_of_days_pdf_service.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_export_write_service.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_floor_plan_pdf_service.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_fountain_io_service.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_one_line_schedule_pdf_service.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_pdf_export_service.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_resources_xlsx_export_service.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_save_location_service.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_scenario_coverage_pdf_service.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_script_import_service.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_share_service.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_shooting_plan_pdf_service.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_shooting_plan_xlsx_export_service.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_shot_list_xlsx_export_service.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_sides_pdf_service.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_storyboard_pdf_service.dart';
import 'package:open_cine_prod_tools/managers/logging/ocpt_logs_helper_builder.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_sheets_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_xlsx_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_cash_journal_xlsx_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_financial_report_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_financing_plan_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_quote_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_call_sheet_export_result.dart';
import 'package:open_cine_prod_tools/models/ocpt_call_sheet_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_contact_list_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_day_out_of_days_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_export_outcome.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_imported_fountain_model.dart';
import 'package:open_cine_prod_tools/models/ocpt_one_line_schedule_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_resources_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_resources_xlsx_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_scenario_coverage_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_schedule_plan_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_plan_grids.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_plan_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_plan_xlsx_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_xlsx_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_sides_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_storyboard_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_storyboard_snapshot.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_tax_basis.dart';
import 'package:open_cine_prod_tools/types/ocpt_screenplay_import_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_sides_presentation.dart';

/// Build the [OcptExportManager] instance registered by the global manager.
class OcptExportManagerBuilder extends AbsLifeCycleFactory<OcptExportManager> {
  /// Class constructor
  const OcptExportManagerBuilder() : super(OcptExportManager.new);

  /// {@macro act_life_cycle.AbsLifeCycleFactory.dependsOn}
  @override
  Iterable<Type> dependsOn() => [LoggerManager, FileSelectorManager, PlatformManager];
}

/// Own everything about getting a screenplay in and out of the app as a plain `.fountain` file or
/// a PDF, the project's shot list out of it as an XLSX workbook, its scenario coverage as an
/// annotated screenplay PDF, its storyboard and its floor plans each as their own PDF, its
/// resources catalogue as a second, four-sheet XLSX workbook, its breakdown as one printed sheet
/// per scene and as a third, two-sheet XLSX workbook, and its shooting schedule as call sheets —
/// the general one and the named ones, both per day —, as one whole-shoot shooting plan (a PDF and,
/// reading the very same [OcptShootingPlanPdfService]'s own [OcptShootingPlanGrids], a five-sheet
/// XLSX workbook), as its cast's own *Day Out of Days*, as the compact one-line schedule, as a
/// day's own sides booklet, its crew and cast as a standalone, whole-production contact list, and
/// its budget as the quote (a PDF, account by account with its lines), the financing plan (a PDF,
/// its in-kind contributions kept apart), the cash journal (an XLSX workbook, every entry in its
/// own chronological order) and the financial report (a PDF, the quote read against what has
/// actually moved).
///
/// Holds the native save/open dialogs; the actual bytes/text conversion is delegated to
/// [fountainIoService], [scriptImportService], [pdfExportService], [shotListXlsxExportService],
/// [scenarioCoveragePdfService], [storyboardPdfService], [floorPlanPdfService],
/// [resourcesXlsxExportService], [breakdownSheetsPdfService], [breakdownXlsxExportService],
/// [callSheetPdfService], [shootingPlanPdfService], [shootingPlanXlsxExportService],
/// [dayOutOfDaysPdfService], [oneLineSchedulePdfService], [sidesPdfService],
/// [contactListPdfService], [budgetQuotePdfService], [budgetFinancingPlanPdfService],
/// [budgetCashJournalXlsxExportService] and [budgetFinancialReportPdfService], the "save
/// as"/"choose a folder" location picking to [saveLocationService], and — on mobile, where
/// `file_selector`'s `getSaveLocation`/`getDirectoryPath` have no Android or iOS implementation —
/// the OS share sheet to [shareService] — the twenty-three services this manager owns.
///
/// Every write funnels through `OcptExportWriteService.writeToPickedLocation` (a single file) or
/// `writeBytesInFolder` and its two callers (several files at once): on [PlatformManager.isMobile]
/// each writes into a `path_provider` temporary directory and hands the result to [shareService]
/// instead of showing the native dialog, which is why every export method below returns an
/// [OcptExportOutcome] rather than a bare path — [OcptExportSaved] on desktop, [OcptExportShared]
/// on mobile — and takes an optional `shareAnchor`, the tapped `Export` control's own screen `Rect`
/// (`sharePositionOrigin` on an iPad/Mac popover; this manager sees no `BuildContext` to resolve
/// one itself).
class OcptExportManager extends AbsWithLifeCycle {
  /// The logger category linked to this manager.
  static const _loggerCategory = "export";

  /// The service converting Fountain files to and from text.
  final OcptFountainIoService fountainIoService;

  /// The service reading a picked screenplay file — a `.fountain`, an `.fdx` or a `.celtx` — as
  /// the Fountain text the app stores.
  final OcptScriptImportService scriptImportService;

  /// The service rendering a screenplay PDF.
  final OcptPdfExportService pdfExportService;

  /// The service building the shot list XLSX workbook.
  final OcptShotListXlsxExportService shotListXlsxExportService;

  /// The service rendering the scenario coverage PDF.
  final OcptScenarioCoveragePdfService scenarioCoveragePdfService;

  /// The service building the resources catalogue's four-sheet XLSX workbook.
  final OcptResourcesXlsxExportService resourcesXlsxExportService;

  /// The service rendering the breakdown sheets PDF.
  final OcptBreakdownSheetsPdfService breakdownSheetsPdfService;

  /// The service building the breakdown's two-sheet XLSX workbook.
  final OcptBreakdownXlsxExportService breakdownXlsxExportService;

  /// The service rendering the general and the named call sheets PDFs.
  final OcptCallSheetPdfService callSheetPdfService;

  /// The service rendering the whole-shoot shooting plan PDF.
  final OcptShootingPlanPdfService shootingPlanPdfService;

  /// The service building the whole-shoot shooting plan's own five-sheet XLSX workbook.
  final OcptShootingPlanXlsxExportService shootingPlanXlsxExportService;

  /// The service rendering the cast's own *Day Out of Days* PDF.
  final OcptDayOutOfDaysPdfService dayOutOfDaysPdfService;

  /// The service rendering the one-line schedule PDF.
  final OcptOneLineSchedulePdfService oneLineSchedulePdfService;

  /// The service rendering a day's own sides booklet PDF.
  final OcptSidesPdfService sidesPdfService;

  /// The service rendering the whole-production contact list PDF.
  final OcptContactListPdfService contactListPdfService;

  /// The service rendering the budget's own quote PDF.
  final OcptBudgetQuotePdfService budgetQuotePdfService;

  /// The service rendering the budget's own financing plan PDF.
  final OcptBudgetFinancingPlanPdfService budgetFinancingPlanPdfService;

  /// The service building the budget's own cash journal XLSX workbook.
  final OcptBudgetCashJournalXlsxExportService budgetCashJournalXlsxExportService;

  /// The service rendering the budget's own financial report PDF.
  final OcptBudgetFinancialReportPdfService budgetFinancialReportPdfService;

  /// The service rendering the storyboard PDF.
  final OcptStoryboardPdfService storyboardPdfService;

  /// The service rendering the floor plans PDF.
  final OcptFloorPlanPdfService floorPlanPdfService;

  /// The service showing the native "save as"/"choose a folder" dialog and resolving the chosen
  /// path.
  final OcptSaveLocationService saveLocationService;

  /// The service handing an export's bytes to the OS share sheet on mobile.
  final OcptShareService shareService;

  /// The logger this manager writes to, and the parent of every service's own.
  final LogsHelper _logger;

  /// The manager used to show the native "open" dialog when importing.
  final FileSelectorManager _fileSelectorManager;

  /// Tells whether the write funnel shows the native save dialog or hands the bytes to the OS
  /// share sheet instead.
  final PlatformManager _platformManager;

  /// The write funnel every export goes through, built over [saveLocationService], [shareService]
  /// and the platform manager once the first export (or [initLifeCycle]) asks for it, so a test
  /// double of either service is the one it writes through.
  late final OcptExportWriteService _writer = OcptExportWriteService(
    logger: _sub(_logger, 'export_write'),
    saveLocationService: saveLocationService,
    shareService: shareService,
    platformManager: _platformManager,
  );

  /// Tell whether the write funnel shows the native save dialog or hands the bytes to
  /// [shareService]'s
  /// OS share sheet — `file_selector`'s `getSaveLocation`/`getDirectoryPath` having no Android or
  /// iOS implementation.
  ///
  /// Exposed so a caller that writes outside this manager's own export methods (the project
  /// package export, `MixinOcptProjectPackageBloc`) can branch the very same way, rather than
  /// resolving [PlatformManager] a second time through [globalGetIt].
  bool get isMobile => _platformManager.isMobile;

  /// Class constructor
  OcptExportManager({
    FileSelectorManager? fileSelectorManager,
    PlatformManager? platformManager,
    OcptSaveLocationService? saveLocationService,
    OcptShareService? shareService,
  }) : this._(
         logger: buildOcptLogsHelper(_loggerCategory),
         fontsLoader: OcptCourierPrimeFontsLoader(),
         fileSelectorManager: fileSelectorManager,
         platformManager: platformManager,
         saveLocationService: saveLocationService,
         shareService: shareService,
       );

  /// Class constructor, taking the one font loader every PDF renderer shares.
  ///
  /// Handing them all the same [OcptCourierPrimeFontsLoader] is what keeps the app from decoding
  /// the 4 embedded Courier Prime TTFs once per renderer, however many exports of any kind it runs.
  OcptExportManager._({
    required LogsHelper logger,
    required OcptCourierPrimeFontsLoader fontsLoader,
    required FileSelectorManager? fileSelectorManager,
    required PlatformManager? platformManager,
    required OcptSaveLocationService? saveLocationService,
    required OcptShareService? shareService,
  }) : _logger = logger,
       _fileSelectorManager = fileSelectorManager ?? globalGetIt().get<FileSelectorManager>(),
       // Not resolved through globalGetIt() like the manager above: PlatformManager's own
       // constructor is a synchronous, side-effect-free read of the real platform (isMobile does
       // not depend on initLifeCycle()'s async SDK-version lookup), so building one directly here
       // is exactly as correct as the registered singleton would be, and it keeps every other
       // export test — none of which registers PlatformManager in GetIt — from having to.
       _platformManager = platformManager ?? PlatformManager(),
       saveLocationService =
           saveLocationService ?? OcptSaveLocationService(logger: _sub(logger, 'save_location')),
       shareService = shareService ?? OcptShareService(logger: _sub(logger, 'share')),
       fountainIoService = OcptFountainIoService(logger: _sub(logger, 'fountain_io')),
       scriptImportService = OcptScriptImportService(
         logger: _sub(logger, 'script_import'),
         fountainIoService: OcptFountainIoService(logger: _sub(logger, 'fountain_io')),
       ),
       pdfExportService = OcptPdfExportService(
         logger: _sub(logger, 'pdf_export'),
         fontsLoader: fontsLoader,
       ),
       scenarioCoveragePdfService = OcptScenarioCoveragePdfService(
         logger: _sub(logger, 'scenario_coverage_pdf'),
         fontsLoader: fontsLoader,
       ),
       breakdownSheetsPdfService = OcptBreakdownSheetsPdfService(
         logger: _sub(logger, 'breakdown_sheets_pdf'),
         fontsLoader: fontsLoader,
       ),
       breakdownXlsxExportService = OcptBreakdownXlsxExportService(
         logger: _sub(logger, 'breakdown_xlsx_export'),
       ),
       callSheetPdfService = OcptCallSheetPdfService(
         logger: _sub(logger, 'call_sheet_pdf'),
         fontsLoader: fontsLoader,
       ),
       shootingPlanPdfService = OcptShootingPlanPdfService(
         logger: _sub(logger, 'shooting_plan_pdf'),
         fontsLoader: fontsLoader,
       ),
       shootingPlanXlsxExportService = OcptShootingPlanXlsxExportService(
         logger: _sub(logger, 'shooting_plan_xlsx_export'),
       ),
       dayOutOfDaysPdfService = OcptDayOutOfDaysPdfService(
         logger: _sub(logger, 'day_out_of_days_pdf'),
         fontsLoader: fontsLoader,
       ),
       oneLineSchedulePdfService = OcptOneLineSchedulePdfService(
         logger: _sub(logger, 'one_line_schedule_pdf'),
         fontsLoader: fontsLoader,
       ),
       sidesPdfService = OcptSidesPdfService(
         logger: _sub(logger, 'sides_pdf'),
         fontsLoader: fontsLoader,
       ),
       contactListPdfService = OcptContactListPdfService(
         logger: _sub(logger, 'contact_list_pdf'),
         fontsLoader: fontsLoader,
       ),
       budgetQuotePdfService = OcptBudgetQuotePdfService(
         logger: _sub(logger, 'budget_quote_pdf'),
         fontsLoader: fontsLoader,
       ),
       budgetFinancingPlanPdfService = OcptBudgetFinancingPlanPdfService(
         logger: _sub(logger, 'budget_financing_plan_pdf'),
         fontsLoader: fontsLoader,
       ),
       budgetFinancialReportPdfService = OcptBudgetFinancialReportPdfService(
         logger: _sub(logger, 'budget_financial_report_pdf'),
         fontsLoader: fontsLoader,
       ),
       floorPlanPdfService = OcptFloorPlanPdfService(
         logger: _sub(logger, 'floor_plan_pdf'),
         fontsLoader: fontsLoader,
       ),
       storyboardPdfService = OcptStoryboardPdfService(
         logger: _sub(logger, 'storyboard_pdf'),
         fontsLoader: fontsLoader,
         floorPlanPdfService: OcptFloorPlanPdfService(
           logger: _sub(logger, 'floor_plan_pdf'),
           fontsLoader: fontsLoader,
         ),
       ),
       budgetCashJournalXlsxExportService = OcptBudgetCashJournalXlsxExportService(
         logger: _sub(logger, 'budget_cash_journal_xlsx_export'),
       ),
       shotListXlsxExportService = OcptShotListXlsxExportService(
         logger: _sub(logger, 'shot_list_xlsx_export'),
       ),
       resourcesXlsxExportService = OcptResourcesXlsxExportService(
         logger: _sub(logger, 'resources_xlsx_export'),
       );

  /// {@macro act_life_cycle.MixinWithLifeCycle.initLifeCycle}
  ///
  /// Initialises the services this manager builds, in the order its constructor builds them.
  @override
  Future<void> initLifeCycle() async {
    await super.initLifeCycle();
    await saveLocationService.initLifeCycle();
    await shareService.initLifeCycle();
    await _writer.initLifeCycle();
    await fountainIoService.initLifeCycle();
    await scriptImportService.initLifeCycle();
    await pdfExportService.initLifeCycle();
    await scenarioCoveragePdfService.initLifeCycle();
    await breakdownSheetsPdfService.initLifeCycle();
    await breakdownXlsxExportService.initLifeCycle();
    await callSheetPdfService.initLifeCycle();
    await shootingPlanPdfService.initLifeCycle();
    await shootingPlanXlsxExportService.initLifeCycle();
    await dayOutOfDaysPdfService.initLifeCycle();
    await oneLineSchedulePdfService.initLifeCycle();
    await sidesPdfService.initLifeCycle();
    await contactListPdfService.initLifeCycle();
    await budgetQuotePdfService.initLifeCycle();
    await budgetFinancingPlanPdfService.initLifeCycle();
    await budgetFinancialReportPdfService.initLifeCycle();
    await floorPlanPdfService.initLifeCycle();
    await storyboardPdfService.initLifeCycle();
    await budgetCashJournalXlsxExportService.initLifeCycle();
    await shotListXlsxExportService.initLifeCycle();
    await resourcesXlsxExportService.initLifeCycle();

    _logger.i("The export manager started");
  }

  /// Show the native save dialog and write [fountainText] to the chosen `.fountain` file.
  Future<OcptExportOutcome?> exportFountain({
    required String fountainText,
    required String projectName,
    required String fileTypeLabel,
    String? episodeTag,
    Rect? shareAnchor,
  }) => OcptDocumentExportOps.exportFountain(
    fountainText: fountainText,
    projectName: projectName,
    fileTypeLabel: fileTypeLabel,
    episodeTag: episodeTag,
    shareAnchor: shareAnchor,
    writer: _writer,
    fountainIoService: fountainIoService,
  );

  /// Render [document] into a PDF via [pdfExportService] and show the native save dialog to
  /// write it out.
  Future<OcptExportOutcome?> exportPdf({
    required FountainDocument document,
    required OcptPageSetup pageSetup,
    required String projectName,
    required bool includeSceneNumbers,
    required bool includeTitlePage,
    required String fileTypeLabel,
    String? episodeTag,
    Rect? shareAnchor,
  }) => OcptDocumentExportOps.exportPdf(
    document: document,
    pageSetup: pageSetup,
    projectName: projectName,
    includeSceneNumbers: includeSceneNumbers,
    includeTitlePage: includeTitlePage,
    fileTypeLabel: fileTypeLabel,
    episodeTag: episodeTag,
    shareAnchor: shareAnchor,
    writer: _writer,
    pdfExportService: pdfExportService,
  );

  /// Build the XLSX workbook of [snapshot] via [shotListXlsxExportService] and show the native
  /// save dialog to write it out.
  Future<OcptExportOutcome?> exportShotListXlsx({
    required OcptShotListSnapshot snapshot,
    required OcptShotListXlsxLabels labels,
    required String projectName,
    required String fileTypeLabel,
    String? episodeTag,
    Rect? shareAnchor,
  }) => OcptDocumentExportOps.exportShotListXlsx(
    snapshot: snapshot,
    labels: labels,
    projectName: projectName,
    fileTypeLabel: fileTypeLabel,
    episodeTag: episodeTag,
    shareAnchor: shareAnchor,
    writer: _writer,
    shotListXlsxExportService: shotListXlsxExportService,
  );

  /// Render the scenario coverage of [snapshot] over [document] via [scenarioCoveragePdfService]
  /// and show the native save dialog to write it out.
  Future<OcptExportOutcome?> exportScenarioCoverage({
    required FountainDocument document,
    required String screenplayText,
    required OcptShotListSnapshot snapshot,
    required OcptPageSetup pageSetup,
    required OcptScenarioCoverageLabels labels,
    required String projectName,
    required bool includeSceneNumbers,
    required bool includeTitlePage,
    required bool includeLegendPage,
    required bool includeSummaryPage,
    required String fileTypeLabel,
    String? episodeTag,
    Rect? shareAnchor,
  }) => OcptDocumentExportOps.exportScenarioCoverage(
    document: document,
    screenplayText: screenplayText,
    snapshot: snapshot,
    pageSetup: pageSetup,
    labels: labels,
    projectName: projectName,
    includeSceneNumbers: includeSceneNumbers,
    includeTitlePage: includeTitlePage,
    includeLegendPage: includeLegendPage,
    includeSummaryPage: includeSummaryPage,
    fileTypeLabel: fileTypeLabel,
    episodeTag: episodeTag,
    shareAnchor: shareAnchor,
    writer: _writer,
    scenarioCoveragePdfService: scenarioCoveragePdfService,
  );

  /// Render the storyboard of [snapshot]/[storyboardSnapshot] via [storyboardPdfService] and show
  /// the native save dialog to write it out.
  Future<OcptExportOutcome?> exportStoryboard({
    required OcptShotListSnapshot snapshot,
    required OcptStoryboardSnapshot storyboardSnapshot,
    required OcptPageSetup pageSetup,
    required OcptStoryboardLabels labels,
    required String projectName,
    required int shotsPerPage,
    required bool includeFloorPlansAfterEachSequence,
    OcptFloorPlanSnapshot? floorPlanSnapshot,
    OcptFloorPlanLabels? floorPlanLabels,
    required String fileTypeLabel,
    String? episodeTag,
    Rect? shareAnchor,
  }) => OcptDocumentExportOps.exportStoryboard(
    snapshot: snapshot,
    storyboardSnapshot: storyboardSnapshot,
    pageSetup: pageSetup,
    labels: labels,
    projectName: projectName,
    shotsPerPage: shotsPerPage,
    includeFloorPlansAfterEachSequence: includeFloorPlansAfterEachSequence,
    floorPlanSnapshot: floorPlanSnapshot,
    floorPlanLabels: floorPlanLabels,
    fileTypeLabel: fileTypeLabel,
    episodeTag: episodeTag,
    shareAnchor: shareAnchor,
    writer: _writer,
    storyboardPdfService: storyboardPdfService,
  );

  /// Render the floor plans of [snapshot]/[floorPlanSnapshot] via [floorPlanPdfService] and show
  /// the native save dialog to write it out — no options dialog of its own, the page format coming
  /// from [pageSetup] (`OcptShotListState.pageSetup`), mirroring the shot list workbook's own
  /// `Export XLSX` button.
  Future<OcptExportOutcome?> exportFloorPlans({
    required OcptShotListSnapshot snapshot,
    required OcptFloorPlanSnapshot floorPlanSnapshot,
    required OcptPageSetup pageSetup,
    required OcptFloorPlanLabels labels,
    required String projectName,
    required String fileTypeLabel,
    String? episodeTag,
    Rect? shareAnchor,
  }) => OcptDocumentExportOps.exportFloorPlans(
    snapshot: snapshot,
    floorPlanSnapshot: floorPlanSnapshot,
    pageSetup: pageSetup,
    labels: labels,
    projectName: projectName,
    fileTypeLabel: fileTypeLabel,
    episodeTag: episodeTag,
    shareAnchor: shareAnchor,
    writer: _writer,
    floorPlanPdfService: floorPlanPdfService,
  );

  /// Build the resources catalogue's four-sheet XLSX workbook of [snapshot] via
  /// [resourcesXlsxExportService] and show the native save dialog to write it out.
  Future<OcptExportOutcome?> exportResourcesXlsx({
    required OcptResourcesSnapshot snapshot,
    required OcptResourcesXlsxLabels labels,
    required String projectName,
    required String fileTypeLabel,
    Rect? shareAnchor,
  }) => OcptDocumentExportOps.exportResourcesXlsx(
    snapshot: snapshot,
    labels: labels,
    projectName: projectName,
    fileTypeLabel: fileTypeLabel,
    shareAnchor: shareAnchor,
    writer: _writer,
    resourcesXlsxExportService: resourcesXlsxExportService,
  );

  /// Render the contact list of [snapshot] via [contactListPdfService] and show the native save
  /// dialog to write it out.
  Future<OcptExportOutcome?> exportContactList({
    required OcptResourcesSnapshot snapshot,
    required OcptPageSetup pageSetup,
    required OcptContactListLabels labels,
    required String projectName,
    required String fileTypeLabel,
    DateTime? exportDate,
    Rect? shareAnchor,
  }) => OcptDocumentExportOps.exportContactList(
    snapshot: snapshot,
    pageSetup: pageSetup,
    labels: labels,
    projectName: projectName,
    fileTypeLabel: fileTypeLabel,
    exportDate: exportDate,
    shareAnchor: shareAnchor,
    writer: _writer,
    contactListPdfService: contactListPdfService,
  );

  /// Render the quote of [snapshot] via [budgetQuotePdfService] and show the native save dialog
  /// to write it out.
  Future<OcptExportOutcome?> exportBudgetQuote({
    required OcptBudgetSnapshot snapshot,
    required Map<String, String> elementNameById,
    required OcptPageSetup pageSetup,
    required OcptBudgetTaxBasis taxBasis,
    required OcptBudgetQuoteLabels labels,
    required String projectName,
    required bool includeTitlePage,
    required String fileTypeLabel,
    Rect? shareAnchor,
  }) => OcptBudgetExportOps.exportBudgetQuote(
    snapshot: snapshot,
    elementNameById: elementNameById,
    pageSetup: pageSetup,
    taxBasis: taxBasis,
    labels: labels,
    projectName: projectName,
    includeTitlePage: includeTitlePage,
    fileTypeLabel: fileTypeLabel,
    shareAnchor: shareAnchor,
    writer: _writer,
    budgetQuotePdfService: budgetQuotePdfService,
  );

  /// Render the financing plan of [snapshot] via [budgetFinancingPlanPdfService] and show the
  /// native save dialog to write it out.
  Future<OcptExportOutcome?> exportBudgetFinancingPlan({
    required OcptBudgetSnapshot snapshot,
    required OcptPageSetup pageSetup,
    required OcptBudgetFinancingPlanLabels labels,
    required String projectName,
    required bool includeTitlePage,
    required String fileTypeLabel,
    Rect? shareAnchor,
  }) => OcptBudgetExportOps.exportBudgetFinancingPlan(
    snapshot: snapshot,
    pageSetup: pageSetup,
    labels: labels,
    projectName: projectName,
    includeTitlePage: includeTitlePage,
    fileTypeLabel: fileTypeLabel,
    shareAnchor: shareAnchor,
    writer: _writer,
    budgetFinancingPlanPdfService: budgetFinancingPlanPdfService,
  );

  /// Build the cash journal's own XLSX workbook of [snapshot] via
  /// [budgetCashJournalXlsxExportService] and show the native save dialog to write it out.
  Future<OcptExportOutcome?> exportBudgetCashJournalXlsx({
    required OcptBudgetSnapshot snapshot,
    required Map<String, String> linkLabelByEntryId,
    required OcptBudgetCashJournalXlsxLabels labels,
    required String projectName,
    required String fileTypeLabel,
    Rect? shareAnchor,
  }) => OcptBudgetExportOps.exportBudgetCashJournalXlsx(
    snapshot: snapshot,
    linkLabelByEntryId: linkLabelByEntryId,
    labels: labels,
    projectName: projectName,
    fileTypeLabel: fileTypeLabel,
    shareAnchor: shareAnchor,
    writer: _writer,
    budgetCashJournalXlsxExportService: budgetCashJournalXlsxExportService,
  );

  /// Render the financial report of [snapshot] via [budgetFinancialReportPdfService] and show the
  /// native save dialog to write it out.
  Future<OcptExportOutcome?> exportBudgetFinancialReport({
    required OcptBudgetSnapshot snapshot,
    required OcptPageSetup pageSetup,
    required OcptBudgetFinancialReportLabels labels,
    required String projectName,
    required bool includeTitlePage,
    required String fileTypeLabel,
    Rect? shareAnchor,
  }) => OcptBudgetExportOps.exportBudgetFinancialReport(
    snapshot: snapshot,
    pageSetup: pageSetup,
    labels: labels,
    projectName: projectName,
    includeTitlePage: includeTitlePage,
    fileTypeLabel: fileTypeLabel,
    shareAnchor: shareAnchor,
    writer: _writer,
    budgetFinancialReportPdfService: budgetFinancialReportPdfService,
  );

  /// Render the breakdown sheets of [snapshot] via [breakdownSheetsPdfService] and show the
  /// native save dialog to write them out.
  Future<OcptExportOutcome?> exportBreakdownSheets({
    required FountainDocument document,
    required OcptBreakdownSnapshot snapshot,
    required OcptPageSetup pageSetup,
    required OcptBreakdownSheetsLabels labels,
    required String projectName,
    required bool onlyDoneScenes,
    required bool includeNotes,
    required bool includeToFindList,
    required String fileTypeLabel,
    String? episodeTag,
    Rect? shareAnchor,
  }) => OcptDocumentExportOps.exportBreakdownSheets(
    document: document,
    snapshot: snapshot,
    pageSetup: pageSetup,
    labels: labels,
    projectName: projectName,
    onlyDoneScenes: onlyDoneScenes,
    includeNotes: includeNotes,
    includeToFindList: includeToFindList,
    fileTypeLabel: fileTypeLabel,
    episodeTag: episodeTag,
    shareAnchor: shareAnchor,
    writer: _writer,
    breakdownSheetsPdfService: breakdownSheetsPdfService,
  );

  /// Build the breakdown's two-sheet XLSX workbook of [snapshot] via [breakdownXlsxExportService]
  /// and show the native save dialog to write it out.
  Future<OcptExportOutcome?> exportBreakdownXlsx({
    required FountainDocument document,
    required OcptBreakdownSnapshot snapshot,
    required OcptPageSetup pageSetup,
    required OcptBreakdownXlsxLabels labels,
    required String projectName,
    required String fileTypeLabel,
    String? episodeTag,
    Rect? shareAnchor,
  }) => OcptDocumentExportOps.exportBreakdownXlsx(
    document: document,
    snapshot: snapshot,
    pageSetup: pageSetup,
    labels: labels,
    projectName: projectName,
    fileTypeLabel: fileTypeLabel,
    episodeTag: episodeTag,
    shareAnchor: shareAnchor,
    writer: _writer,
    breakdownXlsxExportService: breakdownXlsxExportService,
  );

  /// Render one general call sheet per day of [dayIds] via [callSheetPdfService] and write every
  /// one of them into a folder the user picks.
  Future<OcptCallSheetExportResult?> exportGeneralCallSheets({
    required OcptSchedulePlanSnapshot plan,
    required List<String> dayIds,
    required OcptPageSetup pageSetup,
    required OcptCallSheetLabels labels,
    required String projectName,
    required String confirmButtonText,
    Rect? shareAnchor,
  }) => OcptScheduleExportOps.exportGeneralCallSheets(
    plan: plan,
    dayIds: dayIds,
    pageSetup: pageSetup,
    labels: labels,
    projectName: projectName,
    confirmButtonText: confirmButtonText,
    shareAnchor: shareAnchor,
    writer: _writer,
    callSheetPdfService: callSheetPdfService,
  );

  /// Render one named call sheet per (convocation × day) of [dayIds] via [callSheetPdfService] and
  /// write every one of them into a folder the user picks — a call sheet being a document about a
  /// day, so a recipient convoked on two of [dayIds] gets two files, one for each.
  Future<OcptCallSheetExportResult?> exportNamedCallSheets({
    required OcptSchedulePlanSnapshot plan,
    required List<String> dayIds,
    Set<String>? convocationKeys,
    required OcptPageSetup pageSetup,
    required OcptCallSheetLabels labels,
    required String projectName,
    required String confirmButtonText,
    Rect? shareAnchor,
  }) => OcptScheduleExportOps.exportNamedCallSheets(
    plan: plan,
    dayIds: dayIds,
    convocationKeys: convocationKeys,
    pageSetup: pageSetup,
    labels: labels,
    projectName: projectName,
    confirmButtonText: confirmButtonText,
    shareAnchor: shareAnchor,
    writer: _writer,
    callSheetPdfService: callSheetPdfService,
  );

  /// Render the whole-shoot shooting plan of [dayIds] via [shootingPlanPdfService] and show the
  /// native save dialog to write it out.
  Future<OcptExportOutcome?> exportShootingPlan({
    required OcptSchedulePlanSnapshot plan,
    required List<String> dayIds,
    required OcptPageSetup pageSetup,
    required OcptShootingPlanLabels labels,
    required String projectName,
    required bool includeTitlePage,
    required bool includeLocationsGrid,
    required bool includeSequencesGrid,
    required bool includePeopleGrid,
    required bool includeTenMinuteGrid,
    required bool includeElementsGrid,
    required String fileTypeLabel,
    Rect? shareAnchor,
  }) => OcptScheduleExportOps.exportShootingPlan(
    plan: plan,
    dayIds: dayIds,
    pageSetup: pageSetup,
    labels: labels,
    projectName: projectName,
    includeTitlePage: includeTitlePage,
    includeLocationsGrid: includeLocationsGrid,
    includeSequencesGrid: includeSequencesGrid,
    includePeopleGrid: includePeopleGrid,
    includeTenMinuteGrid: includeTenMinuteGrid,
    includeElementsGrid: includeElementsGrid,
    fileTypeLabel: fileTypeLabel,
    shareAnchor: shareAnchor,
    writer: _writer,
    shootingPlanPdfService: shootingPlanPdfService,
  );

  /// Build the whole-shoot shooting plan's own five-sheet XLSX workbook of [dayIds] via
  /// [shootingPlanXlsxExportService] and show the native save dialog to write it out.
  Future<OcptExportOutcome?> exportShootingPlanXlsx({
    required OcptSchedulePlanSnapshot plan,
    required List<String> dayIds,
    required OcptShootingPlanXlsxLabels labels,
    required String projectName,
    required String fileTypeLabel,
    Rect? shareAnchor,
  }) => OcptScheduleExportOps.exportShootingPlanXlsx(
    plan: plan,
    dayIds: dayIds,
    labels: labels,
    projectName: projectName,
    fileTypeLabel: fileTypeLabel,
    shareAnchor: shareAnchor,
    writer: _writer,
    shootingPlanXlsxExportService: shootingPlanXlsxExportService,
  );

  /// Render the cast's own *Day Out of Days* over [dayIds] via [dayOutOfDaysPdfService] and show
  /// the native save dialog to write it out.
  Future<OcptExportOutcome?> exportDayOutOfDays({
    required OcptSchedulePlanSnapshot plan,
    required List<String> dayIds,
    required OcptPageSetup pageSetup,
    required OcptDayOutOfDaysLabels labels,
    required String projectName,
    required bool includeTitlePage,
    required String fileTypeLabel,
    Rect? shareAnchor,
  }) => OcptScheduleExportOps.exportDayOutOfDays(
    plan: plan,
    dayIds: dayIds,
    pageSetup: pageSetup,
    labels: labels,
    projectName: projectName,
    includeTitlePage: includeTitlePage,
    fileTypeLabel: fileTypeLabel,
    shareAnchor: shareAnchor,
    writer: _writer,
    dayOutOfDaysPdfService: dayOutOfDaysPdfService,
  );

  /// Render the one-line schedule over [dayIds] via [oneLineSchedulePdfService] and show the
  /// native save dialog to write it out.
  Future<OcptExportOutcome?> exportOneLineSchedule({
    required OcptSchedulePlanSnapshot plan,
    required List<String> dayIds,
    required OcptPageSetup pageSetup,
    required OcptOneLineScheduleLabels labels,
    required String projectName,
    required bool includeTitlePage,
    required String fileTypeLabel,
    Rect? shareAnchor,
  }) => OcptScheduleExportOps.exportOneLineSchedule(
    plan: plan,
    dayIds: dayIds,
    pageSetup: pageSetup,
    labels: labels,
    projectName: projectName,
    includeTitlePage: includeTitlePage,
    fileTypeLabel: fileTypeLabel,
    shareAnchor: shareAnchor,
    writer: _writer,
    oneLineSchedulePdfService: oneLineSchedulePdfService,
  );

  /// Render [dayId]'s own sides booklet via [sidesPdfService] and show the native save dialog to
  /// write it out.
  Future<OcptExportOutcome?> exportSides({
    required OcptSchedulePlanSnapshot plan,
    required String dayId,
    required List<({String screenplayId, FountainDocument document})> documents,
    required OcptPageSetup pageSetup,
    required OcptSidesLabels labels,
    required String projectName,
    required bool includeSceneNumbers,
    required OcptSidesPresentation presentation,
    required String fileTypeLabel,
    Rect? shareAnchor,
  }) => OcptScheduleExportOps.exportSides(
    plan: plan,
    dayId: dayId,
    documents: documents,
    pageSetup: pageSetup,
    labels: labels,
    projectName: projectName,
    includeSceneNumbers: includeSceneNumbers,
    presentation: presentation,
    fileTypeLabel: fileTypeLabel,
    shareAnchor: shareAnchor,
    writer: _writer,
    sidesPdfService: sidesPdfService,
  );

  /// Show the native open dialog, read the picked screenplay file and return it as Fountain
  /// text.
  ///
  /// The dialog accepts the three formats of [OcptScriptImportService.importableExtensions]: a
  /// `.fountain` file is decoded as it is, an `.fdx` and a `.celtx` are converted by
  /// [scriptImportService] — one-way and knowingly lossy. Whichever door it came through, what
  /// comes back **is** Fountain, which is why the returned model keeps its name.
  ///
  /// The outcome is a status rather than a nullable model: a file that is not the screenplay its
  /// name claims has to be told apart from a cancelled dialog, and only the first of the two is
  /// worth stating to the user.
  Future<ResultWithStatus<OcptScreenplayImportStatus, OcptImportedFountainModel>>
  pickAndReadScreenplay({required String fileTypeLabel}) async {
    final selection = await _fileSelectorManager.openSelector(
      allowedExtensions: OcptScriptImportService.importableExtensions,
      label: fileTypeLabel,
    );

    final selectedFile = selection.value;
    if (!selection.status.isSuccess || selectedFile == null) {
      // The user cancelled the dialog, or the selection failed; the latter is a soft failure
      // deliberately not surfaced as an error, since the OS dialog itself already reported it.
      return const ResultWithStatus(status: OcptScreenplayImportStatus.cancelled);
    }

    final bytes = await XFileUtilities.getBinaryFileContent(xFile: selectedFile);
    if (bytes == null) {
      _logger.e("A problem occurred when tried to read the picked file");
      return const ResultWithStatus(status: OcptScreenplayImportStatus.ioError);
    }

    final read = scriptImportService.readScreenplay(bytes: bytes, fileName: selectedFile.name);
    final fountainText = read.value;
    if (!read.status.isSuccess || fountainText == null) {
      _logger.w("The picked file could not be read as a screenplay: ${read.status}");
      return ResultWithStatus(status: read.status);
    }

    return ResultWithStatus(
      status: OcptScreenplayImportStatus.ok,
      value: OcptImportedFountainModel(
        fountainText: fountainText,
        sourceFileName: selectedFile.name,
      ),
    );
  }

  /// Get the sub-logger named [category] of [logger]: the one logger each service this manager
  /// builds
  /// is handed.
  static LogsHelper _sub(LogsHelper logger, String category) =>
      logger.createSubLogger(subCategory: category);

  /// {@macro act_life_cycle.MixinWithLifeCycleDispose.disposeLifeCycle}
  ///
  /// Disposes the services this manager builds, in the reverse order they were initialised.
  @override
  Future<void> disposeLifeCycle() async {
    _logger.i("The export manager is being disposed");
    await resourcesXlsxExportService.disposeLifeCycle();
    await shotListXlsxExportService.disposeLifeCycle();
    await budgetCashJournalXlsxExportService.disposeLifeCycle();
    await storyboardPdfService.disposeLifeCycle();
    await floorPlanPdfService.disposeLifeCycle();
    await budgetFinancialReportPdfService.disposeLifeCycle();
    await budgetFinancingPlanPdfService.disposeLifeCycle();
    await budgetQuotePdfService.disposeLifeCycle();
    await contactListPdfService.disposeLifeCycle();
    await sidesPdfService.disposeLifeCycle();
    await oneLineSchedulePdfService.disposeLifeCycle();
    await dayOutOfDaysPdfService.disposeLifeCycle();
    await shootingPlanXlsxExportService.disposeLifeCycle();
    await shootingPlanPdfService.disposeLifeCycle();
    await callSheetPdfService.disposeLifeCycle();
    await breakdownXlsxExportService.disposeLifeCycle();
    await breakdownSheetsPdfService.disposeLifeCycle();
    await scenarioCoveragePdfService.disposeLifeCycle();
    await pdfExportService.disposeLifeCycle();
    await scriptImportService.disposeLifeCycle();
    await fountainIoService.disposeLifeCycle();
    await _writer.disposeLifeCycle();
    await shareService.disposeLifeCycle();
    await saveLocationService.disposeLifeCycle();

    return super.disposeLifeCycle();
  }
}
