// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_default_provision_poste.dart';

/// Run the tests of [ocptBudgetDefaultProvisionPosteIdOf].
void main() {
  const regiePosteId = "d75aa74c-ed99-494a-bca0-3508b166ec18";

  OcptBudgetPoste poste(String id) => OcptBudgetPoste(
    id: id,
    code: id,
    label: id,
    simpleLabel: null,
    sortKey: id,
    lines: const [],
    estimateToCompleteCents: null,
  );

  group("ocptBudgetDefaultProvisionPosteIdOf", () {
    test("prefers the seeded travel and catering poste while the project still has it", () {
      expect(
        ocptBudgetDefaultProvisionPosteIdOf([poste("first"), poste(regiePosteId)]),
        regiePosteId,
      );
    });

    test("falls back to the first poste once that one was renamed away or deleted", () {
      expect(ocptBudgetDefaultProvisionPosteIdOf([poste("first"), poste("second")]), "first");
    });

    test("answers nothing for a project with no poste at all", () {
      expect(ocptBudgetDefaultProvisionPosteIdOf(const []), isNull);
    });
  });
}
