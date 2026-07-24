// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_fountain_syntax_entry.dart';
import 'package:open_cine_prod_tools/types/ocpt_fountain_syntax_topic.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_preview_layout.dart';

/// The read-only Fountain syntax guide: a scrollable rendering of the whole
/// [ocptFountainSyntaxEntries] table, grouped by [OcptFountainSyntaxSection] in the order the enum
/// declares them.
///
/// Purely static content driven by a `const` table, so this widget takes no constructor
/// parameters beyond `key` and behaves identically regardless of the editor's raw/styled mode or
/// any other surrounding state.
class OcptEditorSyntaxGuidePanel extends StatelessWidget {
  /// Class constructor
  const OcptEditorSyntaxGuidePanel({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final section in OcptFountainSyntaxSection.values) ...[
          Padding(
            padding: EdgeInsets.only(
              top: section == OcptFountainSyntaxSection.values.first ? 0 : 20,
              bottom: 8,
            ),
            child: Text(
              _sectionTitleOf(tr, section),
              style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary),
            ),
          ),
          for (final entry in ocptFountainSyntaxEntries.where((entry) => entry.section == section))
            _OcptSyntaxGuideEntry(entry: entry, tr: tr, theme: theme),
        ],
      ],
    );
  }

  /// The localized header of [section], read from [tr].
  String _sectionTitleOf(Tr tr, OcptFountainSyntaxSection section) => switch (section) {
    OcptFountainSyntaxSection.structure => tr.editorSyntaxGuideStructureSectionTitle,
    OcptFountainSyntaxSection.organisation => tr.editorSyntaxGuideOrganisationSectionTitle,
    OcptFountainSyntaxSection.formatting => tr.editorSyntaxGuideFormattingSectionTitle,
    OcptFountainSyntaxSection.titlePage => tr.editorSyntaxGuideTitlePageSectionTitle,
  };
}

/// One entry of the guide: its title, its Fountain source snippet in a selectable, monospaced
/// block, and its description.
class _OcptSyntaxGuideEntry extends StatelessWidget {
  /// The entry this row documents.
  final OcptFountainSyntaxEntry entry;

  /// The localizations to resolve the entry's title and description from.
  final Tr tr;

  /// The current theme, used for text styles and colors.
  final ThemeData theme;

  /// Class constructor
  const _OcptSyntaxGuideEntry({required this.entry, required this.tr, required this.theme});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(_labelOf(tr, entry.topic), style: theme.textTheme.labelLarge),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(4),
          ),
          child: SelectableText(
            entry.snippetLines.join("\n"),
            style: TextStyle(
              fontFamily: OcptEditorPreviewLayout.fontFamily,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _descriptionOf(tr, entry.topic),
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    ),
  );

  /// The localized title of [topic], read from [tr].
  String _labelOf(Tr tr, OcptFountainSyntaxTopic topic) => switch (topic) {
    OcptFountainSyntaxTopic.sceneHeading => tr.editorBlockTypeSceneHeading,
    OcptFountainSyntaxTopic.action => tr.editorBlockTypeAction,
    OcptFountainSyntaxTopic.character => tr.editorBlockTypeCharacter,
    OcptFountainSyntaxTopic.parenthetical => tr.editorBlockTypeParenthetical,
    OcptFountainSyntaxTopic.dialogue => tr.editorBlockTypeDialogue,
    OcptFountainSyntaxTopic.dualDialogue => tr.editorSyntaxGuideDualDialogueTitle,
    OcptFountainSyntaxTopic.transition => tr.editorBlockTypeTransition,
    OcptFountainSyntaxTopic.centeredText => tr.editorBlockTypeCenteredText,
    OcptFountainSyntaxTopic.lyrics => tr.editorBlockTypeLyrics,
    OcptFountainSyntaxTopic.pageBreak => tr.editorBlockTypePageBreak,
    OcptFountainSyntaxTopic.section => tr.editorBlockTypeSection,
    OcptFountainSyntaxTopic.synopsis => tr.editorBlockTypeSynopsis,
    OcptFountainSyntaxTopic.note => tr.editorSyntaxGuideNoteTitle,
    OcptFountainSyntaxTopic.boneyard => tr.editorSyntaxGuideBoneyardTitle,
    OcptFountainSyntaxTopic.emphasis => tr.editorSyntaxGuideEmphasisTitle,
    OcptFountainSyntaxTopic.titlePage => tr.editorSyntaxGuideTitlePageTitle,
  };

  /// The localized description of [topic], read from [tr].
  String _descriptionOf(Tr tr, OcptFountainSyntaxTopic topic) => switch (topic) {
    OcptFountainSyntaxTopic.sceneHeading => tr.editorSyntaxGuideSceneHeadingDescription,
    OcptFountainSyntaxTopic.action => tr.editorSyntaxGuideActionDescription,
    OcptFountainSyntaxTopic.character => tr.editorSyntaxGuideCharacterDescription,
    OcptFountainSyntaxTopic.parenthetical => tr.editorSyntaxGuideParentheticalDescription,
    OcptFountainSyntaxTopic.dialogue => tr.editorSyntaxGuideDialogueDescription,
    OcptFountainSyntaxTopic.dualDialogue => tr.editorSyntaxGuideDualDialogueDescription,
    OcptFountainSyntaxTopic.transition => tr.editorSyntaxGuideTransitionDescription,
    OcptFountainSyntaxTopic.centeredText => tr.editorSyntaxGuideCenteredTextDescription,
    OcptFountainSyntaxTopic.lyrics => tr.editorSyntaxGuideLyricsDescription,
    OcptFountainSyntaxTopic.pageBreak => tr.editorSyntaxGuidePageBreakDescription,
    OcptFountainSyntaxTopic.section => tr.editorSyntaxGuideSectionDescription,
    OcptFountainSyntaxTopic.synopsis => tr.editorSyntaxGuideSynopsisDescription,
    OcptFountainSyntaxTopic.note => tr.editorSyntaxGuideNoteDescription,
    OcptFountainSyntaxTopic.boneyard => tr.editorSyntaxGuideBoneyardDescription,
    OcptFountainSyntaxTopic.emphasis => tr.editorSyntaxGuideEmphasisDescription,
    OcptFountainSyntaxTopic.titlePage => tr.editorSyntaxGuideTitlePageDescription,
  };
}
