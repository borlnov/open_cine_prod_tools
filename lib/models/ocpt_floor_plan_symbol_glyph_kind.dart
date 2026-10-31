// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/models/ocpt_floor_plan_sheet.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_symbol_shape.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_floor_plan_character_colour.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_layer.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_set_element_shape.dart';

/// Which glyph a symbol shape draws as, derived from its own [OcptFloorPlanSymbolShape.layer] —
/// the one switch [OcptFloorPlanSheet] resolves so neither renderer has to re-derive it from the
/// layer itself: [OcptFloorPlanLayer.characters] → [character], [OcptFloorPlanLayer.cameras] →
/// [camera], [OcptFloorPlanLayer.lights] → [light], and [OcptFloorPlanLayer.set]/`.props` →
/// [setElement].
enum OcptFloorPlanSymbolGlyphKind {
  /// A character's own facing disc, drawn in [OcptFloorPlanSymbolShape.colorArgb] — the colour
  /// [ocptFloorPlanCharacterColourOf] derives from the symbol's own
  /// [OcptFloorPlanSymbolShape.label].
  character,

  /// A camera's own body, lens and, while [OcptFloorPlanSymbolShape.cameraFovWedgeDeg] is set, its
  /// field-of-view wedge.
  camera,

  /// A light/projector's own body and beam.
  light,

  /// A décor primitive — see [OcptFloorPlanSymbolShape.setElementShape] and
  /// [OcptFloorPlanSetElementShape].
  setElement,
}
