// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:ui';
import 'package:open_cine_prod_tools/models/ocpt_call_sheet_export_options.dart';
import 'package:open_cine_prod_tools/models/ocpt_call_sheet_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_day_out_of_days_export_options.dart';
import 'package:open_cine_prod_tools/models/ocpt_day_out_of_days_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_one_line_schedule_export_options.dart';
import 'package:open_cine_prod_tools/models/ocpt_one_line_schedule_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_plan_export_options.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_plan_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_plan_xlsx_export_options.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_plan_xlsx_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_sides_export_options.dart';
import 'package:open_cine_prod_tools/models/ocpt_sides_labels.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/events/schedule_base_event.dart';

/// The events about exports.
sealed class OcptScheduleExportEvent extends OcptScheduleEvent {
  /// Class constructor
  const OcptScheduleExportEvent();
}

/// Request exporting the general call sheets of [options]' own days, one PDF per day, into a
/// folder the user picks — dispatched once `OcptScheduleCallSheetsExportDialog` returns its result.
class OcptScheduleCallSheetsExportRequestedEvent extends OcptScheduleExportEvent {
  /// The one-off options the export runs with (the page format/margins and which days to print).
  final OcptCallSheetExportOptions options;

  /// Every localized string the exported documents carry.
  final OcptCallSheetLabels labels;

  /// The localized label of the native "choose a folder" dialog's own confirm button.
  final String confirmButtonText;

  /// The tapped `Export` control's own screen `Rect`, anchoring the OS share sheet's popover on an
  /// iPad/Mac when the run is handed to it rather than to the native folder dialog; null on desktop
  /// and wherever no anchor was resolved.
  final Rect? shareAnchor;

  /// Class constructor
  const OcptScheduleCallSheetsExportRequestedEvent({
    required this.options,
    required this.labels,
    required this.confirmButtonText,
    this.shareAnchor,
  });

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, options, labels, confirmButtonText, shareAnchor];
}

/// Request exporting the named call sheets of [options]' own days, one PDF per (selected
/// convocation × day), into a folder the user picks — dispatched once
/// `OcptScheduleNamedCallSheetsExportDialog` returns its result.
class OcptScheduleNamedCallSheetsExportRequestedEvent extends OcptScheduleExportEvent {
  /// The one-off options the export runs with: the page format/margins, the days to print
  /// ([OcptCallSheetExportOptions.dayIds]) and which of their own convocations are printed —
  /// [OcptCallSheetExportOptions.selectedConvocationKeys] being the union over every day named
  /// here, so a key convoked on only one of them yields one file, not one per day.
  final OcptCallSheetExportOptions options;

  /// Every localized string the exported documents carry.
  final OcptCallSheetLabels labels;

  /// The localized label of the native "choose a folder" dialog's own confirm button.
  final String confirmButtonText;

  /// {@template open_cine_prod_tools.exportShareAnchorLikeCallSheets}
  /// The tapped `Export` control's own screen `Rect`, exactly as
  /// [OcptScheduleCallSheetsExportRequestedEvent.shareAnchor] is — see its own doc comment.
  /// {@endtemplate}
  final Rect? shareAnchor;

  /// Class constructor
  const OcptScheduleNamedCallSheetsExportRequestedEvent({
    required this.options,
    required this.labels,
    required this.confirmButtonText,
    this.shareAnchor,
  });

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, options, labels, confirmButtonText, shareAnchor];
}

/// Request exporting the whole-shoot shooting plan of [options]' own days as a single PDF, written
/// through the native save dialog — dispatched once `OcptScheduleShootingPlanExportDialog` returns
/// its result.
class OcptScheduleShootingPlanExportRequestedEvent extends OcptScheduleExportEvent {
  /// The one-off options the export runs with (the page format/margins, which days to print, and
  /// the title page/summary grid toggles).
  final OcptShootingPlanExportOptions options;

  /// Every localized string the exported document carries.
  final OcptShootingPlanLabels labels;

  /// The localized label passed to the native save dialog's own type filter.
  final String fileTypeLabel;

  /// {@macro open_cine_prod_tools.exportShareAnchorLikeCallSheets}
  final Rect? shareAnchor;

  /// Class constructor
  const OcptScheduleShootingPlanExportRequestedEvent({
    required this.options,
    required this.labels,
    required this.fileTypeLabel,
    this.shareAnchor,
  });

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, options, labels, fileTypeLabel, shareAnchor];
}

