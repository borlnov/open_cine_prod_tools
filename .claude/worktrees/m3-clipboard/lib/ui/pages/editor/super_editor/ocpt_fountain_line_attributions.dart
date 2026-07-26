// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:fountain_kit/fountain_kit.dart';
import 'package:super_editor/super_editor.dart';

/// Maps every [FountainLineType] to the `NamedAttribution` stored under the `blockType` metadata
/// key of the `ParagraphNode` typesetting that line in the styled editor, and back.
///
/// super_editor's `Stylesheet` selects its rules by a block's `blockType` metadata (see
/// `BlockSelector`), so reusing that existing metadata slot for the Fountain line type lets
/// `OcptFountainEditorStylesheet` style every line purely through stylesheet rules: no custom
/// `ComponentBuilder` is needed, since `Styles.padding`, `Styles.maxWidth`, `Styles.textAlign` and
/// `Styles.textStyle` already apply to any text-based component through this same mechanism.
class OcptFountainLineAttributions {
  /// Private constructor: this class only exposes static members.
  const OcptFountainLineAttributions._();

  /// The `blockType` attribution used for each [FountainLineType].
  static const Map<FountainLineType, NamedAttribution> _attributionsByType = {
    FountainLineType.blank: NamedAttribution("fountainBlank"),
    FountainLineType.pageBreak: NamedAttribution("fountainPageBreak"),
    FountainLineType.section: NamedAttribution("fountainSection"),
    FountainLineType.synopsis: NamedAttribution("fountainSynopsis"),
    FountainLineType.sceneHeading: NamedAttribution("fountainSceneHeading"),
    FountainLineType.transition: NamedAttribution("fountainTransition"),
    FountainLineType.centeredText: NamedAttribution("fountainCenteredText"),
    FountainLineType.lyrics: NamedAttribution("fountainLyrics"),
    FountainLineType.character: NamedAttribution("fountainCharacter"),
    FountainLineType.parenthetical: NamedAttribution("fountainParenthetical"),
    FountainLineType.dialogue: NamedAttribution("fountainDialogue"),
    FountainLineType.action: NamedAttribution("fountainAction"),
  };

  /// The reverse of [_attributionsByType], keyed by the attribution's name, to recover a node's
  /// classified [FountainLineType] back from its stored `blockType` metadata.
  static final Map<String, FountainLineType> _typesByAttributionName = {
    for (final entry in _attributionsByType.entries) entry.value.name: entry.key,
  };

  /// The `blockType` attribution to store for a line classified as [type].
  static NamedAttribution attributionOf(FountainLineType type) => _attributionsByType[type]!;

  /// The [FountainLineType] a node was last classified as, read back from its `blockType`
  /// metadata [value] (as returned by `DocumentNode.getMetadataValue("blockType")`).
  ///
  /// Falls back to [FountainLineType.action] when [value] isn't one of ours (e.g. a brand new
  /// node that hasn't been classified yet), which is also the classifier's own fallback for
  /// unrecognized lines.
  static FountainLineType typeOfAttributionValue(Object? value) =>
      value is NamedAttribution
          ? (_typesByAttributionName[value.name] ?? FountainLineType.action)
          : FountainLineType.action;
}
