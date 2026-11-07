// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_export_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_export_state.dart';

/// What the schedule mode's view blocs ask the screen for, wrapped around the mode: the outcome of
/// an export as a SnackBar.
///
/// It is dismissed by dispatching the bloc's own dismissal event as soon as it has been shown, so a
/// later emission never raises it twice. The mode bloc's own effects (the dock fractions, the
/// version and package notices) stay with the mode, which owns the dock layout controller they
/// feed.
class OcptScheduleViewEffects extends StatelessWidget {
  /// The mode, which the listener wraps.
  final Widget child;

  /// Class constructor
  const OcptScheduleViewEffects({super.key, required this.child});

  /// Build the schedule view effects as a [BlocListener].
  @override
  Widget build(BuildContext context) =>
      BlocListener<OcptScheduleExportBloc, OcptScheduleExportState>(
        listener: _onExportStateChanged,
        child: child,
      );

  /// Show the outcome of an export as a SnackBar, then dismiss it.
  void _onExportStateChanged(BuildContext context, OcptScheduleExportState state) {
    final ioNotice = state.ioNotice;
    if (ioNotice == null) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(_ioNoticeMessage(context, ioNotice))));
    context.read<OcptScheduleExportBloc>().add(const OcptScheduleIoNoticeDismissedEvent());
  }

  /// Map [notice] to its localized, user-facing message.
  ///
  /// The two full-success kinds degrade to the generic "shared" message on mobile
  /// ([OcptScheduleIoNotice.wasShared]): there is no path or folder to name, the run having been
  /// handed to the OS share sheet rather than written to a location the user picked. A **partial**
  /// folder failure keeps naming [OcptScheduleIoNotice.folderPath] even then — a temporary
  /// directory rather than one the user picked — since which files failed still matters more than
  /// where they sat, and that case is rare enough on mobile (a share sheet's own temp storage
  /// failing to write) not to warrant its own wording.
  String _ioNoticeMessage(BuildContext context, OcptScheduleIoNotice notice) {
    final tr = Tr.of(context);

    return switch (notice.kind) {
      OcptScheduleIoNoticeKind.fileExportSucceeded =>
        notice.wasShared
            ? tr.exportSharedMessage
            : tr.scheduleExportFileSuccessMessage(notice.path ?? ""),
      OcptScheduleIoNoticeKind.folderExportSucceeded =>
        notice.wasShared
            ? tr.exportSharedMessage
            : tr.scheduleExportFolderSuccessMessage(
                notice.writtenCount ?? 0,
                notice.folderPath ?? "",
              ),
      OcptScheduleIoNoticeKind.folderExportPartiallySucceeded =>
        tr.scheduleExportFolderPartialMessage(
          notice.writtenCount ?? 0,
          notice.folderPath ?? "",
          notice.failedCount ?? 0,
        ),
      OcptScheduleIoNoticeKind.exportFailed => tr.scheduleExportError,
    };
  }
}
