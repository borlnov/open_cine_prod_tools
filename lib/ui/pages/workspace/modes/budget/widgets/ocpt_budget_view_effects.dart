// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_export_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_export_state.dart';

/// What the budget mode's view blocs ask the screen for, wrapped around the mode: the outcome of an
/// export, as a SnackBar.
///
/// It is dismissed by dispatching the bloc's own dismissal event as soon as it has been shown, so a
/// later emission never raises it twice. The mode bloc's own effects (the dock fractions, the
/// version and package notices) stay with the mode, which owns the dock layout controller they
/// feed.
class OcptBudgetViewEffects extends StatelessWidget {
  /// The mode, which the listener wraps.
  final Widget child;

  /// Class constructor
  const OcptBudgetViewEffects({super.key, required this.child});

  /// Build the budget view effects as a [MultiBlocListener].
  @override
  Widget build(BuildContext context) => MultiBlocListener(
    listeners: [
      BlocListener<OcptBudgetExportBloc, OcptBudgetExportState>(listener: _onExportStateChanged),
    ],
    child: child,
  );

  /// Shows the outcome of an export as a SnackBar, then dismisses it.
  void _onExportStateChanged(BuildContext context, OcptBudgetExportState state) {
    final ioNotice = state.ioNotice;
    if (ioNotice == null) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(_ioNoticeMessage(context, ioNotice))));
    context.read<OcptBudgetExportBloc>().add(const OcptBudgetIoNoticeDismissedEvent());
  }

  /// The SnackBar text for [notice] — mirrors `OcptScheduleMode._ioNoticeMessage`,
  /// `OcptBudgetIoNotice.wasShared` included.
  String _ioNoticeMessage(BuildContext context, OcptBudgetIoNotice notice) {
    final tr = Tr.of(context);

    return switch (notice.kind) {
      OcptBudgetIoNoticeKind.fileExportSucceeded =>
        notice.wasShared
            ? tr.exportSharedMessage
            : tr.budgetExportFileSuccessMessage(notice.path ?? ""),
      OcptBudgetIoNoticeKind.exportFailed => tr.budgetExportError,
    };
  }
}
