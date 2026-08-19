// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:uuid/uuid.dart';

/// CRUD over `project_dictionary_words`, the words this project's writer has taught the spell
/// checker — "Add to the project's dictionary" from the styled editor's right-click, and the add
/// field of the project settings page's dictionary dialog alike.
///
/// {@macro open_cine_prod_tools.tombstones}
///
/// Every match against an existing word is **case-insensitive**
/// (`OcptProjectDictionaryWordsTable`'s own doc comment): `Marie` and `marie` are the same entry,
/// so a writer who right-clicks the same name twice, in two different cases, never ends up with two
/// rows for it. What is actually stored is the word **as typed**, case included — matching is
/// case-insensitive, storage is not.
class OcptProjectDictionaryService {
  /// Class constructor
  const OcptProjectDictionaryService();

  /// The live words of this project's dictionary, sorted case-insensitively (ties broken by the
  /// exact text, so the ordering is deterministic), tombstones filtered out.
  Future<List<String>> loadWords({required OcptProjectDatabase database}) async {
    final rows = await database.select(database.ocptProjectDictionaryWordsTable).get();

    final words = [
      for (final row in rows)
        if (!row.isDeleted) row.word,
    ]..sort((a, b) {
      final byLowerCase = a.toLowerCase().compareTo(b.toLowerCase());
      return byLowerCase != 0 ? byLowerCase : a.compareTo(b);
    });

    return words;
  }

  /// Teaches [word] to this project's dictionary, on a user's own "Add to the project's
  /// dictionary" gesture — never on an "Ignore this word" one, which is session-only and reaches
  /// `OcptSpellCheckManager` alone (`docs/plans/screenplay-spell-check.md` §4.4).
  ///
  /// [word] is trimmed first; a blank result is a no-op — there is nothing worth learning. The
  /// existing rows, tombstoned ones included, are then matched **case-insensitively**:
  ///
  /// - a live match means the word is already known, so nothing is written;
  /// - a tombstoned match is **revived** — its [OcptProjectDictionaryWordRow.isDeleted] flipped
  ///   back to false and its [OcptProjectDictionaryWordRow.word] rewritten to the freshly typed
  ///   spelling — rather than inserted a second time, so re-learning a word removed earlier gives
  ///   the lexicon its old row back, not a duplicate one;
  /// - no match at all inserts a fresh row, with a new id and [word] stored exactly as typed.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> learnWord({required OcptProjectDatabase database, required String word}) async {
    if (database.refusesUserWrite("learnWord")) {
      return;
    }

    final trimmedWord = word.trim();
    if (trimmedWord.isEmpty) {
      return;
    }

    final existing = await database.select(database.ocptProjectDictionaryWordsTable).get();
    final loweredWord = trimmedWord.toLowerCase();

    OcptProjectDictionaryWordRow? match;
    for (final row in existing) {
      if (row.word.toLowerCase() == loweredWord) {
        match = row;
        break;
      }
    }

    if (match == null) {
      await database
          .into(database.ocptProjectDictionaryWordsTable)
          .insert(
            OcptProjectDictionaryWordsTableCompanion.insert(
              id: const Uuid().v4(),
              word: trimmedWord,
            ),
          );
      return;
    }

    if (!match.isDeleted) {
      // Already known, live: nothing to do.
      return;
    }

    final matchId = match.id;
    await (database.update(
      database.ocptProjectDictionaryWordsTable,
    )..where((table) => table.id.equals(matchId))).write(
      OcptProjectDictionaryWordsTableCompanion(
        word: Value(trimmedWord),
        isDeleted: const Value(false),
      ),
    );
  }

  /// Removes [word] from this project's dictionary, on a user's own gesture in the project
  /// settings page's dictionary dialog.
  ///
  /// Matches **case-insensitively**, tombstoning every live row it finds — never deleting one.
  ///
  /// {@macro open_cine_prod_tools.tombstones}
  ///
  /// The matching runs in Dart, on rows read back first, rather than through SQLite's own `LOWER`:
  /// that function only folds ASCII by default, which would silently miss an accented match such as
  /// `Séquence`/`séquence` — the exact kind of French word this dictionary exists for.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> unlearnWord({required OcptProjectDatabase database, required String word}) async {
    if (database.refusesUserWrite("unlearnWord")) {
      return;
    }

    final loweredWord = word.trim().toLowerCase();

    final liveMatches = await (database.select(
      database.ocptProjectDictionaryWordsTable,
    )..where((table) => table.isDeleted.equals(false))).get();

    for (final row in liveMatches) {
      if (row.word.toLowerCase() != loweredWord) {
        continue;
      }

      await (database.update(
        database.ocptProjectDictionaryWordsTable,
      )..where((table) => table.id.equals(row.id))).write(
        const OcptProjectDictionaryWordsTableCompanion(isDeleted: Value(true)),
      );
    }
  }
}
