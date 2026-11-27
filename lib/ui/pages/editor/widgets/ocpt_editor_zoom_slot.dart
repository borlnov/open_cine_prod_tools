// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_page_zoom.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_event.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_state.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_zoom_control.dart';

/// The page zoom control of the status bar, wired to the editor bloc: it shows the factor the page
/// is typeset at and sends the zoom the user picks.
///
/// Only the zoom rebuilds it, so a keystroke does not. The minus and plus buttons are withheld at
/// the ends of [OcptPageZoom.steps], through [OcptPageZoom.canStep].
class OcptEditorZoomSlot extends StatelessWidget {
  /// Class constructor
  const OcptEditorZoomSlot({super.key});

  /// Build the zoom slot as a [BlocBuilder].
  @override
  Widget build(BuildContext context) => BlocBuilder<OcptEditorBloc, OcptEditorState>(
    buildWhen: (previous, current) =>
        previous.styledPageZoom != current.styledPageZoom ||
        previous.measuredFitPageZoomFactor != current.measuredFitPageZoomFactor,
    builder: (context, state) {
      final bloc = context.read<OcptEditorBloc>();
      final factor = state.pageZoomFactor;

      return OcptEditorZoomControl(
        factor: factor,
        isFitToWidth: state.styledPageZoom.isFitToWidth,
        onZoomOutRequested: OcptPageZoom.canStep(-1, factor)
            ? () => bloc.add(const OcptEditorPageZoomSteppedEvent(direction: -1))
            : null,
        onZoomInRequested: OcptPageZoom.canStep(1, factor)
            ? () => bloc.add(const OcptEditorPageZoomSteppedEvent(direction: 1))
            : null,
        onZoomSelected: (zoom) => bloc.add(OcptEditorPageZoomSelectedEvent(zoom: zoom)),
      );
    },
  );
}
