// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_storyboard_panels_table.dart';
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

/// One mark drawn over a storyboard panel's frame: a movement arrow, a camera-move arrow or a
/// short text label — the fixed vocabulary the storyboard's light annotation layer is limited to,
/// no freehand drawing of any kind (`docs/plans/storyboard.md`, §1).
///
/// One row per mark, rather than one JSON column on the panel: ADR 0010's per-column stamps are
/// what merge two replicas, and a JSON blob would make two people annotating one panel a
/// last-writer-wins over the whole layer (`docs/adr/0031-storyboard-panels-and-floor-plans-in-
/// metres.md`).
@DataClassName('OcptStoryboardAnnotationRow')
class OcptStoryboardAnnotationsTable extends Table {
  /// {@macro open_cine_prod_tools.OcptStoryboardAnnotationsTable}
  @override
  String get tableName => 'storyboard_annotations';

  /// The stable, unique id of this annotation (a UUID).
  TextColumn get id => text()();

  /// The panel this mark is drawn on.
  TextColumn get panelId => text().references(OcptStoryboardPanelsTable, #id)();

  /// What kind of mark this is.
  TextColumn get kind => text().map(const OcptStoryboardAnnotationKindConverter())();

  /// {@macro open_cine_prod_tools.sortKey}
  ///
  /// Orders the marks of one panel, which is also their draw order.
  TextColumn get sortKey => text().withDefault(const Constant(''))();

  /// The first end's X coordinate, **normalised 0..1 to the frame** — a label's anchor point when
  /// [kind] is `OcptStoryboardAnnotationKind.label`, the arrow's tail otherwise. Normalised rather
  /// than in logical pixels, so a replaced image of another size keeps the marks where they were.
  RealColumn get x1 => real()();

  /// The first end's Y coordinate, normalised 0..1 to the frame. See [x1].
  RealColumn get y1 => real()();

  /// The second end's X coordinate, normalised 0..1 to the frame — an arrow's head. Meaningless,
  /// and left at 0, for a label.
  RealColumn get x2 => real()();

  /// The second end's Y coordinate, normalised 0..1 to the frame. See [x2].
  RealColumn get y2 => real()();

  /// The label's text when [kind] is `OcptStoryboardAnnotationKind.label`, or an arrow's optional
  /// caption (`dolly in`).
  ///
  /// Named [labelText] rather than `text` on the Dart side — that identifier would shadow the
  /// inherited `Table.text()` column builder this very declaration calls — but stored as the
  /// column `text`, the same trick `OcptRowFieldVersionsTable.targetTableName` uses for
  /// `table_name`.
  TextColumn get labelText => text().named('text').withDefault(const Constant(''))();

  /// {@macro open_cine_prod_tools.isDeleted}
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  /// {@macro drift.Table.primaryKey}
  @override
  Set<Column> get primaryKey => {id};
}
