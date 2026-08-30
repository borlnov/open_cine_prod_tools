// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_changeset.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_field_stamp.dart';

void main() {
  const stamp = OcptFieldStamp(
    tableName: 'locations',
    rowId: 'location-1',
    columnName: 'name',
    value: 'Exterior',
    version: 3,
    deviceId: 'device-1',
  );

  test('a field stamp round-trips through JSON', () {
    expect(OcptFieldStamp.fromJson(stamp.toJson()), stamp);
  });

  test('a changeset round-trips through its encoded bytes', () {
    const changeset = OcptChangeset(fieldStamps: [stamp]);

    expect(OcptChangeset.decode(changeset.encode()), changeset);
  });

  test('an empty changeset round-trips too', () {
    const changeset = OcptChangeset(fieldStamps: []);

    expect(OcptChangeset.decode(changeset.encode()), changeset);
  });

  test('a null value round-trips', () {
    const nullStamp = OcptFieldStamp(
      tableName: 'shots',
      rowId: 'shot-1',
      columnName: 'sceneId',
      value: null,
      version: 1,
      deviceId: 'device-1',
    );

    expect(OcptFieldStamp.fromJson(nullStamp.toJson()), nullStamp);
  });
}
