// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// A pure Dart parser, serializer and layout-metrics engine for the
/// Fountain screenplay format (https://fountain.io/syntax).
library;

export 'src/layout/fountain_layout_metrics.dart';
export 'src/models/fountain_block.dart';
export 'src/models/fountain_document.dart';
export 'src/models/fountain_inline_span.dart';
export 'src/models/fountain_source_range.dart';
export 'src/models/fountain_styled_run.dart';
export 'src/models/fountain_title_page.dart';
export 'src/parser/fountain_block_builder.dart';
export 'src/parser/fountain_inline_parser.dart';
export 'src/parser/fountain_line_classifier.dart';
export 'src/parser/fountain_parser.dart';
export 'src/serializer/fountain_inline_serializer.dart';
export 'src/serializer/fountain_serializer.dart';
