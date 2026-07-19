// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:fountain_kit/src/models/fountain_source_range.dart';
import 'package:fountain_kit/src/models/fountain_title_page.dart';
import 'package:fountain_kit/src/parser/fountain_parser.dart';
import 'package:fountain_kit/src/serializer/fountain_title_page_writer.dart';
import 'package:test/test.dart';

void main() {
  const writer = FountainTitlePageWriter();
  const parser = FountainParser();

  /// A placeholder range for entries built directly (never read by the writer).
  const _dummyRange = FountainSourceRange(startLine: 0, endLine: 0, startOffset: 0, endOffset: 0);

  group('insert (no existing title page)', () {
    test('prepends a rendered block, followed by a blank line, ahead of the source', () {
      const body = 'INT. HOUSE - DAY\n\nSome action.\n';

      final result = writer.apply(
        source: body,
        existingRange: null,
        entries: const [
          FountainTitlePageEntry(key: 'Title', values: ['My Screenplay'], sourceRange: _dummyRange),
        ],
      );

      expect(result, 'Title: My Screenplay\n\n$body');
      // The body is byte-identical to the original source, from its own first character onward.
      expect(result.substring(result.length - body.length), body);
    });

    test('renders a multi-value entry as indented continuation lines', () {
      const body = 'INT. HOUSE - DAY\n';

      final result = writer.apply(
        source: body,
        existingRange: null,
        entries: const [
          FountainTitlePageEntry(
            key: 'Contact',
            values: ['Open Cine Prod Tools', '123 Reel Street'],
            sourceRange: _dummyRange,
          ),
        ],
      );

      expect(result, 'Contact:\n    Open Cine Prod Tools\n    123 Reel Street\n\n$body');
    });

    test('returns the source unchanged when there is nothing to insert', () {
      const body = 'INT. HOUSE - DAY\n';

      final result = writer.apply(source: body, existingRange: null, entries: const []);

      expect(result, body);
    });
  });

  group('replace (existing title page, new values)', () {
    test('splices the new block in place, leaving the body byte-identical', () {
      const body = 'INT. HOUSE - DAY\n\nSome action.\n';
      const source = 'Title: Old\nCredit: written by\n\n$body';
      final existingRange = parser.parse(source).titlePage!.sourceRange;

      final result = writer.apply(
        source: source,
        existingRange: existingRange,
        entries: const [
          FountainTitlePageEntry(key: 'Title', values: ['New Screenplay'], sourceRange: _dummyRange),
        ],
      );

      expect(result, 'Title: New Screenplay\n\n$body');
      expect(result.substring(result.length - body.length), body);
    });

    test('replacing a single-line title page value keeps a single "Key: value" line', () {
      const body = 'INT. HOUSE - DAY\n';
      const source = 'Title: Old\n\n$body';
      final existingRange = parser.parse(source).titlePage!.sourceRange;

      final result = writer.apply(
        source: source,
        existingRange: existingRange,
        entries: const [
          FountainTitlePageEntry(key: 'Title', values: ['Brand New'], sourceRange: _dummyRange),
        ],
      );

      expect(result, 'Title: Brand New\n\n$body');
    });
  });

  group('remove (existing title page, empty entries list)', () {
    test('drops the title page and the blank separator line, leaving only the body', () {
      const body = 'INT. HOUSE - DAY\n\nSome action.\n';
      const source = 'Title: Old\nCredit: written by\n\n$body';
      final existingRange = parser.parse(source).titlePage!.sourceRange;

      final result = writer.apply(source: source, existingRange: existingRange, entries: const []);

      expect(result, body);
      // The body's own parsed blocks must be exactly what they'd be parsing the body alone.
      expect(parser.parse(result).blocks, parser.parse(body).blocks);
    });

    test('handles a title page that ran all the way to the end of the source', () {
      const source = 'Title: Only\n';
      final existingRange = parser.parse(source).titlePage!.sourceRange;

      final result = writer.apply(source: source, existingRange: existingRange, entries: const []);

      expect(result, '');
      expect(parser.parse(result).blocks, isEmpty);
    });

    test('handles a multi-line title page, leaving the body byte-identical', () {
      const body = 'INT. HOUSE - DAY\n';
      const source = 'Contact:\n    Open Cine Prod Tools\n    123 Reel Street\n\n$body';
      final existingRange = parser.parse(source).titlePage!.sourceRange;

      final result = writer.apply(source: source, existingRange: existingRange, entries: const []);

      expect(result, body);
      expect(parser.parse(result).blocks, parser.parse(body).blocks);
    });
  });
}
