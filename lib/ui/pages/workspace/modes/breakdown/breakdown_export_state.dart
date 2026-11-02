// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/breakdown_io_notice.dart';

export 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/breakdown_io_notice.dart';
export 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/breakdown_io_notice_kind.dart';

/// The state of `OcptBreakdownExportBloc`: the transient notice an export leaves behind.
///
/// An export reads the mode's data and writes nothing back to the project, so the only thing it has
/// to show is how it ended.
class OcptBreakdownExportState extends BlocStateForMixin<OcptBreakdownExportState> {
  /// {@template open_cine_prod_tools.exportIoNoticeField}
  /// The transient notice reporting the outcome of the last export, or null while none is waiting
  /// to be shown. Shown as a SnackBar, then dismissed.
  /// {@endtemplate}
  final OcptBreakdownIoNotice? ioNotice;

  /// Class constructor
  const OcptBreakdownExportState({required this.ioNotice});

  /// Build the state of a bloc that has exported nothing yet.
  const OcptBreakdownExportState.init() : ioNotice = null;

  /// {@macro open_cine_prod_tools.exportStateCopyWith}
  @override
  OcptBreakdownExportState copyWith({
    OcptBreakdownIoNotice? ioNotice,
    bool forceIoNoticeValue = false,
  }) => OcptBreakdownExportState(ioNotice: ioNotice ?? (forceIoNoticeValue ? null : this.ioNotice));

  /// Copy this state with [ioNotice] as the outcome of the last export.
  OcptBreakdownExportState copyWithIoNotice({required OcptBreakdownIoNotice ioNotice}) =>
      copyWith(ioNotice: ioNotice);

  /// Copy this state with the export notice dismissed.
  OcptBreakdownExportState copyWithIoNoticeDismissed() => copyWith(forceIoNoticeValue: true);

  /// {@macro act_flutter_utility.BlocStateForMixin.props}
  @override
  List<Object?> get props => [...super.props, ioNotice];
}
