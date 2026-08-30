// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/utils/ocpt_sql_column_name.dart';

void main() {
  test('a single-word column name is returned as is', () {
    expect(ocptDartFieldName('id'), 'id');
    expect(ocptDartFieldName('name'), 'name');
  });

  test('a snake_case column name becomes camelCase', () {
    expect(ocptDartFieldName('color_index'), 'colorIndex');
    expect(ocptDartFieldName('address_line1'), 'addressLine1');
    expect(ocptDartFieldName('contact_person_id'), 'contactPersonId');
    expect(ocptDartFieldName('is_deleted'), 'isDeleted');
    expect(ocptDartFieldName('sort_key'), 'sortKey');
  });
}
