// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// Join [names] into one readable enumeration: `A`, `A and B`, `A, B and C`.
///
/// Every name but the last two is followed by a comma, the last two are joined by [conjunction]
/// with no comma before it, which is how both English (en_GB) and French write a list. The
/// conjunction is a parameter because this rule is free of any translation: the caller resolves
/// the word. Blank names are dropped and a name repeated is kept once, in the order of its first
/// occurrence, so an empty string is answered when nothing is left.
String ocptJoinNames(List<String> names, String conjunction) {
  final kept = <String>[];
  for (final name in names) {
    final trimmed = name.trim();
    if (trimmed.isNotEmpty && !kept.contains(trimmed)) {
      kept.add(trimmed);
    }
  }

  if (kept.length <= 1) {
    return kept.isEmpty ? "" : kept.first;
  }

  return "${kept.sublist(0, kept.length - 1).join(", ")} $conjunction ${kept.last}";
}
