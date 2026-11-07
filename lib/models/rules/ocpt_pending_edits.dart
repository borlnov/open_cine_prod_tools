// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// Get what is left of the typed edits [current] once [written] has reached the database.
///
/// An edit is forgotten only if it still holds the very text that was written: a keystroke typed
/// while the write was in flight replaced it in [current] and has not been written yet, so it stays
/// (and the debounce that its keystroke re-armed will write it). Dropping every key of [written]
/// regardless would lose that keystroke for good.
///
/// Read [current] at the moment of the emit, never before the write: a map taken earlier is exactly
/// the one that does not hold the keystroke.
Map<K, String> ocptPendingEditsAfterWrite<K>({
  required Map<K, String> current,
  required Map<K, String> written,
}) => Map<K, String>.of(current)..removeWhere((key, value) => written[key] == value);
