// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/models/ocpt_budget_mileage_rate.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_element.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';

/// What the budget mode reads from the project database in one go: the joined snapshot, and the
/// raw catalogues and the set names the views read directly.
class OcptBudgetRead {
  /// The quote, the cash journal, the financing plan, the revenue sharing and the
  /// catering-and-travel pass, joined.
  final OcptBudgetSnapshot snapshot;

  /// Every live role of the project.
  final List<OcptRole> roles;

  /// Every live person of the project's address book.
  final List<OcptPerson> people;

  /// Every live element of the breakdown's own catalogue.
  final List<OcptElement> elements;

  /// Every live mileage rate of the project.
  final List<OcptBudgetMileageRate> mileageRates;

  /// The set name printed under each shooting day, keyed by the day's own id.
  final Map<String, String> logisticsSetNameByDayId;

  /// Class constructor
  const OcptBudgetRead({
    required this.snapshot,
    required this.roles,
    required this.people,
    required this.elements,
    required this.mileageRates,
    required this.logisticsSetNameByDayId,
  });
}
