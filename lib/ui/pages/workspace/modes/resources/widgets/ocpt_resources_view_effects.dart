// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_export_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_export_state.dart';

/// What the resources mode's view blocs ask the screen for, wrapped around the mode: the outcome
/// of an export as a SnackBar.
///
/// It is dismissed by dispatching the bloc's own dismissal event as soon as it has been shown, so a
/// later emission never raises it twice. The mode bloc's own effects (the transient write error,
/// the dock fractions, the cross-mode reveal, the version and package notices) stay with the mode,
/// which owns the dock layout controller and the workspace bloc they feed.
class OcptResourcesViewEffects extends StatelessWidget {
  /// The mode, which the listener wraps.
  final Widget child;

  /// Class constructor
  const OcptResourcesViewEffects({super.key, required this.child});

  /// Build the resources view effects as a [BlocListener].
  @override
  Widget build(BuildContext context) =>
      BlocListener<OcptResourcesExportBloc, OcptResourcesExportState>(
        listener: _onExportStateChanged,
        child: child,
      );

  /// Show the outcome of an export as a SnackBar, then dismiss it.
  void _onExportStateChanged(BuildContext context, OcptResourcesExportState state) {
    final ioNotice = state.ioNotice;
    if (ioNotice == null) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(_ioNoticeMessage(context, ioNotice))));
    context.read<OcptResourcesExportBloc>().add(const OcptResourcesIoNoticeDismissedEvent());
  }

  /// Map [notice] to its localized, user-facing message, mirroring
  /// `OcptShotListViewEffects._ioNoticeMessage`, [OcptResourcesIoNotice.wasShared] included.
  String _ioNoticeMessage(BuildContext context, OcptResourcesIoNotice notice) {
    final tr = Tr.of(context);

    return switch (notice.kind) {
      OcptResourcesIoNoticeKind.xlsxExportSucceeded =>
        notice.wasShared
            ? tr.exportSharedMessage
            : tr.resourcesExportXlsxSuccessMessage(notice.path ?? ""),
      OcptResourcesIoNoticeKind.xlsxExportFailed => tr.resourcesExportXlsxError,
      OcptResourcesIoNoticeKind.contactListExportSucceeded =>
        notice.wasShared
            ? tr.exportSharedMessage
            : tr.resourcesExportContactListSuccessMessage(notice.path ?? ""),
      OcptResourcesIoNoticeKind.contactListExportFailed => tr.resourcesExportContactListError,
    };
  }
}
