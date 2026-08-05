// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/constants/ocpt_breakdown_palette.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_target.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_target_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_status.dart';
import 'package:open_cine_prod_tools/utils/ocpt_breakdown_legend.dart';

/// Builds an element target of [category] named [name].
OcptBreakdownTarget _buildElementTarget({
  required String id,
  required String name,
  required OcptElementCategory category,
}) => OcptBreakdownTarget(
  kind: OcptBreakdownTargetKind.element,
  id: id,
  name: name,
  category: category,
  status: OcptElementStatus.toFind,
  sceneIds: const [],
  occurrenceCount: 1,
);

/// Builds a role or a set target named [name].
OcptBreakdownTarget _buildTarget({
  required OcptBreakdownTargetKind kind,
  required String id,
  required String name,
}) => OcptBreakdownTarget(
  kind: kind,
  id: id,
  name: name,
  category: null,
  status: null,
  sceneIds: const [],
  occurrenceCount: 1,
);

void main() {
  group("ocptBreakdownLegendKeyOf", () {
    test("an element target's key carries its own category", () {
      final target = _buildElementTarget(id: "el-1", name: "Lamp", category: OcptElementCategory.prop);

      expect(ocptBreakdownLegendKeyOf(target), (OcptBreakdownTargetKind.element, OcptElementCategory.prop));
    });

    test("a role or a set target's key carries no category", () {
      final role = _buildTarget(kind: OcptBreakdownTargetKind.role, id: "role-1", name: "LÉA");
      final set = _buildTarget(kind: OcptBreakdownTargetKind.set, id: "set-1", name: "Kitchen");

      expect(ocptBreakdownLegendKeyOf(role), (OcptBreakdownTargetKind.role, null));
      expect(ocptBreakdownLegendKeyOf(set), (OcptBreakdownTargetKind.set, null));
    });
  });

  group("ocptBreakdownLegendEntriesOf", () {
    test("an empty target list yields no row", () {
      expect(ocptBreakdownLegendEntriesOf(const []), isEmpty);
    });

    test("two targets of the same category count as one entry, sized by their count", () {
      final entries = ocptBreakdownLegendEntriesOf([
        _buildElementTarget(id: "el-1", name: "Lamp", category: OcptElementCategory.prop),
        _buildElementTarget(id: "el-2", name: "Chair", category: OcptElementCategory.prop),
      ]);

      expect(entries, hasLength(1));
      expect(entries.single.kind, OcptBreakdownTargetKind.element);
      expect(entries.single.category, OcptElementCategory.prop);
      expect(entries.single.count, 2);
      expect(
        entries.single.color,
        ocptBreakdownColorOf(kind: OcptBreakdownTargetKind.element, category: OcptElementCategory.prop),
      );
      expect(entries.single.key, (OcptBreakdownTargetKind.element, OcptElementCategory.prop));
    });

    test("a category absent from the targets gets no row", () {
      final entries = ocptBreakdownLegendEntriesOf([
        _buildElementTarget(id: "el-1", name: "Lamp", category: OcptElementCategory.prop),
      ]);

      expect(entries.any((entry) => entry.category == OcptElementCategory.costume), isFalse);
    });

    test("entries are ordered: element categories first, then roles, then sets", () {
      final entries = ocptBreakdownLegendEntriesOf([
        _buildTarget(kind: OcptBreakdownTargetKind.set, id: "set-1", name: "Kitchen"),
        _buildTarget(kind: OcptBreakdownTargetKind.role, id: "role-1", name: "LÉA"),
        _buildElementTarget(id: "el-1", name: "Jacket", category: OcptElementCategory.costume),
        _buildElementTarget(id: "el-2", name: "Lamp", category: OcptElementCategory.prop),
      ]);

      expect(entries.map((entry) => entry.key).toList(), [
        // Element categories keep `OcptElementCategory.values`' own order (prop before costume).
        (OcptBreakdownTargetKind.element, OcptElementCategory.prop),
        (OcptBreakdownTargetKind.element, OcptElementCategory.costume),
        (OcptBreakdownTargetKind.role, null),
        (OcptBreakdownTargetKind.set, null),
      ]);
      expect(entries[2].color, ocptBreakdownRoleColor);
      expect(entries[3].color, ocptBreakdownSetColor);
    });
  });
}
