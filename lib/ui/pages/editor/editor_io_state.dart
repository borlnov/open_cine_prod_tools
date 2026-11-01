// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_io_notice.dart';

/// The state of `OcptEditorIoBloc`: the transient notice an export or an import leaves behind.
class OcptEditorIoState extends BlocStateForMixin<OcptEditorIoState> {
  /// The transient export/import outcome currently shown as a SnackBar, or null if none is.
  final OcptEditorIoNotice? ioNotice;

  /// Class constructor
  const OcptEditorIoState({required this.ioNotice});

  /// Init class constructor
  const OcptEditorIoState.init() : ioNotice = null;

  /// Copies this state, replacing what is given. [ioNotice] goes back to null only through
  /// [forceIoNoticeValue], since a null argument means "keep".
  @override
  OcptEditorIoState copyWith({OcptEditorIoNotice? ioNotice, bool forceIoNoticeValue = false}) =>
      OcptEditorIoState(ioNotice: ioNotice ?? (forceIoNoticeValue ? null : this.ioNotice));

  /// Copies this state with [ioNotice] shown as the outcome of an export or an import.
  OcptEditorIoState copyWithIoNotice({required OcptEditorIoNotice ioNotice}) =>
      copyWith(ioNotice: ioNotice);

  /// Copies this state with the shown notice cleared.
  OcptEditorIoState copyWithIoNoticeDismissed() => copyWith(forceIoNoticeValue: true);

  /// {@macro act_flutter_utility.BlocStateForMixin.props}
  @override
  List<Object?> get props => [...super.props, ioNotice];
}
