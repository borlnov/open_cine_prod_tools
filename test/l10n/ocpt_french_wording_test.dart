// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The French ARB file, read from the repository rather than through the generated `Tr`: this test
/// is about what is *written* in it, and the generated class would only ever show the same strings
/// back with no way to name the key that carries one.
const _frenchArbPath = 'lib/l10n/intl_fr.arb';

/// The one French idiom that legitimately keeps the word « scène »: a shot's directing notes.
///
/// « Mise en scène » names the direction of the actors, not a unit of the screenplay, and no other
/// wording says it. Every other occurrence is the mistake this test exists for.
const _misEnSceneKey = 'shotListInspectorNotesSectionTitle';

/// Matches « scène » and « scènes », whatever their capitalisation, on a word boundary — so
/// « scénario » (which is the right word for a screenplay and must stay) is left alone.
final RegExp _sceneWord = RegExp(r'\bscènes?\b', caseSensitive: false);

void main() {
  test('no French string calls a screenplay scene « une scène »', () {
    // In this trade a screenplay's scene is **une séquence** in French; « une scène » names
    // something else entirely (the stage). The code, the ARB keys, the models and the tables all
    // say `scene`, and so does the English UI — this is a rule about the French wording alone, and
    // it has been broken once already, on the element sheet, which is why it is pinned here rather
    // than left to review.
    final arb = jsonDecode(File(_frenchArbPath).readAsStringSync()) as Map<String, dynamic>;

    final offenders = [
      for (final entry in arb.entries)
        // A `@key` entry holds the metadata of the key before it — descriptions and contexts are
        // written in English and are not what this rule is about.
        if (!entry.key.startsWith('@') && entry.key != _misEnSceneKey)
          if (entry.value case final String value when _sceneWord.hasMatch(value))
            '${entry.key}: "$value"',
    ];

    expect(
      offenders,
      isEmpty,
      reason:
          "these French strings say « scène » where a screenplay's scene is « une séquence »; the "
          "only key allowed to keep the word is '$_misEnSceneKey' (« mise en scène »)",
    );
  });

  test('the key allowed to keep the word still says « mise en scène »', () {
    // Guards the exemption itself: if that key is ever reworded, the exemption above must go with
    // it rather than quietly covering a genuine mistake under the same name.
    final arb = jsonDecode(File(_frenchArbPath).readAsStringSync()) as Map<String, dynamic>;

    expect(arb[_misEnSceneKey], contains('mise en scène'));
  });
}
