// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_codec.dart';

/// What the random lines are made of.
const List<String> _tokens = [
  'a',
  'b',
  'x',
  'Y',
  ' ',
  ' ',
  '*',
  '**',
  '_',
  r'\',
  '[[',
  ']]',
  '/*',
  '*/',
];

/// Decode [line] and encode it back.
String _roundTrip(String line) {
  final decoded = OcptWysiwygCodec.decode(line);
  return OcptWysiwygCodec.encode(
    decoded.document,
    trailingBlankLines: decoded.trailingBlankLines,
  ).text;
}

/// Get the letters of [text], sorted.
String _lettersOf(String text) =>
    (text.split('').where((c) => RegExp('[A-Za-z]').hasMatch(c)).toList()..sort()).join();

/// Run the seeded fuzz test of the codec on single random lines.
void main() {
  test('random single lines round trip stably, lose no letter and decode settled', () {
    final random = Random(128);
    final changed = <String>[];
    const count = 2000;

    for (var index = 0; index < count; index++) {
      final line = [
        for (var token = 0; token < 1 + random.nextInt(10); token++)
          _tokens[random.nextInt(_tokens.length)],
      ].join();

      final first = _roundTrip(line);
      expect(_roundTrip(first), first, reason: 'unstable: ${jsonLike(line)}');
      expect(_lettersOf(first), _lettersOf(line), reason: 'letters lost: ${jsonLike(line)}');

      final document = OcptWysiwygCodec.decode(line).document;
      expect(OcptWysiwygCodec.reclassifyRequests(document), isEmpty, reason: jsonLike(line));
      expect(OcptWysiwygCodec.noteAttributionRequests(document), isEmpty, reason: jsonLike(line));
      expect(
        OcptWysiwygCodec.commentAttributionRequests(document),
        isEmpty,
        reason: jsonLike(line),
      );
      expect(OcptWysiwygCodec.sceneNumberRequests(document), isEmpty, reason: jsonLike(line));

      if (first != line) {
        changed.add('${jsonLike(line)} -> ${jsonLike(first)}');
      }
    }

    debugPrint('FUZZ not byte-identical: ${changed.length}/$count');
    changed.take(5).forEach((example) => debugPrint('FUZZ example: $example'));
  });
}

/// Get [text] with its backslashes and line breaks visible.
String jsonLike(String text) => '"${text.replaceAll(r'\', r'\\').replaceAll('\n', r'\n')}"';
