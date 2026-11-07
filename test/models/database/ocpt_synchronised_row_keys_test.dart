// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_sql_column_name.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_synchronised_tables.dart';

/// Run the guard tying the JSON keys of every synchronised row to its SQL columns.
///
/// `OcptRowStampService` names a stamp after the `toJson` keys of the row class, while the
/// changeset push and the merge look the stamp's column up by `ocptDartFieldName` of the SQL column
/// name. A column whose Dart getter differs from its SQL name must therefore carry a `@JsonKey`
/// naming the SQL one, or its stamps are refused and the project goes offline for good.
///
/// The keys are read from drift's generated source, since a `toJson` map cannot be listed without a
/// row to call it on and a row cannot be built generically (the enum columns refuse a dummy value).
void main() {
  late String generated;

  setUpAll(() {
    generated = File(
      'lib/generated/models/database/ocpt_project_database.g.dart',
    ).readAsStringSync();
  });

  /// Get the `toJson` keys of the generated row class [rowClass].
  Set<String> jsonKeysOf(String rowClass) {
    final start = generated.indexOf('class $rowClass extends DataClass');
    expect(start, isNonNegative, reason: 'the generated row class $rowClass is not found');
    final toJson = generated.indexOf('Map<String, dynamic> toJson(', start);
    final end = generated.indexOf('};', toJson);

    return {
      for (final match in RegExp(
        r"'(\w+)': serializer\.toJson",
      ).allMatches(generated.substring(toJson, end)))
        match.group(1)!,
    };
  }

  test('every synchronised row serialises under the Dart spelling of its SQL columns', () {
    final database = OcptProjectDatabase.memory();
    addTearDown(database.close);

    final rowClassByTableClass = {
      for (final match in RegExp(r'with\s+TableInfo<\s*(\$\w+),\s*(\w+)\s*>').allMatches(generated))
        match.group(1)!: match.group(2)!,
    };

    final tables = ocptSynchronisedTables(database).toList();
    expect(tables, isNotEmpty);

    for (final table in tables) {
      final rowClass = rowClassByTableClass[table.runtimeType.toString()];
      expect(rowClass, isNotNull, reason: '${table.actualTableName} has no generated row class');

      final columnFieldNames = {
        for (final column in table.$columns) ocptDartFieldName(column.name),
      };

      expect(
        jsonKeysOf(rowClass!),
        columnFieldNames,
        reason:
            '${table.actualTableName}: a column whose Dart name differs from its SQL name needs '
            "a @JsonKey with the SQL spelling, or its stamps can't be pushed or merged",
      );
    }
  });
}
