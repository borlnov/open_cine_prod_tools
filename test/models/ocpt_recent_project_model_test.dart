// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <benoit.rolandeau@allcircuits.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_recent_project_model.dart';

void main() {
  // OcptRecentProjectModel.fromJson logs through appLogger(), which requires a global manager
  // instance to be set; merely accessing it creates the (otherwise unused) singleton.
  setUpAll(() => OcptGlobalManager.instance);

  group('OcptRecentProjectModel JSON round trip', () {
    test('fromJson(toJson(model)) returns an equal model', () {
      final model = OcptRecentProjectModel(
        path: "/home/user/projects/my_script.ocpt",
        name: "My Script",
        lastOpenedAt: DateTime.utc(2026, 7, 12, 10, 30),
      );

      final roundTripped = OcptRecentProjectModel.fromJson(model.toJson());

      expect(roundTripped, model);
    });

    test('fromJson returns null when a required key is missing', () {
      final json = {
        "path": "/home/user/projects/my_script.ocpt",
        "name": "My Script",
      };

      expect(OcptRecentProjectModel.fromJson(json), isNull);
    });

    test('fromJson returns null when lastOpenedAt is not a valid date', () {
      final json = {
        "path": "/home/user/projects/my_script.ocpt",
        "name": "My Script",
        "lastOpenedAt": "not-a-date",
      };

      expect(OcptRecentProjectModel.fromJson(json), isNull);
    });

    test('copyWith only replaces the given fields', () {
      final model = OcptRecentProjectModel(
        path: "/home/user/projects/my_script.ocpt",
        name: "My Script",
        lastOpenedAt: DateTime.utc(2026, 7, 12, 10, 30),
      );

      final copy = model.copyWith(name: "Renamed Script");

      expect(copy.path, model.path);
      expect(copy.name, "Renamed Script");
      expect(copy.lastOpenedAt, model.lastOpenedAt);
    });
  });
}
