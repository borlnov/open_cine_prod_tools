// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/utils/ocpt_role_origin.dart';

void main() {
  group("ocptRoleIsActionDetected", () {
    test("false for a cued role, isFromScreenplay true", () {
      expect(
        ocptRoleIsActionDetected(
          isFromScreenplay: true,
          kind: OcptRoleKind.speaking,
        ),
        isFalse,
      );
    });

    test("true for a silent role reconciled from the action", () {
      expect(
        ocptRoleIsActionDetected(
          isFromScreenplay: true,
          kind: OcptRoleKind.silent,
        ),
        isTrue,
      );
    });

    test(
      "true for a detected role requalified as an extra: the middle row is any non-speaking "
      "kind, not silent alone",
      () {
        expect(
          ocptRoleIsActionDetected(
            isFromScreenplay: true,
            kind: OcptRoleKind.extra,
          ),
          isTrue,
        );
      },
    );

    test("false for a hand-added role, whatever its kind", () {
      for (final kind in OcptRoleKind.values) {
        expect(
          ocptRoleIsActionDetected(isFromScreenplay: false, kind: kind),
          isFalse,
          reason: kind.name,
        );
      }
    });
  });
}
