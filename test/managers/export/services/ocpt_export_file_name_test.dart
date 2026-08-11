// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_export_file_name.dart';

void main() {
  group("ocptExportFileNameOf", () {
    test("joins only the project name and the extension when neither segment is given", () {
      expect(
        ocptExportFileNameOf(projectName: "My Movie", extension: "pdf"),
        "My Movie.pdf",
      );
    });

    test("a blank suffix is dropped rather than leaving a dangling separator", () {
      expect(
        ocptExportFileNameOf(projectName: "My Movie", suffix: "   ", extension: "pdf"),
        "My Movie.pdf",
      );
    });

    test("a null episode tag is dropped exactly as a blank one is", () {
      expect(
        ocptExportFileNameOf(projectName: "My Movie", suffix: "breakdown", extension: "pdf"),
        "My Movie - breakdown.pdf",
      );
    });

    test("the suffix and the episode tag are both trimmed and joined, in that order", () {
      expect(
        ocptExportFileNameOf(
          projectName: "My Movie",
          suffix: " breakdown ",
          episodeTag: " ep. 2 ",
          extension: "pdf",
        ),
        "My Movie - breakdown - ep. 2.pdf",
      );
    });

    test("an episode tag with no suffix still lands right before the extension", () {
      expect(
        ocptExportFileNameOf(projectName: "My Movie", episodeTag: "ep. 2", extension: "xlsx"),
        "My Movie - ep. 2.xlsx",
      );
    });
  });
}
