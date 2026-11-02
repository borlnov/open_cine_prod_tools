// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// A pure Dart parser, serializer and layout-metrics engine for the
/// Fountain screenplay format (https://fountain.io/syntax).
library;

export 'package:fountain_kit/src/layout/fountain_element_layout.dart';
export 'package:fountain_kit/src/layout/fountain_layout_alignment.dart';
export 'package:fountain_kit/src/layout/fountain_layout_metrics.dart';
export 'package:fountain_kit/src/layout/fountain_page_margins.dart';
export 'package:fountain_kit/src/layout/fountain_print_style.dart';
// Only `normalizeCharacterName` is exported from this file: the app's shot-list character
// normalisation must match the one `speakingCharactersOf` already uses, so a shot's character
// name and a screenplay's speaking character compare equal byte-for-byte. The file's other
// helpers (`printableTextsOf`, `characterCueTextOf`, `wordCountOf`, `signCountOf`) stay internal,
// shared only between the two statistics classes.
export 'package:fountain_kit/src/layout/fountain_printable_text.dart' show normalizeCharacterName;
export 'package:fountain_kit/src/layout/fountain_scene_statistics.dart';
export 'package:fountain_kit/src/layout/fountain_screenplay_characters.dart';
export 'package:fountain_kit/src/layout/fountain_script_composer.dart';
export 'package:fountain_kit/src/layout/fountain_script_layout.dart';
export 'package:fountain_kit/src/layout/fountain_script_line.dart';
export 'package:fountain_kit/src/layout/fountain_script_page.dart';
export 'package:fountain_kit/src/layout/fountain_script_statistics.dart';
export 'package:fountain_kit/src/layout/fountain_speaking_characters.dart';
export 'package:fountain_kit/src/models/fountain_block.dart';
export 'package:fountain_kit/src/models/fountain_document.dart';
export 'package:fountain_kit/src/models/fountain_inline_span.dart';
export 'package:fountain_kit/src/models/fountain_inline_style.dart';
export 'package:fountain_kit/src/models/fountain_source_range.dart';
export 'package:fountain_kit/src/models/fountain_styled_run.dart';
export 'package:fountain_kit/src/models/fountain_title_page.dart';
export 'package:fountain_kit/src/models/fountain_title_page_entry.dart';
export 'package:fountain_kit/src/parser/fountain_block_builder.dart';
export 'package:fountain_kit/src/parser/fountain_character_cue.dart';
export 'package:fountain_kit/src/parser/fountain_inline_parser.dart';
export 'package:fountain_kit/src/parser/fountain_line_classifier.dart';
export 'package:fountain_kit/src/parser/fountain_line_type.dart';
export 'package:fountain_kit/src/parser/fountain_parser.dart';
export 'package:fountain_kit/src/serializer/fountain_inline_serializer.dart';
export 'package:fountain_kit/src/serializer/fountain_line_writer.dart';
export 'package:fountain_kit/src/serializer/fountain_serializer.dart';
export 'package:fountain_kit/src/serializer/fountain_title_page_writer.dart';
