// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';

/// One breakdown prop of a scene, as `OcptElementsService.propsOfScene` builds it — a scene's own
/// `scene_elements` link (category [OcptElementCategory.prop] alone) joined with the `elements`
/// catalogue, resolved down to what the floor plans palette's own props chips need
/// (`docs/plans/storyboard.md`, §10.4).
class OcptScenePropSummary extends Equatable {
  /// The element's own catalogue id.
  final String elementId;

  /// The element's own display name.
  final String name;

  /// The effective quantity: the scene's own `scene_elements.quantity` override when it isn't
  /// empty, the element's own catalogue `elements.quantity` otherwise — empty while neither is
  /// set. A decimal stored as text, for the same reason both columns are.
  final String quantity;

  /// Class constructor
  const OcptScenePropSummary({required this.elementId, required this.name, required this.quantity});

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() => "OcptScenePropSummary(elementId: $elementId, name: $name)";

  /// Object properties
  @override
  List<Object?> get props => [elementId, name, quantity];
}
