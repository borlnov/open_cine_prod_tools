// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <benoit.rolandeau@allcircuits.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:fountain_kit/src/parser/fountain_parser.dart';
import 'package:fountain_kit/src/serializer/fountain_serializer.dart';
import 'package:test/test.dart';

const FountainParser _parser = FountainParser();
const FountainSerializer _serializer = FountainSerializer();

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
    });
  }
}
