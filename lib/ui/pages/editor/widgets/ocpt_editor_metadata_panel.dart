// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_dock_field.dart';

/// A missing title-page field's display. A plain punctuation glyph rather than a localized
/// string: it carries no language-specific meaning.
const String _dash = '—';

/// The right dock's metadata tab: the screenplay's title-page fields (title, credit, author,
/// source, draft date, contact), read-only, followed by the script-wide statistics already shown
/// in the editor's status bar. A missing title-page field shows a dash rather than an empty row.
///
/// Editing stays the existing title-page dialog's job: [onEditTitlePage] opens it, through
/// `EditorPage`'s own router-manager call, exactly like the toolbar's "Title page…" overflow
/// entry does. A null [onEditTitlePage] renders no "Edit…" button at all: what this panel reads out
/// is worth showing whether or not it may be changed, which is what makes it usable as-is while a
/// project version is being previewed read-only.
class OcptEditorMetadataPanel extends StatelessWidget {
  /// The screenplay's title page, or null if it has none.
  final FountainTitlePage? titlePage;

  /// The script-wide statistics, already computed for the status bar.
  final FountainScriptStatistics statistics;

  /// Called when the "Edit…" button is clicked, or null when the title page may not be edited —
  /// the button is then not rendered at all.
  final VoidCallback? onEditTitlePage;

  /// Class constructor
  const OcptEditorMetadataPanel({
    super.key,
    required this.titlePage,
    required this.statistics,
    required this.onEditTitlePage,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            tr.editorMetadataTitlePageSectionTitle,
            style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary),
          ),
        ),
        OcptEditorDockField(label: tr.editorTitlePageTitleLabel, value: _displayValueOf('Title')),
        OcptEditorDockField(label: tr.editorTitlePageCreditLabel, value: _displayValueOf('Credit')),
        OcptEditorDockField(label: tr.editorTitlePageAuthorLabel, value: _authorValue),
        OcptEditorDockField(label: tr.editorTitlePageSourceLabel, value: _displayValueOf('Source')),
        OcptEditorDockField(
          label: tr.editorTitlePageDraftDateLabel,
          value: _displayValueOf('Draft date'),
        ),
        OcptEditorDockField(label: tr.editorTitlePageContactLabel, value: _displayValueOf('Contact')),
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 12),
          child: Text(
            tr.editorMetadataStatisticsSectionTitle,
            style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary),
          ),
        ),
        Wrap(
          spacing: 16,
          runSpacing: 4,
          children: [
            Text(tr.editorStatsPages(statistics.pageCount), style: theme.textTheme.bodySmall),
            Text(tr.editorStatsScenes(statistics.sceneCount), style: theme.textTheme.bodySmall),
            Text(
              tr.editorStatsCharacters(statistics.speakingCharacterCount),
              style: theme.textTheme.bodySmall,
            ),
            Text(tr.editorStatsWords(statistics.wordCount), style: theme.textTheme.bodySmall),
            Text(tr.editorStatsSigns(statistics.signCount), style: theme.textTheme.bodySmall),
          ],
        ),
        if (onEditTitlePage != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onEditTitlePage,
              child: Text(tr.editorMetadataEditTitlePageButtonLabel),
            ),
          ),
      ],
    );
  }

  /// [titlePage]'s entry for [key], as its raw joined value (not `FountainTitlePage`'s semantic
  /// getters, which re-split and re-join their source text) — empty when the entry is absent or
  /// itself empty.
  String _rawValueOf(String key) => titlePage?.entry(key)?.joinedValue ?? '';

  /// [key]'s display value: its raw joined value, or a dash when that's empty.
  String _displayValueOf(String key) {
    final value = _rawValueOf(key);
    return value.isEmpty ? _dash : value;
  }

  /// The Author field's display value: the `Author` entry, falling back to the `Authors` spelling
  /// (both accepted on parse), or a dash when neither is present.
  String get _authorValue {
    final author = _rawValueOf('Author');
    if (author.isNotEmpty) {
      return author;
    }
    final authors = _rawValueOf('Authors');
    return authors.isEmpty ? _dash : authors;
  }
}
