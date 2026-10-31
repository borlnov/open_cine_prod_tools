// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_export_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_export_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_floor_plan_canvas_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_floor_plan_canvas_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_floor_plan_placements_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_floor_plan_placements_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_floor_plan_sets_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_floor_plan_sets_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_inspector_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_inspector_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_storyboard_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_storyboard_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_character_name_picker_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_shot_list_floor_plan_centre.dart';

/// What the shot list mode's view blocs ask the screen for, wrapped around the mode: each bloc's
/// transient write error as a SnackBar, the outcome of an export as one, and the name prompt a
/// freshly placed character symbol asks for.
///
/// Every one of them is dismissed by dispatching the bloc's own dismissal event as soon as it has
/// been shown, so a later emission never raises it twice. The mode bloc's own effects (the dock
/// fractions, the version and package notices) stay with the mode, which owns the dock layout
/// controller they feed.
class OcptShotListViewEffects extends StatelessWidget {
  /// The mode, which every one of those listeners wraps.
  final Widget child;

  /// Class constructor
  const OcptShotListViewEffects({super.key, required this.child});

  @override
  Widget build(BuildContext context) => MultiBlocListener(
    listeners: [
      BlocListener<OcptShotListExportBloc, OcptShotListExportState>(
        listener: _onExportStateChanged,
      ),
      BlocListener<OcptShotListStoryboardBloc, OcptShotListStoryboardState>(
        listener: _onStoryboardStateChanged,
      ),
      BlocListener<OcptShotListInspectorBloc, OcptShotListInspectorState>(
        listener: _onInspectorStateChanged,
      ),
      BlocListener<OcptShotListFloorPlanSetsBloc, OcptShotListFloorPlanSetsState>(
        listener: _onFloorPlanSetsStateChanged,
      ),
      BlocListener<OcptShotListFloorPlanCanvasBloc, OcptShotListFloorPlanCanvasState>(
        listener: _onFloorPlanCanvasStateChanged,
      ),
      BlocListener<OcptShotListFloorPlanPlacementsBloc, OcptShotListFloorPlanPlacementsState>(
        listener: _onFloorPlanPlacementsStateChanged,
      ),
    ],
    child: child,
  );

