// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/constants/ocpt_breakdown_palette.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_target.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_target_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';

/// One entry of the breakdown legend and of the palette: an element category, or
/// [OcptBreakdownTargetKind.role]/[OcptBreakdownTargetKind.set] on their own ([OcptElementCategory]
/// null then).
///
/// The same key `OcptBreakdownCategoryLegend`'s own hiding and `OcptBreakdownScriptView`'s
/// highlighting both index by, so the two surfaces always agree on what "one category" means.
typedef OcptBreakdownLegendKey = (OcptBreakdownTargetKind kind, OcptElementCategory? category);

/// The legend key [target] falls under.
OcptBreakdownLegendKey ocptBreakdownLegendKeyOf(OcptBreakdownTarget target) =>
    (target.kind, target.category);

/// One row of `OcptBreakdownCategoryLegend`: its key ([kind]/[category]), its palette [color] and
/// how many distinct targets of the snapshot fall under it.
class OcptBreakdownLegendEntry extends Equatable {
  /// What kind of target this entry is about.
  final OcptBreakdownTargetKind kind;

  /// The element category this entry is about, non-null only when [kind] is
  /// [OcptBreakdownTargetKind.element].
  final OcptElementCategory? category;

  /// This entry's colour, as an ARGB integer — [ocptBreakdownColorOf] applied to [kind]/[category].
  final int color;

  /// The number of distinct targets tagged anywhere in the screenplay that fall under [kind]/
  /// [category].
  final int count;

  /// Class constructor
  const OcptBreakdownLegendEntry({
    required this.kind,
    required this.category,
    required this.color,
    required this.count,
  });

  /// This entry's own legend key: `(kind, category)`.
  OcptBreakdownLegendKey get key => (kind, category);

  /// Object properties
  @override
  List<Object?> get props => [kind, category, color, count];
}

/// The legend rows of [targets] (`OcptBreakdownSnapshot.targets`): one per [OcptBreakdownLegendKey]
/// actually present among them, element categories first — in [OcptElementCategory.values] order —
/// then roles, then sets.
///
/// A key absent from [targets] gets no row: the legend teaches the reader to read *this*
/// screenplay's highlighting, and sixteen rows of which four are used would teach less.
List<OcptBreakdownLegendEntry> ocptBreakdownLegendEntriesOf(List<OcptBreakdownTarget> targets) {
  final counts = <OcptBreakdownLegendKey, int>{};
  for (final target in targets) {
    final key = ocptBreakdownLegendKeyOf(target);
    counts[key] = (counts[key] ?? 0) + 1;
  }

  return [
    for (final category in OcptElementCategory.values)
      if (counts[(OcptBreakdownTargetKind.element, category)] case final count?)
        OcptBreakdownLegendEntry(
          kind: OcptBreakdownTargetKind.element,
          category: category,
          color: ocptBreakdownColorOf(kind: OcptBreakdownTargetKind.element, category: category),
          count: count,
        ),
    if (counts[(OcptBreakdownTargetKind.role, null)] case final count?)
      OcptBreakdownLegendEntry(
        kind: OcptBreakdownTargetKind.role,
        category: null,
        color: ocptBreakdownRoleColor,
        count: count,
      ),
    if (counts[(OcptBreakdownTargetKind.set, null)] case final count?)
      OcptBreakdownLegendEntry(
        kind: OcptBreakdownTargetKind.set,
        category: null,
        color: ocptBreakdownSetColor,
        count: count,
      ),
  ];
}
