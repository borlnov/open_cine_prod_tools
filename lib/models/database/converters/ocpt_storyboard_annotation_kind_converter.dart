// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/types/ocpt_storyboard_annotation_kind.dart';

/// Converts a [OcptStoryboardAnnotationKind] to and from the text stored in the
/// `storyboard_annotations.kind` column.
class OcptStoryboardAnnotationKindConverter
    extends TypeConverter<OcptStoryboardAnnotationKind, String> {
  /// Class constructor
  const OcptStoryboardAnnotationKindConverter();

  /// {@macro drift.TypeConverter.fromSql}
  @override
  OcptStoryboardAnnotationKind fromSql(String fromDb) =>
      OcptStoryboardAnnotationKind.values.byName(fromDb);

  /// {@macro drift.TypeConverter.toSql}
  @override
  String toSql(OcptStoryboardAnnotationKind value) => value.name;
}