  /// Shows the transient write error the board raised as a SnackBar, then dismisses it.
  void _onStoryboardStateChanged(BuildContext context, OcptShotListStoryboardState state) {
    if (!state.hasWriteError) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(Tr.of(context).shotListWriteError)));
    context.read<OcptShotListStoryboardBloc>().add(
      const OcptShotListStoryboardWriteErrorDismissedEvent(),
    );
  }

  /// Shows the transient write error the inspector raised as a SnackBar, then dismisses it.
  void _onInspectorStateChanged(BuildContext context, OcptShotListInspectorState state) {
    if (!state.hasWriteError) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(Tr.of(context).shotListWriteError)));
    context.read<OcptShotListInspectorBloc>().add(
      const OcptShotListInspectorWriteErrorDismissedEvent(),
    );
  }

  /// Shows the transient write error the floor plan sets bloc raised as a SnackBar, then dismisses
  /// it.
  void _onFloorPlanSetsStateChanged(BuildContext context, OcptShotListFloorPlanSetsState state) {
    if (!state.hasWriteError) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(Tr.of(context).shotListWriteError)));
    context.read<OcptShotListFloorPlanSetsBloc>().add(
      const OcptShotListFloorPlanSetsWriteErrorDismissedEvent(),
    );
  }

  /// Shows the transient write error the placements bloc raised as a SnackBar, then dismisses it.
  void _onFloorPlanPlacementsStateChanged(
    BuildContext context,
    OcptShotListFloorPlanPlacementsState state,
  ) {
    if (!state.hasWriteError) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(Tr.of(context).shotListWriteError)));
    context.read<OcptShotListFloorPlanPlacementsBloc>().add(
      const OcptShotListFloorPlanPlacementsWriteErrorDismissedEvent(),
    );
  }

  /// Shows the transient write error the floor plan canvas raised as a SnackBar, then dismisses
  /// it, and opens the character name prompt a freshly placed character symbol asks for.
  void _onFloorPlanCanvasStateChanged(
    BuildContext context,
    OcptShotListFloorPlanCanvasState state,
  ) {
    if (state.hasWriteError) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(Tr.of(context).shotListWriteError)));
      context.read<OcptShotListFloorPlanCanvasBloc>().add(
        const OcptShotListFloorPlanCanvasWriteErrorDismissedEvent(),
      );
    }

    final pendingCharacterNamePromptSymbolId = state.pendingCharacterNamePromptSymbolId;
    if (pendingCharacterNamePromptSymbolId != null) {
      context.read<OcptShotListFloorPlanCanvasBloc>().add(
        const OcptShotListFloorPlanCharacterNamePromptDismissedEvent(),
      );
      unawaited(
        _askCharacterName(
          context,
          context.read<OcptShotListBloc>().state,
          pendingCharacterNamePromptSymbolId,
        ),
      );
    }
  }

  /// Shows the outcome of an export as a SnackBar, then dismisses it.
  void _onExportStateChanged(BuildContext context, OcptShotListExportState state) {
    final ioNotice = state.ioNotice;
    if (ioNotice == null) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(_ioNoticeMessage(context, ioNotice))));
    context.read<OcptShotListExportBloc>().add(const OcptShotListIoNoticeDismissedEvent());
  }

  /// Opens `OcptFloorPlanCharacterNamePickerDialog` for the character symbol [symbolId] the bloc
  /// just placed, pre-filled with its own already-assigned
  /// default label ([OcptShotListFloorPlanCentre.symbolLabelValueOf]) and offering the selected shot's
  /// own characters as
  /// one-click picks. Writes the name picked through the very same pending-edit path the inline
  /// label editor rides — but flushed immediately (`OcptShotListFloorPlanPlacementsFieldEditFlushRequestedEvent`)
  /// rather than left to the 2 s debounce, since picking a name from a dialog is already a
  /// deliberate, discrete action. Dismissing the dialog leaves the placement's own default label
  /// untouched.
  Future<void> _askCharacterName(
    BuildContext context,
    OcptShotListState state,
    String symbolId,
  ) async {
    final currentLabel = OcptShotListFloorPlanCentre.symbolLabelValueOf(
      state,
      context.read<OcptShotListFloorPlanPlacementsBloc>().state,
      symbolId,
    );
    final suggestedNames = [
      for (final name in state.selectedShot?.characters ?? const <String>[])
        if (name.isNotEmpty) name,
    ];

    final picked = await OcptFloorPlanCharacterNamePickerDialog.show(
      context,
      initialValue: currentLabel,
      suggestedNames: suggestedNames,
    );
    if (picked == null) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    final placementsBloc = context.read<OcptShotListFloorPlanPlacementsBloc>();
    placementsBloc.add(
      OcptShotListFloorPlanSymbolLabelChangedEvent(symbolId: symbolId, rawValue: picked),
    );
    placementsBloc.add(const OcptShotListFloorPlanPlacementsFieldEditFlushRequestedEvent());
  }

  /// Maps [notice] to its localized, user-facing message.
  ///
  /// A succeeded kind degrades to the generic "shared" message on mobile
  /// ([OcptShotListIoNotice.wasShared]): there is no path to name, the export having been handed to
  /// the OS share sheet rather than written to a location the user picked.
  String _ioNoticeMessage(BuildContext context, OcptShotListIoNotice notice) {
    final tr = Tr.of(context);

    return switch (notice.kind) {
      OcptShotListIoNoticeKind.xlsxExportSucceeded =>
        notice.wasShared
            ? tr.exportSharedMessage
            : tr.shotListExportXlsxSuccessMessage(notice.path ?? ""),
      OcptShotListIoNoticeKind.xlsxExportFailed => tr.shotListExportXlsxError,
      OcptShotListIoNoticeKind.scenarioCoverageExportSucceeded =>
        notice.wasShared
            ? tr.exportSharedMessage
            : tr.shotListExportCoverageSuccessMessage(notice.path ?? ""),
      OcptShotListIoNoticeKind.scenarioCoverageExportFailed => tr.shotListExportCoverageError,
      OcptShotListIoNoticeKind.storyboardExportSucceeded =>
        notice.wasShared
            ? tr.exportSharedMessage
            : tr.shotListExportStoryboardSuccessMessage(notice.path ?? ""),
      OcptShotListIoNoticeKind.storyboardExportFailed => tr.shotListExportStoryboardError,
      OcptShotListIoNoticeKind.floorPlansExportSucceeded =>
        notice.wasShared
            ? tr.exportSharedMessage
            : tr.shotListExportFloorPlansSuccessMessage(notice.path ?? ""),
      OcptShotListIoNoticeKind.floorPlansExportFailed => tr.shotListExportFloorPlansError,
    };
  }
}