/// Request exporting the whole-shoot shooting plan's own **workbook** of [options]' own days as a
/// single XLSX file, written through the native save dialog — dispatched once
/// `OcptScheduleShootingPlanXlsxExportDialog` returns its result. The workbook sibling of
/// [OcptScheduleShootingPlanExportRequestedEvent].
class OcptScheduleShootingPlanXlsxExportRequestedEvent extends OcptScheduleExportEvent {
  /// The one-off options the export runs with — which days to print, and nothing else.
  final OcptShootingPlanXlsxExportOptions options;

  /// Every localized string the exported workbook carries.
  final OcptShootingPlanXlsxLabels labels;

  /// The localized label passed to the native save dialog's own type filter.
  final String fileTypeLabel;

  /// {@macro open_cine_prod_tools.exportShareAnchorLikeCallSheets}
  final Rect? shareAnchor;

  /// Class constructor
  const OcptScheduleShootingPlanXlsxExportRequestedEvent({
    required this.options,
    required this.labels,
    required this.fileTypeLabel,
    this.shareAnchor,
  });

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, options, labels, fileTypeLabel, shareAnchor];
}

/// Request exporting the cast's own *Day Out of Days* over [options]' own days as a single PDF,
/// written through the native save dialog — dispatched once
/// `OcptScheduleDayOutOfDaysExportDialog` returns its result.
class OcptScheduleDayOutOfDaysExportRequestedEvent extends OcptScheduleExportEvent {
  /// The one-off options the export runs with (the page format/margins, which days the table
  /// crosses, and the title page toggle).
  final OcptDayOutOfDaysExportOptions options;

  /// Every localized string the exported document carries.
  final OcptDayOutOfDaysLabels labels;

  /// The localized label passed to the native save dialog's own type filter.
  final String fileTypeLabel;

  /// {@macro open_cine_prod_tools.exportShareAnchorLikeCallSheets}
  final Rect? shareAnchor;

  /// Class constructor
  const OcptScheduleDayOutOfDaysExportRequestedEvent({
    required this.options,
    required this.labels,
    required this.fileTypeLabel,
    this.shareAnchor,
  });

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, options, labels, fileTypeLabel, shareAnchor];
}

/// Request exporting the one-line schedule over `options.dayIds` as a single PDF, written through
/// the native save dialog — dispatched once `OcptScheduleOneLineScheduleExportDialog` returns its
/// result.
class OcptScheduleOneLineScheduleExportRequestedEvent extends OcptScheduleExportEvent {
  /// The one-off options the export runs with (the page format/margins, which days to print, and
  /// the title page toggle).
  final OcptOneLineScheduleExportOptions options;

  /// Every localized string the exported document carries.
  final OcptOneLineScheduleLabels labels;

  /// The localized label passed to the native save dialog's own type filter.
  final String fileTypeLabel;

  /// {@macro open_cine_prod_tools.exportShareAnchorLikeCallSheets}
  final Rect? shareAnchor;

  /// Class constructor
  const OcptScheduleOneLineScheduleExportRequestedEvent({
    required this.options,
    required this.labels,
    required this.fileTypeLabel,
    this.shareAnchor,
  });

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, options, labels, fileTypeLabel, shareAnchor];
}

/// Request exporting `options.dayId`'s own sides booklet as a single PDF, written through the
/// native save dialog — dispatched once `OcptScheduleSidesExportDialog` returns its result.
class OcptScheduleSidesExportRequestedEvent extends OcptScheduleExportEvent {
  /// The one-off options the export runs with (the page format/margins, the one day printed, the
  /// scene-numbers toggle and the presentation).
  final OcptSidesExportOptions options;

  /// Every localized string the exported booklet carries.
  final OcptSidesLabels labels;

  /// The localized label passed to the native save dialog's own type filter.
  final String fileTypeLabel;

  /// {@macro open_cine_prod_tools.exportShareAnchorLikeCallSheets}
  final Rect? shareAnchor;

  /// Class constructor
  const OcptScheduleSidesExportRequestedEvent({
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
class OcptScheduleIoNoticeDismissedEvent extends OcptScheduleExportEvent {
  /// Class constructor
  const OcptScheduleIoNoticeDismissedEvent();
}
