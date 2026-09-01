// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:act_dart_result/act_dart_result.dart';
import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:act_global_manager/act_global_manager.dart';
import 'package:act_life_cycle/act_life_cycle.dart';
import 'package:act_logger_manager/act_logger_manager.dart';
import 'package:act_platform_manager/act_platform_manager.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_breakdown_sheets_pdf_service.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_breakdown_xlsx_export_service.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_budget_cash_journal_xlsx_export_service.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_budget_financial_report_pdf_service.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_budget_financing_plan_pdf_service.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_budget_quote_pdf_service.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_call_sheet_pdf_service.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_contact_list_pdf_service.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_courier_prime_fonts.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_day_out_of_days_pdf_service.dart';
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
import 'package:open_cine_prod_tools/models/ocpt_imported_fountain_model.dart';
import 'package:open_cine_prod_tools/models/ocpt_one_line_schedule_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_resources_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_resources_xlsx_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_scenario_coverage_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_schedule_plan_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_script_sides_layout.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_plan_grids.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_plan_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_plan_xlsx_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_xlsx_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_sides_labels.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_tax_basis.dart';
import 'package:open_cine_prod_tools/types/ocpt_export_outcome.dart';
import 'package:open_cine_prod_tools/types/ocpt_screenplay_import_status.dart';
import 'package:open_cine_prod_tools/utils/ocpt_shooting_convocations.dart';
import 'package:path/path.dart' as p;

/// Builds the [OcptExportManager] instance registered by the global manager.
class OcptExportManagerBuilder extends AbsLifeCycleFactory<OcptExportManager> {
  /// Class constructor
  const OcptExportManagerBuilder() : super(OcptExportManager.new);

  /// {@macro act_life_cycle.AbsLifeCycleFactory.dependsOn}
  @override
  Iterable<Type> dependsOn() => [LoggerManager, FileSelectorManager, PlatformManager];
}

/// Owns everything about getting a screenplay in and out of the app as a plain `.fountain` file
/// or a PDF, the project's shot list out of it as an XLSX workbook, its scenario coverage as an
/// annotated screenplay PDF, its resources catalogue as a second, four-sheet XLSX workbook, its
/// breakdown as one printed sheet per scene and as a third, two-sheet XLSX workbook, and its
/// shooting schedule as call sheets — the general one and the named ones, both per day —, as one
/// whole-shoot shooting plan (a PDF and, reading the very same
/// [OcptShootingPlanPdfService]'s own [OcptShootingPlanGrids], a five-sheet XLSX workbook), as its
/// cast's own *Day Out of Days*, as the compact one-line schedule, as a day's own sides booklet,
/// its crew and cast as a standalone, whole-production contact list, and its budget as the quote (a
/// PDF, poste by poste with its lines), the financing plan (a PDF, its in-kind contributions kept
/// apart), the cash journal (an XLSX workbook, every entry in its own chronological order) and the
/// financial report (a PDF, the quote read against what has actually moved).
///
/// Holds the native save/open dialogs; the actual bytes/text conversion is delegated to
/// [fountainIoService], [scriptImportService], [pdfExportService], [shotListXlsxExportService],
/// [scenarioCoveragePdfService], [resourcesXlsxExportService], [breakdownSheetsPdfService],
/// [breakdownXlsxExportService], [callSheetPdfService], [shootingPlanPdfService],
/// [shootingPlanXlsxExportService], [dayOutOfDaysPdfService], [oneLineSchedulePdfService],
/// [sidesPdfService], [contactListPdfService], [budgetQuotePdfService],
/// [budgetFinancingPlanPdfService], [budgetCashJournalXlsxExportService] and
/// [budgetFinancialReportPdfService], the "save as"/"choose a folder" location picking to
/// [saveLocationService], and — on mobile, where `file_selector`'s `getSaveLocation`/
/// `getDirectoryPath` have no Android or iOS implementation — the OS share sheet to [shareService]
/// — the twenty-one services this manager owns (RFL18).
///
/// Every write funnels through [_writeToPickedLocation] (a single file) or [_writeBytesInFolder]
/// and its two callers (several files at once): on [PlatformManager.isMobile] each writes into a
/// `path_provider` temporary directory and hands the result to [shareService] instead of showing
/// the native dialog, which is why every export method below returns an [OcptExportOutcome]
/// rather than a bare path — [OcptExportSaved] on desktop, [OcptExportShared] on mobile — and
/// takes an optional `shareAnchor`, the tapped `Export` control's own screen `Rect`
/// (`sharePositionOrigin` on an iPad/Mac popover; this manager sees no `BuildContext` to resolve
/// one itself).
class OcptExportManager extends AbsWithLifeCycle {
  /// The manager used to show the native "open" dialog when importing.
  final FileSelectorManager _fileSelectorManager;

  /// Tells whether the write funnel shows the native save dialog or hands the bytes to the OS
  /// share sheet instead.
  final PlatformManager _platformManager;

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

  /// The service showing the native "save as"/"choose a folder" dialog and resolving the chosen
  /// path.
  final OcptSaveLocationService saveLocationService;

  /// The service handing an export's bytes to the OS share sheet on mobile.
  final OcptShareService shareService;

