// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/models/ocpt_floor_plan_symbol_shape.dart';

/// Which level a symbol's own override marking ([OcptFloorPlanSymbolShape.isOverride],
/// [OcptFloorPlanSymbolShape.isOverriddenOriginalGhost], [OcptFloorPlanSymbolShape
/// .isHiddenOverrideGhost]) belongs to — a scene-scope
/// override replaces a **set-scope** original for one sequence; a shot-scope override replaces a
/// **scene-scope** symbol (a plain prop/furniture, or itself already a sequence-level override)
/// for one shot alone. Only ever set alongside one of those three flags — null otherwise. Purely
/// what a UI reads to word the inspector's own "Changed for this sequence"/"Changed for this
/// shot" and `Restore` labels differently; `OcptFloorPlanSheet.of` never treats the two levels
/// differently beyond which original each replaces.
enum OcptFloorPlanOverrideLevel {
  /// A scene-scope override of a set-scope original.
  sequence,

  /// A shot-scope override of a scene-scope symbol.
  shot,
}
