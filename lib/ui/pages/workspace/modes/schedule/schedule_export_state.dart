// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_io_notice.dart';

export 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_io_notice.dart';

/// The state of `OcptScheduleExportBloc`: the transient notice an export leaves behind.
///
/// An export reads the mode's data and writes nothing back to the project, so the only thing it has
/// to show is how it ended.
class OcptScheduleExportState extends BlocStateForMixin<OcptScheduleExportState> {
  /// The transient notice reporting the outcome of the last export, or null while none is waiting
  /// to be shown. Shown as a SnackBar, then dismissed.
  final OcptScheduleIoNotice? ioNotice;

  /// Class constructor
  const OcptScheduleExportState({required this.ioNotice});

  /// Builds the state of a bloc that has exported nothing yet.
  const OcptScheduleExportState.init() : ioNotice = null;

  /// Copies this state, replacing what is given. [ioNotice] goes back to null only through
  /// [forceIoNoticeValue], since a null argument means "keep".
  @override
  OcptScheduleExportState copyWith({
    OcptScheduleIoNotice? ioNotice,
    bool forceIoNoticeValue = false,
  }) => OcptScheduleExportState(ioNotice: ioNotice ?? (forceIoNoticeValue ? null : this.ioNotice));

  /// Copies this state with [ioNotice] as the outcome of the last export.
  OcptScheduleExportState copyWithIoNotice({required OcptScheduleIoNotice ioNotice}) =>
      copyWith(ioNotice: ioNotice);

  /// Copies this state with the export notice dismissed.
  OcptScheduleExportState copyWithIoNoticeDismissed() => copyWith(forceIoNoticeValue: true);

  /// {@macro act_flutter_utility.BlocStateForMixin.props}
  @override
  List<Object?> get props => [...super.props, ioNotice];
}
