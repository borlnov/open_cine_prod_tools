// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart' as ocpt_theme;
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_symbol_shape.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_floor_plan_geometry.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_canvas_painter.dart';

/// The width, in logical pixels, the inline symbol label editor's own text box is drawn at.
const double _labelEditorWidth = 130;

/// The height, in logical pixels, the inline symbol label editor's own text box is drawn at.
const double _labelEditorHeight = 30;

/// The `label` tool's own inline text box, centred under [symbol]'s own footprint (where its drawn
/// label already sits, see `OcptFloorPlanCanvasPainter._paintLabel`), editing its label in place.
///
/// [onChanged] is null while withheld (a read-only preview), which is what makes the field read
/// its value out instead of accepting one, mirroring `OcptShotInspectorField`'s own reading. The
/// internal controller is only ever reset to [value] when the symbol changes (a different symbol
/// is now selected) or [value] genuinely differs from what the controller already holds (an edit
/// landed, or a reload changed the underlying data) — see `OcptShotInspectorField`'s own doc
/// comment for why a rebuild for an unrelated reason must never touch the controller, or the caret
/// jumps mid-typing.
class OcptFloorPlanSymbolLabelEditor extends StatelessWidget {
  /// The symbol whose label is edited.
  final OcptFloorPlanSymbolShape symbol;

  /// The size of the canvas the symbol is placed in.
  final Size canvasSize;

  /// The canvas's current zoom.
  final double zoom;

  /// The canvas's current pan.
  final Offset pan;

  /// The field's current authoritative value.
  final String value;

  /// Called with the field's raw text on every keystroke, or null while withheld.
  final ValueChanged<String>? onChanged;

  /// Class constructor
  const OcptFloorPlanSymbolLabelEditor({
    super.key,
    required this.symbol,
    required this.canvasSize,
    required this.zoom,
    required this.pan,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final centre = ocptFloorPlanScreenPointOf(
      xM: symbol.xM,
      yM: symbol.yM,
      canvasSize: canvasSize,
      zoom: zoom,
      pan: pan,
    );
    final pixelsPerMetre = ocptFloorPlanPixelsPerMetreAt(zoom);
    final heightPx = symbol.heightM * pixelsPerMetre;

    return Positioned(
      left: centre.dx - _labelEditorWidth / 2,
      top: centre.dy + heightPx / 2 + 20,
      width: _labelEditorWidth,
      height: _labelEditorHeight,
      child: _SymbolLabelField(symbolId: symbol.symbolId, value: value, onChanged: onChanged),
    );
  }
}

/// The text box itself, which owns the controller.
class _SymbolLabelField extends StatefulWidget {
  /// The id of the symbol this field edits, used only to detect a symbol switch.
  final String symbolId;

  /// The field's current authoritative value.
  final String value;

  /// Called with the field's raw text on every keystroke, or null while withheld.
  final ValueChanged<String>? onChanged;

  /// Class constructor
  const _SymbolLabelField({required this.symbolId, required this.value, required this.onChanged});

  @override
  State<_SymbolLabelField> createState() => _SymbolLabelFieldState();
}

class _SymbolLabelFieldState extends State<_SymbolLabelField> {
  late final TextEditingController _controller = TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(covariant _SymbolLabelField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.symbolId != oldWidget.symbolId || widget.value != _controller.text) {
      _controller.text = widget.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      elevation: 3,
      borderRadius: BorderRadius.circular(ocpt_theme.ocptRadiusSmall),
      child: TextField(
        controller: _controller,
        enabled: widget.onChanged != null,
        onChanged: widget.onChanged,
        style: theme.textTheme.bodySmall,
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(ocpt_theme.ocptRadiusSmall),
          ),
          hintText: Tr.of(context).shotListFloorPlanSymbolLabelFieldHint,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
