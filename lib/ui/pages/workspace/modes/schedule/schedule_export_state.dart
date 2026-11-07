// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_io_notice.dart';

export 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_io_notice.dart';
export 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_io_notice_kind.dart';

/// The state of `OcptScheduleExportBloc`: the transient notice an export leaves behind.
///
/// An export reads the mode's data and writes nothing back to the project, so the only thing it has
/// to show is how it ended.
class OcptScheduleExportState extends BlocStateForMixin<OcptScheduleExportState> {
  /// {@macro open_cine_prod_tools.exportIoNoticeField}
  final OcptScheduleIoNotice? ioNotice;

  /// Class constructor
  const OcptScheduleExportState({required this.ioNotice});

  /// Build the state of a bloc that has exported nothing yet.
  const OcptScheduleExportState.init() : ioNotice = null;

  /// {@macro open_cine_prod_tools.exportStateCopyWith}
  @override
  OcptScheduleExportState copyWith({
    OcptScheduleIoNotice? ioNotice,
    bool forceIoNoticeValue = false,
  }) => OcptScheduleExportState(ioNotice: ioNotice ?? (forceIoNoticeValue ? null : this.ioNotice));

  /// Copy this state with [ioNotice] as the outcome of the last export.
  OcptScheduleExportState copyWithIoNotice({required OcptScheduleIoNotice ioNotice}) =>
      copyWith(ioNotice: ioNotice);

  /// Copy this state with the export notice dismissed.
  OcptScheduleExportState copyWithIoNoticeDismissed() => copyWith(forceIoNoticeValue: true);

  /// {@macro act_flutter_utility.BlocStateForMixin.props}
  @override
  List<Object?> get props => [...super.props, ioNotice];
}
