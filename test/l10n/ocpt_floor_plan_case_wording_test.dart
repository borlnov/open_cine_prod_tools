// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The two ARB files, read from the repository rather than through the generated `Tr`: this test
/// is about what is *written* in them — both the key names and their values (English side
/// includes its own `@key` metadata, the description/context a plain `grep` would match too) —
/// and the generated class would only ever show the same strings back with no way to name the key
/// that carries one.
const _englishArbPath = 'lib/l10n/intl_en_GB.arb';
const _frenchArbPath = 'lib/l10n/intl_fr.arb';

/// Matches every floor-plan key, including its own `@key` metadata entry on the English side.
bool _isFloorPlanEntry(String key) =>
    key.startsWith('shotListFloorPlan') || key.startsWith('@shotListFloorPlan');

/// Matches "case"/"cases", whatever their capitalisation, on a word boundary — so a word that
/// merely contains it (`staircase`, `décor`) is left alone.
final RegExp _caseWord = RegExp(r'\bcases?\b', caseSensitive: false);

/// Matches "porté"/"portés" — the old « accessoires portés » (worn props) wording, replaced by the
/// bare « Accessoires » per the maintainer's own rename.
final RegExp _porteWord = RegExp(r'\bportés?\b', caseSensitive: false);

void main() {
  test(
    'no floor-plan key name or English string says "case" — the model is a Set',
    () {
      // The floor plan's own room used to be called a "case" (R0 renamed it to "Set" in the store;
      // this pins the same rename in the ARB, which the R3 chrome pass missed for a handful of
      // strings — R3b's own fix).
      final arb = jsonDecode(File(_englishArbPath).readAsStringSync()) as Map<String, dynamic>;

      final offenders = [
        for (final entry in arb.entries)
          if (_isFloorPlanEntry(entry.key))
            if (_caseWord.hasMatch(entry.key) ||
                (entry.value is String && _caseWord.hasMatch(entry.value as String)))
              '${entry.key}: ${entry.value}',
      ];

      expect(
        offenders,
        isEmpty,
        reason: 'these floor-plan ARB entries still say "case" (or "cases") — the floor plan '
            'model is a Set, never a case',
      );
    },
  );

  test('no French floor-plan string says « case » or « portés »', () {
    final arb = jsonDecode(File(_frenchArbPath).readAsStringSync()) as Map<String, dynamic>;

    final caseOffenders = [
      for (final entry in arb.entries)
        if (_isFloorPlanEntry(entry.key))
          if (entry.value case final String value when _caseWord.hasMatch(value))
            '${entry.key}: "$value"',
    ];
    expect(
      caseOffenders,
      isEmpty,
      reason: 'these French floor-plan strings still say « case » — the model is a « décor »',
    );

    final porteOffenders = [
      for (final entry in arb.entries)
        if (_isFloorPlanEntry(entry.key))
          if (entry.value case final String value when _porteWord.hasMatch(value))
            '${entry.key}: "$value"',
    ];
    expect(
      porteOffenders,
      isEmpty,
      reason: 'these French floor-plan strings still say « porté(s) » — renamed to « Accessoires »',
    );
  });
}
