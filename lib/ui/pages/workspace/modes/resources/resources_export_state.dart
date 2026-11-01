// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_io_notice.dart';

export 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_io_notice.dart';
export 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_io_notice_kind.dart';

/// The state of `OcptResourcesExportBloc`: the transient notice an export leaves behind.
///
/// An export reads the mode's data and writes nothing back to the project, so the only thing it has
/// to show is how it ended — which is why this is kept apart from the mode's own write error: a
/// failed export says nothing about the catalogue itself.
class OcptResourcesExportState extends BlocStateForMixin<OcptResourcesExportState> {
  /// The transient notice reporting the outcome of the last export, or null while none is waiting
  /// to be shown. Shown as a SnackBar, then dismissed.
  final OcptResourcesIoNotice? ioNotice;

  /// Class constructor
  const OcptResourcesExportState({required this.ioNotice});

  /// Build the state of a bloc that has exported nothing yet.
  const OcptResourcesExportState.init() : ioNotice = null;

  /// Copy this state, replacing what is given. [ioNotice] goes back to null only through
  /// [forceIoNoticeValue], since a null argument means "keep".
  @override
  OcptResourcesExportState copyWith({
    OcptResourcesIoNotice? ioNotice,
    bool forceIoNoticeValue = false,
  }) => OcptResourcesExportState(ioNotice: ioNotice ?? (forceIoNoticeValue ? null : this.ioNotice));

  /// Copy this state with [ioNotice] as the outcome of the last export.
  OcptResourcesExportState copyWithIoNotice({required OcptResourcesIoNotice ioNotice}) =>
      copyWith(ioNotice: ioNotice);

  /// Copy this state with the export notice dismissed.
  OcptResourcesExportState copyWithIoNoticeDismissed() => copyWith(forceIoNoticeValue: true);

  /// {@macro act_flutter_utility.BlocStateForMixin.props}
  @override
  List<Object?> get props => [...super.props, ioNotice];
}
