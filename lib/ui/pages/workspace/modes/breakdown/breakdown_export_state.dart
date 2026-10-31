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
  /// The transient notice reporting the outcome of the last export, or null while none is waiting
  /// to be shown. Shown as a SnackBar, then dismissed.
  final OcptBreakdownIoNotice? ioNotice;

  /// Class constructor
  const OcptBreakdownExportState({required this.ioNotice});

  /// Builds the state of a bloc that has exported nothing yet.
  const OcptBreakdownExportState.init() : ioNotice = null;

  /// Copies this state, replacing what is given. [ioNotice] goes back to null only through
  /// [forceIoNoticeValue], since a null argument means "keep".
  @override
  OcptBreakdownExportState copyWith({
    OcptBreakdownIoNotice? ioNotice,
    bool forceIoNoticeValue = false,
  }) => OcptBreakdownExportState(ioNotice: ioNotice ?? (forceIoNoticeValue ? null : this.ioNotice));

  /// Object properties
  @override
  List<Object?> get props => [...super.props, ioNotice];
}