  /// Whether the write funnel shows the native save dialog or hands the bytes to [shareService]'s
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
    required OcptCourierPrimeFontsLoader fontsLoader,
    required FileSelectorManager? fileSelectorManager,
    required PlatformManager? platformManager,
    required OcptSaveLocationService? saveLocationService,
    required OcptShareService? shareService,
  }) : _fileSelectorManager = fileSelectorManager ?? globalGetIt().get<FileSelectorManager>(),
       // Not resolved through globalGetIt() like the manager above: PlatformManager's own
       // constructor is a synchronous, side-effect-free read of the real platform (isMobile does
       // not depend on initLifeCycle()'s async SDK-version lookup), so building one directly here
       // is exactly as correct as the registered singleton would be, and it keeps every other
       // export test — none of which registers PlatformManager in GetIt — from having to.
       _platformManager = platformManager ?? PlatformManager(),
       saveLocationService = saveLocationService ?? const OcptSaveLocationService(),
       shareService = shareService ?? const OcptShareService(),
       fountainIoService = const OcptFountainIoService(),
       scriptImportService = const OcptScriptImportService(),
       pdfExportService = OcptPdfExportService(fontsLoader: fontsLoader),
       scenarioCoveragePdfService = OcptScenarioCoveragePdfService(fontsLoader: fontsLoader),
       breakdownSheetsPdfService = OcptBreakdownSheetsPdfService(fontsLoader: fontsLoader),
       breakdownXlsxExportService = const OcptBreakdownXlsxExportService(),
       callSheetPdfService = OcptCallSheetPdfService(fontsLoader: fontsLoader),
       shootingPlanPdfService = OcptShootingPlanPdfService(fontsLoader: fontsLoader),
       shootingPlanXlsxExportService = const OcptShootingPlanXlsxExportService(),
       dayOutOfDaysPdfService = OcptDayOutOfDaysPdfService(fontsLoader: fontsLoader),
       oneLineSchedulePdfService = OcptOneLineSchedulePdfService(fontsLoader: fontsLoader),
       sidesPdfService = OcptSidesPdfService(fontsLoader: fontsLoader),
       contactListPdfService = OcptContactListPdfService(fontsLoader: fontsLoader),
       budgetQuotePdfService = OcptBudgetQuotePdfService(fontsLoader: fontsLoader),
       budgetFinancingPlanPdfService = OcptBudgetFinancingPlanPdfService(fontsLoader: fontsLoader),
       budgetFinancialReportPdfService = OcptBudgetFinancialReportPdfService(fontsLoader: fontsLoader),
       budgetCashJournalXlsxExportService = const OcptBudgetCashJournalXlsxExportService(),
       shotListXlsxExportService = const OcptShotListXlsxExportService(),
       resourcesXlsxExportService = const OcptResourcesXlsxExportService();

  /// Shows the native save dialog and writes [fountainText] to the chosen `.fountain` file.
  ///
  /// [fileTypeLabel] is the localized label passed to the native dialog's type filter. [episodeTag]
  /// is the selected episode's own tag, resolved by the caller (this manager has no `Tr` of its
  /// own) and present only while the open project holds more than one episode — a screenplay is one
  /// episode's own text, so two episodes exported into the same folder must not silently overwrite
  /// one another (issue #55, ADR 0019). Returns the write funnel's own outcome, or null if the user
  /// cancelled or the save failed (failures are logged; the OS dialog already reported a
  /// cancellation to the user).
  Future<OcptExportOutcome?> exportFountain({
    required String fountainText,
    required String projectName,
    required String fileTypeLabel,
    String? episodeTag,
    Rect? shareAnchor,
  }) => _writeToPickedLocation(
    suggestedFileName: fountainIoService.fountainFileName(
      projectName: projectName,
      episodeTag: episodeTag,
    ),
    fileTypeLabel: fileTypeLabel,
    extensions: [OcptFountainIoService.fountainFileExtension],
    bytes: fountainIoService.encodeFountainText(fountainText),
    shareAnchor: shareAnchor,
  );

  /// Renders [document] into a PDF via [pdfExportService] and shows the native save dialog to
  /// write it out.
  ///
  /// [fileTypeLabel] is the localized label passed to the native dialog's type filter. [episodeTag]
  /// is the selected episode's own tag, resolved by the caller (this manager has no `Tr` of its
  /// own) and present only while the open project holds more than one episode — see
  /// [exportFountain]'s own doc comment for why. Returns the write funnel's own outcome, or null if
  /// the user cancelled or the save failed (failures are logged; the OS dialog already reported a
  /// cancellation to the user).
  Future<OcptExportOutcome?> exportPdf({
    required FountainDocument document,
    required OcptPageSetup pageSetup,
    required String projectName,
    required bool includeSceneNumbers,
    required bool includeTitlePage,
    required String fileTypeLabel,
    String? episodeTag,
    Rect? shareAnchor,
  }) async {
    final bytes = await pdfExportService.generate(
      document: document,
      pageSetup: pageSetup,
      projectName: projectName,
      includeSceneNumbers: includeSceneNumbers,
      includeTitlePage: includeTitlePage,
    );

    return _writeToPickedLocation(
      suggestedFileName: pdfExportService.pdfFileName(
        projectName: projectName,
        episodeTag: episodeTag,
      ),
      fileTypeLabel: fileTypeLabel,
      extensions: const ["pdf"],
      bytes: bytes,
      shareAnchor: shareAnchor,
    );
  }

  /// Builds the XLSX workbook of [snapshot] via [shotListXlsxExportService] and shows the native
  /// save dialog to write it out.
  ///
  /// [labels] carries every localized string the sheet itself holds (its name, its headers, the
  /// status labels and the sequence separator titles), and [fileTypeLabel] is the localized label
  /// passed to the native dialog's type filter — this manager has no `Tr` of its own. [episodeTag]
  /// is the selected episode's own tag, resolved by the caller and present only while the open
  /// project holds more than one episode — see [exportFountain]'s own doc comment for why. Returns
  /// the write funnel's own outcome, or null if the user cancelled or the save failed (failures are
  /// logged; the OS dialog already reported a cancellation to the user).
  Future<OcptExportOutcome?> exportShotListXlsx({
    required OcptShotListSnapshot snapshot,
    required OcptShotListXlsxLabels labels,
    required String projectName,
    required String fileTypeLabel,
    String? episodeTag,
    Rect? shareAnchor,
  }) => _writeToPickedLocation(
    suggestedFileName: shotListXlsxExportService.xlsxFileName(
      projectName: projectName,
      episodeTag: episodeTag,
    ),
    fileTypeLabel: fileTypeLabel,
    extensions: const [OcptShotListXlsxExportService.xlsxFileExtension],
    bytes: shotListXlsxExportService.generate(snapshot: snapshot, labels: labels),
    shareAnchor: shareAnchor,
  );

  /// Renders the scenario coverage of [snapshot] over [document] via [scenarioCoveragePdfService]
  /// and shows the native save dialog to write it out.
  ///
  /// [screenplayText] must be the very text [document] was parsed from and [snapshot]'s scenes were
  /// indexed against — a coverage range addresses it by character offset. [labels] carries every
  /// localized string the document itself holds (the two appendix pages' headings and headers, the
  /// sequence titles and the file name's own suffix) and [fileTypeLabel] the one the native dialog
  /// needs — this manager has no `Tr` of its own. [episodeTag] is the selected episode's own tag,
  /// resolved by the caller and present only while the open project holds more than one episode —
  /// see [exportFountain]'s own doc comment for why. Returns the write funnel's own outcome, or null
  /// if the user cancelled or the save failed (failures are logged; the OS dialog already reported
  /// a cancellation to the user).
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
  }) async {
    final bytes = await scenarioCoveragePdfService.generate(
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
    );

    return _writeToPickedLocation(
      suggestedFileName: scenarioCoveragePdfService.coverageFileName(
        projectName: projectName,
        suffix: labels.fileNameSuffix,
        episodeTag: episodeTag,
      ),
      fileTypeLabel: fileTypeLabel,
      extensions: const ["pdf"],
      bytes: bytes,
      shareAnchor: shareAnchor,
    );
  }

  /// Builds the resources catalogue's four-sheet XLSX workbook of [snapshot] via
  /// [resourcesXlsxExportService] and shows the native save dialog to write it out.
  ///
  /// [labels] carries every localized string the four sheets themselves hold, and [fileTypeLabel]
  /// is the localized label passed to the native dialog's type filter — this manager has no `Tr`
  /// of its own. Returns the write funnel's own outcome, or null if the user cancelled or the save
  /// failed (failures are logged; the OS dialog already reported a cancellation to the user).
  Future<OcptExportOutcome?> exportResourcesXlsx({
    required OcptResourcesSnapshot snapshot,
    required OcptResourcesXlsxLabels labels,
    required String projectName,
    required String fileTypeLabel,
    Rect? shareAnchor,
  }) => _writeToPickedLocation(
    suggestedFileName: resourcesXlsxExportService.xlsxFileName(
      projectName: projectName,
      suffix: labels.fileNameSuffix,
    ),
    fileTypeLabel: fileTypeLabel,
    extensions: const [OcptShotListXlsxExportService.xlsxFileExtension],
    bytes: resourcesXlsxExportService.generate(snapshot: snapshot, labels: labels),
    shareAnchor: shareAnchor,
  );

  /// Renders the contact list of [snapshot] via [contactListPdfService] and shows the native save
  /// dialog to write it out.
  ///
  /// [labels] carries every localized string the document itself holds (the section titles, the
  /// department and position labels and the file name's own suffix) and [fileTypeLabel] the one the
  /// native dialog needs — this manager has no `Tr` of its own. [exportDate] is resolved by the
  /// caller, exactly as the schedule mode's own PDF exports resolve theirs, so a test can pin it
  /// rather than race a midnight rollover. Returns the write funnel's own outcome, or null if the
  /// user cancelled or the save failed (failures are logged; the OS dialog already reported a
  /// cancellation to the user).
  Future<OcptExportOutcome?> exportContactList({
    required OcptResourcesSnapshot snapshot,
    required OcptPageSetup pageSetup,
    required OcptContactListLabels labels,
    required String projectName,
    required String fileTypeLabel,
    DateTime? exportDate,
    Rect? shareAnchor,
  }) async {
    final bytes = await contactListPdfService.generate(
      snapshot: snapshot,
      pageSetup: pageSetup,
      labels: labels,
      projectName: projectName,
      exportDate: exportDate,
    );

    return _writeToPickedLocation(
      suggestedFileName: contactListPdfService.contactListFileName(
        projectName: projectName,
        suffix: labels.fileNameSuffix,
      ),
      fileTypeLabel: fileTypeLabel,
      extensions: const ["pdf"],
      bytes: bytes,
      shareAnchor: shareAnchor,
    );
  }

  /// Renders the quote of [snapshot] via [budgetQuotePdfService] and shows the native save dialog
  /// to write it out.
  ///
  /// [elementNameById] names every breakdown element a quote line prices
  /// (`OcptBudgetLine.elementId`), resolved by the caller — this manager has no `Tr` of its own.
  /// [labels] carries every localized string the document itself holds and [fileTypeLabel] the one
  /// the native dialog needs. Returns the write funnel's own outcome, or null if the user cancelled
  /// or the save failed (failures are logged; the OS dialog already reported a cancellation to the
  /// user).
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
  }) async {
    final bytes = await budgetQuotePdfService.generate(
      snapshot: snapshot,
      elementNameById: elementNameById,
      pageSetup: pageSetup,
      taxBasis: taxBasis,
      labels: labels,
      projectName: projectName,
      includeTitlePage: includeTitlePage,
    );

    return _writeToPickedLocation(
      suggestedFileName: budgetQuotePdfService.quoteFileName(projectName: projectName, suffix: labels.fileNameSuffix),
      fileTypeLabel: fileTypeLabel,
      extensions: const ["pdf"],
      bytes: bytes,
      shareAnchor: shareAnchor,
    );
  }

  /// Renders the financing plan of [snapshot] via [budgetFinancingPlanPdfService] and shows the
  /// native save dialog to write it out.
  ///
  /// [labels] carries every localized string the document itself holds and [fileTypeLabel] the one
  /// the native dialog needs. Returns the write funnel's own outcome, or null if the user cancelled
  /// or the save failed (failures are logged; the OS dialog already reported a cancellation to the
  /// user).
  Future<OcptExportOutcome?> exportBudgetFinancingPlan({
    required OcptBudgetSnapshot snapshot,
    required OcptPageSetup pageSetup,
    required OcptBudgetFinancingPlanLabels labels,
    required String projectName,
    required bool includeTitlePage,
    required String fileTypeLabel,
    Rect? shareAnchor,
  }) async {
    final bytes = await budgetFinancingPlanPdfService.generate(
      snapshot: snapshot,
      pageSetup: pageSetup,
      labels: labels,
      projectName: projectName,
      includeTitlePage: includeTitlePage,
    );

    return _writeToPickedLocation(
      suggestedFileName: budgetFinancingPlanPdfService.financingPlanFileName(
        projectName: projectName,
        suffix: labels.fileNameSuffix,
      ),
      fileTypeLabel: fileTypeLabel,
      extensions: const ["pdf"],
      bytes: bytes,
      shareAnchor: shareAnchor,
    );
  }

  /// Builds the cash journal's own XLSX workbook of [snapshot] via
  /// [budgetCashJournalXlsxExportService] and shows the native save dialog to write it out.
  ///
  /// [linkLabelByEntryId] is the "what this entry settles" column's own text, keyed by
  /// `OcptBudgetEntry.id` and resolved by the caller — this manager has no `Tr` of its own, and
  /// this service resolves nothing itself either (`OcptBudgetCashJournalXlsxExportService`'s own
  /// doc comment). [labels] carries every localized string the sheet itself holds and
  /// [fileTypeLabel] the one the native dialog needs. Returns the write funnel's own outcome, or null
  /// if the user cancelled or the save failed (failures are logged; the OS dialog already reported
  /// a cancellation to the user).
  Future<OcptExportOutcome?> exportBudgetCashJournalXlsx({
    required OcptBudgetSnapshot snapshot,
    required Map<String, String> linkLabelByEntryId,
    required OcptBudgetCashJournalXlsxLabels labels,
    required String projectName,
    required String fileTypeLabel,
    Rect? shareAnchor,
  }) => _writeToPickedLocation(
    suggestedFileName: budgetCashJournalXlsxExportService.xlsxFileName(projectName: projectName),
    fileTypeLabel: fileTypeLabel,
    extensions: const [OcptShotListXlsxExportService.xlsxFileExtension],
    bytes: budgetCashJournalXlsxExportService.generate(
      snapshot: snapshot,
      linkLabelByEntryId: linkLabelByEntryId,
      labels: labels,
    ),
    shareAnchor: shareAnchor,
  );

  /// Renders the financial report of [snapshot] via [budgetFinancialReportPdfService] and shows the
  /// native save dialog to write it out.
  ///
  /// [labels] carries every localized string the document itself holds and [fileTypeLabel] the one
  /// the native dialog needs. Returns the write funnel's own outcome, or null if the user cancelled
  /// or the save failed (failures are logged; the OS dialog already reported a cancellation to the
  /// user).
  Future<OcptExportOutcome?> exportBudgetFinancialReport({
    required OcptBudgetSnapshot snapshot,
    required OcptPageSetup pageSetup,
    required OcptBudgetFinancialReportLabels labels,
    required String projectName,
    required bool includeTitlePage,
    required String fileTypeLabel,
    Rect? shareAnchor,
  }) async {
    final bytes = await budgetFinancialReportPdfService.generate(
      snapshot: snapshot,
      pageSetup: pageSetup,
      labels: labels,
      projectName: projectName,
      includeTitlePage: includeTitlePage,
    );

    return _writeToPickedLocation(
      suggestedFileName: budgetFinancialReportPdfService.financialReportFileName(
        projectName: projectName,
        suffix: labels.fileNameSuffix,
      ),
      fileTypeLabel: fileTypeLabel,
      extensions: const ["pdf"],
      bytes: bytes,
      shareAnchor: shareAnchor,
    );
  }

  /// Renders the breakdown sheets of [snapshot] via [breakdownSheetsPdfService] and shows the
  /// native save dialog to write them out.
  ///
  /// [document] is the screenplay [snapshot]'s scenes were indexed against, read for each scene's
  /// own length alone (see the service's own doc comment). [labels] carries every localized string
  /// the document itself holds (the scene titles, the section headings, the status and category
  /// labels and the file name's own suffix) and [fileTypeLabel] the one the native dialog needs —
  /// this manager has no `Tr` of its own. [episodeTag] is the selected episode's own tag, resolved
  /// by the caller and present only while the open project holds more than one episode — see
  /// [exportFountain]'s own doc comment for why. Returns the write funnel's own outcome, or null if
  /// the user cancelled or the save failed (failures are logged; the OS dialog already reported a
  /// cancellation to the user).
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
  }) async {
    final bytes = await breakdownSheetsPdfService.generate(
      document: document,
      snapshot: snapshot,
      pageSetup: pageSetup,
      labels: labels,
      projectName: projectName,
      onlyDoneScenes: onlyDoneScenes,
      includeNotes: includeNotes,
      includeToFindList: includeToFindList,
    );

    return _writeToPickedLocation(
      suggestedFileName: breakdownSheetsPdfService.sheetsFileName(
        projectName: projectName,
        suffix: labels.fileNameSuffix,
        episodeTag: episodeTag,
      ),
      fileTypeLabel: fileTypeLabel,
      extensions: const ["pdf"],
      bytes: bytes,
      shareAnchor: shareAnchor,
    );
  }

  /// Builds the breakdown's two-sheet XLSX workbook of [snapshot] via [breakdownXlsxExportService]
  /// and shows the native save dialog to write it out.
  ///
  /// [document] is the screenplay [snapshot]'s scenes were indexed against, read for each scene's
  /// own length alone, exactly as [exportBreakdownSheets] reads it — see
  /// [OcptBreakdownXlsxExportService]'s own doc comment. [labels] carries every localized string
  /// the two sheets themselves hold and [fileTypeLabel] the one the native dialog needs — this
  /// manager has no `Tr` of its own. [episodeTag] is the selected episode's own tag, resolved by
  /// the caller and present only while the open project holds more than one episode — see
  /// [exportFountain]'s own doc comment for why. Unlike the breakdown sheets, this export takes no
  /// options dialog: there is nothing to ask before writing it out. Returns the write funnel's own outcome, or null if the user cancelled or the save failed (failures are logged; the OS dialog
  /// already reported a cancellation to the user).
  Future<OcptExportOutcome?> exportBreakdownXlsx({
    required FountainDocument document,
    required OcptBreakdownSnapshot snapshot,
    required OcptPageSetup pageSetup,
    required OcptBreakdownXlsxLabels labels,
    required String projectName,
    required String fileTypeLabel,
    String? episodeTag,
    Rect? shareAnchor,
  }) => _writeToPickedLocation(
    suggestedFileName: breakdownXlsxExportService.xlsxFileName(
      projectName: projectName,
      suffix: labels.fileNameSuffix,
      episodeTag: episodeTag,
    ),
    fileTypeLabel: fileTypeLabel,
    extensions: const [OcptShotListXlsxExportService.xlsxFileExtension],
    bytes: breakdownXlsxExportService.generate(
      document: document,
      snapshot: snapshot,
      pageSetup: pageSetup,
      labels: labels,
    ),
    shareAnchor: shareAnchor,
  );

  /// Renders one general call sheet per day of [dayIds] via [callSheetPdfService] and writes every
  /// one of them into a folder the user picks.
  ///
  /// This is the one export of this app that writes more than one file, so it shows the native
  /// "choose a folder" dialog ([confirmButtonText] is its own confirm button's localized label)
  /// rather than a "save as" one. Returns null if the user cancelled that dialog — nothing was
  /// touched on disk yet at that point — or an [OcptCallSheetExportResult] once a folder was chosen,
  /// even when every write inside it failed: a folder was picked, so the caller needs to know
  /// exactly what did and did not get written into it rather than being told the whole run "failed".
  /// A write failure is logged (this manager's usual soft-failure convention) and the file's own
  /// name lands in [OcptCallSheetExportResult.failedFileNames] instead of
  /// [OcptCallSheetExportResult.writtenFileNames].
  ///
  /// The moment every sheet of the run is stamped with is resolved **once**, here, and handed to
  /// each of them: a folder of sheets produced by one gesture is one issue of that day's paperwork,
  /// and a batch that read the clock per file would hand two people sheets a minute apart with no
  /// way to tell they are the same one.
  ///
  /// On mobile there is no folder to choose at all: every sheet is written into a temporary one
  /// instead, then handed to the OS share sheet together once the run is done, anchored at
  /// [shareAnchor] on an iPad/Mac — [OcptCallSheetExportResult.wasShared] is what tells a caller
  /// which of the two happened.
  Future<OcptCallSheetExportResult?> exportGeneralCallSheets({
    required OcptSchedulePlanSnapshot plan,
    required List<String> dayIds,
    required OcptPageSetup pageSetup,
    required OcptCallSheetLabels labels,
    required String projectName,
    required String confirmButtonText,
    Rect? shareAnchor,
  }) async {
    final folderPath = await _resolveCallSheetFolder(confirmButtonText: confirmButtonText);
    if (folderPath == null) {
      return null;
    }

    final exportDate = DateTime.now();
    final written = <String>[];
    final failed = <String>[];

    for (final dayId in dayIds) {
      final day = plan.schedule.daysById[dayId];
      final fileName = callSheetPdfService.callSheetFileName(
        labels: labels,
        dayNumber: day?.dayNumber ?? 0,
      );

      final bytes = await callSheetPdfService.generateGeneralCallSheet(
        plan: plan,
        dayId: dayId,
        pageSetup: pageSetup,
        labels: labels,
        projectName: projectName,
        exportDate: exportDate,
      );

      if (await _writeBytesInFolder(folderPath: folderPath, fileName: fileName, bytes: bytes)) {
        written.add(fileName);
      } else {
        failed.add(fileName);
      }
    }

    return _finishCallSheetExport(
      folderPath: folderPath,
      written: written,
      failed: failed,
      shareAnchor: shareAnchor,
    );
  }

  /// Renders one named call sheet per (convocation × day) of [dayIds] via [callSheetPdfService] and
  /// writes every one of them into a folder the user picks — a call sheet being a document about a
  /// day, so a recipient convoked on two of [dayIds] gets two files, one for each.
  ///
  /// The loop is over each day's **own** convocations, filtered by [convocationKeys], never over the
  /// product of the two: a key ticked in the dialog but convoked on none of a given day's slots
  /// simply yields no file for that day rather than an empty one. [convocationKeys] selects which of
  /// a day's own convocations are printed — `OcptDayConvocation.selectionKey`, the very key the
  /// dialog ticks them by — or null to print every convocation of every day, the common case when
  /// nobody has narrowed the selection down. See [exportGeneralCallSheets] for the folder-picking,
  /// the once-per-run export moment (its own argument holds for a run spanning several days exactly
  /// as it does for one: a folder of sheets produced by one gesture is one issue of that paperwork)
  /// and the partial-failure contract, identical here.
  ///
  /// **A guest is never printed here**, whatever [convocationKeys] says: a guest carries no
  /// `selectionKey` at all, so they are out before either the explicit selection or the "print every
  /// convocation" default is applied — a guest is not yet a call sheet recipient. A **candidate**
  /// very much is one: somebody coming to be seen for a part is convoked like anybody else (ADR
  /// 0018) and is owed the sheet saying when.
  ///
  /// [_uniqueFileName] accumulates across the **whole** run rather than being reset per day, so two
  /// recipients whose names collide on one day still each get a file of their own (`-2`, `-3`) — the
  /// file name already carries the day's own tag, so two different days' sheets never collide with
  /// each other in the first place.
  ///
  /// On mobile the whole run is shared together in one gesture rather than written into a folder the
  /// user picks — see [exportGeneralCallSheets]'s own doc comment for [shareAnchor] and
  /// [OcptCallSheetExportResult.wasShared].
  Future<OcptCallSheetExportResult?> exportNamedCallSheets({
    required OcptSchedulePlanSnapshot plan,
    required List<String> dayIds,
    Set<String>? convocationKeys,
    required OcptPageSetup pageSetup,
    required OcptCallSheetLabels labels,
    required String projectName,
    required String confirmButtonText,
    Rect? shareAnchor,
  }) async {
    final folderPath = await _resolveCallSheetFolder(confirmButtonText: confirmButtonText);
    if (folderPath == null) {
      return null;
    }

    final exportDate = DateTime.now();
    final written = <String>[];
    final failed = <String>[];

    for (final dayId in dayIds) {
      final day = plan.schedule.daysById[dayId];
      final dayNumber = day?.dayNumber ?? 0;
      final convocations = [
        for (final convocation in plan.convocationsOfDay(dayId))
          if (convocation.selectionKey case final key?)
            if (convocationKeys == null || convocationKeys.contains(key)) convocation,
      ];

      for (final convocation in convocations) {
        final personName = _namedCallSheetRecipientNameOf(plan, convocation);
        final fileName = _uniqueFileName(
          callSheetPdfService.namedCallSheetFileName(
            labels: labels,
            dayNumber: dayNumber,
            personName: personName,
          ),
          written,
          failed,
        );

        final bytes = await callSheetPdfService.generateNamedCallSheet(
          plan: plan,
          dayId: dayId,
          pageSetup: pageSetup,
          labels: labels,
          projectName: projectName,
          convocation: convocation,
          exportDate: exportDate,
        );

        if (await _writeBytesInFolder(folderPath: folderPath, fileName: fileName, bytes: bytes)) {
          written.add(fileName);
        } else {
          failed.add(fileName);
        }
      }
    }

    return _finishCallSheetExport(
      folderPath: folderPath,
      written: written,
      failed: failed,
      shareAnchor: shareAnchor,
    );
  }

  /// Renders the whole-shoot shooting plan of [dayIds] via [shootingPlanPdfService] and shows the
  /// native save dialog to write it out.
  ///
  /// [labels] carries every localized string the document itself holds (the day titles, the
  /// director line, the grid and section headings, the shot table's own headers and the file name's
  /// own suffix) and [fileTypeLabel] the one the native dialog needs — this manager has no `Tr` of
  /// its own. Unlike the call sheets, this is a **single** file: the whole shoot's own plan, through
  /// `pickSaveLocation` rather than a folder. Returns the write funnel's own outcome, or null if the
  /// user cancelled or the save failed (failures are logged; the OS dialog already reported a
  /// cancellation to the user).
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
  }) async {
    final bytes = await shootingPlanPdfService.generate(
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
    );

    return _writeToPickedLocation(
      suggestedFileName: shootingPlanPdfService.shootingPlanFileName(
        projectName: projectName,
        suffix: labels.fileNameSuffix,
      ),
      fileTypeLabel: fileTypeLabel,
      extensions: const ["pdf"],
      bytes: bytes,
      shareAnchor: shareAnchor,
    );
  }

  /// Builds the whole-shoot shooting plan's own five-sheet XLSX workbook of [dayIds] via
  /// [shootingPlanXlsxExportService] and shows the native save dialog to write it out.
  ///
  /// [labels] carries every localized string the five sheets themselves hold and [fileTypeLabel]
  /// the one the native dialog needs — this manager has no `Tr` of its own. Unlike [exportShootingPlan],
  /// this export takes no options beyond [dayIds]: there is no page geometry to ask about, and a
  /// sheet costs nothing to hide, unlike a PDF's own page. Returns the write funnel's own outcome,
  /// or null if the user cancelled or the save failed (failures are logged; the OS dialog already
  /// reported a cancellation to the user).
  Future<OcptExportOutcome?> exportShootingPlanXlsx({
    required OcptSchedulePlanSnapshot plan,
    required List<String> dayIds,
    required OcptShootingPlanXlsxLabels labels,
    required String projectName,
    required String fileTypeLabel,
    Rect? shareAnchor,
  }) => _writeToPickedLocation(
    suggestedFileName: shootingPlanXlsxExportService.xlsxFileName(
      projectName: projectName,
      suffix: labels.fileNameSuffix,
    ),
    fileTypeLabel: fileTypeLabel,
    extensions: const [OcptShotListXlsxExportService.xlsxFileExtension],
    bytes: shootingPlanXlsxExportService.generate(plan: plan, dayIds: dayIds, labels: labels),
    shareAnchor: shareAnchor,
  );

  /// Renders the cast's own *Day Out of Days* over [dayIds] via [dayOutOfDaysPdfService] and shows
  /// the native save dialog to write it out.
  ///
  /// [labels] carries every localized string the document itself holds (the column dates, the code
  /// letters and their legend, the two count headers and the file name's own suffix) and
  /// [fileTypeLabel] the one the native dialog needs — this manager has no `Tr` of its own. Like the
  /// shooting plan and unlike the call sheets, this is a **single** file, through `pickSaveLocation`
  /// rather than a folder. Returns the write funnel's own outcome, or null if the user cancelled or
  /// the save failed (failures are logged; the OS dialog already reported a cancellation to the
  /// user).
  Future<OcptExportOutcome?> exportDayOutOfDays({
    required OcptSchedulePlanSnapshot plan,
    required List<String> dayIds,
    required OcptPageSetup pageSetup,
    required OcptDayOutOfDaysLabels labels,
    required String projectName,
    required bool includeTitlePage,
    required String fileTypeLabel,
    Rect? shareAnchor,
  }) async {
    final bytes = await dayOutOfDaysPdfService.generate(
      plan: plan,
      dayIds: dayIds,
      pageSetup: pageSetup,
      labels: labels,
      projectName: projectName,
      includeTitlePage: includeTitlePage,
    );

    return _writeToPickedLocation(
      suggestedFileName: dayOutOfDaysPdfService.dayOutOfDaysFileName(
        projectName: projectName,
        suffix: labels.fileNameSuffix,
      ),
      fileTypeLabel: fileTypeLabel,
      extensions: const ["pdf"],
      bytes: bytes,
      shareAnchor: shareAnchor,
    );
  }

  /// Renders the one-line schedule over [dayIds] via [oneLineSchedulePdfService] and shows the
  /// native save dialog to write it out.
  ///
  /// [labels] carries every localized string the document itself holds (the day titles, the column
  /// headers and the file name's own suffix) and [fileTypeLabel] the one the native dialog needs —
  /// this manager has no `Tr` of its own. Like the shooting plan and the *Day Out of Days*, this is
  /// a **single** file, through `pickSaveLocation` rather than a folder. Returns the write funnel's own outcome, or null if the user cancelled or the save failed (failures are logged; the OS
  /// dialog already reported a cancellation to the user).
  Future<OcptExportOutcome?> exportOneLineSchedule({
    required OcptSchedulePlanSnapshot plan,
    required List<String> dayIds,
    required OcptPageSetup pageSetup,
    required OcptOneLineScheduleLabels labels,
    required String projectName,
    required bool includeTitlePage,
    required String fileTypeLabel,
    Rect? shareAnchor,
  }) async {
    final bytes = await oneLineSchedulePdfService.generate(
      plan: plan,
      dayIds: dayIds,
      pageSetup: pageSetup,
      labels: labels,
      projectName: projectName,
      includeTitlePage: includeTitlePage,
    );

    return _writeToPickedLocation(
      suggestedFileName: oneLineSchedulePdfService.oneLineScheduleFileName(
        projectName: projectName,
        suffix: labels.fileNameSuffix,
      ),
      fileTypeLabel: fileTypeLabel,
      extensions: const ["pdf"],
      bytes: bytes,
      shareAnchor: shareAnchor,
    );
  }

  /// Renders [dayId]'s own sides booklet via [sidesPdfService] and shows the native save dialog to
  /// write it out.
  ///
  /// [documents] is a parameter rather than something this manager reads off the open project, for
  /// the same reason [exportScenarioCoverage] takes one: this manager touches no database, and the
  /// screenplay text a booklet is sliced from is the caller's to supply — one composed run per
  /// episode the day plays, in the order the booklet chains them in (see
  /// [OcptSidesPdfService.generate]'s own doc comment for why a screenplay is never composed
  /// alongside another's). [labels] carries every localized string the document itself holds (its
  /// own title, the day tag prefix, the printed day's own title, each episode's own label, the
  /// script-page prefix and the file name's own suffix) and [fileTypeLabel] the one the native
  /// dialog needs — this manager has no `Tr` of its own. Like the shooting plan, the *Day Out of
  /// Days* and the one-line schedule, this is a **single** file, through `pickSaveLocation` rather
  /// than a folder — one booklet is one day's own paperwork, handed to one recipient at a time.
  /// Returns the write funnel's own outcome, or null if the user cancelled or the save failed
  /// (failures are logged; the OS dialog already reported a cancellation to the user).
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
  }) async {
    final bytes = await sidesPdfService.generate(
      plan: plan,
      dayId: dayId,
      documents: documents,
      pageSetup: pageSetup,
      labels: labels,
      projectName: projectName,
      includeSceneNumbers: includeSceneNumbers,
      presentation: presentation,
    );

    return _writeToPickedLocation(
      suggestedFileName: sidesPdfService.sidesFileName(
        plan: plan,
        dayId: dayId,
        projectName: projectName,
        labels: labels,
      ),
      fileTypeLabel: fileTypeLabel,
      extensions: const ["pdf"],
      bytes: bytes,
      shareAnchor: shareAnchor,
    );
  }

  /// The name a named call sheet's own file is built from for [convocation]: the person's own display
  /// name for a crew or cast recipient, the **candidate's** own for a candidacy — read through
  /// `plan.roleCandidateById`, the candidacy being what points at the person — and the role's own
  /// name for an uncast role, which names nobody else.
  ///
  /// An empty string is a perfectly ordinary answer here, for a recipient the project has not named
  /// yet or a candidacy the file no longer holds:
  /// `OcptCallSheetPdfService.namedCallSheetFileName` falls back to its own localized unnamed-person
  /// label for it, and the sheet still gets a readable file name rather than none.
  String _namedCallSheetRecipientNameOf(OcptSchedulePlanSnapshot plan, OcptDayConvocation convocation) {
    final personId = convocation.personId;
    if (personId != null) {
      return plan.personById[personId]?.displayName ?? "";
    }

    return plan.roleById[convocation.roleId]?.name ?? "";
  }

  /// [fileName], suffixed with `-2`, `-3`… while [written] or [failed] already holds it.
  ///
  /// Two convoked people sharing one display name — or, far more likely, two whose name is still
  /// blank and which therefore both fall back to the same label — would otherwise be handed the
  /// same file name, and the second write would overwrite the first: one person on the call list
  /// silently ending the export with no call sheet at all. A suffixed duplicate is a name somebody
  /// has to read twice; a missing file is somebody who never gets told when to turn up.
  String _uniqueFileName(String fileName, List<String> written, List<String> failed) {
    if (!written.contains(fileName) && !failed.contains(fileName)) {
      return fileName;
    }

    final extension = p.extension(fileName);
    final base = p.basenameWithoutExtension(fileName);
    for (var suffix = 2; ; suffix++) {
      final candidate = "$base-$suffix$extension";
      if (!written.contains(candidate) && !failed.contains(candidate)) {
        return candidate;
      }
    }
  }

  /// Resolves the folder [exportGeneralCallSheets]/[exportNamedCallSheets] write into: the folder
  /// the user picks through the native "choose a folder" dialog on desktop, or a `path_provider`
  /// temporary directory on mobile, where there is no such dialog to show at all.
  Future<String?> _resolveCallSheetFolder({required String confirmButtonText}) async {
    if (_platformManager.isMobile) {
      return (await shareService.temporaryDirectory()).path;
    }

    return saveLocationService.pickDirectory(confirmButtonText: confirmButtonText);
  }

  /// Finishes a call sheet run: on mobile, hands every file in [written] to the OS share sheet
  /// together, in the one gesture, anchored at [shareAnchor] — rather than leaving them sitting in
  /// the temporary folder [_resolveCallSheetFolder] wrote them into. A no-op on desktop, and when
  /// [written] is empty (nothing came out of the run to share).
  Future<OcptCallSheetExportResult> _finishCallSheetExport({
    required String folderPath,
    required List<String> written,
    required List<String> failed,
    Rect? shareAnchor,
  }) async {
    var wasShared = false;
    if (_platformManager.isMobile && written.isNotEmpty) {
      wasShared = await shareService.shareFiles(
        paths: [for (final fileName in written) p.join(folderPath, fileName)],
        sharePositionOrigin: shareAnchor,
      );
    }

    return OcptCallSheetExportResult(
      folderPath: folderPath,
      writtenFileNames: written,
      failedFileNames: failed,
      wasShared: wasShared,
    );
  }

  /// Writes [bytes] to `[folderPath]/[fileName]`, returning whether it succeeded — logged on
  /// failure, exactly like [_writeToPickedLocation]'s own write.
  Future<bool> _writeBytesInFolder({
    required String folderPath,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final path = p.join(folderPath, fileName);
    try {
      await File(path).writeAsBytes(bytes, flush: true);
      return true;
    } catch (error) {
      appLogger().e("A problem occurred when tried to write the file at: $path, error: $error");
      return false;
    }
  }

  /// Shows the native save dialog and writes [bytes] to the chosen location — or, on
  /// [PlatformManager.isMobile], writes them to a `path_provider` temporary file and hands that to
  /// [shareService] instead, [shareAnchor] anchoring the popover it opens as on an iPad or a Mac.
  ///
  /// Returns [OcptExportSaved] with the written path, [OcptExportShared] once the bytes were handed
  /// to the share sheet, or null if the user cancelled the dialog or the write/share failed
  /// (logged; treated the same as a cancellation by every caller).
  Future<OcptExportOutcome?> _writeToPickedLocation({
    required String suggestedFileName,
    required String fileTypeLabel,
    required List<String> extensions,
    required Uint8List bytes,
    Rect? shareAnchor,
  }) async {
    if (_platformManager.isMobile) {
      return _shareBytes(fileName: suggestedFileName, bytes: bytes, shareAnchor: shareAnchor);
    }

    final path = await saveLocationService.pickSaveLocation(
      suggestedFileName: suggestedFileName,
      fileTypeLabel: fileTypeLabel,
      extensions: extensions,
    );
    if (path == null) {
      return null;
    }

    try {
      await File(path).writeAsBytes(bytes, flush: true);
      return OcptExportSaved(path);
    } catch (error) {
      appLogger().e("A problem occurred when tried to write the file at: $path, error: $error");
      return null;
    }
  }

  /// [_writeToPickedLocation]'s mobile branch: writes [bytes] to [fileName] under
  /// [OcptShareService.temporaryDirectory] and hands that file to [shareService], anchored at
  /// [shareAnchor].
  ///
  /// Returns [OcptExportShared] once the share sheet was shown, or null if the temporary file could
  /// not be written or the share sheet itself could not be shown (logged, exactly like the desktop
  /// write).
  Future<OcptExportOutcome?> _shareBytes({
    required String fileName,
    required Uint8List bytes,
    Rect? shareAnchor,
  }) async {
    try {
      final directory = await shareService.temporaryDirectory();
      final path = p.join(directory.path, fileName);
      await File(path).writeAsBytes(bytes, flush: true);

      final shared = await shareService.shareFiles(paths: [path], sharePositionOrigin: shareAnchor);
      return shared ? const OcptExportShared() : null;
    } catch (error) {
      appLogger().e("A problem occurred when tried to share the file: $fileName, error: $error");
      return null;
    }
  }

  /// Shows the native open dialog, reads the picked screenplay file and returns it as Fountain
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
      appLogger().e("A problem occurred when tried to read the picked file: ${selectedFile.name}");
      return const ResultWithStatus(status: OcptScreenplayImportStatus.ioError);
    }

    final read = scriptImportService.readScreenplay(bytes: bytes, fileName: selectedFile.name);
    final fountainText = read.value;
    if (!read.status.isSuccess || fountainText == null) {
      appLogger().w("The picked file ${selectedFile.name} could not be read as a screenplay: "
          "${read.extraInfo}");
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
}
