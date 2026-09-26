// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/utils/ocpt_free_file_path.dart';

void main() {
  group("ocptFreeFilePath", () {
    test("returns the plain path when nothing is taken", () {
      final path = ocptFreeFilePath(
        directoryPath: "/projects",
        baseName: "Movie",
        extension: "ocpt",
        exists: (_) => false,
      );

      expect(path, "/projects/Movie.ocpt");
    });

    test("appends ' (2)' when the plain path is already taken", () {
      final taken = {"/projects/Movie.ocpt"};

      final path = ocptFreeFilePath(
        directoryPath: "/projects",
        baseName: "Movie",
        extension: "ocpt",
        exists: taken.contains,
      );

      expect(path, "/projects/Movie (2).ocpt");
    });

    test("keeps counting up past ' (2)' while every candidate is taken", () {
      final taken = {
        "/projects/Movie.ocpt",
        "/projects/Movie (2).ocpt",
        "/projects/Movie (3).ocpt",
      };

      final path = ocptFreeFilePath(
        directoryPath: "/projects",
        baseName: "Movie",
        extension: "ocpt",
        exists: taken.contains,
      );

      expect(path, "/projects/Movie (4).ocpt");
    });

    test("never calls exists again once a free path has been found", () {
      final checked = <String>[];

      final path = ocptFreeFilePath(
        directoryPath: "/projects",
        baseName: "Movie",
        extension: "ocpt",
        exists: (candidate) {
          checked.add(candidate);
          return candidate == "/projects/Movie.ocpt";
        },
      );

      expect(path, "/projects/Movie (2).ocpt");
      expect(checked, ["/projects/Movie.ocpt", "/projects/Movie (2).ocpt"]);
    });
  });
}
