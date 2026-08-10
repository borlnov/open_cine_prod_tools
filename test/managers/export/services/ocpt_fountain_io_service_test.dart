// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_fountain_io_service.dart';

void main() {
  const service = OcptFountainIoService();

  group('decodeFountainBytes', () {
    test('strips a leading UTF-8 byte-order mark', () {
      final bytes = Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode("INT. HOUSE - DAY")]);

      expect(service.decodeFountainBytes(bytes), "INT. HOUSE - DAY");
    });

    test('normalises CRLF and CR line endings to LF', () {
      final bytes = Uint8List.fromList(utf8.encode("Line one\r\nLine two\rLine three\n"));

      expect(service.decodeFountainBytes(bytes), "Line one\nLine two\nLine three\n");
    });

    test('decodes plain UTF-8 text unchanged', () {
      final bytes = Uint8List.fromList(utf8.encode("INT. CAFÉ - DAY\n"));

      expect(service.decodeFountainBytes(bytes), "INT. CAFÉ - DAY\n");
    });
  });

  group('encodeFountainText', () {
    test('encodes to UTF-8 and appends a trailing newline when missing', () {
      final bytes = service.encodeFountainText("INT. HOUSE - DAY");

      expect(utf8.decode(bytes), "INT. HOUSE - DAY\n");
    });

    test('does not duplicate an already-present trailing newline', () {
      final bytes = service.encodeFountainText("INT. HOUSE - DAY\n");

      expect(utf8.decode(bytes), "INT. HOUSE - DAY\n");
    });

    test('round-trips through decodeFountainBytes', () {
      const original = "Title: My Screenplay\n\nINT. HOUSE - DAY\n\nAction.\n";

      final bytes = service.encodeFountainText(original);
      final decoded = service.decodeFountainBytes(bytes);

      expect(decoded, original);
    });
  });

  group('suggestedProjectName', () {
    test('uses the title page Title entry when there is one', () {
      final name = service.suggestedProjectName(
        fountainText: "Title: The Great Escape\nAuthor: Jane Doe\n\nINT. HOUSE - DAY\n",
        sourceFileName: "draft.fountain",
      );

      expect(name, "The Great Escape");
    });

    test('falls back to the source file base name when there is no title page', () {
      final name = service.suggestedProjectName(
        fountainText: "INT. HOUSE - DAY\n\nAction.\n",
        sourceFileName: "my_movie.fountain",
      );

      expect(name, "my_movie");
    });

    test('sanitises characters illegal in a file name', () {
      final name = service.suggestedProjectName(
        fountainText: 'Title: A/B: The "Sequel"?\n\nINT. HOUSE - DAY\n',
        sourceFileName: "draft.fountain",
      );

      expect(name, "AB The Sequel");
    });

    test('collapses internal whitespace and trims the sanitised name', () {
      final name = service.suggestedProjectName(
        fountainText: "Title:   The    Great   Escape   \n\nINT. HOUSE - DAY\n",
        sourceFileName: "draft.fountain",
      );

      expect(name, "The Great Escape");
    });

    test('falls back to "Screenplay" when nothing usable is left', () {
      final name = service.suggestedProjectName(
        fountainText: 'Title: ///???\n\nINT. HOUSE - DAY\n',
        sourceFileName: "***.fountain",
      );

      expect(name, "Screenplay");
    });

    test('falls back to "Screenplay" when the source file has no usable base name either', () {
      final name = service.suggestedProjectName(
        fountainText: "INT. HOUSE - DAY\n\nAction.\n",
        sourceFileName: "***.fountain",
      );

      expect(name, "Screenplay");
    });
  });

  group('fountainFileName', () {
    test('appends the fountain extension to the project name', () {
      expect(service.fountainFileName(projectName: "My Movie"), "My Movie.fountain");
    });

    test('appends the episode tag last when there is one', () {
      expect(
        service.fountainFileName(projectName: "My Movie", episodeTag: "ep. 2"),
        "My Movie - ep. 2.fountain",
      );
    });
  });
}
