// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/breakdown_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/breakdown_export_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/breakdown_export_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/breakdown_tagging_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/breakdown_tagging_state.dart';

/// What the breakdown mode's view blocs ask the screen for, wrapped around the mode: the outcome
/// of an export and the refusal of a tag write, each as a SnackBar.
///
/// Each is dismissed by dispatching the bloc's own dismissal event as soon as it has been shown, so
/// a later emission never raises it twice. The mode bloc's own effects (the dock fractions, the
/// version and package notices) stay with the mode, which owns the dock layout
/// controller and the workspace bloc they feed.
class OcptBreakdownViewEffects extends StatelessWidget {
  /// The mode, which the listener wraps.
  final Widget child;

  /// Class constructor
  const OcptBreakdownViewEffects({super.key, required this.child});

  @override
  Widget build(BuildContext context) => MultiBlocListener(
    listeners: [
      BlocListener<OcptBreakdownExportBloc, OcptBreakdownExportState>(
        listener: _onExportStateChanged,
      ),
      BlocListener<OcptBreakdownTaggingBloc, OcptBreakdownTaggingState>(
        listener: _onTaggingStateChanged,
      ),
    ],
    child: child,
  );

  /// Shows the outcome of an export as a SnackBar, then dismisses it.
  void _onExportStateChanged(BuildContext context, OcptBreakdownExportState state) {
    final ioNotice = state.ioNotice;
    if (ioNotice == null) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(_ioNoticeMessage(context, ioNotice))));
    context.read<OcptBreakdownExportBloc>().add(const OcptBreakdownIoNoticeDismissedEvent());
  }

  /// Shows the refusal of a tag write as a SnackBar, then dismisses it.
  void _onTaggingStateChanged(BuildContext context, OcptBreakdownTaggingState state) {
    if (!state.hasTagWriteError) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(Tr.of(context).breakdownTagWriteError)));
    context.read<OcptBreakdownTaggingBloc>().add(const OcptBreakdownTagWriteErrorDismissedEvent());
  }

  /// Maps [notice] to its localized, user-facing message, mirroring
  /// `OcptResourcesViewEffects._ioNoticeMessage`, [OcptBreakdownIoNotice.wasShared] included.
  String _ioNoticeMessage(BuildContext context, OcptBreakdownIoNotice notice) {
    final tr = Tr.of(context);

    return switch (notice.kind) {
      OcptBreakdownIoNoticeKind.sheetsExportSucceeded =>
        notice.wasShared
            ? tr.exportSharedMessage
            : tr.breakdownExportSheetsSuccessMessage(notice.path ?? ""),
      OcptBreakdownIoNoticeKind.sheetsExportFailed => tr.breakdownExportSheetsError,
      OcptBreakdownIoNoticeKind.xlsxExportSucceeded =>
        notice.wasShared
            ? tr.exportSharedMessage
            : tr.breakdownExportXlsxSuccessMessage(notice.path ?? ""),
      OcptBreakdownIoNoticeKind.xlsxExportFailed => tr.breakdownExportXlsxError,
    };
  }
}
