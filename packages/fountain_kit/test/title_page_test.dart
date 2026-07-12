// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <benoit.rolandeau@allcircuits.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:fountain_kit/src/parser/fountain_parser.dart';
import 'package:test/test.dart';

void main() {
  group('absence', () {
    test('a document with no title page has a null titlePage', () {
      final document = const FountainParser().parse(
        'INT. HOUSE - DAY\n\nSome action.\n',
      );
      expect(document.titlePage, isNull);
    });

    test('a leading line with no colon is not mistaken for a title page', () {
      final document = const FountainParser().parse(
        'Just some action to start with.\n',
      );
      expect(document.titlePage, isNull);
    });
  });

  group('single-line values', () {
    test('a simple key: value pair is read back as a single value', () {
      final document = const FountainParser().parse(
        'Title: My Screenplay\n\nINT. HOUSE - DAY\n',
      );
      final titlePage = document.titlePage!;
      expect(titlePage.title, 'My Screenplay');
      expect(titlePage.entry('Title')!.values, ['My Screenplay']);
    });
  });

  group('multi-key title pages', () {
    test('several keys are read in source order', () {
      final document = const FountainParser().parse(
        'Title: My Screenplay\n'
        'Credit: written by\n'
        'Author: Jane Doe\n'
        'Draft date: 7/12/2026\n'
        '\n'
        'INT. HOUSE - DAY\n',
      );
      final titlePage = document.titlePage!;
      expect(titlePage.entries.map((entry) => entry.key), [
        'Title',
        'Credit',
        'Author',
        'Draft date',
      ]);
      expect(titlePage.title, 'My Screenplay');
      expect(titlePage.credit, 'written by');
      expect(titlePage.authors, ['Jane Doe']);
      expect(titlePage.draftDate, '7/12/2026');
    });

    test('Author may list several names', () {
      final document = const FountainParser().parse(
        'Author: Jane Doe and John Smith\n\nINT. HOUSE - DAY\n',
      );
      expect(document.titlePage!.authors, ['Jane Doe', 'John Smith']);
    });
  });

  group('multi-line values', () {
    test("indented continuation lines extend the previous key's value", () {
      final document = const FountainParser().parse(
        'Contact:\n'
        '    Open Cine Prod Tools\n'
        '    123 Reel Street\n'
        '\n'
        'INT. HOUSE - DAY\n',
      );
      final titlePage = document.titlePage!;
      expect(titlePage.contact, ['Open Cine Prod Tools', '123 Reel Street']);
    });

    test(
      'a value that starts on the key line can still continue on indented lines',
      () {
        final document = const FountainParser().parse(
          'Notes: first line\n    second line\n\nINT. HOUSE - DAY\n',
        );
        final entry = document.titlePage!.entry('Notes')!;
        expect(entry.values, ['first line', 'second line']);
        expect(entry.joinedValue, 'first line second line');
      },
    );
  });

  group('body separation', () {
    test('the title page stops at the first blank line', () {
      final document = const FountainParser().parse(
        'Title: My Screenplay\n\nINT. HOUSE - DAY\n\nSome action.\n',
      );
      expect(document.blocks, hasLength(2));
    });

    test(
      'a title page that runs to the end of the source has an empty body',
      () {
        final document = const FountainParser().parse('Title: My Screenplay\n');
        expect(document.titlePage!.title, 'My Screenplay');
        expect(document.blocks, isEmpty);
      },
    );
  });
}
