// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';

/// A word this project's writer has taught the spell checker: typed as-is, once, through
/// `OcptProjectDictionaryService.learnWord` — the right-click "Add to the project's dictionary" and
/// the project settings dialog's add field alike.
///
/// **A table, not a key in `project_info.settingsJson`.** A setting is one value the last writer to
/// save overwrites; a lexicon is a set two writers each grow independently, and once sync lands
/// (`docs/adr/0010-sync-ready-data-model-prerequisites.md`) their two additions have to *merge* —
/// Marie's name learned on one replica and Julien's learned on another must both survive a sync,
/// not have one overwrite the other because they happened to land in the same JSON blob. A row per
/// word, each with its own `id` and its own `row_field_versions` stamps, is what makes that an
/// ordinary merge instead of a special case.
///
/// [word] is stored **as typed**, case included: `OcptProjectDictionaryService` matches it
/// case-insensitively when checking whether a word is already known, but keeps the capitalisation
/// the writer actually used, which is what lets `Marie` cover `marie`'s absence without `MacGuffin`
/// covering `macguffin`.
///
/// No `sortKey`: a project's learned words are an unordered set a writer builds up over the course
/// of a screenplay, never a list they arrange — the same reasoning `OcptRoleEpisodesTable`'s own
/// doc comment gives for a role's episodes. `OcptProjectDictionaryService.loadWords` reads them back
/// sorted by the word itself (case-insensitively), not by an order anybody chose.
@DataClassName('OcptProjectDictionaryWordRow')
class OcptProjectDictionaryWordsTable extends Table {
  /// {@macro open_cine_prod_tools.OcptProjectDictionaryWordsTable}
  @override
  String get tableName => 'project_dictionary_words';

  /// The stable, unique id of this row (a UUID).
  TextColumn get id => text()();

  /// The word, exactly as it was typed when it was learned.
  TextColumn get word => text()();

  /// {@macro open_cine_prod_tools.isDeleted}
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  /// {@macro drift.Table.primaryKey}
  @override
  Set<Column> get primaryKey => {id};
}
