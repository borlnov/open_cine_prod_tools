// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:typed_data';

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

  test('a Uint8List value round-trips as a tagged base64 blob', () {
    final blobStamp = OcptFieldStamp(
      tableName: 'assets',
      rowId: 'asset-1',
      columnName: 'thumbnail',
      value: Uint8List.fromList([0, 1, 2, 254, 255]),
      version: 1,
      deviceId: 'device-1',
    );

    final json = blobStamp.toJson();
    expect(json['value'], {'blobBase64': 'AAEC/v8='});

    final decoded = OcptFieldStamp.fromJson(json);
    expect(decoded.value, isA<Uint8List>());
    expect(decoded, blobStamp);
  });

  test('an empty Uint8List value round-trips too', () {
    final emptyBlobStamp = OcptFieldStamp(
      tableName: 'assets',
      rowId: 'asset-1',
      columnName: 'thumbnail',
      value: Uint8List(0),
      version: 1,
      deviceId: 'device-1',
    );

    expect(OcptFieldStamp.fromJson(emptyBlobStamp.toJson()), emptyBlobStamp);
  });

  test('a plain String value is never mistaken for a tagged blob', () {
    // Even a string that happens to look like the tagged blob's own JSON shape stays a bare JSON
    // string once encoded — `_encodeValue` never wraps anything but a `Uint8List` in an object, so
    // decoding it back never mistakes it for one.
    const stringStamp = OcptFieldStamp(
      tableName: 'locations',
      rowId: 'location-1',
      columnName: 'name',
      value: '{"blobBase64":"not-actually-a-blob"}',
      version: 1,
      deviceId: 'device-1',
    );

    final json = stringStamp.toJson();
    expect(json['value'], isA<String>());
    expect(OcptFieldStamp.fromJson(json), stringStamp);
  });
}
