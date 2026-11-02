// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_account.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_default_provision_account.dart';

/// Run the tests of [ocptBudgetDefaultProvisionAccountIdOf].
void main() {
  const logisticsAccountId = "d75aa74c-ed99-494a-bca0-3508b166ec18";

  OcptBudgetAccount account(String id) => OcptBudgetAccount(
    id: id,
    code: id,
    label: id,
    simpleLabel: null,
    sortKey: id,
    lines: const [],
    estimateToCompleteCents: null,
  );

  group("ocptBudgetDefaultProvisionAccountIdOf", () {
    test("prefers the seeded travel and catering poste while the project still has it", () {
      expect(
        ocptBudgetDefaultProvisionAccountIdOf([account("first"), account(logisticsAccountId)]),
        logisticsAccountId,
      );
    });

    test("falls back to the first poste once that one was renamed away or deleted", () {
      expect(ocptBudgetDefaultProvisionAccountIdOf([account("first"), account("second")]), "first");
    });

    test("answers nothing for a project with no poste at all", () {
      expect(ocptBudgetDefaultProvisionAccountIdOf(const []), isNull);
    });
  });
}
