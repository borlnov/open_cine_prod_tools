// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:ui';
import 'package:open_cine_prod_tools/models/ocpt_budget_cash_journal_xlsx_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_financial_report_export_options.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_financial_report_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_financing_plan_export_options.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_financing_plan_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_quote_export_options.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_quote_labels.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/events/budget_base_event.dart';

/// The events of the budget mode about exports.
sealed class OcptBudgetExportEvent extends OcptBudgetEvent {
  /// Class constructor
  const OcptBudgetExportEvent();
}

/// Request exporting the quote as a single PDF, written through the native save dialog —
/// dispatched once `OcptBudgetQuoteExportDialog` returns its result.
class OcptBudgetQuoteExportRequestedEvent extends OcptBudgetExportEvent {
  /// The one-off options the export runs with (the page format/margins, the title page toggle and
  /// the tax basis every line and total is printed in).
  final OcptBudgetQuoteExportOptions options;

  /// Every localized string the exported document carries.
  final OcptBudgetQuoteLabels labels;

  /// Every breakdown element a live quote line prices, keyed by its own id — resolved by the mode,
  /// which has the whole catalogue on state; the bloc has no `Tr` of its own but does carry the
  /// catalogue, so this still travels on the event exactly as `labels` does, for the same reason
  /// nothing in this event ever needs a `BuildContext`.
  final Map<String, String> elementNameById;

  /// The localized label passed to the native save dialog's own type filter.
  final String fileTypeLabel;

  /// The tapped `Export` control's own screen `Rect`, anchoring the OS share sheet's popover on an
  /// iPad/Mac when the export is handed to it rather than to the native save dialog; null on
  /// desktop and wherever no anchor was resolved.
  final Rect? shareAnchor;

  /// Class constructor
  const OcptBudgetQuoteExportRequestedEvent({
    required this.options,
    required this.labels,
    required this.elementNameById,
    required this.fileTypeLabel,
    this.shareAnchor,
  });

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [
    ...super.props,
    options,
    labels,
    elementNameById,
    fileTypeLabel,
    shareAnchor,
  ];
}

/// Request exporting the financing plan as a single PDF, written through the native save dialog —
/// dispatched once `OcptBudgetFinancingPlanExportDialog` returns its result.
class OcptBudgetFinancingPlanExportRequestedEvent extends OcptBudgetExportEvent {
  /// The one-off options the export runs with (the page format/margins and the title page toggle).
  final OcptBudgetFinancingPlanExportOptions options;

  /// Every localized string the exported document carries.
  final OcptBudgetFinancingPlanLabels labels;

  /// The localized label passed to the native save dialog's own type filter.
  final String fileTypeLabel;

  /// The tapped `Export` control's own screen `Rect`, exactly as
  /// [OcptBudgetQuoteExportRequestedEvent.shareAnchor] is — see its own doc comment.
  final Rect? shareAnchor;

  /// Class constructor
  const OcptBudgetFinancingPlanExportRequestedEvent({
    required this.options,
    required this.labels,
    required this.fileTypeLabel,
    this.shareAnchor,
  });

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, options, labels, fileTypeLabel, shareAnchor];
}

/// Request exporting the cash journal as a single XLSX workbook, written through the native save
/// dialog — dispatched the moment its own card is picked, this export taking no options dialog of
/// its own.
class OcptBudgetCashJournalExportRequestedEvent extends OcptBudgetExportEvent {
  /// Every localized string the exported workbook carries.
  final OcptBudgetCashJournalXlsxLabels labels;

  /// What each live entry settles, keyed by its own id — a resource, a taking or a share's own
  /// label, resolved by the mode: this service resolves nothing itself
  /// (`OcptBudgetCashJournalXlsxExportService`'s own doc comment).
  final Map<String, String> linkLabelByEntryId;

  /// The localized label passed to the native save dialog's own type filter.
  final String fileTypeLabel;

  /// The tapped `Export` control's own screen `Rect`, exactly as
  /// [OcptBudgetQuoteExportRequestedEvent.shareAnchor] is — see its own doc comment.
  final Rect? shareAnchor;

  /// Class constructor
  const OcptBudgetCashJournalExportRequestedEvent({
    required this.labels,
    required this.linkLabelByEntryId,
    required this.fileTypeLabel,
    this.shareAnchor,
  });

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [
    ...super.props,
    labels,
    linkLabelByEntryId,
    fileTypeLabel,
    shareAnchor,
  ];
}

/// Request exporting the financial report as a single PDF, written through the native save
/// dialog — dispatched once `OcptBudgetFinancialReportExportDialog` returns its result.
class OcptBudgetFinancialReportExportRequestedEvent extends OcptBudgetExportEvent {
  /// The one-off options the export runs with (the page format/margins and the title page toggle).
  final OcptBudgetFinancialReportExportOptions options;

  /// Every localized string the exported document carries.
  final OcptBudgetFinancialReportLabels labels;

  /// The localized label passed to the native save dialog's own type filter.
  final String fileTypeLabel;

  /// The tapped `Export` control's own screen `Rect`, exactly as
  /// [OcptBudgetQuoteExportRequestedEvent.shareAnchor] is — see its own doc comment.
  final Rect? shareAnchor;

  /// Class constructor
  const OcptBudgetFinancialReportExportRequestedEvent({
    required this.options,
    required this.labels,
    required this.fileTypeLabel,
    this.shareAnchor,
  });

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, options, labels, fileTypeLabel, shareAnchor];
}

/// Clear the transient export notice currently shown, if any.
class OcptBudgetIoNoticeDismissedEvent extends OcptBudgetExportEvent {
  /// Class constructor
  const OcptBudgetIoNoticeDismissedEvent();
}
