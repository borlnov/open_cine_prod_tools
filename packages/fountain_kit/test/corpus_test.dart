// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:fountain_kit/src/parser/fountain_inline_parser.dart';
import 'package:fountain_kit/src/parser/fountain_parser.dart';
import 'package:fountain_kit/src/serializer/fountain_inline_serializer.dart';
import 'package:fountain_kit/src/serializer/fountain_serializer.dart';
import 'package:test/test.dart';

const FountainParser _parser = FountainParser();
const FountainSerializer _serializer = FountainSerializer();
const FountainInlineParser _inlineParser = FountainInlineParser();
const FountainInlineSerializer _inlineSerializer = FountainInlineSerializer();

/// Lines whose `parseRuns` → `write` round trip is not byte-identical to
/// the original source line, keyed by `"<file name>:<0-based line index>"`,
/// each with a comment explaining why the normalization is accepted.
///
/// Empty by design: every line of every corpus file currently round-trips
/// byte-identically through [FountainInlineParser.parseRuns] and
/// [FountainInlineSerializer.write]. Add an entry here only after
/// confirming the discrepancy is a deliberate, harmless normalization (for
/// example a canonical marker choice), not a bug.
const Map<String, String> _acceptedInlineNormalizations = {};

void main() {
  final corpusDirectory = Directory('test/corpus');
  final corpusFiles =
      corpusDirectory
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.fountain'))
          .toList(growable: false)
        ..sort((a, b) => a.path.compareTo(b.path));

  test('the corpus directory is not empty', () {
    expect(corpusFiles, isNotEmpty);
  });

  for (final file in corpusFiles) {
    group(file.uri.pathSegments.last, () {
      final source = file.readAsStringSync();

      test('parses without throwing', () {
        expect(() => _parser.parse(source), returnsNormally);
      });

      test('produces at least one block', () {
        final document = _parser.parse(source);
        expect(document.blocks, isNotEmpty);
      });

      test('round-trips through the serializer', () {
        final original = _parser.parse(source);
        final rewritten = _serializer.write(original);
        final reparsed = _parser.parse(rewritten);
        expect(reparsed.blocks, original.blocks);
        expect(reparsed.titlePage, original.titlePage);
      });

      test('every line round-trips through parseRuns/write', () {
        final fileName = file.uri.pathSegments.last;
        final lines = source.split('\n');
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          final runs = _inlineParser.parseRuns(line);
          final rewritten = _inlineSerializer.write(runs);
          final accepted = _acceptedInlineNormalizations['$fileName:$i'];
          if (accepted != null) {
            expect(
              rewritten,
              accepted,
              reason: 'line $i ($fileName) has an allow-listed normalization',
            );
          } else {
            expect(
              rewritten,
              line,
              reason:
                  'line $i ($fileName) did not round-trip byte-identically; '
                  'either fix the escaping/serialization or add an explicit, '
                  'justified entry to _acceptedInlineNormalizations',
            );
          }
        }
      });
    });
  }
}
