// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:spell_kit/src/hunspell_affix_condition.dart';

/// A single `PFX`/`SFX` rule line: how to turn a dictionary stem into a
/// surface form (or, read the other way round, how affix stripping tries
/// to turn a typed word back into one).
class HunspellAffixRule {
  /// The flag identifying this rule; a dictionary entry must carry it (or
  /// receive it through a continuation class) to accept the rule.
  final String flag;

  /// The text removed from the end (`SFX`) or start (`PFX`) of the
  /// dictionary stem to build the surface form (empty for hunspell's `0`).
  final String strip;

  /// The text added to the end (`SFX`) or start (`PFX`) of the dictionary
  /// stem to build the surface form (empty for hunspell's `0`).
  final String append;

  /// The flags this rule grants to the surface form it builds, in addition
  /// to the base stem's own flags — what lets, for example, a suffix rule
  /// applied with no visible text change still make a prefix flag
  /// available for a cross-product combination.
  final String continuationFlags;

  /// The condition [strip]'s removal (equivalently, the reconstructed
  /// stem) must satisfy.
  final HunspellAffixCondition condition;

  /// Whether this rule may combine with a rule of the other affix kind
  /// (the header line's `Y`/`N`).
  final bool crossProduct;

  /// Creates a [HunspellAffixRule].
  const HunspellAffixRule({
    required this.flag,
    required this.strip,
    required this.append,
    required this.continuationFlags,
    required this.condition,
    required this.crossProduct,
  });
}
