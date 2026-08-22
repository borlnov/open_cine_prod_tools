// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/types/ocpt_asset_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_scene_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_target_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_commitment_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_group_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_revenue_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_day_part_slot.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_source_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_image_rights_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_location_availability_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/types/ocpt_permit_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_candidate_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_day_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_slot_anchor_edge.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:open_cine_prod_tools/utils/ocpt_weekday_mask.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite3;

// The exact `CREATE TABLE` statements drift generated for schema version 1 (captured from
// `ocpt_project_database.g.dart` before the shot list tables were added), used to build a v1
// fixture from scratch rather than through drift itself. Keeping this verbatim, rather than
// reconstructing it from the current table declarations, is what makes this test prove a real
// upgrade path instead of just a fresh `onCreate`.
const _v1Ddl = '''
CREATE TABLE "project_info" ("id" INTEGER NOT NULL DEFAULT 1, "name" TEXT NOT NULL, "created_at" TEXT NOT NULL, "app_version_at_creation" TEXT NOT NULL, "page_format" TEXT NOT NULL, "settings_json" TEXT NULL, PRIMARY KEY ("id"));
CREATE TABLE "screenplays" ("id" TEXT NOT NULL, "title" TEXT NOT NULL, "fountain_text" TEXT NOT NULL DEFAULT '', "updated_at" TEXT NOT NULL, PRIMARY KEY ("id"));
CREATE TABLE "screenplay_snapshots" ("id" TEXT NOT NULL, "screenplay_id" TEXT NOT NULL REFERENCES screenplays (id), "created_at" TEXT NOT NULL, "reason" TEXT NOT NULL, "fountain_text" TEXT NOT NULL, PRIMARY KEY ("id"));
CREATE TABLE "scenes" ("id" TEXT NOT NULL, "screenplay_id" TEXT NOT NULL REFERENCES screenplays (id), "position" INTEGER NOT NULL, "heading" TEXT NOT NULL, "scene_number" TEXT NULL, "char_start" INTEGER NOT NULL, "char_end" INTEGER NOT NULL, PRIMARY KEY ("id"));
''';

// The same, for schema version 2: the v1 tables plus the three shot list ones, all of them still
// without the sync-ready columns version 3 adds (`is_deleted` everywhere, `sort_key` on the two
// ordered tables) and without `row_field_versions`.
const _v2Ddl =
    '''
$_v1Ddl
CREATE TABLE "shots" ("id" TEXT NOT NULL, "screenplay_id" TEXT NOT NULL REFERENCES screenplays (id), "scene_id" TEXT NULL REFERENCES scenes (id), "orphaned_heading" TEXT NULL, "position" INTEGER NOT NULL, "shot_size" TEXT NOT NULL DEFAULT '', "framing" TEXT NOT NULL DEFAULT '', "camera_move" TEXT NOT NULL DEFAULT '', "lens" TEXT NOT NULL DEFAULT '', "recording_format" TEXT NOT NULL DEFAULT '', "estimated_duration_ms" INTEGER NULL, "shooting_day" TEXT NULL, "planned_takes" INTEGER NULL, "sound" TEXT NOT NULL DEFAULT '', "status" TEXT NOT NULL DEFAULT 'toShoot', "difficulty_set" INTEGER NOT NULL DEFAULT 1, "difficulty_camera" INTEGER NOT NULL DEFAULT 1, "difficulty_acting" INTEGER NOT NULL DEFAULT 1, "difficulty_sound" INTEGER NOT NULL DEFAULT 1, "notes" TEXT NOT NULL DEFAULT '', "location_notes" TEXT NOT NULL DEFAULT '', "needs_check" INTEGER NOT NULL DEFAULT 0 CHECK ("needs_check" IN (0, 1)), "check_reason" TEXT NULL, PRIMARY KEY ("id"));
CREATE TABLE "shot_characters" ("shot_id" TEXT NOT NULL REFERENCES shots (id), "character_name" TEXT NOT NULL, "position" INTEGER NOT NULL, PRIMARY KEY ("shot_id", "character_name"));
CREATE TABLE "shot_coverages" ("id" TEXT NOT NULL, "shot_id" TEXT NOT NULL REFERENCES shots (id), "scene_id" TEXT NOT NULL REFERENCES scenes (id), "start_offset" INTEGER NOT NULL, "end_offset" INTEGER NOT NULL, "covered_text_digest" TEXT NOT NULL, PRIMARY KEY ("id"));
''';

// The same, for schema version 3: every table carrying its sync-ready columns (`is_deleted`
// everywhere, `sort_key` on the two ordered tables) and the `row_field_versions` sidecar, but the
// `shots` table still without the `abbreviation` column version 4 adds, and no `project_versions`
// table nor the `project_info.current_version_id` column pointing into it, both of which version 5
// adds.
const _v3Ddl = '''
CREATE TABLE "project_info" ("id" INTEGER NOT NULL DEFAULT 1, "name" TEXT NOT NULL, "created_at" TEXT NOT NULL, "app_version_at_creation" TEXT NOT NULL, "page_format" TEXT NOT NULL, "settings_json" TEXT NULL, PRIMARY KEY ("id"));
CREATE TABLE "screenplays" ("id" TEXT NOT NULL, "title" TEXT NOT NULL, "fountain_text" TEXT NOT NULL DEFAULT '', "updated_at" TEXT NOT NULL, "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "screenplay_snapshots" ("id" TEXT NOT NULL, "screenplay_id" TEXT NOT NULL REFERENCES screenplays (id), "created_at" TEXT NOT NULL, "reason" TEXT NOT NULL, "fountain_text" TEXT NOT NULL, "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "scenes" ("id" TEXT NOT NULL, "screenplay_id" TEXT NOT NULL REFERENCES screenplays (id), "position" INTEGER NOT NULL, "heading" TEXT NOT NULL, "scene_number" TEXT NULL, "char_start" INTEGER NOT NULL, "char_end" INTEGER NOT NULL, "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "shots" ("id" TEXT NOT NULL, "screenplay_id" TEXT NOT NULL REFERENCES screenplays (id), "scene_id" TEXT NULL REFERENCES scenes (id), "orphaned_heading" TEXT NULL, "position" INTEGER NOT NULL, "sort_key" TEXT NOT NULL DEFAULT '', "shot_size" TEXT NOT NULL DEFAULT '', "framing" TEXT NOT NULL DEFAULT '', "camera_move" TEXT NOT NULL DEFAULT '', "lens" TEXT NOT NULL DEFAULT '', "recording_format" TEXT NOT NULL DEFAULT '', "estimated_duration_ms" INTEGER NULL, "shooting_day" TEXT NULL, "planned_takes" INTEGER NULL, "sound" TEXT NOT NULL DEFAULT '', "status" TEXT NOT NULL DEFAULT 'toShoot', "difficulty_set" INTEGER NOT NULL DEFAULT 1, "difficulty_camera" INTEGER NOT NULL DEFAULT 1, "difficulty_acting" INTEGER NOT NULL DEFAULT 1, "difficulty_sound" INTEGER NOT NULL DEFAULT 1, "notes" TEXT NOT NULL DEFAULT '', "location_notes" TEXT NOT NULL DEFAULT '', "needs_check" INTEGER NOT NULL DEFAULT 0 CHECK ("needs_check" IN (0, 1)), "check_reason" TEXT NULL, "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "shot_characters" ("shot_id" TEXT NOT NULL REFERENCES shots (id), "character_name" TEXT NOT NULL, "position" INTEGER NOT NULL, "sort_key" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("shot_id", "character_name"));
CREATE TABLE "shot_coverages" ("id" TEXT NOT NULL, "shot_id" TEXT NOT NULL REFERENCES shots (id), "scene_id" TEXT NOT NULL REFERENCES scenes (id), "start_offset" INTEGER NOT NULL, "end_offset" INTEGER NOT NULL, "covered_text_digest" TEXT NOT NULL, "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "row_field_versions" ("table_name" TEXT NOT NULL, "row_id" TEXT NOT NULL, "column_name" TEXT NOT NULL, "version" INTEGER NOT NULL, "device_id" TEXT NOT NULL, PRIMARY KEY ("table_name", "row_id", "column_name"));
''';

// And for schema version 4: every table of version 3, `shots` gaining the `abbreviation` column at
// the end, where `ALTER TABLE … ADD COLUMN` puts it. This is the shape `v0.1.0-alpha.2` shipped and
// stamped `PRAGMA user_version = 4` into: version 4 belongs to the scenario coverage export's
// abbreviation, and never to the project versions, which land in version 5 whatever the file
// carried before.
const _v4Ddl = '''
CREATE TABLE "project_info" ("id" INTEGER NOT NULL DEFAULT 1, "name" TEXT NOT NULL, "created_at" TEXT NOT NULL, "app_version_at_creation" TEXT NOT NULL, "page_format" TEXT NOT NULL, "settings_json" TEXT NULL, PRIMARY KEY ("id"));
CREATE TABLE "screenplays" ("id" TEXT NOT NULL, "title" TEXT NOT NULL, "fountain_text" TEXT NOT NULL DEFAULT '', "updated_at" TEXT NOT NULL, "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "screenplay_snapshots" ("id" TEXT NOT NULL, "screenplay_id" TEXT NOT NULL REFERENCES screenplays (id), "created_at" TEXT NOT NULL, "reason" TEXT NOT NULL, "fountain_text" TEXT NOT NULL, "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "scenes" ("id" TEXT NOT NULL, "screenplay_id" TEXT NOT NULL REFERENCES screenplays (id), "position" INTEGER NOT NULL, "heading" TEXT NOT NULL, "scene_number" TEXT NULL, "char_start" INTEGER NOT NULL, "char_end" INTEGER NOT NULL, "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "shots" ("id" TEXT NOT NULL, "screenplay_id" TEXT NOT NULL REFERENCES screenplays (id), "scene_id" TEXT NULL REFERENCES scenes (id), "orphaned_heading" TEXT NULL, "position" INTEGER NOT NULL, "sort_key" TEXT NOT NULL DEFAULT '', "shot_size" TEXT NOT NULL DEFAULT '', "framing" TEXT NOT NULL DEFAULT '', "camera_move" TEXT NOT NULL DEFAULT '', "lens" TEXT NOT NULL DEFAULT '', "recording_format" TEXT NOT NULL DEFAULT '', "estimated_duration_ms" INTEGER NULL, "shooting_day" TEXT NULL, "planned_takes" INTEGER NULL, "sound" TEXT NOT NULL DEFAULT '', "status" TEXT NOT NULL DEFAULT 'toShoot', "difficulty_set" INTEGER NOT NULL DEFAULT 1, "difficulty_camera" INTEGER NOT NULL DEFAULT 1, "difficulty_acting" INTEGER NOT NULL DEFAULT 1, "difficulty_sound" INTEGER NOT NULL DEFAULT 1, "notes" TEXT NOT NULL DEFAULT '', "location_notes" TEXT NOT NULL DEFAULT '', "needs_check" INTEGER NOT NULL DEFAULT 0 CHECK ("needs_check" IN (0, 1)), "check_reason" TEXT NULL, "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), "abbreviation" TEXT NOT NULL DEFAULT '', PRIMARY KEY ("id"));
CREATE TABLE "shot_characters" ("shot_id" TEXT NOT NULL REFERENCES shots (id), "character_name" TEXT NOT NULL, "position" INTEGER NOT NULL, "sort_key" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("shot_id", "character_name"));
CREATE TABLE "shot_coverages" ("id" TEXT NOT NULL, "shot_id" TEXT NOT NULL REFERENCES shots (id), "scene_id" TEXT NOT NULL REFERENCES scenes (id), "start_offset" INTEGER NOT NULL, "end_offset" INTEGER NOT NULL, "covered_text_digest" TEXT NOT NULL, "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "row_field_versions" ("table_name" TEXT NOT NULL, "row_id" TEXT NOT NULL, "column_name" TEXT NOT NULL, "version" INTEGER NOT NULL, "device_id" TEXT NOT NULL, PRIMARY KEY ("table_name", "row_id", "column_name"));
''';

// And for schema version 5: `project_versions` created with `content_digest` already declared on
// it (the v4/v5 collision described in `docs/adr/0007-schema-migration-policy.md` was folded into
// a single version 5 rather than shipped as two separate steps), plus `project_info` gaining its
// `current_version_id` pointer. This is the shape `onCreate` produced for every schema version 5
// build (captured through a real `OcptProjectDatabase`, not hand-written, for the same reason the
// column order of every fixture above matters), and it still lacks every resources table version 6
// adds.
const _v5Ddl = '''
CREATE TABLE "project_info" ("id" INTEGER NOT NULL DEFAULT 1, "name" TEXT NOT NULL, "created_at" TEXT NOT NULL, "app_version_at_creation" TEXT NOT NULL, "page_format" TEXT NOT NULL, "settings_json" TEXT NULL, "current_version_id" TEXT NULL REFERENCES project_versions (id), PRIMARY KEY ("id"));
CREATE TABLE "project_versions" ("id" TEXT NOT NULL, "name" TEXT NOT NULL, "note" TEXT NOT NULL DEFAULT '', "created_at" TEXT NOT NULL, "app_version" TEXT NOT NULL, "payload_format" INTEGER NOT NULL, "payload" TEXT NOT NULL, "summary_json" TEXT NOT NULL, "created_by_device_id" TEXT NOT NULL, "content_digest" TEXT NULL, PRIMARY KEY ("id"));
CREATE TABLE "row_field_versions" ("table_name" TEXT NOT NULL, "row_id" TEXT NOT NULL, "column_name" TEXT NOT NULL, "version" INTEGER NOT NULL, "device_id" TEXT NOT NULL, PRIMARY KEY ("table_name", "row_id", "column_name"));
CREATE TABLE "scenes" ("id" TEXT NOT NULL, "screenplay_id" TEXT NOT NULL REFERENCES screenplays (id), "position" INTEGER NOT NULL, "heading" TEXT NOT NULL, "scene_number" TEXT NULL, "char_start" INTEGER NOT NULL, "char_end" INTEGER NOT NULL, "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "screenplay_snapshots" ("id" TEXT NOT NULL, "screenplay_id" TEXT NOT NULL REFERENCES screenplays (id), "created_at" TEXT NOT NULL, "reason" TEXT NOT NULL, "fountain_text" TEXT NOT NULL, "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "screenplays" ("id" TEXT NOT NULL, "title" TEXT NOT NULL, "fountain_text" TEXT NOT NULL DEFAULT '', "updated_at" TEXT NOT NULL, "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "shot_characters" ("shot_id" TEXT NOT NULL REFERENCES shots (id), "character_name" TEXT NOT NULL, "position" INTEGER NOT NULL, "sort_key" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("shot_id", "character_name"));
CREATE TABLE "shot_coverages" ("id" TEXT NOT NULL, "shot_id" TEXT NOT NULL REFERENCES shots (id), "scene_id" TEXT NOT NULL REFERENCES scenes (id), "start_offset" INTEGER NOT NULL, "end_offset" INTEGER NOT NULL, "covered_text_digest" TEXT NOT NULL, "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "shots" ("id" TEXT NOT NULL, "screenplay_id" TEXT NOT NULL REFERENCES screenplays (id), "scene_id" TEXT NULL REFERENCES scenes (id), "orphaned_heading" TEXT NULL, "position" INTEGER NOT NULL, "sort_key" TEXT NOT NULL DEFAULT '', "shot_size" TEXT NOT NULL DEFAULT '', "abbreviation" TEXT NOT NULL DEFAULT '', "framing" TEXT NOT NULL DEFAULT '', "camera_move" TEXT NOT NULL DEFAULT '', "lens" TEXT NOT NULL DEFAULT '', "recording_format" TEXT NOT NULL DEFAULT '', "estimated_duration_ms" INTEGER NULL, "shooting_day" TEXT NULL, "planned_takes" INTEGER NULL, "sound" TEXT NOT NULL DEFAULT '', "status" TEXT NOT NULL DEFAULT 'toShoot', "difficulty_set" INTEGER NOT NULL DEFAULT 1, "difficulty_camera" INTEGER NOT NULL DEFAULT 1, "difficulty_acting" INTEGER NOT NULL DEFAULT 1, "difficulty_sound" INTEGER NOT NULL DEFAULT 1, "notes" TEXT NOT NULL DEFAULT '', "location_notes" TEXT NOT NULL DEFAULT '', "needs_check" INTEGER NOT NULL DEFAULT 0 CHECK ("needs_check" IN (0, 1)), "check_reason" TEXT NULL, "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
''';

// The twelve tables version 6 added on top of [_v5Ddl]: the resources mode as it first shipped,
// with no `location_availabilities` — a location could say when it was free only in the free text
// of its constraints. Captured through a real `OcptProjectDatabase`, like every fixture above.
const _v6ResourcesDdl = '''
CREATE TABLE "people" ("id" TEXT NOT NULL, "sort_key" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), "first_name" TEXT NOT NULL DEFAULT '', "last_name" TEXT NOT NULL DEFAULT '', "email" TEXT NOT NULL DEFAULT '', "phone" TEXT NOT NULL DEFAULT '', "address_line1" TEXT NOT NULL DEFAULT '', "address_line2" TEXT NOT NULL DEFAULT '', "postal_code" TEXT NOT NULL DEFAULT '', "city" TEXT NOT NULL DEFAULT '', "region" TEXT NOT NULL DEFAULT '', "country" TEXT NOT NULL DEFAULT '', "color_index" INTEGER NOT NULL DEFAULT 0, "birth_date" TEXT NULL, "minor_notes" TEXT NOT NULL DEFAULT '', "is_transport_autonomous" INTEGER NULL CHECK ("is_transport_autonomous" IN (0, 1)), "accommodation_notes" TEXT NOT NULL DEFAULT '', "travel_notes" TEXT NOT NULL DEFAULT '', "dietary_notes" TEXT NOT NULL DEFAULT '', "allergies" TEXT NOT NULL DEFAULT '', "measurement_height" TEXT NOT NULL DEFAULT '', "measurement_chest" TEXT NOT NULL DEFAULT '', "measurement_waist" TEXT NOT NULL DEFAULT '', "measurement_hips" TEXT NOT NULL DEFAULT '', "size_top" TEXT NOT NULL DEFAULT '', "size_bottom" TEXT NOT NULL DEFAULT '', "size_shoes" TEXT NOT NULL DEFAULT '', "hmc_notes" TEXT NOT NULL DEFAULT '', "image_rights_status" TEXT NOT NULL DEFAULT 'notApplicable', "image_rights_date" TEXT NULL, "image_rights_asset_id" TEXT NULL REFERENCES assets (id), "photo_asset_id" TEXT NULL REFERENCES assets (id), "notes" TEXT NOT NULL DEFAULT '', PRIMARY KEY ("id"));
CREATE TABLE "person_positions" ("id" TEXT NOT NULL, "person_id" TEXT NOT NULL REFERENCES people (id), "position_id" TEXT NOT NULL DEFAULT '', "custom_label" TEXT NOT NULL DEFAULT '', "sort_key" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "person_skills" ("id" TEXT NOT NULL, "person_id" TEXT NOT NULL REFERENCES people (id), "label" TEXT NOT NULL DEFAULT '', "sort_key" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "person_unavailabilities" ("id" TEXT NOT NULL, "person_id" TEXT NOT NULL REFERENCES people (id), "start_date" TEXT NOT NULL, "end_date" TEXT NOT NULL, "slot" TEXT NOT NULL DEFAULT 'fullDay', "start_minute" INTEGER NULL, "end_minute" INTEGER NULL, "reason" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "roles" ("id" TEXT NOT NULL, "screenplay_id" TEXT NOT NULL REFERENCES screenplays (id), "name" TEXT NOT NULL, "sort_key" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), "person_id" TEXT NULL REFERENCES people (id), "kind" TEXT NOT NULL, "is_from_screenplay" INTEGER NOT NULL DEFAULT 0 CHECK ("is_from_screenplay" IN (0, 1)), "orphaned_name" TEXT NULL, "casting_notes" TEXT NOT NULL DEFAULT '', PRIMARY KEY ("id"));
CREATE TABLE "locations" ("id" TEXT NOT NULL, "name" TEXT NOT NULL, "color_index" INTEGER NOT NULL DEFAULT 0, "address_line1" TEXT NOT NULL DEFAULT '', "address_line2" TEXT NOT NULL DEFAULT '', "postal_code" TEXT NOT NULL DEFAULT '', "city" TEXT NOT NULL DEFAULT '', "region" TEXT NOT NULL DEFAULT '', "country" TEXT NOT NULL DEFAULT '', "latitude" REAL NULL, "longitude" REAL NULL, "contact_person_id" TEXT NULL, "contact_notes" TEXT NOT NULL DEFAULT '', "permit_status" TEXT NOT NULL DEFAULT 'toRequest', "permit_label" TEXT NOT NULL DEFAULT '', "permit_date" TEXT NULL, "permit_asset_id" TEXT NULL, "parking_notes" TEXT NOT NULL DEFAULT '', "power_notes" TEXT NOT NULL DEFAULT '', "facilities_notes" TEXT NOT NULL DEFAULT '', "constraints_notes" TEXT NOT NULL DEFAULT '', "notes" TEXT NOT NULL DEFAULT '', "sort_key" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "sets" ("id" TEXT NOT NULL, "location_id" TEXT NOT NULL REFERENCES locations (id), "code" TEXT NOT NULL DEFAULT '', "name" TEXT NOT NULL, "notes" TEXT NOT NULL DEFAULT '', "sort_key" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "scene_sets" ("id" TEXT NOT NULL, "scene_id" TEXT NOT NULL REFERENCES scenes (id), "set_id" TEXT NOT NULL REFERENCES sets (id), "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "elements" ("id" TEXT NOT NULL, "sort_key" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), "category" TEXT NOT NULL, "sub_category" TEXT NOT NULL DEFAULT '', "name" TEXT NOT NULL, "code" TEXT NOT NULL DEFAULT '', "quantity" TEXT NOT NULL DEFAULT '', "source_kind" TEXT NOT NULL, "owner_person_id" TEXT NULL, "owner_notes" TEXT NOT NULL DEFAULT '', "brought_by_person_id" TEXT NULL, "storage_notes" TEXT NOT NULL DEFAULT '', "is_secured" INTEGER NOT NULL DEFAULT 0 CHECK ("is_secured" IN (0, 1)), "is_ready_for_shoot" INTEGER NOT NULL DEFAULT 0 CHECK ("is_ready_for_shoot" IN (0, 1)), "is_returned" INTEGER NOT NULL DEFAULT 0 CHECK ("is_returned" IN (0, 1)), "cost" INTEGER NULL, "purpose_notes" TEXT NOT NULL DEFAULT '', "notes" TEXT NOT NULL DEFAULT '', "photo_asset_id" TEXT NULL, PRIMARY KEY ("id"));
CREATE TABLE "scene_elements" ("id" TEXT NOT NULL, "scene_id" TEXT NOT NULL REFERENCES scenes (id), "element_id" TEXT NOT NULL REFERENCES elements (id), "quantity" TEXT NOT NULL DEFAULT '', "notes" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "assets" ("id" TEXT NOT NULL, "kind" TEXT NOT NULL, "path" TEXT NOT NULL, "label" TEXT NOT NULL DEFAULT '', "added_at" TEXT NOT NULL, "sort_key" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), "person_id" TEXT NULL, "location_id" TEXT NULL REFERENCES locations (id), "element_id" TEXT NULL REFERENCES elements (id), PRIMARY KEY ("id"));
CREATE TABLE "local_erasures" ("person_id" TEXT NOT NULL REFERENCES people (id), "erased_at" TEXT NOT NULL, PRIMARY KEY ("person_id"));
''';

// The one table version 7 added on top of [_v5Ddl]/[_v6ResourcesDdl]: `location_availabilities`,
// the dated windows during which a location may be shot in. Captured through a real
// `OcptProjectDatabase`, like every fixture above. `project_info` here still lacks
// `currency_code`, which version 8 adds.
const _v7LocationAvailabilitiesDdl = '''
CREATE TABLE "location_availabilities" ("id" TEXT NOT NULL, "location_id" TEXT NOT NULL REFERENCES locations (id), "start_date" TEXT NOT NULL, "end_date" TEXT NOT NULL, "weekdays" INTEGER NOT NULL DEFAULT 127, "slot" TEXT NOT NULL DEFAULT 'fullDay', "start_minute" INTEGER NULL, "end_minute" INTEGER NULL, "kind" TEXT NOT NULL DEFAULT 'available', "note" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
''';

// The one column version 8 added on top of [_v5Ddl]/[_v6ResourcesDdl]/
// [_v7LocationAvailabilitiesDdl]: `project_info.currency_code`. Composed as an
// `ALTER TABLE … ADD COLUMN`, matching what the real migration step does to an existing table —
// `_v5Ddl` already declares the full `CREATE TABLE` for `project_info` without this column, so it
// cannot be redeclared here. `onCreate`'s own statement for a fresh version 8 file instead inlines
// the column right after `page_format`
// (`… "page_format" TEXT NOT NULL, "currency_code" TEXT NOT NULL DEFAULT 'EUR', "settings_json" …`);
// the test compares column sets, not order, so either position is fine.
const _v8CurrencyDdl = '''
ALTER TABLE "project_info" ADD COLUMN "currency_code" TEXT NOT NULL DEFAULT 'EUR';
''';

// The two tables and the one column version 9 added on top of the fixtures above: the breakdown
// pass's own tables, and `elements.status`. The column is composed as an `ALTER TABLE`, for the
// reason [_v8CurrencyDdl] gives — [_v6ResourcesDdl] already declares `elements` without it.
// `sets.code` exists here and is empty, which is exactly the state version 10 fills in.
const _v9BreakdownDdl = '''
CREATE TABLE "breakdown_tags" ("id" TEXT NOT NULL, "scene_id" TEXT NOT NULL REFERENCES scenes (id), "target_kind" TEXT NOT NULL, "element_id" TEXT NULL REFERENCES elements (id), "role_id" TEXT NULL REFERENCES roles (id), "set_id" TEXT NULL REFERENCES sets (id), "start_offset" INTEGER NOT NULL, "end_offset" INTEGER NOT NULL, "tagged_text" TEXT NOT NULL, "needs_check" INTEGER NOT NULL DEFAULT 0 CHECK ("needs_check" IN (0, 1)), "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "scene_breakdowns" ("id" TEXT NOT NULL, "scene_id" TEXT NOT NULL REFERENCES scenes (id), "status" TEXT NOT NULL DEFAULT 'toDo', "notes" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
ALTER TABLE "elements" ADD COLUMN "status" TEXT NOT NULL DEFAULT 'toFind';
''';

// The six tables version 11 added on top of the fixtures above: the schedule mode as it first
// shipped — a slot's own typed `crew_call_minute`/`crew_wrap_minute` and its `cast_call_minute`/
// `cast_wrap_minute` defaults, a crew row's own `call_minute`/`wrap_minute` override, a cast row's
// own `arrival_minute`/`cast_call_minute`/`cast_wrap_minute` override, and `shooting_day_blocks
// .slot_id` still nullable — every one of which schema version 12 reshapes (see
// `_alterScheduleTablesToV12`). No `shooting_day_groups` here: that table doesn't exist before
// version 12.
const _v11ScheduleDdl = '''
CREATE TABLE "shooting_days" ("id" TEXT NOT NULL, "screenplay_id" TEXT NOT NULL REFERENCES screenplays (id), "date" TEXT NOT NULL, "sort_key" TEXT NOT NULL DEFAULT '', "status" TEXT NOT NULL DEFAULT 'planned', "crew_note" TEXT NOT NULL DEFAULT '', "weather_note" TEXT NOT NULL DEFAULT '', "notes" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "shooting_slots" ("id" TEXT NOT NULL, "shooting_day_id" TEXT NOT NULL REFERENCES shooting_days (id), "sort_key" TEXT NOT NULL DEFAULT '', "label" TEXT NOT NULL DEFAULT '', "location_id" TEXT NULL REFERENCES locations (id), "set_id" TEXT NULL REFERENCES sets (id), "crew_call_minute" INTEGER NOT NULL, "crew_wrap_minute" INTEGER NOT NULL, "cast_call_minute" INTEGER NULL, "cast_wrap_minute" INTEGER NULL, "notes" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "shooting_slot_crew" ("id" TEXT NOT NULL, "slot_id" TEXT NOT NULL REFERENCES shooting_slots (id), "sort_key" TEXT NOT NULL DEFAULT '', "person_id" TEXT NOT NULL REFERENCES people (id), "position_id" TEXT NOT NULL DEFAULT '', "custom_label" TEXT NOT NULL DEFAULT '', "call_minute" INTEGER NULL, "wrap_minute" INTEGER NULL, "notes" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "shooting_slot_cast" ("id" TEXT NOT NULL, "slot_id" TEXT NOT NULL REFERENCES shooting_slots (id), "role_id" TEXT NOT NULL REFERENCES roles (id), "sort_key" TEXT NOT NULL DEFAULT '', "arrival_minute" INTEGER NULL, "cast_call_minute" INTEGER NULL, "cast_wrap_minute" INTEGER NULL, "notes" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "shooting_day_blocks" ("id" TEXT NOT NULL, "shooting_day_id" TEXT NOT NULL REFERENCES shooting_days (id), "sort_key" TEXT NOT NULL DEFAULT '', "slot_id" TEXT NULL REFERENCES shooting_slots (id), "kind" TEXT NOT NULL DEFAULT 'shot', "shot_id" TEXT NULL REFERENCES shots (id), "label" TEXT NOT NULL DEFAULT '', "duration_minutes" INTEGER NULL, "anchor_minute" INTEGER NULL, "notes" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "shooting_presences" ("id" TEXT NOT NULL, "shooting_day_id" TEXT NOT NULL REFERENCES shooting_days (id), "person_id" TEXT NOT NULL REFERENCES people (id), "code" TEXT NOT NULL, "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
''';

// The shape schema version 12 left the six schedule tables in, replacing [_v11ScheduleDdl] in full
// (it, not a fragment layered on top of it, since `shooting_slots`/`shooting_day_blocks` are
// reshaped in place rather than gaining a plain new column): `shooting_slots.start_minute` renamed
// from `crew_call_minute`, its three siblings dropped; `shooting_day_blocks.slot_id` made non-null
// and gaining `scene_id`; `shooting_slot_crew`/`shooting_slot_cast` trading their own typed minute
// columns for a nullable `group_id`/`lead_minutes` pair; and `shooting_day_groups`, the table that
// pair pointed at — every one of which schema version 13 undoes (see `_alterScheduleTablesToV13`).
// Captured through a real `OcptProjectDatabase`, like every fixture above.
const _v12ScheduleDdl = '''
CREATE TABLE "shooting_day_blocks" ("id" TEXT NOT NULL, "shooting_day_id" TEXT NOT NULL REFERENCES shooting_days (id), "sort_key" TEXT NOT NULL DEFAULT '', "slot_id" TEXT NOT NULL REFERENCES shooting_slots (id), "kind" TEXT NOT NULL DEFAULT 'shot', "shot_id" TEXT NULL REFERENCES shots (id), "scene_id" TEXT NULL REFERENCES scenes (id), "label" TEXT NOT NULL DEFAULT '', "duration_minutes" INTEGER NULL, "anchor_minute" INTEGER NULL, "notes" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "shooting_day_groups" ("id" TEXT NOT NULL, "shooting_day_id" TEXT NOT NULL REFERENCES shooting_days (id), "sort_key" TEXT NOT NULL DEFAULT '', "label" TEXT NOT NULL DEFAULT '', "lead_minutes" INTEGER NOT NULL DEFAULT 0, "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "shooting_days" ("id" TEXT NOT NULL, "screenplay_id" TEXT NOT NULL REFERENCES screenplays (id), "date" TEXT NOT NULL, "sort_key" TEXT NOT NULL DEFAULT '', "status" TEXT NOT NULL DEFAULT 'planned', "crew_note" TEXT NOT NULL DEFAULT '', "weather_note" TEXT NOT NULL DEFAULT '', "notes" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "shooting_presences" ("id" TEXT NOT NULL, "shooting_day_id" TEXT NOT NULL REFERENCES shooting_days (id), "person_id" TEXT NOT NULL REFERENCES people (id), "code" TEXT NOT NULL, "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "shooting_slot_cast" ("id" TEXT NOT NULL, "slot_id" TEXT NOT NULL REFERENCES shooting_slots (id), "role_id" TEXT NOT NULL REFERENCES roles (id), "sort_key" TEXT NOT NULL DEFAULT '', "group_id" TEXT NULL REFERENCES shooting_day_groups (id), "lead_minutes" INTEGER NULL, "notes" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "shooting_slot_crew" ("id" TEXT NOT NULL, "slot_id" TEXT NOT NULL REFERENCES shooting_slots (id), "sort_key" TEXT NOT NULL DEFAULT '', "person_id" TEXT NOT NULL REFERENCES people (id), "position_id" TEXT NOT NULL DEFAULT '', "custom_label" TEXT NOT NULL DEFAULT '', "group_id" TEXT NULL REFERENCES shooting_day_groups (id), "lead_minutes" INTEGER NULL, "notes" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "shooting_slots" ("id" TEXT NOT NULL, "shooting_day_id" TEXT NOT NULL REFERENCES shooting_days (id), "sort_key" TEXT NOT NULL DEFAULT '', "label" TEXT NOT NULL DEFAULT '', "location_id" TEXT NULL REFERENCES locations (id), "set_id" TEXT NULL REFERENCES sets (id), "start_minute" INTEGER NOT NULL, "notes" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
''';

// The shape schema version 13 left the six schedule tables in, replacing [_v12ScheduleDdl] in
// full: `shooting_day_groups` dropped outright and the `group_id`/`lead_minutes` pair gone from
// `shooting_slot_crew`/`shooting_slot_cast`, everything else exactly as version 12 left it —
// `shooting_slots` still carrying the single `start_minute` schema version 14 replaces with the
// anchored-edge trio (see `_alterScheduleTablesToV14`). Captured through a real
// `OcptProjectDatabase`, like every fixture above.
const _v13ScheduleDdl = '''
CREATE TABLE "shooting_day_blocks" ("id" TEXT NOT NULL, "shooting_day_id" TEXT NOT NULL REFERENCES shooting_days (id), "sort_key" TEXT NOT NULL DEFAULT '', "slot_id" TEXT NOT NULL REFERENCES shooting_slots (id), "kind" TEXT NOT NULL DEFAULT 'shot', "shot_id" TEXT NULL REFERENCES shots (id), "scene_id" TEXT NULL REFERENCES scenes (id), "label" TEXT NOT NULL DEFAULT '', "duration_minutes" INTEGER NULL, "anchor_minute" INTEGER NULL, "notes" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "shooting_days" ("id" TEXT NOT NULL, "screenplay_id" TEXT NOT NULL REFERENCES screenplays (id), "date" TEXT NOT NULL, "sort_key" TEXT NOT NULL DEFAULT '', "status" TEXT NOT NULL DEFAULT 'planned', "crew_note" TEXT NOT NULL DEFAULT '', "weather_note" TEXT NOT NULL DEFAULT '', "notes" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "shooting_presences" ("id" TEXT NOT NULL, "shooting_day_id" TEXT NOT NULL REFERENCES shooting_days (id), "person_id" TEXT NOT NULL REFERENCES people (id), "code" TEXT NOT NULL, "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "shooting_slot_cast" ("id" TEXT NOT NULL, "slot_id" TEXT NOT NULL REFERENCES shooting_slots (id), "role_id" TEXT NOT NULL REFERENCES roles (id), "sort_key" TEXT NOT NULL DEFAULT '', "notes" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "shooting_slot_crew" ("id" TEXT NOT NULL, "slot_id" TEXT NOT NULL REFERENCES shooting_slots (id), "sort_key" TEXT NOT NULL DEFAULT '', "person_id" TEXT NOT NULL REFERENCES people (id), "position_id" TEXT NOT NULL DEFAULT '', "custom_label" TEXT NOT NULL DEFAULT '', "notes" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "shooting_slots" ("id" TEXT NOT NULL, "shooting_day_id" TEXT NOT NULL REFERENCES shooting_days (id), "sort_key" TEXT NOT NULL DEFAULT '', "label" TEXT NOT NULL DEFAULT '', "location_id" TEXT NULL REFERENCES locations (id), "set_id" TEXT NULL REFERENCES sets (id), "start_minute" INTEGER NOT NULL, "notes" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
''';

// The shape schema version 14 left the six schedule tables in: [_v13ScheduleDdl] with
// `shooting_slots`' single `start_minute` replaced by the anchored-edge trio — `anchor_edge`,
// `anchor_minute` and the self-referencing `anchor_slot_id` (see `_alterScheduleTablesToV14`) —
// and the other five untouched. Captured through a real `OcptProjectDatabase`, like every fixture
// above.
const _v14ScheduleDdl = '''
CREATE TABLE "shooting_day_blocks" ("id" TEXT NOT NULL, "shooting_day_id" TEXT NOT NULL REFERENCES shooting_days (id), "sort_key" TEXT NOT NULL DEFAULT '', "slot_id" TEXT NOT NULL REFERENCES shooting_slots (id), "kind" TEXT NOT NULL DEFAULT 'shot', "shot_id" TEXT NULL REFERENCES shots (id), "scene_id" TEXT NULL REFERENCES scenes (id), "label" TEXT NOT NULL DEFAULT '', "duration_minutes" INTEGER NULL, "anchor_minute" INTEGER NULL, "notes" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "shooting_days" ("id" TEXT NOT NULL, "screenplay_id" TEXT NOT NULL REFERENCES screenplays (id), "date" TEXT NOT NULL, "sort_key" TEXT NOT NULL DEFAULT '', "status" TEXT NOT NULL DEFAULT 'planned', "crew_note" TEXT NOT NULL DEFAULT '', "weather_note" TEXT NOT NULL DEFAULT '', "notes" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "shooting_presences" ("id" TEXT NOT NULL, "shooting_day_id" TEXT NOT NULL REFERENCES shooting_days (id), "person_id" TEXT NOT NULL REFERENCES people (id), "code" TEXT NOT NULL, "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "shooting_slot_cast" ("id" TEXT NOT NULL, "slot_id" TEXT NOT NULL REFERENCES shooting_slots (id), "role_id" TEXT NOT NULL REFERENCES roles (id), "sort_key" TEXT NOT NULL DEFAULT '', "notes" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "shooting_slot_crew" ("id" TEXT NOT NULL, "slot_id" TEXT NOT NULL REFERENCES shooting_slots (id), "sort_key" TEXT NOT NULL DEFAULT '', "person_id" TEXT NOT NULL REFERENCES people (id), "position_id" TEXT NOT NULL DEFAULT '', "custom_label" TEXT NOT NULL DEFAULT '', "notes" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "shooting_slots" ("id" TEXT NOT NULL, "shooting_day_id" TEXT NOT NULL REFERENCES shooting_days (id), "sort_key" TEXT NOT NULL DEFAULT '', "label" TEXT NOT NULL DEFAULT '', "location_id" TEXT NULL REFERENCES locations (id), "set_id" TEXT NULL REFERENCES sets (id), "anchor_edge" TEXT NOT NULL DEFAULT 'start', "anchor_minute" INTEGER NULL, "anchor_slot_id" TEXT NULL REFERENCES shooting_slots (id), "notes" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
''';

// The one table version 15 added on top of the fixtures above: `role_elements`, what a role wears,
// carries and is made up with. `people` here still lacks `max_daily_presence_minutes`, which
// version 16 adds. Captured through a real `OcptProjectDatabase`, like every fixture above.
const _v15RoleElementsDdl = '''
CREATE TABLE "role_elements" ("id" TEXT NOT NULL, "role_id" TEXT NOT NULL REFERENCES roles (id), "element_id" TEXT NOT NULL REFERENCES elements (id), "notes" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
''';

// The one column version 16 added on top of the fixtures above: `people.max_daily_presence_minutes`.
// Composed as an `ALTER TABLE`, for the reason [_v8CurrencyDdl] gives — [_v6ResourcesDdl] already
// declares `people` without it.
const _v16MaxDailyPresenceMinutesDdl = '''
ALTER TABLE "people" ADD COLUMN "max_daily_presence_minutes" INTEGER NULL;
''';

// The complete shape schema version 17 left every table in: `screenplays` still without
// `number`/`sort_key` (schema version 18 adds them), `roles` still carrying `screenplay_id`
// (schema version 18 drops it in favour of `role_episodes`, which doesn't exist yet here), and
// `shooting_days` still carrying its own `screenplay_id` too (schema version 18 drops it outright).
// Captured whole, through a real `OcptProjectDatabase`, before schema version 18 existed — rather
// than layered fragment-by-fragment onto `_v5Ddl` the way the shapes above are, since version 17 is
// deep enough into the schedule mode's own reshapes that composing it from every fragment above
// would just be replaying every step above a second time for no extra coverage. This is what
// `'upgraded_from_v17.ocpt'` below is built from, and what the dedicated `a v17 database migrates
// on…` test below uses as its own starting shape.
const _v17Ddl = '''
CREATE TABLE "assets" ("id" TEXT NOT NULL, "kind" TEXT NOT NULL, "path" TEXT NOT NULL, "label" TEXT NOT NULL DEFAULT '', "added_at" TEXT NOT NULL, "sort_key" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), "person_id" TEXT NULL, "location_id" TEXT NULL REFERENCES locations (id), "element_id" TEXT NULL REFERENCES elements (id), "valid_from" TEXT NULL, "valid_until" TEXT NULL, PRIMARY KEY ("id"));
CREATE TABLE "breakdown_tags" ("id" TEXT NOT NULL, "scene_id" TEXT NOT NULL REFERENCES scenes (id), "target_kind" TEXT NOT NULL, "element_id" TEXT NULL REFERENCES elements (id), "role_id" TEXT NULL REFERENCES roles (id), "set_id" TEXT NULL REFERENCES sets (id), "start_offset" INTEGER NOT NULL, "end_offset" INTEGER NOT NULL, "tagged_text" TEXT NOT NULL, "needs_check" INTEGER NOT NULL DEFAULT 0 CHECK ("needs_check" IN (0, 1)), "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "elements" ("id" TEXT NOT NULL, "sort_key" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), "category" TEXT NOT NULL, "sub_category" TEXT NOT NULL DEFAULT '', "name" TEXT NOT NULL, "code" TEXT NOT NULL DEFAULT '', "quantity" TEXT NOT NULL DEFAULT '', "source_kind" TEXT NOT NULL, "owner_person_id" TEXT NULL, "owner_notes" TEXT NOT NULL DEFAULT '', "brought_by_person_id" TEXT NULL, "storage_notes" TEXT NOT NULL DEFAULT '', "status" TEXT NOT NULL DEFAULT 'toFind', "is_secured" INTEGER NOT NULL DEFAULT 0 CHECK ("is_secured" IN (0, 1)), "is_ready_for_shoot" INTEGER NOT NULL DEFAULT 0 CHECK ("is_ready_for_shoot" IN (0, 1)), "is_returned" INTEGER NOT NULL DEFAULT 0 CHECK ("is_returned" IN (0, 1)), "cost" INTEGER NULL, "purpose_notes" TEXT NOT NULL DEFAULT '', "notes" TEXT NOT NULL DEFAULT '', "photo_asset_id" TEXT NULL, PRIMARY KEY ("id"));
CREATE TABLE "local_erasures" ("person_id" TEXT NOT NULL REFERENCES people (id), "erased_at" TEXT NOT NULL, PRIMARY KEY ("person_id"));
CREATE TABLE "location_availabilities" ("id" TEXT NOT NULL, "location_id" TEXT NOT NULL REFERENCES locations (id), "start_date" TEXT NOT NULL, "end_date" TEXT NOT NULL, "weekdays" INTEGER NOT NULL DEFAULT 127, "slot" TEXT NOT NULL DEFAULT 'fullDay', "start_minute" INTEGER NULL, "end_minute" INTEGER NULL, "kind" TEXT NOT NULL DEFAULT 'available', "note" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "locations" ("id" TEXT NOT NULL, "name" TEXT NOT NULL, "color_index" INTEGER NOT NULL DEFAULT 0, "address_line1" TEXT NOT NULL DEFAULT '', "address_line2" TEXT NOT NULL DEFAULT '', "postal_code" TEXT NOT NULL DEFAULT '', "city" TEXT NOT NULL DEFAULT '', "region" TEXT NOT NULL DEFAULT '', "country" TEXT NOT NULL DEFAULT '', "latitude" REAL NULL, "longitude" REAL NULL, "contact_person_id" TEXT NULL, "contact_notes" TEXT NOT NULL DEFAULT '', "permit_status" TEXT NOT NULL DEFAULT 'toRequest', "permit_label" TEXT NOT NULL DEFAULT '', "permit_date" TEXT NULL, "permit_asset_id" TEXT NULL, "parking_notes" TEXT NOT NULL DEFAULT '', "power_notes" TEXT NOT NULL DEFAULT '', "facilities_notes" TEXT NOT NULL DEFAULT '', "constraints_notes" TEXT NOT NULL DEFAULT '', "notes" TEXT NOT NULL DEFAULT '', "sort_key" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "people" ("id" TEXT NOT NULL, "sort_key" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), "first_name" TEXT NOT NULL DEFAULT '', "last_name" TEXT NOT NULL DEFAULT '', "email" TEXT NOT NULL DEFAULT '', "phone" TEXT NOT NULL DEFAULT '', "address_line1" TEXT NOT NULL DEFAULT '', "address_line2" TEXT NOT NULL DEFAULT '', "postal_code" TEXT NOT NULL DEFAULT '', "city" TEXT NOT NULL DEFAULT '', "region" TEXT NOT NULL DEFAULT '', "country" TEXT NOT NULL DEFAULT '', "color_index" INTEGER NOT NULL DEFAULT 0, "birth_date" TEXT NULL, "minor_notes" TEXT NOT NULL DEFAULT '', "max_daily_presence_minutes" INTEGER NULL, "is_transport_autonomous" INTEGER NULL CHECK ("is_transport_autonomous" IN (0, 1)), "accommodation_notes" TEXT NOT NULL DEFAULT '', "travel_notes" TEXT NOT NULL DEFAULT '', "dietary_notes" TEXT NOT NULL DEFAULT '', "allergies" TEXT NOT NULL DEFAULT '', "measurement_height" TEXT NOT NULL DEFAULT '', "measurement_chest" TEXT NOT NULL DEFAULT '', "measurement_waist" TEXT NOT NULL DEFAULT '', "measurement_hips" TEXT NOT NULL DEFAULT '', "size_top" TEXT NOT NULL DEFAULT '', "size_bottom" TEXT NOT NULL DEFAULT '', "size_shoes" TEXT NOT NULL DEFAULT '', "hmc_notes" TEXT NOT NULL DEFAULT '', "image_rights_status" TEXT NOT NULL DEFAULT 'notApplicable', "image_rights_date" TEXT NULL, "image_rights_asset_id" TEXT NULL REFERENCES assets (id), "photo_asset_id" TEXT NULL REFERENCES assets (id), "notes" TEXT NOT NULL DEFAULT '', PRIMARY KEY ("id"));
CREATE TABLE "person_positions" ("id" TEXT NOT NULL, "person_id" TEXT NOT NULL REFERENCES people (id), "position_id" TEXT NOT NULL DEFAULT '', "custom_label" TEXT NOT NULL DEFAULT '', "sort_key" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "person_skills" ("id" TEXT NOT NULL, "person_id" TEXT NOT NULL REFERENCES people (id), "label" TEXT NOT NULL DEFAULT '', "sort_key" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "person_unavailabilities" ("id" TEXT NOT NULL, "person_id" TEXT NOT NULL REFERENCES people (id), "start_date" TEXT NOT NULL, "end_date" TEXT NOT NULL, "slot" TEXT NOT NULL DEFAULT 'fullDay', "start_minute" INTEGER NULL, "end_minute" INTEGER NULL, "reason" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "project_info" ("id" INTEGER NOT NULL DEFAULT 1, "name" TEXT NOT NULL, "created_at" TEXT NOT NULL, "app_version_at_creation" TEXT NOT NULL, "page_format" TEXT NOT NULL, "currency_code" TEXT NOT NULL DEFAULT 'EUR', "settings_json" TEXT NULL, "minimum_rest_minutes" INTEGER NULL, "current_version_id" TEXT NULL REFERENCES project_versions (id), PRIMARY KEY ("id"));
CREATE TABLE "project_versions" ("id" TEXT NOT NULL, "name" TEXT NOT NULL, "note" TEXT NOT NULL DEFAULT '', "created_at" TEXT NOT NULL, "app_version" TEXT NOT NULL, "payload_format" INTEGER NOT NULL, "payload" TEXT NOT NULL, "summary_json" TEXT NOT NULL, "created_by_device_id" TEXT NOT NULL, "content_digest" TEXT NULL, PRIMARY KEY ("id"));
CREATE TABLE "role_elements" ("id" TEXT NOT NULL, "role_id" TEXT NOT NULL REFERENCES roles (id), "element_id" TEXT NOT NULL REFERENCES elements (id), "notes" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "roles" ("id" TEXT NOT NULL, "screenplay_id" TEXT NOT NULL REFERENCES screenplays (id), "name" TEXT NOT NULL, "sort_key" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), "person_id" TEXT NULL REFERENCES people (id), "kind" TEXT NOT NULL, "is_from_screenplay" INTEGER NOT NULL DEFAULT 0 CHECK ("is_from_screenplay" IN (0, 1)), "orphaned_name" TEXT NULL, "casting_notes" TEXT NOT NULL DEFAULT '', PRIMARY KEY ("id"));
CREATE TABLE "row_field_versions" ("table_name" TEXT NOT NULL, "row_id" TEXT NOT NULL, "column_name" TEXT NOT NULL, "version" INTEGER NOT NULL, "device_id" TEXT NOT NULL, PRIMARY KEY ("table_name", "row_id", "column_name"));
CREATE TABLE "scene_breakdowns" ("id" TEXT NOT NULL, "scene_id" TEXT NOT NULL REFERENCES scenes (id), "status" TEXT NOT NULL DEFAULT 'toDo', "notes" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "scene_elements" ("id" TEXT NOT NULL, "scene_id" TEXT NOT NULL REFERENCES scenes (id), "element_id" TEXT NOT NULL REFERENCES elements (id), "quantity" TEXT NOT NULL DEFAULT '', "notes" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "scene_sets" ("id" TEXT NOT NULL, "scene_id" TEXT NOT NULL REFERENCES scenes (id), "set_id" TEXT NOT NULL REFERENCES sets (id), "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "scenes" ("id" TEXT NOT NULL, "screenplay_id" TEXT NOT NULL REFERENCES screenplays (id), "position" INTEGER NOT NULL, "heading" TEXT NOT NULL, "scene_number" TEXT NULL, "char_start" INTEGER NOT NULL, "char_end" INTEGER NOT NULL, "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "screenplay_snapshots" ("id" TEXT NOT NULL, "screenplay_id" TEXT NOT NULL REFERENCES screenplays (id), "created_at" TEXT NOT NULL, "reason" TEXT NOT NULL, "fountain_text" TEXT NOT NULL, "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "screenplays" ("id" TEXT NOT NULL, "title" TEXT NOT NULL, "fountain_text" TEXT NOT NULL DEFAULT '', "updated_at" TEXT NOT NULL, "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "sets" ("id" TEXT NOT NULL, "location_id" TEXT NOT NULL REFERENCES locations (id), "code" TEXT NOT NULL DEFAULT '', "name" TEXT NOT NULL, "notes" TEXT NOT NULL DEFAULT '', "sort_key" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "shooting_day_blocks" ("id" TEXT NOT NULL, "shooting_day_id" TEXT NOT NULL REFERENCES shooting_days (id), "sort_key" TEXT NOT NULL DEFAULT '', "slot_id" TEXT NOT NULL REFERENCES shooting_slots (id), "kind" TEXT NOT NULL DEFAULT 'shot', "shot_id" TEXT NULL REFERENCES shots (id), "scene_id" TEXT NULL REFERENCES scenes (id), "label" TEXT NOT NULL DEFAULT '', "duration_minutes" INTEGER NULL, "anchor_minute" INTEGER NULL, "notes" TEXT NOT NULL DEFAULT '', "crew_note" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "shooting_day_events" ("id" TEXT NOT NULL, "shooting_day_id" TEXT NOT NULL REFERENCES shooting_days (id), "minute" INTEGER NOT NULL, "label" TEXT NOT NULL DEFAULT '', "notes" TEXT NOT NULL DEFAULT '', "sort_key" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "shooting_days" ("id" TEXT NOT NULL, "screenplay_id" TEXT NOT NULL REFERENCES screenplays (id), "date" TEXT NOT NULL, "sort_key" TEXT NOT NULL DEFAULT '', "status" TEXT NOT NULL DEFAULT 'planned', "crew_note" TEXT NOT NULL DEFAULT '', "weather_note" TEXT NOT NULL DEFAULT '', "notes" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "shooting_slot_cast" ("id" TEXT NOT NULL, "slot_id" TEXT NOT NULL REFERENCES shooting_slots (id), "role_id" TEXT NOT NULL REFERENCES roles (id), "sort_key" TEXT NOT NULL DEFAULT '', "notes" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "shooting_slot_crew" ("id" TEXT NOT NULL, "slot_id" TEXT NOT NULL REFERENCES shooting_slots (id), "sort_key" TEXT NOT NULL DEFAULT '', "person_id" TEXT NOT NULL REFERENCES people (id), "position_id" TEXT NOT NULL DEFAULT '', "custom_label" TEXT NOT NULL DEFAULT '', "notes" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "shooting_slot_guests" ("id" TEXT NOT NULL, "slot_id" TEXT NOT NULL REFERENCES shooting_slots (id), "person_id" TEXT NULL REFERENCES people (id), "free_name" TEXT NOT NULL DEFAULT '', "reason" TEXT NOT NULL DEFAULT '', "notes" TEXT NOT NULL DEFAULT '', "sort_key" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "shooting_slots" ("id" TEXT NOT NULL, "shooting_day_id" TEXT NOT NULL REFERENCES shooting_days (id), "sort_key" TEXT NOT NULL DEFAULT '', "label" TEXT NOT NULL DEFAULT '', "location_id" TEXT NULL REFERENCES locations (id), "set_id" TEXT NULL REFERENCES sets (id), "anchor_edge" TEXT NOT NULL DEFAULT 'start', "anchor_minute" INTEGER NULL, "anchor_slot_id" TEXT NULL REFERENCES shooting_slots (id), "notes" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "shot_characters" ("shot_id" TEXT NOT NULL REFERENCES shots (id), "character_name" TEXT NOT NULL, "position" INTEGER NOT NULL, "sort_key" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("shot_id", "character_name"));
CREATE TABLE "shot_coverages" ("id" TEXT NOT NULL, "shot_id" TEXT NOT NULL REFERENCES shots (id), "scene_id" TEXT NOT NULL REFERENCES scenes (id), "start_offset" INTEGER NOT NULL, "end_offset" INTEGER NOT NULL, "covered_text_digest" TEXT NOT NULL, "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "shots" ("id" TEXT NOT NULL, "screenplay_id" TEXT NOT NULL REFERENCES screenplays (id), "scene_id" TEXT NULL REFERENCES scenes (id), "orphaned_heading" TEXT NULL, "position" INTEGER NOT NULL, "sort_key" TEXT NOT NULL DEFAULT '', "shot_size" TEXT NOT NULL DEFAULT '', "abbreviation" TEXT NOT NULL DEFAULT '', "framing" TEXT NOT NULL DEFAULT '', "camera_move" TEXT NOT NULL DEFAULT '', "lens" TEXT NOT NULL DEFAULT '', "recording_format" TEXT NOT NULL DEFAULT '', "estimated_duration_ms" INTEGER NULL, "shooting_day" TEXT NULL, "planned_takes" INTEGER NULL, "sound" TEXT NOT NULL DEFAULT '', "status" TEXT NOT NULL DEFAULT 'toShoot', "difficulty_set" INTEGER NOT NULL DEFAULT 1, "difficulty_camera" INTEGER NOT NULL DEFAULT 1, "difficulty_acting" INTEGER NOT NULL DEFAULT 1, "difficulty_sound" INTEGER NOT NULL DEFAULT 1, "notes" TEXT NOT NULL DEFAULT '', "location_notes" TEXT NOT NULL DEFAULT '', "needs_check" INTEGER NOT NULL DEFAULT 0 CHECK ("needs_check" IN (0, 1)), "check_reason" TEXT NULL, "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
''';

// The complete shape schema version 19 left every table in: everything version 20 knows about
// except `role_candidates`, the people seen for a part, which version 20 adds. Captured whole,
// through a real `OcptProjectDatabase`, for the reason [_v17Ddl] gives — versions 18 and 19
// reshaped `roles`, `screenplays` and `shooting_days` deeply enough that composing this shape
// fragment by fragment onto the fixtures above would replay every step above a second time for no
// extra coverage. This is what `'upgraded_from_v19.ocpt'` below is built from, and what the
// dedicated `a v19 database migrates on…` test below uses as its own starting shape.
const _v19Ddl = '''
CREATE TABLE "assets" ("id" TEXT NOT NULL, "kind" TEXT NOT NULL, "path" TEXT NOT NULL, "label" TEXT NOT NULL DEFAULT '', "added_at" TEXT NOT NULL, "sort_key" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), "person_id" TEXT NULL, "location_id" TEXT NULL REFERENCES locations (id), "element_id" TEXT NULL REFERENCES elements (id), "valid_from" TEXT NULL, "valid_until" TEXT NULL, PRIMARY KEY ("id"));
CREATE TABLE "breakdown_tags" ("id" TEXT NOT NULL, "scene_id" TEXT NOT NULL REFERENCES scenes (id), "target_kind" TEXT NOT NULL, "element_id" TEXT NULL REFERENCES elements (id), "role_id" TEXT NULL REFERENCES roles (id), "set_id" TEXT NULL REFERENCES sets (id), "start_offset" INTEGER NOT NULL, "end_offset" INTEGER NOT NULL, "tagged_text" TEXT NOT NULL, "needs_check" INTEGER NOT NULL DEFAULT 0 CHECK ("needs_check" IN (0, 1)), "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "elements" ("id" TEXT NOT NULL, "sort_key" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), "category" TEXT NOT NULL, "sub_category" TEXT NOT NULL DEFAULT '', "name" TEXT NOT NULL, "code" TEXT NOT NULL DEFAULT '', "quantity" TEXT NOT NULL DEFAULT '', "source_kind" TEXT NOT NULL, "owner_person_id" TEXT NULL, "owner_notes" TEXT NOT NULL DEFAULT '', "brought_by_person_id" TEXT NULL, "storage_notes" TEXT NOT NULL DEFAULT '', "status" TEXT NOT NULL DEFAULT 'toFind', "is_secured" INTEGER NOT NULL DEFAULT 0 CHECK ("is_secured" IN (0, 1)), "is_ready_for_shoot" INTEGER NOT NULL DEFAULT 0 CHECK ("is_ready_for_shoot" IN (0, 1)), "is_returned" INTEGER NOT NULL DEFAULT 0 CHECK ("is_returned" IN (0, 1)), "cost" INTEGER NULL, "purpose_notes" TEXT NOT NULL DEFAULT '', "notes" TEXT NOT NULL DEFAULT '', "photo_asset_id" TEXT NULL, PRIMARY KEY ("id"));
CREATE TABLE "local_erasures" ("person_id" TEXT NOT NULL REFERENCES people (id), "erased_at" TEXT NOT NULL, PRIMARY KEY ("person_id"));
CREATE TABLE "location_availabilities" ("id" TEXT NOT NULL, "location_id" TEXT NOT NULL REFERENCES locations (id), "start_date" TEXT NOT NULL, "end_date" TEXT NOT NULL, "weekdays" INTEGER NOT NULL DEFAULT 127, "slot" TEXT NOT NULL DEFAULT 'fullDay', "start_minute" INTEGER NULL, "end_minute" INTEGER NULL, "kind" TEXT NOT NULL DEFAULT 'available', "note" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "locations" ("id" TEXT NOT NULL, "name" TEXT NOT NULL, "color_index" INTEGER NOT NULL DEFAULT 0, "address_line1" TEXT NOT NULL DEFAULT '', "address_line2" TEXT NOT NULL DEFAULT '', "postal_code" TEXT NOT NULL DEFAULT '', "city" TEXT NOT NULL DEFAULT '', "region" TEXT NOT NULL DEFAULT '', "country" TEXT NOT NULL DEFAULT '', "latitude" REAL NULL, "longitude" REAL NULL, "contact_person_id" TEXT NULL, "contact_notes" TEXT NOT NULL DEFAULT '', "permit_status" TEXT NOT NULL DEFAULT 'toRequest', "permit_label" TEXT NOT NULL DEFAULT '', "permit_date" TEXT NULL, "permit_asset_id" TEXT NULL, "parking_notes" TEXT NOT NULL DEFAULT '', "power_notes" TEXT NOT NULL DEFAULT '', "facilities_notes" TEXT NOT NULL DEFAULT '', "constraints_notes" TEXT NOT NULL DEFAULT '', "notes" TEXT NOT NULL DEFAULT '', "sort_key" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "people" ("id" TEXT NOT NULL, "sort_key" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), "first_name" TEXT NOT NULL DEFAULT '', "last_name" TEXT NOT NULL DEFAULT '', "email" TEXT NOT NULL DEFAULT '', "phone" TEXT NOT NULL DEFAULT '', "address_line1" TEXT NOT NULL DEFAULT '', "address_line2" TEXT NOT NULL DEFAULT '', "postal_code" TEXT NOT NULL DEFAULT '', "city" TEXT NOT NULL DEFAULT '', "region" TEXT NOT NULL DEFAULT '', "country" TEXT NOT NULL DEFAULT '', "color_index" INTEGER NOT NULL DEFAULT 0, "birth_date" TEXT NULL, "minor_notes" TEXT NOT NULL DEFAULT '', "max_daily_presence_minutes" INTEGER NULL, "is_transport_autonomous" INTEGER NULL CHECK ("is_transport_autonomous" IN (0, 1)), "accommodation_notes" TEXT NOT NULL DEFAULT '', "travel_notes" TEXT NOT NULL DEFAULT '', "dietary_notes" TEXT NOT NULL DEFAULT '', "allergies" TEXT NOT NULL DEFAULT '', "measurement_height" TEXT NOT NULL DEFAULT '', "measurement_chest" TEXT NOT NULL DEFAULT '', "measurement_waist" TEXT NOT NULL DEFAULT '', "measurement_hips" TEXT NOT NULL DEFAULT '', "size_top" TEXT NOT NULL DEFAULT '', "size_bottom" TEXT NOT NULL DEFAULT '', "size_shoes" TEXT NOT NULL DEFAULT '', "hmc_notes" TEXT NOT NULL DEFAULT '', "image_rights_status" TEXT NOT NULL DEFAULT 'notApplicable', "image_rights_date" TEXT NULL, "image_rights_asset_id" TEXT NULL REFERENCES assets (id), "photo_asset_id" TEXT NULL REFERENCES assets (id), "notes" TEXT NOT NULL DEFAULT '', PRIMARY KEY ("id"));
CREATE TABLE "person_positions" ("id" TEXT NOT NULL, "person_id" TEXT NOT NULL REFERENCES people (id), "position_id" TEXT NOT NULL DEFAULT '', "custom_label" TEXT NOT NULL DEFAULT '', "sort_key" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "person_skills" ("id" TEXT NOT NULL, "person_id" TEXT NOT NULL REFERENCES people (id), "label" TEXT NOT NULL DEFAULT '', "sort_key" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "person_unavailabilities" ("id" TEXT NOT NULL, "person_id" TEXT NOT NULL REFERENCES people (id), "start_date" TEXT NOT NULL, "end_date" TEXT NOT NULL, "slot" TEXT NOT NULL DEFAULT 'fullDay', "start_minute" INTEGER NULL, "end_minute" INTEGER NULL, "reason" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "project_dictionary_words" ("id" TEXT NOT NULL, "word" TEXT NOT NULL, "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "project_info" ("id" INTEGER NOT NULL DEFAULT 1, "name" TEXT NOT NULL, "created_at" TEXT NOT NULL, "app_version_at_creation" TEXT NOT NULL, "page_format" TEXT NOT NULL, "currency_code" TEXT NOT NULL DEFAULT 'EUR', "settings_json" TEXT NULL, "minimum_rest_minutes" INTEGER NULL, "screenplay_language" TEXT NULL, "current_version_id" TEXT NULL REFERENCES project_versions (id), PRIMARY KEY ("id"));
CREATE TABLE "project_versions" ("id" TEXT NOT NULL, "name" TEXT NOT NULL, "note" TEXT NOT NULL DEFAULT '', "created_at" TEXT NOT NULL, "app_version" TEXT NOT NULL, "payload_format" INTEGER NOT NULL, "payload" TEXT NOT NULL, "summary_json" TEXT NOT NULL, "created_by_device_id" TEXT NOT NULL, "content_digest" TEXT NULL, PRIMARY KEY ("id"));
CREATE TABLE "role_elements" ("id" TEXT NOT NULL, "role_id" TEXT NOT NULL REFERENCES roles (id), "element_id" TEXT NOT NULL REFERENCES elements (id), "notes" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "role_episodes" ("id" TEXT NOT NULL, "role_id" TEXT NOT NULL REFERENCES roles (id), "screenplay_id" TEXT NOT NULL REFERENCES screenplays (id), "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "roles" ("id" TEXT NOT NULL, "name" TEXT NOT NULL, "sort_key" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), "person_id" TEXT NULL REFERENCES people (id), "kind" TEXT NOT NULL, "is_from_screenplay" INTEGER NOT NULL DEFAULT 0 CHECK ("is_from_screenplay" IN (0, 1)), "orphaned_name" TEXT NULL, "casting_notes" TEXT NOT NULL DEFAULT '', PRIMARY KEY ("id"));
CREATE TABLE "row_field_versions" ("table_name" TEXT NOT NULL, "row_id" TEXT NOT NULL, "column_name" TEXT NOT NULL, "version" INTEGER NOT NULL, "device_id" TEXT NOT NULL, PRIMARY KEY ("table_name", "row_id", "column_name"));
CREATE TABLE "scene_breakdowns" ("id" TEXT NOT NULL, "scene_id" TEXT NOT NULL REFERENCES scenes (id), "status" TEXT NOT NULL DEFAULT 'toDo', "notes" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "scene_elements" ("id" TEXT NOT NULL, "scene_id" TEXT NOT NULL REFERENCES scenes (id), "element_id" TEXT NOT NULL REFERENCES elements (id), "quantity" TEXT NOT NULL DEFAULT '', "notes" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "scene_sets" ("id" TEXT NOT NULL, "scene_id" TEXT NOT NULL REFERENCES scenes (id), "set_id" TEXT NOT NULL REFERENCES sets (id), "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "scenes" ("id" TEXT NOT NULL, "screenplay_id" TEXT NOT NULL REFERENCES screenplays (id), "position" INTEGER NOT NULL, "heading" TEXT NOT NULL, "scene_number" TEXT NULL, "char_start" INTEGER NOT NULL, "char_end" INTEGER NOT NULL, "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "screenplay_snapshots" ("id" TEXT NOT NULL, "screenplay_id" TEXT NOT NULL REFERENCES screenplays (id), "created_at" TEXT NOT NULL, "reason" TEXT NOT NULL, "fountain_text" TEXT NOT NULL, "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "screenplays" ("id" TEXT NOT NULL, "title" TEXT NOT NULL, "fountain_text" TEXT NOT NULL DEFAULT '', "updated_at" TEXT NOT NULL, "number" INTEGER NOT NULL DEFAULT 1, "sort_key" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "sets" ("id" TEXT NOT NULL, "location_id" TEXT NOT NULL REFERENCES locations (id), "code" TEXT NOT NULL DEFAULT '', "name" TEXT NOT NULL, "notes" TEXT NOT NULL DEFAULT '', "sort_key" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "shooting_day_blocks" ("id" TEXT NOT NULL, "shooting_day_id" TEXT NOT NULL REFERENCES shooting_days (id), "sort_key" TEXT NOT NULL DEFAULT '', "slot_id" TEXT NOT NULL REFERENCES shooting_slots (id), "kind" TEXT NOT NULL DEFAULT 'shot', "shot_id" TEXT NULL REFERENCES shots (id), "scene_id" TEXT NULL REFERENCES scenes (id), "label" TEXT NOT NULL DEFAULT '', "duration_minutes" INTEGER NULL, "anchor_minute" INTEGER NULL, "notes" TEXT NOT NULL DEFAULT '', "crew_note" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "shooting_day_events" ("id" TEXT NOT NULL, "shooting_day_id" TEXT NOT NULL REFERENCES shooting_days (id), "minute" INTEGER NOT NULL, "label" TEXT NOT NULL DEFAULT '', "notes" TEXT NOT NULL DEFAULT '', "sort_key" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "shooting_days" ("id" TEXT NOT NULL, "date" TEXT NOT NULL, "sort_key" TEXT NOT NULL DEFAULT '', "status" TEXT NOT NULL DEFAULT 'planned', "crew_note" TEXT NOT NULL DEFAULT '', "weather_note" TEXT NOT NULL DEFAULT '', "notes" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "shooting_slot_cast" ("id" TEXT NOT NULL, "slot_id" TEXT NOT NULL REFERENCES shooting_slots (id), "role_id" TEXT NOT NULL REFERENCES roles (id), "sort_key" TEXT NOT NULL DEFAULT '', "notes" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "shooting_slot_crew" ("id" TEXT NOT NULL, "slot_id" TEXT NOT NULL REFERENCES shooting_slots (id), "sort_key" TEXT NOT NULL DEFAULT '', "person_id" TEXT NOT NULL REFERENCES people (id), "position_id" TEXT NOT NULL DEFAULT '', "custom_label" TEXT NOT NULL DEFAULT '', "notes" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "shooting_slot_guests" ("id" TEXT NOT NULL, "slot_id" TEXT NOT NULL REFERENCES shooting_slots (id), "person_id" TEXT NULL REFERENCES people (id), "free_name" TEXT NOT NULL DEFAULT '', "reason" TEXT NOT NULL DEFAULT '', "notes" TEXT NOT NULL DEFAULT '', "sort_key" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "shooting_slots" ("id" TEXT NOT NULL, "shooting_day_id" TEXT NOT NULL REFERENCES shooting_days (id), "sort_key" TEXT NOT NULL DEFAULT '', "label" TEXT NOT NULL DEFAULT '', "location_id" TEXT NULL REFERENCES locations (id), "set_id" TEXT NULL REFERENCES sets (id), "anchor_edge" TEXT NOT NULL DEFAULT 'start', "anchor_minute" INTEGER NULL, "anchor_slot_id" TEXT NULL REFERENCES shooting_slots (id), "notes" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "shot_characters" ("shot_id" TEXT NOT NULL REFERENCES shots (id), "character_name" TEXT NOT NULL, "position" INTEGER NOT NULL, "sort_key" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("shot_id", "character_name"));
CREATE TABLE "shot_coverages" ("id" TEXT NOT NULL, "shot_id" TEXT NOT NULL REFERENCES shots (id), "scene_id" TEXT NOT NULL REFERENCES scenes (id), "start_offset" INTEGER NOT NULL, "end_offset" INTEGER NOT NULL, "covered_text_digest" TEXT NOT NULL, "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "shots" ("id" TEXT NOT NULL, "screenplay_id" TEXT NOT NULL REFERENCES screenplays (id), "scene_id" TEXT NULL REFERENCES scenes (id), "orphaned_heading" TEXT NULL, "position" INTEGER NOT NULL, "sort_key" TEXT NOT NULL DEFAULT '', "shot_size" TEXT NOT NULL DEFAULT '', "abbreviation" TEXT NOT NULL DEFAULT '', "framing" TEXT NOT NULL DEFAULT '', "camera_move" TEXT NOT NULL DEFAULT '', "lens" TEXT NOT NULL DEFAULT '', "recording_format" TEXT NOT NULL DEFAULT '', "estimated_duration_ms" INTEGER NULL, "shooting_day" TEXT NULL, "planned_takes" INTEGER NULL, "sound" TEXT NOT NULL DEFAULT '', "status" TEXT NOT NULL DEFAULT 'toShoot', "difficulty_set" INTEGER NOT NULL DEFAULT 1, "difficulty_camera" INTEGER NOT NULL DEFAULT 1, "difficulty_acting" INTEGER NOT NULL DEFAULT 1, "difficulty_sound" INTEGER NOT NULL DEFAULT 1, "notes" TEXT NOT NULL DEFAULT '', "location_notes" TEXT NOT NULL DEFAULT '', "needs_check" INTEGER NOT NULL DEFAULT 0 CHECK ("needs_check" IN (0, 1)), "check_reason" TEXT NULL, "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
''';

// The one table schema version 20 adds on top of [_v19Ddl]: `role_candidates`, the people seen for
// a part. Composed onto that fixture rather than captured whole, version 20 having reshaped nothing
// — it is a plain `createTable` — so `'$_v19Ddl$_v20RoleCandidatesDdl'` is exactly the shape a file
// that genuinely reached version 20 carries.
const _v20RoleCandidatesDdl = '''
CREATE TABLE "role_candidates" ("id" TEXT NOT NULL, "role_id" TEXT NOT NULL REFERENCES roles (id), "person_id" TEXT NOT NULL REFERENCES people (id), "status" TEXT NOT NULL DEFAULT 'seen', "auditioned_on" TEXT NULL, "notes" TEXT NOT NULL DEFAULT '', "sort_key" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
''';

// The one column an unmerged build briefly added to `shooting_days`: `kind`, taken back out at
// schema version 23. No released build ever wrote it, so this fixture stands for the only files
// that can carry it — the ones this branch was developed against — and is what proves the drop step
// lands them on the same shape as everything else.
const _v21ShootingDayKindDdl = '''
ALTER TABLE "shooting_days" ADD COLUMN "kind" TEXT NOT NULL DEFAULT 'shoot';
''';

// The one table an unmerged build briefly created: `shooting_slot_candidates`, the slot-wide
// convocation taken back out at schema version 24. Its sibling of [_v21ShootingDayKindDdl], there
// for the same reason and standing for the same files — the only ones that can carry it.
const _v22ShootingSlotCandidatesDdl = '''
CREATE TABLE "shooting_slot_candidates" ("id" TEXT NOT NULL, "slot_id" TEXT NOT NULL REFERENCES shooting_slots (id), "role_candidate_id" TEXT NOT NULL REFERENCES role_candidates (id), "sort_key" TEXT NOT NULL DEFAULT '', "notes" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
''';

// The one table schema version 24 adds on top of [_v19Ddl]/[_v20RoleCandidatesDdl]:
// `shooting_block_candidates`, the candidacies an `audition` block sees. Composed for the same
// reason [_v20RoleCandidatesDdl] is — a plain `createTable`, nothing reshaped — rather than
// captured whole: `'$_v19Ddl$_v20RoleCandidatesDdl$_v24ShootingBlockCandidatesDdl'` is exactly the
// shape a file that genuinely reached version 24 carries, and what every budget milestone below is
// composed onto in turn.
const _v24ShootingBlockCandidatesDdl = '''
CREATE TABLE "shooting_block_candidates" ("id" TEXT NOT NULL, "block_id" TEXT NOT NULL REFERENCES shooting_day_blocks (id), "role_candidate_id" TEXT NOT NULL REFERENCES role_candidates (id), "sort_key" TEXT NOT NULL DEFAULT '', "notes" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"));
''';

// The two tables and the three `project_info` columns schema version 25 adds on top of the shape
// above: the budget mode's foundations — [OcptBudgetPostesTable]/[OcptBudgetLinesTable], the
// seeded-then-editable CNC nomenclature and its quote lines, and
// `defaultVatRateBasisPoints`/`mealPriceCents`/`snackPriceCents`. Composed rather than captured
// whole, for the same reason [_v20RoleCandidatesDdl] is: plain `createTable`s and unconditional
// `addColumn`s, nothing reshaped. This is what `'upgraded_from_v25.ocpt'` below is built from, and
// what the dedicated `a v25 database migrates on…` test below uses as its own starting shape.
const _v25BudgetFoundationsDdl = '''
CREATE TABLE "budget_postes" ("id" TEXT NOT NULL, "sort_key" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), "code" TEXT NOT NULL DEFAULT '', "label" TEXT NOT NULL, "simple_label" TEXT NULL, PRIMARY KEY ("id"));
CREATE TABLE "budget_lines" ("id" TEXT NOT NULL, "sort_key" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), "poste_id" TEXT NOT NULL REFERENCES budget_postes (id), "label" TEXT NOT NULL, "quantity_milli" INTEGER NOT NULL DEFAULT 1000, "unit" TEXT NOT NULL DEFAULT '', "unit_amount_cents" INTEGER NOT NULL DEFAULT 0, "is_tax_inclusive" INTEGER NOT NULL DEFAULT 1 CHECK ("is_tax_inclusive" IN (0, 1)), "vat_rate_basis_points" INTEGER NULL, "element_id" TEXT NULL REFERENCES elements (id), "notes" TEXT NOT NULL DEFAULT '', PRIMARY KEY ("id"));
ALTER TABLE "project_info" ADD COLUMN "default_vat_rate_basis_points" INTEGER NULL;
ALTER TABLE "project_info" ADD COLUMN "meal_price_cents" INTEGER NULL;
ALTER TABLE "project_info" ADD COLUMN "snack_price_cents" INTEGER NULL;
''';

// The two tables and the one column schema version 26 adds on top of the shape above: the budget
// mode's cash journal — [OcptBudgetEntriesTable]/[OcptBudgetCommitmentsTable] and
// `assets.budgetEntryId`. Composed for the same reason [_v25BudgetFoundationsDdl] is. This is what
// `'upgraded_from_v26.ocpt'` below is built from, and what the dedicated `a v26 database migrates
// on…` test below uses as its own starting shape.
const _v26CashJournalDdl = '''
CREATE TABLE "budget_entries" ("id" TEXT NOT NULL, "sort_key" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), "date" TEXT NOT NULL, "label" TEXT NOT NULL, "poste_id" TEXT NULL REFERENCES budget_postes (id), "debit_cents" INTEGER NOT NULL DEFAULT 0, "credit_cents" INTEGER NOT NULL DEFAULT 0, "is_tax_inclusive" INTEGER NOT NULL DEFAULT 1 CHECK ("is_tax_inclusive" IN (0, 1)), "vat_rate_basis_points" INTEGER NULL, "voucher_number" TEXT NOT NULL DEFAULT '', PRIMARY KEY ("id"));
CREATE TABLE "budget_commitments" ("id" TEXT NOT NULL, "sort_key" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), "due_date" TEXT NULL, "label" TEXT NOT NULL, "poste_id" TEXT NOT NULL REFERENCES budget_postes (id), "amount_cents" INTEGER NOT NULL DEFAULT 0, "is_tax_inclusive" INTEGER NOT NULL DEFAULT 1 CHECK ("is_tax_inclusive" IN (0, 1)), "vat_rate_basis_points" INTEGER NULL, "status" TEXT NOT NULL DEFAULT 'quoteAccepted', "settled_entry_id" TEXT NULL REFERENCES budget_entries (id), PRIMARY KEY ("id"));
ALTER TABLE "assets" ADD COLUMN "budget_entry_id" TEXT NULL REFERENCES budget_entries (id);
''';

// The two tables and the three columns schema version 27 adds on top of the shape above: the
// budget mode's financing plan — [OcptBudgetMileageRatesTable]/[OcptBudgetResourcesTable],
// `budget_entries.resourceId` and `people.commuteKmMilli`/`.mileageRateId`. Composed for the same
// reason [_v25BudgetFoundationsDdl] is. This is what `'upgraded_from_v27.ocpt'` below is built
// from, and what the dedicated `a v26 database migrates on…` test below uses as its own starting
// shape.
const _v27FinancingDdl = '''
CREATE TABLE "budget_mileage_rates" ("id" TEXT NOT NULL, "sort_key" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), "label" TEXT NOT NULL, "rate_per_km_milli_cents" INTEGER NOT NULL DEFAULT 0, PRIMARY KEY ("id"));
CREATE TABLE "budget_resources" ("id" TEXT NOT NULL, "sort_key" TEXT NOT NULL DEFAULT '', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), "group_kind" TEXT NOT NULL DEFAULT 'subsidy', "label" TEXT NOT NULL, "amount_cents" INTEGER NOT NULL DEFAULT 0, "status" TEXT NOT NULL DEFAULT 'applied', "is_reimbursable" INTEGER NOT NULL DEFAULT 0 CHECK ("is_reimbursable" IN (0, 1)), "notes" TEXT NOT NULL DEFAULT '', PRIMARY KEY ("id"));
ALTER TABLE "budget_entries" ADD COLUMN "resource_id" TEXT NULL REFERENCES budget_resources (id);
ALTER TABLE "people" ADD COLUMN "commute_km_milli" INTEGER NULL;
ALTER TABLE "people" ADD COLUMN "mileage_rate_id" TEXT NULL REFERENCES budget_mileage_rates (id);
''';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ocpt_project_database_migration_test_');
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  final createdAt = DateTime.utc(2026, 1, 15, 9, 30);
  final updatedAt = DateTime.utc(2026, 1, 16, 18, 45, 30);
  final snapshotCreatedAt = DateTime.utc(2026, 1, 16, 18, 44);

  /// Writes the rows every version of the schema already had — the project header, one screenplay,
  /// one snapshot and one scene — into the legacy database [db] built from [_v1Ddl], [_v2Ddl] or
  /// [_v3Ddl].
  void seedCommonRows(sqlite3.Database db) {
    db.execute(
      "INSERT INTO project_info (id, name, created_at, app_version_at_creation, page_format) "
      "VALUES (1, 'My Movie', '${createdAt.toIso8601String()}', '0.1.0', 'a4');",
    );
    db.execute(
      "INSERT INTO screenplays (id, title, fountain_text, updated_at) "
      "VALUES ('s1', 'Draft', 'INT. HOUSE - DAY\n\nCLARA enters.', "
      "'${updatedAt.toIso8601String()}');",
    );
    db.execute(
      "INSERT INTO screenplay_snapshots (id, screenplay_id, created_at, reason, fountain_text) "
      "VALUES ('snap1', 's1', '${snapshotCreatedAt.toIso8601String()}', 'manual', "
      "'INT. HOUSE - DAY');",
    );
    db.execute(
      "INSERT INTO scenes (id, screenplay_id, position, heading, scene_number, char_start, "
      "char_end) VALUES ('scene1', 's1', 0, 'INT. HOUSE - DAY', NULL, 0, 18);",
    );
  }

  /// Asserts that the rows [seedCommonRows] wrote all came through [database] unchanged.
  Future<void> expectCommonRowsSurvived(OcptProjectDatabase database) async {
    final projectInfo = await database.select(database.ocptProjectInfoTable).getSingle();
    expect(projectInfo.name, "My Movie");
    expect(projectInfo.appVersionAtCreation, "0.1.0");
    expect(projectInfo.pageFormat, OcptPageFormat.a4);
    expect(projectInfo.createdAt, createdAt);

    final screenplay = await database.select(database.ocptScreenplaysTable).getSingle();
    expect(screenplay.id, "s1");
    expect(screenplay.title, "Draft");
    expect(screenplay.fountainText, "INT. HOUSE - DAY\n\nCLARA enters.");
    expect(screenplay.updatedAt, updatedAt);
    expect(screenplay.isDeleted, isFalse);

    final snapshot = await database.select(database.ocptScreenplaySnapshotsTable).getSingle();
    expect(snapshot.id, "snap1");
    expect(snapshot.screenplayId, "s1");
    expect(snapshot.reason, OcptSnapshotReason.manual);
    expect(snapshot.fountainText, "INT. HOUSE - DAY");
    expect(snapshot.createdAt, snapshotCreatedAt);
    expect(snapshot.isDeleted, isFalse);

    final scene = await (database.select(
      database.ocptScenesTable,
    )..where((table) => table.id.equals("scene1"))).getSingle();
    expect(scene.id, "scene1");
    expect(scene.heading, "INT. HOUSE - DAY");
    expect(scene.sceneNumber, isNull);
    expect(scene.charStart, 0);
    expect(scene.charEnd, 18);
    expect(scene.isDeleted, isFalse);
  }

  /// Asserts that the version 5 shape is in place and usable in [database]: the `project_versions`
  /// table accepts a row, `project_info.current_version_id` — added by the same step — accepts a
  /// pointer to it, and the version's `content_digest` defaults to null for a freshly inserted row
  /// that didn't set it.
  Future<void> expectProjectVersionsAreUsable(OcptProjectDatabase database) async {
    await database
        .into(database.ocptProjectVersionsTable)
        .insert(
          OcptProjectVersionsTableCompanion.insert(
            id: "version1",
            name: "v1 — First read",
            createdAt: DateTime.utc(2026, 2, 1, 10),
            appVersion: "0.1.0",
            payloadFormat: 1,
            payload: '{"payloadFormat":1}',
            summaryJson: '{"pageCount":41}',
            createdByDeviceId: "device-1",
          ),
        );

    await database
        .update(database.ocptProjectInfoTable)
        .write(const OcptProjectInfoTableCompanion(currentVersionId: Value("version1")));

    final version = await database.select(database.ocptProjectVersionsTable).getSingle();
    expect(version.name, "v1 — First read");
    expect(version.note, "");
    expect(version.contentDigest, isNull);

    final projectInfo = await database.select(database.ocptProjectInfoTable).getSingle();
    expect(projectInfo.currentVersionId, "version1");
  }

  /// The `user_version` pragma [database]'s file now carries.
  Future<Object?> readSchemaVersion(OcptProjectDatabase database) async {
    final row = await database.customSelect('PRAGMA user_version').getSingle();
    return row.data['user_version'];
  }

  /// The shape of every table [database] holds: the table name mapped to its columns, each read
  /// from `PRAGMA table_info` as its name, declared type, nullability, default and primary key
  /// rank.
  ///
  /// A table's columns are gathered into a set rather than a list because the two ways a table can
  /// reach the current version disagree on their *order* and on nothing else: `createTable` writes
  /// them in the order the Dart declaration lists them, while `ALTER TABLE … ADD COLUMN` can only
  /// append. Which columns exist, and what each of them is, is what an upgraded file and a fresh
  /// one have to agree on for the rest of the app to treat them alike.
  Future<Map<String, Set<String>>> readSchemaShape(OcptProjectDatabase database) async {
    final tables = await database
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%' "
          "ORDER BY name",
        )
        .get();

    final shape = <String, Set<String>>{};
    for (final table in tables) {
      final tableName = table.read<String>('name');
      final columns = await database.customSelect('PRAGMA table_info("$tableName")').get();
      shape[tableName] = {
        for (final column in columns)
          "${column.read<String>('name')} ${column.read<String>('type')} "
              "notNull=${column.read<int>('notnull')} "
              "default=${column.data['dflt_value']} pk=${column.read<int>('pk')}",
      };
    }

    return shape;
  }

  test('a database created from scratch has the shape every upgrade path lands on', () async {
    // The reference: a file drift creates itself, through `onCreate` alone, never having been
    // anything but version 28.
    final freshDatabase = OcptProjectDatabase(File(p.join(tempDir.path, 'fresh.ocpt')));
    final freshShape = await readSchemaShape(freshDatabase);
    expect(await readSchemaVersion(freshDatabase), 28);
    await freshDatabase.close();

    // Naming the tables rather than counting them: two empty shapes would compare equal below and
    // prove nothing at all, and this is also where a table added later without a migration step
    // shows up.
    expect(freshShape.keys, {
      'project_info',
      'project_versions',
      'row_field_versions',
      'scenes',
      'screenplay_snapshots',
      'screenplays',
      'shot_characters',
      'shot_coverages',
      'shots',
      'people',
      'person_positions',
      'person_skills',
      'person_unavailabilities',
      'roles',
      'locations',
      'location_availabilities',
      'sets',
      'scene_sets',
      'elements',
      'scene_elements',
      'role_elements',
      'role_episodes',
      'role_candidates',
      'assets',
      'local_erasures',
      'breakdown_tags',
      'scene_breakdowns',
      'shooting_days',
      'shooting_slots',
      'shooting_slot_crew',
      'shooting_slot_cast',
      'shooting_day_blocks',
      'shooting_slot_guests',
      'shooting_block_candidates',
      'shooting_day_events',
      'project_dictionary_words',
      'budget_postes',
      'budget_lines',
      'budget_entries',
      'budget_commitments',
      'budget_mileage_rates',
      'budget_resources',
      'budget_revenues',
      'budget_shares',
    });

    // And every file an earlier version could have left behind, brought up by `onUpgrade`: each
    // must land on that same shape, whichever generation of columns it already carried.
    for (final (fileName, ddl, userVersion) in [
      ('upgraded_from_v1.ocpt', _v1Ddl, 1),
      ('upgraded_from_v2.ocpt', _v2Ddl, 2),
      ('upgraded_from_v3.ocpt', _v3Ddl, 3),
      ('upgraded_from_v4.ocpt', _v4Ddl, 4),
      ('upgraded_from_v5.ocpt', _v5Ddl, 5),
      ('upgraded_from_v6.ocpt', '$_v5Ddl$_v6ResourcesDdl', 6),
      ('upgraded_from_v7.ocpt', '$_v5Ddl$_v6ResourcesDdl$_v7LocationAvailabilitiesDdl', 7),
      (
        'upgraded_from_v8.ocpt',
        '$_v5Ddl$_v6ResourcesDdl$_v7LocationAvailabilitiesDdl$_v8CurrencyDdl',
        8,
      ),
      (
        'upgraded_from_v9.ocpt',
        '$_v5Ddl$_v6ResourcesDdl$_v7LocationAvailabilitiesDdl$_v8CurrencyDdl$_v9BreakdownDdl',
        9,
      ),
      (
        // Version 10 added no column and no table (see [_backfillSetCodes]), so its shape is
        // exactly version 9's.
        'upgraded_from_v10.ocpt',
        '$_v5Ddl$_v6ResourcesDdl$_v7LocationAvailabilitiesDdl$_v8CurrencyDdl$_v9BreakdownDdl',
        10,
      ),
      (
        'upgraded_from_v11.ocpt',
        '$_v5Ddl$_v6ResourcesDdl$_v7LocationAvailabilitiesDdl$_v8CurrencyDdl$_v9BreakdownDdl'
            '$_v11ScheduleDdl',
        11,
      ),
      (
        'upgraded_from_v12.ocpt',
        '$_v5Ddl$_v6ResourcesDdl$_v7LocationAvailabilitiesDdl$_v8CurrencyDdl$_v9BreakdownDdl'
            '$_v12ScheduleDdl',
        12,
      ),
      (
        'upgraded_from_v13.ocpt',
        '$_v5Ddl$_v6ResourcesDdl$_v7LocationAvailabilitiesDdl$_v8CurrencyDdl$_v9BreakdownDdl'
            '$_v13ScheduleDdl',
        13,
      ),
      (
        'upgraded_from_v14.ocpt',
        '$_v5Ddl$_v6ResourcesDdl$_v7LocationAvailabilitiesDdl$_v8CurrencyDdl$_v9BreakdownDdl'
            '$_v14ScheduleDdl',
        14,
      ),
      (
        'upgraded_from_v15.ocpt',
        '$_v5Ddl$_v6ResourcesDdl$_v7LocationAvailabilitiesDdl$_v8CurrencyDdl$_v9BreakdownDdl'
            '$_v14ScheduleDdl$_v15RoleElementsDdl',
        15,
      ),
      (
        'upgraded_from_v16.ocpt',
        '$_v5Ddl$_v6ResourcesDdl$_v7LocationAvailabilitiesDdl$_v8CurrencyDdl$_v9BreakdownDdl'
            '$_v14ScheduleDdl$_v15RoleElementsDdl$_v16MaxDailyPresenceMinutesDdl',
        16,
      ),
      ('upgraded_from_v17.ocpt', _v17Ddl, 17),
      ('upgraded_from_v19.ocpt', _v19Ddl, 19),
      ('upgraded_from_v20.ocpt', '$_v19Ddl$_v20RoleCandidatesDdl', 20),
      (
        'upgraded_from_v21.ocpt',
        '$_v19Ddl$_v20RoleCandidatesDdl$_v21ShootingDayKindDdl',
        21,
      ),
      (
        'upgraded_from_v25.ocpt',
        '$_v19Ddl$_v20RoleCandidatesDdl$_v24ShootingBlockCandidatesDdl$_v25BudgetFoundationsDdl',
        25,
      ),
      (
        'upgraded_from_v26.ocpt',
        '$_v19Ddl$_v20RoleCandidatesDdl$_v24ShootingBlockCandidatesDdl$_v25BudgetFoundationsDdl'
            '$_v26CashJournalDdl',
        26,
      ),
      (
        'upgraded_from_v27.ocpt',
        '$_v19Ddl$_v20RoleCandidatesDdl$_v24ShootingBlockCandidatesDdl$_v25BudgetFoundationsDdl'
            '$_v26CashJournalDdl$_v27FinancingDdl',
        27,
      ),
    ]) {
      final filePath = p.join(tempDir.path, fileName);

      final legacyDb = sqlite3.sqlite3.open(filePath);
      legacyDb.execute(ddl);
      legacyDb.execute('PRAGMA user_version = $userVersion;');
      seedCommonRows(legacyDb);
      legacyDb.dispose();

      final database = OcptProjectDatabase(File(filePath));
      expect(
        await readSchemaShape(database),
        freshShape,
        reason:
            "a file coming from version $userVersion must end up on the very shape `onCreate` "
            "writes",
      );
      expect(await readSchemaVersion(database), 28);

      await database.close();
    }
  });

  test('a v1 database migrates to the current schema, preserving every existing row', () async {
    final filePath = p.join(tempDir.path, 'legacy_v1.ocpt');

    // Build the v1 fixture directly with the `sqlite3` package: no drift involved yet, so this
    // is genuinely an "old file on disk" rather than something drift's own `onCreate` produced.
    final legacyDb = sqlite3.sqlite3.open(filePath);
    legacyDb.execute(_v1Ddl);
    legacyDb.execute('PRAGMA user_version = 1;');
    seedCommonRows(legacyDb);
    legacyDb.dispose();

    // Open the same file through the current OcptProjectDatabase: this is the migration, replayed
    // through both of its steps in order.
    final database = OcptProjectDatabase(File(filePath));

    // (a) every original row survived, unchanged.
    await expectCommonRowsSurvived(database);

    // (b) the shot list tables exist and accept a row, referencing the rows the file already held:
    // the migration has to leave the old and the new sides joinable. They were created from the
    // current declarations, so they carry the version 3 columns straight away.
    await database
        .into(database.ocptShotsTable)
        .insert(
          OcptShotsTableCompanion.insert(
            id: "shot1",
            screenplayId: "s1",
            sceneId: const Value("scene1"),
            position: 0,
            sortKey: const Value("V"),
          ),
        );
    await database
        .into(database.ocptShotCharactersTable)
        .insert(
          OcptShotCharactersTableCompanion.insert(
            shotId: "shot1",
            characterName: "CLARA",
            position: 0,
            sortKey: const Value("V"),
          ),
        );
    await database
        .into(database.ocptShotCoveragesTable)
        .insert(
          OcptShotCoveragesTableCompanion.insert(
            id: "cov1",
            shotId: "shot1",
            sceneId: "scene1",
            startOffset: 0,
            endOffset: 12,
            coveredTextDigest: "digest",
          ),
        );

    final shot = await database.select(database.ocptShotsTable).getSingle();
    expect(shot.id, "shot1");
    expect(shot.isDeleted, isFalse);
    expect(shot.abbreviation, "");
    final shotCharacter = await database.select(database.ocptShotCharactersTable).getSingle();
    expect(shotCharacter.characterName, "CLARA");
    final coverage = await database.select(database.ocptShotCoveragesTable).getSingle();
    expect(coverage.sceneId, "scene1");

    // (c) the version 3 sidecar table exists too.
    await database
        .into(database.ocptRowFieldVersionsTable)
        .insert(
          OcptRowFieldVersionsTableCompanion.insert(
            targetTableName: "shots",
            rowId: "shot1",
            columnName: "framing",
            version: 1,
            deviceId: "device-1",
          ),
        );
    expect(await database.select(database.ocptRowFieldVersionsTable).getSingle(), isNotNull);

    // (d) so do the version 5 project versions, pointed at by the project header.
    await expectProjectVersionsAreUsable(database);

    // (e) the schema version stored in the file is now 9.
    expect(await readSchemaVersion(database), 28);

    await database.close();
  });

  test('a v2 database migrates to the current schema, backfilling a sortKey per group', () async {
    final filePath = p.join(tempDir.path, 'legacy_v2.ocpt');

    final legacyDb = sqlite3.sqlite3.open(filePath);
    legacyDb.execute(_v2Ddl);
    legacyDb.execute('PRAGMA user_version = 2;');
    seedCommonRows(legacyDb);
    legacyDb.execute(
      "INSERT INTO scenes (id, screenplay_id, position, heading, scene_number, char_start, "
      "char_end) VALUES ('scene2', 's1', 1, 'EXT. STREET - NIGHT', NULL, 18, 40);",
    );

    // Three shots in the first scene, one in the second, one already orphaned: three independent
    // groups, each numbered from 0 by the version the file comes from.
    for (final (id, sceneId, position) in const [
      ('shot-a', "'scene1'", 0),
      ('shot-b', "'scene1'", 1),
      ('shot-c', "'scene1'", 2),
      ('shot-d', "'scene2'", 0),
      ('shot-orphan', 'NULL', 0),
    ]) {
      legacyDb.execute(
        "INSERT INTO shots (id, screenplay_id, scene_id, position, framing) "
        "VALUES ('$id', 's1', $sceneId, $position, 'framing of $id');",
      );
    }

    for (final (name, position) in const [('CLARA', 0), ('MARC', 1), ('THÉO', 2)]) {
      legacyDb.execute(
        "INSERT INTO shot_characters (shot_id, character_name, position) "
        "VALUES ('shot-a', '$name', $position);",
      );
    }

    legacyDb.execute(
      "INSERT INTO shot_coverages (id, shot_id, scene_id, start_offset, end_offset, "
      "covered_text_digest) VALUES ('cov1', 'shot-a', 'scene1', 0, 12, 'digest');",
    );
    legacyDb.dispose();

    final database = OcptProjectDatabase(File(filePath));

    // (a) every original row survived, unchanged, and is live rather than tombstoned.
    await expectCommonRowsSurvived(database);

    final shots = await (database.select(
      database.ocptShotsTable,
    )..orderBy([(table) => OrderingTerm.asc(table.sortKey)])).get();
    expect(shots, hasLength(5));
    expect(shots.every((row) => !row.isDeleted), isTrue);
    for (final row in shots) {
      expect(row.framing, "framing of ${row.id}");
      expect(row.abbreviation, "");
    }

    final coverage = await database.select(database.ocptShotCoveragesTable).getSingle();
    expect(coverage.shotId, "shot-a");
    expect(coverage.isDeleted, isFalse);

    // (b) every group got its own strictly ascending run of keys, in the order `position` held.
    final sortKeyById = {for (final row in shots) row.id: row.sortKey};
    expect(sortKeyById.values.every((key) => key.isNotEmpty), isTrue);
    expect(sortKeyById['shot-a']!.compareTo(sortKeyById['shot-b']!), lessThan(0));
    expect(sortKeyById['shot-b']!.compareTo(sortKeyById['shot-c']!), lessThan(0));

    // (c) reading each group back by sortKey yields the order the file had under `position`.
    Future<List<String>> shotIdsOfScene(String? sceneId) async {
      final rows =
          await (database.select(database.ocptShotsTable)
                ..where(
                  (table) =>
                      sceneId == null ? table.sceneId.isNull() : table.sceneId.equals(sceneId),
                )
                ..orderBy([(table) => OrderingTerm.asc(table.sortKey)]))
              .get();
      return [for (final row in rows) row.id];
    }

    expect(await shotIdsOfScene('scene1'), ['shot-a', 'shot-b', 'shot-c']);
    expect(await shotIdsOfScene('scene2'), ['shot-d']);
    expect(await shotIdsOfScene(null), ['shot-orphan']);

    // (d) a shot's characters are a group of their own, backfilled the same way.
    final characters = await (database.select(
      database.ocptShotCharactersTable,
    )..orderBy([(table) => OrderingTerm.asc(table.sortKey)])).get();
    expect([for (final row in characters) row.characterName], ['CLARA', 'MARC', 'THÉO']);
    expect(characters.every((row) => row.sortKey.isNotEmpty && !row.isDeleted), isTrue);

    // (e) the sidecar table was created, the project versions are usable, and the file now says
    // version 9.
    await database
        .into(database.ocptRowFieldVersionsTable)
        .insert(
          OcptRowFieldVersionsTableCompanion.insert(
            targetTableName: "shots",
            rowId: "shot-a",
            columnName: "framing",
            version: 1,
            deviceId: "device-1",
          ),
        );
    expect(await database.select(database.ocptRowFieldVersionsTable).getSingle(), isNotNull);
    await expectProjectVersionsAreUsable(database);
    expect(await readSchemaVersion(database), 28);

    await database.close();
  });

  test('a v3 database migrates on, gaining an abbreviation and the project versions', () async {
    final filePath = p.join(tempDir.path, 'legacy_v3.ocpt');

    final legacyDb = sqlite3.sqlite3.open(filePath);
    legacyDb.execute(_v3Ddl);
    legacyDb.execute('PRAGMA user_version = 3;');
    seedCommonRows(legacyDb);
    legacyDb.execute(
      "INSERT INTO shots (id, screenplay_id, scene_id, position, sort_key, shot_size, framing, "
      "is_deleted) VALUES ('shot-a', 's1', 'scene1', 0, 'V', 'Gros plan', 'framing of shot-a', 0);",
    );
    legacyDb.execute(
      "INSERT INTO row_field_versions (table_name, row_id, column_name, version, device_id) "
      "VALUES ('shots', 'shot-a', 'framing', 7, 'device-0');",
    );
    legacyDb.dispose();

    final database = OcptProjectDatabase(File(filePath));

    // (a) every row the file already held survived, the shot and the version 3 ones included:
    // these steps only add columns and a table, and touch nothing else.
    await expectCommonRowsSurvived(database);

    final shot = await database.select(database.ocptShotsTable).getSingle();
    expect(shot.id, "shot-a");
    expect(shot.shotSize, "Gros plan");
    expect(shot.framing, "framing of shot-a");
    expect(shot.sortKey, "V");
    expect(shot.isDeleted, isFalse);

    final stamp = await database.select(database.ocptRowFieldVersionsTable).getSingle();
    expect(stamp.rowId, "shot-a");
    expect(stamp.version, 7);

    // (b) the version 4 column is there, holding its default rather than being deduced
    // retroactively: an abbreviation is only ever written when a shot size is committed from the
    // inspector.
    expect(shot.abbreviation, "");

    await database
        .update(database.ocptShotsTable)
        .write(const OcptShotsTableCompanion(abbreviation: Value("GP")));
    expect((await database.select(database.ocptShotsTable).getSingle()).abbreviation, "GP");

    // (c) the project header kept its own values, and its new pointer starts empty: a project that
    // predates this version has never had a version of its own.
    final projectInfoBefore = await database.select(database.ocptProjectInfoTable).getSingle();
    expect(projectInfoBefore.currentVersionId, isNull);

    // (d) the version 5 shape is in place and usable, and the file now says the current schema version.
    await expectProjectVersionsAreUsable(database);
    expect(await readSchemaVersion(database), 28);

    await database.close();
  });

  test('a v4 database written by the alpha still opens, gaining the project versions', () async {
    final filePath = p.join(tempDir.path, 'legacy_v4.ocpt');

    // The file `v0.1.0-alpha.2` leaves behind: the abbreviation column is what its version 4 means,
    // and it has never heard of the project versions. Opening it must run the version 5 step alone,
    // creating `project_versions` rather than altering a table that isn't there.
    final legacyDb = sqlite3.sqlite3.open(filePath);
    legacyDb.execute(_v4Ddl);
    legacyDb.execute('PRAGMA user_version = 4;');
    seedCommonRows(legacyDb);
    legacyDb.execute(
      "INSERT INTO shots (id, screenplay_id, scene_id, position, sort_key, shot_size, "
      "abbreviation) VALUES ('shot-a', 's1', 'scene1', 0, 'V', 'Plan moyen', 'PM');",
    );
    legacyDb.dispose();

    final database = OcptProjectDatabase(File(filePath));

    // (a) every row the file already held survived, its abbreviation included: the version 4 step
    // is skipped, so nothing tries to add a column the file already carries.
    await expectCommonRowsSurvived(database);

    final shot = await database.select(database.ocptShotsTable).getSingle();
    expect(shot.id, "shot-a");
    expect(shot.shotSize, "Plan moyen");
    expect(shot.abbreviation, "PM");

    // (b) the version 5 shape is in place and usable, and the file now says the current schema version.
    await expectProjectVersionsAreUsable(database);
    expect(await readSchemaVersion(database), 28);

    await database.close();
  });

  test('a v5 database migrates on, gaining the resources tables', () async {
    final filePath = p.join(tempDir.path, 'legacy_v5.ocpt');

    // The shape PR #44 shipped: `project_versions` (with `content_digest` already on it) and
    // `project_info.current_version_id`, but none of the resources mode's twelve tables.
    final legacyDb = sqlite3.sqlite3.open(filePath);
    legacyDb.execute(_v5Ddl);
    legacyDb.execute('PRAGMA user_version = 5;');
    seedCommonRows(legacyDb);
    legacyDb.execute(
      "INSERT INTO project_versions (id, name, note, created_at, app_version, payload_format, "
      "payload, summary_json, created_by_device_id, content_digest) VALUES ('version1', "
      "'v1 — First read', '', '${DateTime.utc(2026, 2, 1, 10).toIso8601String()}', '0.1.0', 1, "
      "'{\"payloadFormat\":1}', '{\"pageCount\":41}', 'device-1', 'digest1');",
    );
    legacyDb.execute("UPDATE project_info SET current_version_id = 'version1' WHERE id = 1;");
    legacyDb.dispose();

    final database = OcptProjectDatabase(File(filePath));

    // (a) every row the file already held survived untouched: this step only creates tables, it
    // touches nothing that exists.
    await expectCommonRowsSurvived(database);

    final version = await database.select(database.ocptProjectVersionsTable).getSingle();
    expect(version.id, "version1");
    expect(version.contentDigest, "digest1");

    final projectInfo = await database.select(database.ocptProjectInfoTable).getSingle();
    expect(projectInfo.currentVersionId, "version1");

    // (b) the twelve resources tables exist and are usable, referencing each other and the rows
    // the file already held.
    await database
        .into(database.ocptPeopleTable)
        .insert(
          OcptPeopleTableCompanion.insert(
            id: "person1",
            firstName: const Value("Clara"),
            lastName: const Value("Dupont"),
          ),
        );

    await database
        .into(database.ocptRolesTable)
        .insert(
          OcptRolesTableCompanion.insert(
            id: "role1",
            name: "CLARA",
            kind: OcptRoleKind.speaking,
            personId: const Value("person1"),
          ),
        );

    await database
        .into(database.ocptLocationsTable)
        .insert(
          OcptLocationsTableCompanion.insert(
            id: "location1",
            name: "La maison des Pains",
            contactPersonId: const Value("person1"),
          ),
        );

    await database
        .into(database.ocptSetsTable)
        .insert(
          OcptSetsTableCompanion.insert(id: "set1", locationId: "location1", name: "Cuisine"),
        );

    await database
        .into(database.ocptElementsTable)
        .insert(
          OcptElementsTableCompanion.insert(
            id: "element1",
            category: OcptElementCategory.prop,
            name: "Valise",
            sourceKind: OcptElementSourceKind.owned,
            ownerPersonId: const Value("person1"),
          ),
        );

    await database
        .into(database.ocptAssetsTable)
        .insert(
          OcptAssetsTableCompanion.insert(
            id: "asset1",
            kind: OcptAssetKind.personPhoto,
            path: "/tmp/clara.jpg",
            addedAt: DateTime.utc(2026, 2, 2),
            personId: const Value("person1"),
          ),
        );

    await database
        .into(database.ocptLocalErasuresTable)
        .insert(
          OcptLocalErasuresTableCompanion.insert(
            personId: "person1",
            erasedAt: DateTime.utc(2026, 2, 3),
          ),
        );

    final person = await database.select(database.ocptPeopleTable).getSingle();
    expect(person.id, "person1");
    expect(person.firstName, "Clara");
    expect(person.imageRightsStatus, OcptImageRightsStatus.notApplicable);

    final role = await database.select(database.ocptRolesTable).getSingle();
    expect(role.personId, "person1");
    expect(role.kind, OcptRoleKind.speaking);

    final location = await database.select(database.ocptLocationsTable).getSingle();
    expect(location.contactPersonId, "person1");
    expect(location.permitStatus, OcptPermitStatus.toRequest);

    final setRow = await database.select(database.ocptSetsTable).getSingle();
    expect(setRow.locationId, "location1");

    final element = await database.select(database.ocptElementsTable).getSingle();
    expect(element.ownerPersonId, "person1");
    expect(element.category, OcptElementCategory.prop);

    final asset = await database.select(database.ocptAssetsTable).getSingle();
    expect(asset.personId, "person1");
    expect(asset.kind, OcptAssetKind.personPhoto);

    final erasure = await database.select(database.ocptLocalErasuresTable).getSingle();
    expect(erasure.personId, "person1");

    // (c) `local_erasures` is the one table of this schema whose rows may be deleted for real.
    await (database.delete(
      database.ocptLocalErasuresTable,
    )..where((table) => table.personId.equals("person1"))).go();
    expect(await database.select(database.ocptLocalErasuresTable).get(), isEmpty);

    // (d) the file now says the current schema version.
    expect(await readSchemaVersion(database), 28);

    await database.close();
  });

  test('a v6 database migrates on, gaining the location availabilities', () async {
    final filePath = p.join(tempDir.path, 'legacy_v6.ocpt');

    // The shape the resources mode first shipped in: every resources table, and no
    // `location_availabilities` — a location could only say when it was free in free text.
    final legacyDb = sqlite3.sqlite3.open(filePath);
    legacyDb.execute(_v5Ddl);
    legacyDb.execute(_v6ResourcesDdl);
    legacyDb.execute('PRAGMA user_version = 6;');
    seedCommonRows(legacyDb);
    legacyDb.execute(
      "INSERT INTO locations (id, name, constraints_notes, sort_key) VALUES ('location1', "
      "'La maison des Pains', 'Free on Mondays', 'V');",
    );
    legacyDb.dispose();

    final database = OcptProjectDatabase(File(filePath));

    // (a) every row the file already held survived untouched: this step only creates one table.
    await expectCommonRowsSurvived(database);

    final location = await database.select(database.ocptLocationsTable).getSingle();
    expect(location.constraintsNotes, "Free on Mondays");

    // (b) the new table exists, is usable, and carries the defaults a fresh row relies on.
    await database
        .into(database.ocptLocationAvailabilitiesTable)
        .insert(
          OcptLocationAvailabilitiesTableCompanion.insert(
            id: "availability1",
            locationId: "location1",
            startDate: DateTime.utc(2026, 3, 2),
            endDate: DateTime.utc(2026, 3, 20),
          ),
        );

    final availability = await database
        .select(database.ocptLocationAvailabilitiesTable)
        .getSingle();
    expect(availability.locationId, "location1");
    expect(availability.weekdays, ocptEveryWeekdayMask);
    expect(availability.slot, OcptDayPartSlot.fullDay);
    expect(availability.kind, OcptLocationAvailabilityKind.available);
    expect(availability.isDeleted, isFalse);

    // (c) the file now says the current schema version.
    expect(await readSchemaVersion(database), 28);

    await database.close();
  });

  test('a v7 database migrates on, gaining the currency', () async {
    final filePath = p.join(tempDir.path, 'legacy_v7.ocpt');

    // The shape version 7 left behind: `location_availabilities` exists, but `project_info` has
    // no `currency_code` yet.
    final legacyDb = sqlite3.sqlite3.open(filePath);
    legacyDb.execute(_v5Ddl);
    legacyDb.execute(_v6ResourcesDdl);
    legacyDb.execute(_v7LocationAvailabilitiesDdl);
    legacyDb.execute('PRAGMA user_version = 7;');
    seedCommonRows(legacyDb);
    legacyDb.dispose();

    final database = OcptProjectDatabase(File(filePath));

    // (a) every row the file already held survived untouched: this step only adds one column.
    await expectCommonRowsSurvived(database);

    // (b) the new column exists and defaults an already-existing project to EUR, exactly as a
    // freshly created one does when the device locale can't suggest anything better.
    final projectInfo = await database.select(database.ocptProjectInfoTable).getSingle();
    expect(projectInfo.currencyCode, "EUR");

    await database
        .update(database.ocptProjectInfoTable)
        .write(const OcptProjectInfoTableCompanion(currencyCode: Value("USD")));
    expect((await database.select(database.ocptProjectInfoTable).getSingle()).currencyCode, "USD");

    // (c) the file now says the current schema version.
    expect(await readSchemaVersion(database), 28);

    await database.close();
  });

  test('a v8 database migrates on, gaining the breakdown tables', () async {
    final filePath = p.join(tempDir.path, 'legacy_v8.ocpt');

    // The shape version 8 left behind: every resources table and the currency column, but no
    // breakdown tables and no `elements.status` column.
    final legacyDb = sqlite3.sqlite3.open(filePath);
    legacyDb.execute(_v5Ddl);
    legacyDb.execute(_v6ResourcesDdl);
    legacyDb.execute(_v7LocationAvailabilitiesDdl);
    legacyDb.execute(_v8CurrencyDdl);
    legacyDb.execute('PRAGMA user_version = 8;');
    seedCommonRows(legacyDb);
    legacyDb.execute(
      "INSERT INTO elements (id, category, name, source_kind) VALUES ('element1', 'prop', "
      "'Valise', 'owned');",
    );
    legacyDb.dispose();

    final database = OcptProjectDatabase(File(filePath));

    // (a) every row the file already held survived untouched, the element included: this step
    // only creates two tables and adds one column.
    await expectCommonRowsSurvived(database);

    final element = await database.select(database.ocptElementsTable).getSingle();
    expect(element.id, "element1");
    expect(element.name, "Valise");

    // (b) the new column exists and holds its own default on the pre-existing row — the honest
    // value for an element nobody has ever given a status.
    expect(element.status, OcptElementStatus.toFind);

    // (c) the two new tables exist, are usable, and reference the rows the file already held.
    await database
        .into(database.ocptBreakdownTagsTable)
        .insert(
          OcptBreakdownTagsTableCompanion.insert(
            id: "tag1",
            sceneId: "scene1",
            targetKind: OcptBreakdownTargetKind.element,
            elementId: const Value("element1"),
            startOffset: 0,
            endOffset: 4,
            taggedText: "desk",
          ),
        );

    final tag = await database.select(database.ocptBreakdownTagsTable).getSingle();
    expect(tag.sceneId, "scene1");
    expect(tag.targetKind, OcptBreakdownTargetKind.element);
    expect(tag.elementId, "element1");
    expect(tag.roleId, isNull);
    expect(tag.setId, isNull);
    expect(tag.needsCheck, isFalse);
    expect(tag.isDeleted, isFalse);

    await database
        .into(database.ocptSceneBreakdownsTable)
        .insert(OcptSceneBreakdownsTableCompanion.insert(id: "sceneBreakdown1", sceneId: "scene1"));

    final sceneBreakdown = await database.select(database.ocptSceneBreakdownsTable).getSingle();
    expect(sceneBreakdown.sceneId, "scene1");
    expect(sceneBreakdown.status, OcptBreakdownSceneStatus.toDo);
    expect(sceneBreakdown.notes, "");
    expect(sceneBreakdown.isDeleted, isFalse);

    // (d) `PRAGMA foreign_keys` really is enforced for the new table: a tag naming no scene the
    // file holds is refused.
    await expectLater(
      database
          .into(database.ocptBreakdownTagsTable)
          .insert(
            OcptBreakdownTagsTableCompanion.insert(
              id: "tag2",
              sceneId: "no-such-scene",
              targetKind: OcptBreakdownTargetKind.element,
              elementId: const Value("element1"),
              startOffset: 0,
              endOffset: 4,
              taggedText: "desk",
            ),
          ),
      throwsA(isA<sqlite3.SqliteException>()),
    );

    // (e) the file now says the current schema version.
    expect(await readSchemaVersion(database), 28);

    await database.close();
  });

  test('a v9 database migrates on, gaining a code for every set it already held', () async {
    final filePath = p.join(tempDir.path, 'legacy_v9.ocpt');

    // The shape version 9 left behind: every table the app has, `sets.code` among them — declared
    // since version 6 and left empty, back when it was a field the user typed into by hand.
    final legacyDb = sqlite3.sqlite3.open(filePath);
    legacyDb.execute(_v5Ddl);
    legacyDb.execute(_v6ResourcesDdl);
    legacyDb.execute(_v7LocationAvailabilitiesDdl);
    legacyDb.execute(_v8CurrencyDdl);
    legacyDb.execute(_v9BreakdownDdl);
    legacyDb.execute('PRAGMA user_version = 9;');
    seedCommonRows(legacyDb);
    legacyDb.execute("INSERT INTO locations (id, name) VALUES ('location1', 'Maison');");
    legacyDb.execute(
      "INSERT INTO sets (id, location_id, code, name, sort_key) VALUES "
      "('set1', 'location1', '', 'Cuisine', 'a'), "
      "('set2', 'location1', 'B', 'Jardin', 'b'), "
      "('set3', 'location1', '', 'Escalier', 'c'), "
      "('set4', 'location1', '', 'Cave', 'd');",
    );
    // A tombstoned set is left out of the backfill entirely: it is not on any sheet to be read
    // from, and numbering it would burn a code for nothing.
    legacyDb.execute(
      "INSERT INTO sets (id, location_id, code, name, sort_key, is_deleted) VALUES "
      "('set5', 'location1', '', 'Grenier', 'e', 1);",
    );
    legacyDb.dispose();

    final database = OcptProjectDatabase(File(filePath));

    // (a) every row the file already held survived: this step adds no column and creates no table.
    await expectCommonRowsSurvived(database);

    final sets = await (database.select(
      database.ocptSetsTable,
    )..orderBy([(table) => OrderingTerm.asc(table.sortKey)])).get();

    // (b) the sets with no code got one, numbered around the `B` somebody had typed — which is
    // left exactly as it was.
    expect(sets.map((row) => (row.id, row.code)), [
      ('set1', 'C'),
      ('set2', 'B'),
      ('set3', 'D'),
      ('set4', 'E'),
      ('set5', ''),
    ]);

    // (c) the file now says the current schema version.
    expect(await readSchemaVersion(database), 28);

    await database.close();
  });

  test(
    'a v10 database migrates on, gaining the schedule tables and erasing legacy shooting days',
    () async {
      final filePath = p.join(tempDir.path, 'legacy_v10.ocpt');

      // The shape version 10 left behind: identical to version 9's — that step only filled
      // `sets.code`, adding no column and no table, so it needs no fixture of its own.
      final legacyDb = sqlite3.sqlite3.open(filePath);
      legacyDb.execute(_v5Ddl);
      legacyDb.execute(_v6ResourcesDdl);
      legacyDb.execute(_v7LocationAvailabilitiesDdl);
      legacyDb.execute(_v8CurrencyDdl);
      legacyDb.execute(_v9BreakdownDdl);
      legacyDb.execute('PRAGMA user_version = 10;');
      seedCommonRows(legacyDb);
      legacyDb.execute(
        "INSERT INTO shots (id, screenplay_id, scene_id, position, sort_key, shooting_day) "
        "VALUES ('shot-a', 's1', 'scene1', 0, 'V', 'J3');",
      );
      legacyDb.dispose();

      final database = OcptProjectDatabase(File(filePath));

      // (a) every row the file already held survived, the shot included.
      await expectCommonRowsSurvived(database);

      final shot = await database.select(database.ocptShotsTable).getSingle();
      expect(shot.id, "shot-a");

      // (b) the legacy free-text shooting day is erased: from here on the schedule's own
      // placement is the only truth, a shooting day is always dated, and `J3` carried no date a
      // migration could have kept.
      expect(shot.shootingDay, isNull);

      // (c) the five schedule tables exist, empty: this project has never been scheduled, and the
      // migration invents nothing — a blank column and an empty schedule say the same true thing.
      expect(await database.select(database.ocptShootingDaysTable).get(), isEmpty);
      expect(await database.select(database.ocptShootingSlotsTable).get(), isEmpty);
      expect(await database.select(database.ocptShootingSlotCrewTable).get(), isEmpty);
      expect(await database.select(database.ocptShootingSlotCastTable).get(), isEmpty);
      expect(await database.select(database.ocptShootingDayBlocksTable).get(), isEmpty);

      // (d) and every one of them is usable, referencing the rows the file already held (and each
      // other).
      await database
          .into(database.ocptPeopleTable)
          .insert(
            OcptPeopleTableCompanion.insert(
              id: "person1",
              firstName: const Value("Clara"),
              lastName: const Value("Dupont"),
            ),
          );
      await database
          .into(database.ocptRolesTable)
          .insert(
            OcptRolesTableCompanion.insert(
              id: "role1",
              name: "CLARA",
              kind: OcptRoleKind.speaking,
              personId: const Value("person1"),
            ),
          );

      await database
          .into(database.ocptShootingDaysTable)
          .insert(
            OcptShootingDaysTableCompanion.insert(id: "day1", date: DateTime.utc(2026, 3, 2)),
          );
      final day = await database.select(database.ocptShootingDaysTable).getSingle();
      expect(day.status, OcptShootingDayStatus.planned);
      expect(day.isDeleted, isFalse);

      // Also usable: a night slot crossing midnight (19:00 -> 03:00 is anchored at minute 1140,
      // not taken modulo anything).
      await database
          .into(database.ocptShootingSlotsTable)
          .insert(
            OcptShootingSlotsTableCompanion.insert(
              id: "slot1",
              shootingDayId: "day1",
              anchorMinute: const Value(1140),
            ),
          );
      final slot = await database.select(database.ocptShootingSlotsTable).getSingle();
      expect(slot.anchorEdge, OcptShootingSlotAnchorEdge.start);
      expect(slot.anchorMinute, 1140);

      await database
          .into(database.ocptShootingSlotCrewTable)
          .insert(
            OcptShootingSlotCrewTableCompanion.insert(
              id: "crew1",
              slotId: "slot1",
              personId: "person1",
            ),
          );
      final crew = await database.select(database.ocptShootingSlotCrewTable).getSingle();
      expect(crew.personId, "person1");

      await database
          .into(database.ocptShootingSlotCastTable)
          .insert(
            OcptShootingSlotCastTableCompanion.insert(id: "cast1", slotId: "slot1", roleId: "role1"),
          );
      final cast = await database.select(database.ocptShootingSlotCastTable).getSingle();
      expect(cast.roleId, "role1");

      await database
          .into(database.ocptShootingDayBlocksTable)
          .insert(
            OcptShootingDayBlocksTableCompanion.insert(
              id: "block1",
              shootingDayId: "day1",
              slotId: "slot1",
              shotId: const Value("shot-a"),
            ),
          );
      final block = await database.select(database.ocptShootingDayBlocksTable).getSingle();
      expect(block.kind, OcptShootingBlockKind.shot);
      expect(block.slotId, "slot1");
      expect(block.shotId, "shot-a");

      // (e) the file now says the current schema version.
      expect(await readSchemaVersion(database), 28);

      await database.close();
    },
  );

  test(
    'a v11 database migrates on, reshaping the schedule tables for the slot rework',
    () async {
      final filePath = p.join(tempDir.path, 'legacy_v11.ocpt');

      final legacyDb = sqlite3.sqlite3.open(filePath);
      legacyDb.execute(_v5Ddl);
      legacyDb.execute(_v6ResourcesDdl);
      legacyDb.execute(_v7LocationAvailabilitiesDdl);
      legacyDb.execute(_v8CurrencyDdl);
      legacyDb.execute(_v9BreakdownDdl);
      legacyDb.execute(_v11ScheduleDdl);
      legacyDb.execute('PRAGMA user_version = 11;');
      seedCommonRows(legacyDb);

      legacyDb.execute(
        "INSERT INTO people (id, first_name, last_name) VALUES ('person1', 'Clara', 'Dupont');",
      );
      legacyDb.execute(
        "INSERT INTO roles (id, screenplay_id, name, kind) VALUES ('role1', 's1', 'CLARA', "
        "'speaking');",
      );

      legacyDb.execute(
        "INSERT INTO shooting_days (id, screenplay_id, date) VALUES "
        "('day1', 's1', '2026-03-02T00:00:00.000'), "
        "('day2', 's1', '2026-03-03T00:00:00.000');",
      );

      // day1: a tombstoned slot sorting before every live one (proving it is never picked), two
      // live slots tied on `sort_key` (proving the tie is broken by `id`), and a third live slot
      // sorting last.
      legacyDb.execute(
        "INSERT INTO shooting_slots (id, shooting_day_id, sort_key, crew_call_minute, "
        "crew_wrap_minute, is_deleted) VALUES "
        "('slotDead', 'day1', '0', 400, 1000, 1), "
        "('slotA1', 'day1', 'a', 480, 1080, 0), "
        "('slotA2', 'day1', 'a', 490, 1090, 0), "
        "('slotB', 'day1', 'b', 600, 1140, 0);",
      );
      // day2: its only slot is tombstoned, so the day has no live slot at all.
      legacyDb.execute(
        "INSERT INTO shooting_slots (id, shooting_day_id, sort_key, crew_call_minute, "
        "crew_wrap_minute, is_deleted) VALUES ('slotC', 'day2', 'a', 500, 1000, 1);",
      );

      legacyDb.execute(
        "INSERT INTO shooting_day_blocks (id, shooting_day_id, sort_key, slot_id, kind) VALUES "
        // Already pointing at a live slot: kept exactly as it was.
        "('blockKept', 'day1', 'a', 'slotB', 'wrap'), "
        // An orphan (`slot_id` null): reassigned to day1's first live slot.
        "('blockOrphanNull', 'day1', 'b', NULL, 'wrap'), "
        // An orphan the other way (`slot_id` names a tombstoned slot): reassigned too.
        "('blockOrphanDangling', 'day1', 'c', 'slotDead', 'wrap'), "
        // A hold, whose held sequence this file could only ever say in free text.
        "('blockHold', 'day1', 'd', 'slotB', 'hold'), "
        // day2 has no live slot: both of these are dropped rather than reassigned.
        "('blockDeleteNull', 'day2', 'a', NULL, 'wrap'), "
        "('blockDeleteDangling', 'day2', 'b', 'slotC', 'wrap');",
      );

      // A crew and a cast row still carrying the old, typed clock overrides — none of it is
      // reconstructed into a lead time or a group, both simply come back null.
      legacyDb.execute(
        "INSERT INTO shooting_slot_crew (id, slot_id, person_id, call_minute, wrap_minute) "
        "VALUES ('crew1', 'slotA1', 'person1', 450, 1090);",
      );
      legacyDb.execute(
        "INSERT INTO shooting_slot_cast (id, slot_id, role_id, arrival_minute, "
        "cast_call_minute, cast_wrap_minute) VALUES "
        "('cast1', 'slotA1', 'role1', 420, 480, 1000);",
      );
      // A real presence-grid override, typed by a user of that build — not merely an absent table:
      // schema version 17 drops `shooting_presences` outright, and this is what proves a file that
      // genuinely held one loses it just as cleanly as one that never did.
      legacyDb.execute(
        "INSERT INTO shooting_presences (id, shooting_day_id, person_id, code) VALUES "
        "('presence1', 'day1', 'person1', 'travelling');",
      );
      legacyDb.dispose();

      final database = OcptProjectDatabase(File(filePath));

      // (a) every row the file already held survived.
      await expectCommonRowsSurvived(database);

      // (b) the old `crew_call_minute` is carried across into the anchor trio schema version 14
      // settles on — pinned by the start edge, at the hour the file already had, reading nothing
      // off another slot — and the three dropped columns are simply gone (there is no getter left
      // to read them through). A file coming from version 11 is reshaped straight onto that current
      // shape by `_alterScheduleTablesToV12`, which is why the version 14 step skips it.
      final slotsById = {
        for (final row in await database.select(database.ocptShootingSlotsTable).get())
          row.id: row,
      };
      expect(slotsById['slotA1']!.anchorEdge, OcptShootingSlotAnchorEdge.start);
      expect(slotsById['slotA1']!.anchorMinute, 480);
      expect(slotsById['slotA1']!.anchorSlotId, isNull);
      expect(slotsById['slotA2']!.anchorMinute, 490);
      expect(slotsById['slotB']!.anchorMinute, 600);

      // (c) every orphan block landed on its day's first *live* slot — the tombstoned `slotDead`,
      // despite sorting first, is never picked, and the tie between `slotA1` and `slotA2` (both
      // `sort_key` `a`) is broken by `id`, `slotA1` winning.
      final blocksById = {
        for (final row in await database.select(database.ocptShootingDayBlocksTable).get())
          row.id: row,
      };
      expect(blocksById.keys, {
        'blockKept',
        'blockOrphanNull',
        'blockOrphanDangling',
        'blockHold',
      });
      expect(blocksById['blockKept']!.slotId, 'slotB');
      expect(blocksById['blockOrphanNull']!.slotId, 'slotA1');
      expect(blocksById['blockOrphanDangling']!.slotId, 'slotA1');

      // (c bis) every block, the hold included, comes out with no scene named: the column is new,
      // and a hold's free-text label is not a scene id to read one out of.
      expect(blocksById.values.every((row) => row.sceneId == null), isTrue);

      // (d) both of day2's blocks are gone: day2 has no live slot for either to land on.
      expect(blocksById.containsKey('blockDeleteNull'), isFalse);
      expect(blocksById.containsKey('blockDeleteDangling'), isFalse);

      // (e) the crew and cast rows survived, their old clock overrides simply dropped rather than
      // reconstructed into a lead time or a group — neither column exists on this build's rows at
      // all any more.
      final crew = await database.select(database.ocptShootingSlotCrewTable).getSingle();
      expect(crew.personId, "person1");

      final cast = await database.select(database.ocptShootingSlotCastTable).getSingle();
      expect(cast.roleId, "role1");

      // (e bis) `shooting_presences` is gone outright — `DROP TABLE IF EXISTS`, unconditionally, so
      // the real override this file held is lost exactly as cleanly as if the table had never
      // existed. Nothing is reconstructed from it anywhere: the schema simply has no table left to
      // read one back from.
      final shape = await readSchemaShape(database);
      expect(shape.containsKey('shooting_presences'), isFalse);

      // (f) the file now says the current schema version.
      expect(await readSchemaVersion(database), 28);

      await database.close();
    },
  );

  test(
    'a v12 database migrates on, dropping the groups table and their lead times',
    () async {
      final filePath = p.join(tempDir.path, 'legacy_v12.ocpt');

      final legacyDb = sqlite3.sqlite3.open(filePath);
      legacyDb.execute(_v5Ddl);
      legacyDb.execute(_v6ResourcesDdl);
      legacyDb.execute(_v7LocationAvailabilitiesDdl);
      legacyDb.execute(_v8CurrencyDdl);
      legacyDb.execute(_v9BreakdownDdl);
      legacyDb.execute(_v12ScheduleDdl);
      legacyDb.execute('PRAGMA user_version = 12;');
      seedCommonRows(legacyDb);

      legacyDb.execute(
        "INSERT INTO people (id, first_name, last_name) VALUES ('person1', 'Clara', 'Dupont');",
      );
      legacyDb.execute(
        "INSERT INTO roles (id, screenplay_id, name, kind) VALUES ('role1', 's1', 'CLARA', "
        "'speaking');",
      );
      legacyDb.execute(
        "INSERT INTO shooting_days (id, screenplay_id, date) VALUES "
        "('day1', 's1', '2026-03-02T00:00:00.000');",
      );
      legacyDb.execute(
        "INSERT INTO shooting_day_groups (id, shooting_day_id, label, lead_minutes) VALUES "
        "('group1', 'day1', 'Équipe image', 20);",
      );
      legacyDb.execute(
        "INSERT INTO shooting_slots (id, shooting_day_id, start_minute) VALUES ('slot1', 'day1', "
        "480);",
      );
      // A crew row inheriting its group's figure (its own `lead_minutes` null) and a cast row with
      // its own figure and no group — both patterns [_alterScheduleTablesToV13] must drop cleanly.
      legacyDb.execute(
        "INSERT INTO shooting_slot_crew (id, slot_id, person_id, group_id, lead_minutes) VALUES "
        "('crew1', 'slot1', 'person1', 'group1', NULL);",
      );
      legacyDb.execute(
        "INSERT INTO shooting_slot_cast (id, slot_id, role_id, group_id, lead_minutes) VALUES "
        "('cast1', 'slot1', 'role1', NULL, 45);",
      );
      legacyDb.dispose();

      final database = OcptProjectDatabase(File(filePath));

      // (a) every row the file already held survived.
      await expectCommonRowsSurvived(database);

      // (b) `shooting_day_groups` is gone outright — `DROP TABLE IF EXISTS`, unconditionally, so a
      // file that genuinely carried the table loses it just as cleanly as one that never did.
      final shape = await readSchemaShape(database);
      expect(shape.containsKey('shooting_day_groups'), isFalse);

      // (c) the crew and cast rows survived, their group and lead time simply dropped — nothing is
      // reconstructed, exactly as no lead time is guessed out of the v11-to-v12 step's own dropped
      // clocks.
      final crew = await database.select(database.ocptShootingSlotCrewTable).getSingle();
      expect(crew.id, "crew1");
      expect(crew.personId, "person1");

      final cast = await database.select(database.ocptShootingSlotCastTable).getSingle();
      expect(cast.id, "cast1");
      expect(cast.roleId, "role1");

      // (d) the file now says the current schema version.
      expect(await readSchemaVersion(database), 28);

      await database.close();
    },
  );

  test(
    'a v13 database migrates on, anchoring every slot by the start it already had',
    () async {
      final filePath = p.join(tempDir.path, 'legacy_v13.ocpt');

      final legacyDb = sqlite3.sqlite3.open(filePath);
      legacyDb.execute(_v5Ddl);
      legacyDb.execute(_v6ResourcesDdl);
      legacyDb.execute(_v7LocationAvailabilitiesDdl);
      legacyDb.execute(_v8CurrencyDdl);
      legacyDb.execute(_v9BreakdownDdl);
      legacyDb.execute(_v13ScheduleDdl);
      legacyDb.execute('PRAGMA user_version = 13;');
      seedCommonRows(legacyDb);

      legacyDb.execute(
        "INSERT INTO shooting_days (id, screenplay_id, date) VALUES "
        "('day1', 's1', '2026-03-02T00:00:00.000');",
      );
      legacyDb.execute(
        "INSERT INTO shooting_slots (id, shooting_day_id, label, start_minute) VALUES "
        "('slotDay', 'day1', 'Matin', 480);",
      );
      // A night slot: its start is stored past 1440 and must come across untouched, nothing ever
      // taken modulo anything.
      legacyDb.execute(
        "INSERT INTO shooting_slots (id, shooting_day_id, label, start_minute) VALUES "
        "('slotNight', 'day1', 'Nuit', 1140);",
      );
      legacyDb.dispose();

      final database = OcptProjectDatabase(File(filePath));

      // (a) every row the file already held survived.
      await expectCommonRowsSurvived(database);

      // (b) every slot comes out anchored by its **start**, at the very hour it already had, and
      // reading nothing off another slot — which is exactly how the app behaved for every file
      // reaching this step, so a day drawn after the migration is the day drawn before it. Nothing
      // is guessed the other way round: no slot becomes end-anchored because its blocks happen to
      // land on a round hour.
      final slotsById = {
        for (final row in await database.select(database.ocptShootingSlotsTable).get())
          row.id: row,
      };
      expect(slotsById.keys, {'slotDay', 'slotNight'});
      expect(slotsById['slotDay']!.anchorEdge, OcptShootingSlotAnchorEdge.start);
      expect(slotsById['slotDay']!.anchorMinute, 480);
      expect(slotsById['slotDay']!.anchorSlotId, isNull);
      expect(slotsById['slotDay']!.label, "Matin");
      expect(slotsById['slotNight']!.anchorEdge, OcptShootingSlotAnchorEdge.start);
      expect(slotsById['slotNight']!.anchorMinute, 1140);
      expect(slotsById['slotNight']!.anchorSlotId, isNull);

      // (c) the file now says the current schema version.
      expect(await readSchemaVersion(database), 28);

      await database.close();
    },
  );

  test('a v14 database migrates on, gaining an empty role_elements', () async {
    final filePath = p.join(tempDir.path, 'legacy_v14.ocpt');

    final legacyDb = sqlite3.sqlite3.open(filePath);
    legacyDb.execute(_v5Ddl);
    legacyDb.execute(_v6ResourcesDdl);
    legacyDb.execute(_v7LocationAvailabilitiesDdl);
    legacyDb.execute(_v8CurrencyDdl);
    legacyDb.execute(_v9BreakdownDdl);
    legacyDb.execute(_v14ScheduleDdl);
    legacyDb.execute('PRAGMA user_version = 14;');
    seedCommonRows(legacyDb);

    // A role and an element the file already held, so the new table can actually be written
    // against them rather than merely existing.
    legacyDb.execute(
      "INSERT INTO roles (id, screenplay_id, name, kind, sort_key) VALUES "
      "('role1', 's1', 'CLARA', 'speaking', 'a');",
    );
    legacyDb.execute(
      "INSERT INTO elements (id, name, category, source_kind) VALUES "
      "('elem1', 'Manteau rouge', 'costume', 'owned');",
    );
    legacyDb.dispose();

    final database = OcptProjectDatabase(File(filePath));

    // (a) every row the file already held survived — the migration adds a table and touches
    // nothing else.
    await expectCommonRowsSurvived(database);
    expect((await database.select(database.ocptRolesTable).getSingle()).name, "CLARA");
    expect((await database.select(database.ocptElementsTable).getSingle()).name, "Manteau rouge");

    // (b) the new table is there and **empty**: a project that predates it linked no role to any
    // element, which is the only truthful reading — nothing is deduced from the breakdown's tags,
    // which answer a different question entirely.
    expect(await database.select(database.ocptRoleElementsTable).get(), isEmpty);

    // (c) and it is usable, foreign keys included.
    await database
        .into(database.ocptRoleElementsTable)
        .insert(
          OcptRoleElementsTableCompanion.insert(
            id: 'link1',
            roleId: 'role1',
            elementId: 'elem1',
            notes: const Value("Taché à partir de la séquence 12"),
          ),
        );
    final link = await database.select(database.ocptRoleElementsTable).getSingle();
    expect(link.roleId, 'role1');
    expect(link.elementId, 'elem1');
    expect(link.isDeleted, isFalse);

    // (d) the file now says the current schema version.
    expect(await readSchemaVersion(database), 28);

    await database.close();
  });

  test(
    "a v15 database migrates on, gaining a person's own maximum daily presence",
    () async {
      final filePath = p.join(tempDir.path, 'legacy_v15.ocpt');

      final legacyDb = sqlite3.sqlite3.open(filePath);
      legacyDb.execute(_v5Ddl);
      legacyDb.execute(_v6ResourcesDdl);
      legacyDb.execute(_v7LocationAvailabilitiesDdl);
      legacyDb.execute(_v8CurrencyDdl);
      legacyDb.execute(_v9BreakdownDdl);
      legacyDb.execute(_v14ScheduleDdl);
      legacyDb.execute(_v15RoleElementsDdl);
      legacyDb.execute('PRAGMA user_version = 15;');
      seedCommonRows(legacyDb);

      // A person the file already held, so the new column can actually be read and written against
      // a real row rather than merely existing.
      legacyDb.execute(
        "INSERT INTO people (id, first_name, last_name) VALUES ('person1', 'Léa', 'Petit');",
      );
      legacyDb.dispose();

      final database = OcptProjectDatabase(File(filePath));

      // (a) every row the file already held survived — the migration adds a column and touches
      // nothing else.
      await expectCommonRowsSurvived(database);
      final person = await database.select(database.ocptPeopleTable).getSingle();
      expect(person.firstName, "Léa");

      // (b) the new column defaults to **null**: a project that predates it never had anybody's
      // maximum recorded, which is "nobody has said" rather than "no limit is imposed".
      expect(person.maxDailyPresenceMinutes, isNull);

      // (c) and it is writable.
      await database
          .update(database.ocptPeopleTable)
          .write(
            const OcptPeopleTableCompanion(maxDailyPresenceMinutes: Value(480)),
          );
      final updated = await database.select(database.ocptPeopleTable).getSingle();
      expect(updated.maxDailyPresenceMinutes, 480);

      // (d) the file now says the current schema version.
      expect(await readSchemaVersion(database), 28);

      await database.close();
    },
  );

  test('a v16 database migrates on, gaining guests and events', () async {
    final filePath = p.join(tempDir.path, 'legacy_v16.ocpt');

    final legacyDb = sqlite3.sqlite3.open(filePath);
    legacyDb.execute(_v5Ddl);
    legacyDb.execute(_v6ResourcesDdl);
    legacyDb.execute(_v7LocationAvailabilitiesDdl);
    legacyDb.execute(_v8CurrencyDdl);
    legacyDb.execute(_v9BreakdownDdl);
    legacyDb.execute(_v14ScheduleDdl);
    legacyDb.execute(_v15RoleElementsDdl);
    legacyDb.execute(_v16MaxDailyPresenceMinutesDdl);
    legacyDb.execute('PRAGMA user_version = 16;');
    seedCommonRows(legacyDb);

    // A day, a slot and a person the file already held, so the two new tables can actually be
    // written against real rows rather than merely existing.
    legacyDb.execute(
      "INSERT INTO shooting_days (id, screenplay_id, date) VALUES "
      "('day1', 's1', '2026-03-10T00:00:00.000Z');",
    );
    legacyDb.execute(
      "INSERT INTO shooting_slots (id, shooting_day_id, anchor_minute) VALUES "
      "('slot1', 'day1', 480);",
    );
    legacyDb.execute(
      "INSERT INTO people (id, first_name, last_name) VALUES ('person1', 'Léa', 'Petit');",
    );
    legacyDb.dispose();

    final database = OcptProjectDatabase(File(filePath));

    // (a) every row the file already held survived — the migration adds two tables and touches
    // nothing else.
    await expectCommonRowsSurvived(database);
    expect((await database.select(database.ocptShootingDaysTable).getSingle()).id, "day1");
    expect((await database.select(database.ocptShootingSlotsTable).getSingle()).id, "slot1");
    expect((await database.select(database.ocptPeopleTable).getSingle()).firstName, "Léa");

    // (b) the two new tables are there and **empty**: a project that predates them had no way to
    // say a day had a guest or an event of its own.
    expect(await database.select(database.ocptShootingSlotGuestsTable).get(), isEmpty);
    expect(await database.select(database.ocptShootingDayEventsTable).get(), isEmpty);

    // (c) and both are usable, foreign keys included.
    await database
        .into(database.ocptShootingSlotGuestsTable)
        .insert(
          OcptShootingSlotGuestsTableCompanion.insert(
            id: "guest1",
            slotId: "slot1",
            personId: const Value("person1"),
          ),
        );
    final guest = await database.select(database.ocptShootingSlotGuestsTable).getSingle();
    expect(guest.slotId, "slot1");
    expect(guest.personId, "person1");
    expect(guest.isDeleted, isFalse);

    await database
        .into(database.ocptShootingDayEventsTable)
        .insert(
          OcptShootingDayEventsTableCompanion.insert(
            id: "event1",
            shootingDayId: "day1",
            minute: 1020,
            label: const Value("Feu d'artifice du village"),
          ),
        );
    final event = await database.select(database.ocptShootingDayEventsTable).getSingle();
    expect(event.shootingDayId, "day1");
    expect(event.minute, 1020);
    expect(event.isDeleted, isFalse);

    // (d) the file now says the current schema version.
    expect(await readSchemaVersion(database), 28);

    await database.close();
  });

  test(
    'a v16 database migrates on, gaining a block crew note, asset validity dates and a '
    'minimum rest',
    () async {
      final filePath = p.join(tempDir.path, 'legacy_v16_columns.ocpt');

      final legacyDb = sqlite3.sqlite3.open(filePath);
      legacyDb.execute(_v5Ddl);
      legacyDb.execute(_v6ResourcesDdl);
      legacyDb.execute(_v7LocationAvailabilitiesDdl);
      legacyDb.execute(_v8CurrencyDdl);
      legacyDb.execute(_v9BreakdownDdl);
      legacyDb.execute(_v14ScheduleDdl);
      legacyDb.execute(_v15RoleElementsDdl);
      legacyDb.execute(_v16MaxDailyPresenceMinutesDdl);
      legacyDb.execute('PRAGMA user_version = 16;');
      seedCommonRows(legacyDb);

      // A day, a slot and a block the file already held, so the new `crew_note` column can be read
      // against a real row rather than merely existing.
      legacyDb.execute(
        "INSERT INTO shooting_days (id, screenplay_id, date) VALUES "
        "('day1', 's1', '2026-03-10T00:00:00.000Z');",
      );
      legacyDb.execute(
        "INSERT INTO shooting_slots (id, shooting_day_id, anchor_minute) VALUES "
        "('slot1', 'day1', 480);",
      );
      legacyDb.execute(
        "INSERT INTO shooting_day_blocks (id, shooting_day_id, slot_id) VALUES "
        "('block1', 'day1', 'slot1');",
      );

      // An asset the file already held, so the new `valid_from`/`valid_until` columns can be read
      // against a real row too.
      legacyDb.execute(
        "INSERT INTO assets (id, kind, path, added_at) VALUES "
        "('asset1', 'document', '/permits/mairie.pdf', '2026-01-01T00:00:00.000Z');",
      );
      legacyDb.dispose();

      final database = OcptProjectDatabase(File(filePath));

      // (a) every row the file already held survived — the migration only adds columns.
      await expectCommonRowsSurvived(database);
      expect((await database.select(database.ocptShootingDayBlocksTable).getSingle()).id, "block1");
      expect((await database.select(database.ocptAssetsTable).getSingle()).id, "asset1");

      // (b) the three new columns default to what a project that predates them truthfully recorded:
      // an empty crew note (a block's own default), and null for the rest — "nobody has said",
      // never "always" or "never".
      final block = await database.select(database.ocptShootingDayBlocksTable).getSingle();
      expect(block.crewNote, "");
      final asset = await database.select(database.ocptAssetsTable).getSingle();
      expect(asset.validFrom, isNull);
      expect(asset.validUntil, isNull);
      final projectInfo = await database.select(database.ocptProjectInfoTable).getSingle();
      expect(projectInfo.minimumRestMinutes, isNull);

      // (c) and all three are writable.
      await database
          .update(database.ocptShootingDayBlocksTable)
          .write(
            const OcptShootingDayBlocksTableCompanion(
              crewNote: Value("Le groupe électrogène arrive pendant ce déplacement"),
            ),
          );
      expect(
        (await database.select(database.ocptShootingDayBlocksTable).getSingle()).crewNote,
        "Le groupe électrogène arrive pendant ce déplacement",
      );

      final validFrom = DateTime.utc(2026, 3, 10);
      final validUntil = DateTime.utc(2026, 3, 31);
      await database
          .update(database.ocptAssetsTable)
          .write(
            OcptAssetsTableCompanion(validFrom: Value(validFrom), validUntil: Value(validUntil)),
          );
      final updatedAsset = await database.select(database.ocptAssetsTable).getSingle();
      expect(updatedAsset.validFrom, validFrom);
      expect(updatedAsset.validUntil, validUntil);

      await database
          .update(database.ocptProjectInfoTable)
          .write(const OcptProjectInfoTableCompanion(minimumRestMinutes: Value(660)));
      expect(
        (await database.select(database.ocptProjectInfoTable).getSingle()).minimumRestMinutes,
        660,
      );

      // (d) the file now says the current schema version.
      expect(await readSchemaVersion(database), 28);

      await database.close();
    },
  );

  test(
    'a v17 database migrates on, numbering its screenplay, deriving role_episodes and losing '
    'the day link',
    () async {
      final filePath = p.join(tempDir.path, 'legacy_v17.ocpt');

      final legacyDb = sqlite3.sqlite3.open(filePath);
      legacyDb.execute(_v17Ddl);
      legacyDb.execute('PRAGMA user_version = 17;');
      seedCommonRows(legacyDb);

      // Two roles the screenplay already held: one live, from the screenplay, and one already
      // tombstoned — only the live one is expected to gain a `role_episodes` link.
      legacyDb.execute(
        "INSERT INTO roles (id, screenplay_id, name, kind, is_from_screenplay) VALUES "
        "('role1', 's1', 'CLARA', 'speaking', 1);",
      );
      legacyDb.execute(
        "INSERT INTO roles (id, screenplay_id, name, kind, is_from_screenplay, is_deleted) "
        "VALUES ('role2', 's1', 'MARC', 'speaking', 1, 1);",
      );

      // A shooting day the file already held, naming the same screenplay — so the column drop can
      // be checked against a real row, not an empty table.
      legacyDb.execute(
        "INSERT INTO shooting_days (id, screenplay_id, date, status) VALUES "
        "('day1', 's1', '2026-03-10T00:00:00.000Z', 'planned');",
      );
      legacyDb.dispose();

      final database = OcptProjectDatabase(File(filePath));

      // (a) every row the file already held survived.
      await expectCommonRowsSurvived(database);

      // (b) the single screenplay comes out episode 1, given a real, non-empty `sortKey` — a file
      // reaching this step has always held exactly one screenplay in practice, so this is simply
      // "that screenplay is episode 1".
      final screenplay = await database.select(database.ocptScreenplaysTable).getSingle();
      expect(screenplay.number, 1);
      expect(screenplay.sortKey, isNotEmpty);

      // (c) the live role gained exactly one `role_episodes` row, pointing at that screenplay,
      // whose own id is the role's own id: deterministic, and unique since a role held exactly one
      // episode at the moment of the derivation (`docs/adr/0019-one-project-several-episodes.md`).
      final links = await database.select(database.ocptRoleEpisodesTable).get();
      expect(links, hasLength(1));
      expect(links.single.id, 'role1');
      expect(links.single.roleId, 'role1');
      expect(links.single.screenplayId, 's1');
      expect(links.single.isDeleted, isFalse);

      // (d) the tombstoned role gained no link at all: it named no episode worth carrying forward,
      // tombstoned or not.
      final tombstonedRoleLinks = await (database.select(
        database.ocptRoleEpisodesTable,
      )..where((table) => table.roleId.equals('role2'))).get();
      expect(tombstonedRoleLinks, isEmpty);

      // (e) the shooting day survived with everything else it held intact, simply belonging to no
      // episode any more — nothing is reconstructed on its way out.
      final day = await database.select(database.ocptShootingDaysTable).getSingle();
      expect(day.id, 'day1');
      expect(day.status, OcptShootingDayStatus.planned);
      expect(day.isDeleted, isFalse);

      // (f) `roles` and `shooting_days` no longer carry `screenplay_id` at all.
      final shape = await readSchemaShape(database);
      expect(shape['roles']!.any((column) => column.startsWith('screenplay_id ')), isFalse);
      expect(shape['shooting_days']!.any((column) => column.startsWith('screenplay_id ')), isFalse);

      // (g) and `role_episodes` still really references the `roles` table the step above dropped
      // and recreated under it. `readSchemaShape` compares columns, never foreign keys, so it would
      // say nothing about a reference left pointing at the temporary table `Migrator.alterTable`
      // renames away — the one thing this whole ordering could plausibly break. Asserted through an
      // orphan insert rather than by reading `PRAGMA foreign_key_list`, since what matters is that
      // the constraint is *enforced* on the migrated file, `beforeOpen`'s own pragma included.
      await expectLater(
        database.customStatement(
          "INSERT INTO role_episodes (id, role_id, screenplay_id) VALUES ('orphan', 'nobody', 's1')",
        ),
        throwsA(anything),
      );

      // (h) the file now says the current schema version.
      expect(await readSchemaVersion(database), 28);

      // (i) `project_info.screenplay_language` didn't exist at version 17: the migration adds it
      // unconditionally, and gets no backfill, so a file that never named a language reads exactly
      // as truthfully null after the migration as "nobody has said" was before it.
      final projectInfo = await database.select(database.ocptProjectInfoTable).getSingle();
      expect(projectInfo.screenplayLanguage, isNull);

      // (j) `project_dictionary_words` didn't exist before this version either: the migration
      // creates it fresh, empty — a project migrating onto this version has taught its spell
      // checker nothing yet.
      expect(await database.select(database.ocptProjectDictionaryWordsTable).get(), isEmpty);

      // (k) neither did `budget_postes`/`budget_lines`, or the three budget columns of
      // `project_info`: a project migrating onto this version has no budget yet, and has recorded
      // none of the three figures — "nobody has said", exactly as (i) already reads for the
      // screenplay language.
      expect(await database.select(database.ocptBudgetPostesTable).get(), isEmpty);
      expect(await database.select(database.ocptBudgetLinesTable).get(), isEmpty);
      expect(projectInfo.defaultVatRateBasisPoints, isNull);
      expect(projectInfo.mealPriceCents, isNull);
      expect(projectInfo.snackPriceCents, isNull);

      // (l) and both new tables are usable, foreign keys included: a poste, then a line pointing at
      // it and, optionally, at an element.
      await database
          .into(database.ocptBudgetPostesTable)
          .insert(
            OcptBudgetPostesTableCompanion.insert(
              id: "poste1",
              label: "Personnel",
              code: const Value("2"),
              sortKey: const Value("V"),
            ),
          );
      await database
          .into(database.ocptBudgetLinesTable)
          .insert(
            OcptBudgetLinesTableCompanion.insert(
              id: "line1",
              posteId: "poste1",
              label: "First assistant camera",
              sortKey: const Value("V"),
            ),
          );
      final poste = await database.select(database.ocptBudgetPostesTable).getSingle();
      expect(poste.label, "Personnel");
      expect(poste.isDeleted, isFalse);
      final line = await database.select(database.ocptBudgetLinesTable).getSingle();
      expect(line.posteId, "poste1");
      expect(line.quantityMilli, 1000);
      expect(line.isTaxInclusive, isTrue);
      expect(line.vatRateBasisPoints, isNull);

      await database
          .update(database.ocptProjectInfoTable)
          .write(
            const OcptProjectInfoTableCompanion(
              defaultVatRateBasisPoints: Value(2000),
              mealPriceCents: Value(1250),
              snackPriceCents: Value(350),
            ),
          );
      final updatedProjectInfo = await database.select(database.ocptProjectInfoTable).getSingle();
      expect(updatedProjectInfo.defaultVatRateBasisPoints, 2000);
      expect(updatedProjectInfo.mealPriceCents, 1250);
      expect(updatedProjectInfo.snackPriceCents, 350);

      await database.close();
    },
  );

  test(
    'a v25 database migrates on, gaining the cash journal',
    () async {
      final filePath = p.join(tempDir.path, 'legacy_v25.ocpt');

      final legacyDb = sqlite3.sqlite3.open(filePath);
      legacyDb.execute(_v19Ddl);
      legacyDb.execute(_v20RoleCandidatesDdl);
      legacyDb.execute(_v24ShootingBlockCandidatesDdl);
      legacyDb.execute(_v25BudgetFoundationsDdl);
      legacyDb.execute('PRAGMA user_version = 25;');
      seedCommonRows(legacyDb);

      // A poste, a line pricing it, and an asset already referencing a person — all rows the
      // migration must carry through untouched, so the new tables and column can be checked
      // against a file that already held real data rather than an empty one.
      legacyDb.execute(
        "INSERT INTO budget_postes (id, sort_key, code, label) VALUES "
        "('poste1', 'V', '2', 'Personnel');",
      );
      legacyDb.execute(
        "INSERT INTO budget_lines (id, sort_key, poste_id, label) VALUES "
        "('line1', 'V', 'poste1', 'Ingénieur du son');",
      );
      legacyDb.execute(
        "INSERT INTO assets (id, kind, path, added_at) VALUES "
        "('asset1', 'document', '/tmp/permit.pdf', '2026-01-01T00:00:00.000Z');",
      );
      legacyDb.dispose();

      final database = OcptProjectDatabase(File(filePath));

      // (a) every row the file already held survived.
      await expectCommonRowsSurvived(database);
      final poste = await database.select(database.ocptBudgetPostesTable).getSingle();
      expect(poste.label, "Personnel");
      final line = await database.select(database.ocptBudgetLinesTable).getSingle();
      expect(line.posteId, "poste1");
      final asset = await database.select(database.ocptAssetsTable).getSingle();
      expect(asset.path, "/tmp/permit.pdf");

      // (b) `budget_entries`/`budget_commitments` didn't exist before this version: the migration
      // creates them fresh, empty — a project migrating onto this version has recorded no cash
      // movement and owes nothing yet.
      expect(await database.select(database.ocptBudgetEntriesTable).get(), isEmpty);
      expect(await database.select(database.ocptBudgetCommitmentsTable).get(), isEmpty);

      // (c) the file's one asset gained a null `budget_entry_id`: it predates the column, and
      // nothing here is reconstructed onto it — a document asset stays a document, naming no
      // journal entry.
      expect(asset.budgetEntryId, isNull);

      // (d) the file now says the current schema version.
      expect(await readSchemaVersion(database), 28);

      // (e) and both new tables are usable, foreign keys included: an entry against the poste
      // already carried, then a commitment pointing at the same poste and settled by that entry.
      await database
          .into(database.ocptBudgetEntriesTable)
          .insert(
            OcptBudgetEntriesTableCompanion.insert(
              id: "entry1",
              date: DateTime.utc(2026, 3, 10),
              label: "Location camion",
              posteId: const Value("poste1"),
              debitCents: const Value(15000),
            ),
          );
      await database
          .into(database.ocptBudgetCommitmentsTable)
          .insert(
            OcptBudgetCommitmentsTableCompanion.insert(
              id: "commitment1",
              posteId: "poste1",
              label: "Assurance",
              amountCents: const Value(15000),
              settledEntryId: const Value("entry1"),
            ),
          );

      final entry = await database.select(database.ocptBudgetEntriesTable).getSingle();
      expect(entry.debitCents, 15000);
      expect(entry.isTaxInclusive, isTrue);
      expect(entry.voucherNumber, "");

      final commitment = await database.select(database.ocptBudgetCommitmentsTable).getSingle();
      expect(commitment.settledEntryId, "entry1");
      expect(commitment.status, OcptBudgetCommitmentStatus.quoteAccepted);

      // (f) and a fresh asset can now name that entry as the voucher it stands for.
      await database
          .into(database.ocptAssetsTable)
          .insert(
            OcptAssetsTableCompanion.insert(
              id: "asset2",
              kind: OcptAssetKind.receipt,
              path: "/tmp/facture.pdf",
              addedAt: DateTime.utc(2026, 3, 10),
              budgetEntryId: const Value("entry1"),
            ),
          );
      final receiptAsset = await (database.select(
        database.ocptAssetsTable,
      )..where((table) => table.id.equals("asset2"))).getSingle();
      expect(receiptAsset.budgetEntryId, "entry1");

      await database.close();
    },
  );

  test(
    'a v26 database migrates on, gaining the financing plan',
    () async {
      final filePath = p.join(tempDir.path, 'legacy_v26.ocpt');

      final legacyDb = sqlite3.sqlite3.open(filePath);
      legacyDb.execute(_v19Ddl);
      legacyDb.execute(_v20RoleCandidatesDdl);
      legacyDb.execute(_v24ShootingBlockCandidatesDdl);
      legacyDb.execute(_v25BudgetFoundationsDdl);
      legacyDb.execute(_v26CashJournalDdl);
      legacyDb.execute('PRAGMA user_version = 26;');
      seedCommonRows(legacyDb);

      // A poste, an entry against it and a person already on the address book — all rows the
      // migration must carry through untouched, so the new tables and columns can be checked
      // against a file that already held real data rather than an empty one.
      legacyDb.execute(
        "INSERT INTO budget_postes (id, sort_key, code, label) VALUES "
        "('poste1', 'V', '2', 'Personnel');",
      );
      legacyDb.execute(
        "INSERT INTO budget_entries (id, sort_key, date, label, poste_id, debit_cents, "
        "voucher_number) VALUES "
        "('entry1', 'V', '2026-03-10T00:00:00.000Z', 'Location camion', 'poste1', 15000, 'J-001');",
      );
      legacyDb.execute(
        "INSERT INTO people (id, sort_key, first_name) VALUES ('person1', 'V', 'Clara');",
      );
      legacyDb.dispose();

      final database = OcptProjectDatabase(File(filePath));

      // (a) every row the file already held survived.
      await expectCommonRowsSurvived(database);
      final entry = await database.select(database.ocptBudgetEntriesTable).getSingle();
      expect(entry.label, "Location camion");
      final person = await database.select(database.ocptPeopleTable).getSingle();
      expect(person.firstName, "Clara");

      // (b) `budget_mileage_rates`/`budget_resources` didn't exist before this version: the
      // migration creates them fresh, empty — a project migrating onto this version names no rate
      // of its own and has no financing plan yet.
      expect(await database.select(database.ocptBudgetMileageRatesTable).get(), isEmpty);
      expect(await database.select(database.ocptBudgetResourcesTable).get(), isEmpty);

      // (c) the file's existing entry and person both gained null new columns: nothing here is
      // reconstructed onto them — an entry settles no resource it never named, and a person claims
      // no commute or rate they never recorded.
      expect(entry.resourceId, isNull);
      expect(person.commuteKmMilli, isNull);
      expect(person.mileageRateId, isNull);

      // (d) the file now says the current schema version.
      expect(await readSchemaVersion(database), 28);

      // (e) and every new table and column is usable, foreign keys included: a mileage rate, a
      // resource, an entry naming that resource, and the existing person naming both.
      await database
          .into(database.ocptBudgetMileageRatesTable)
          .insert(
            OcptBudgetMileageRatesTableCompanion.insert(
              id: "rate1",
              label: "Voiture personnelle",
              ratePerKmMilliCents: const Value(52900),
            ),
          );
      await database
          .into(database.ocptBudgetResourcesTable)
          .insert(
            OcptBudgetResourcesTableCompanion.insert(
              id: "resource1",
              label: "Région Île-de-France",
              amountCents: const Value(500000),
            ),
          );
      await (database.update(
        database.ocptBudgetEntriesTable,
      )..where((table) => table.id.equals("entry1"))).write(
        const OcptBudgetEntriesTableCompanion(resourceId: Value("resource1")),
      );
      await (database.update(
        database.ocptPeopleTable,
      )..where((table) => table.id.equals("person1"))).write(
        const OcptPeopleTableCompanion(
          commuteKmMilli: Value(1484000),
          mileageRateId: Value("rate1"),
        ),
      );

      final rate = await database.select(database.ocptBudgetMileageRatesTable).getSingle();
      expect(rate.ratePerKmMilliCents, 52900);

      final resource = await database.select(database.ocptBudgetResourcesTable).getSingle();
      expect(resource.amountCents, 500000);
      expect(resource.status, OcptBudgetResourceStatus.applied);
      expect(resource.groupKind, OcptBudgetResourceGroupKind.subsidy);

      final updatedEntry = await database.select(database.ocptBudgetEntriesTable).getSingle();
      expect(updatedEntry.resourceId, "resource1");

      final updatedPerson = await database.select(database.ocptPeopleTable).getSingle();
      expect(updatedPerson.commuteKmMilli, 1484000);
      expect(updatedPerson.mileageRateId, "rate1");

      await database.close();
    },
  );

  test(
    'a v27 database migrates on, gaining the sharing view',
    () async {
      final filePath = p.join(tempDir.path, 'legacy_v27.ocpt');

      final legacyDb = sqlite3.sqlite3.open(filePath);
      legacyDb.execute(_v19Ddl);
      legacyDb.execute(_v20RoleCandidatesDdl);
      legacyDb.execute(_v24ShootingBlockCandidatesDdl);
      legacyDb.execute(_v25BudgetFoundationsDdl);
      legacyDb.execute(_v26CashJournalDdl);
      legacyDb.execute(_v27FinancingDdl);
      legacyDb.execute('PRAGMA user_version = 27;');
      seedCommonRows(legacyDb);

      // A poste, an entry against it and a person already on the address book — all rows the
      // migration must carry through untouched, so the new tables and columns can be checked
      // against a file that already held real data rather than an empty one.
      legacyDb.execute(
        "INSERT INTO budget_postes (id, sort_key, code, label) VALUES "
        "('poste1', 'V', '2', 'Personnel');",
      );
      legacyDb.execute(
        "INSERT INTO budget_entries (id, sort_key, date, label, poste_id, debit_cents, "
        "voucher_number) VALUES "
        "('entry1', 'V', '2026-03-10T00:00:00.000Z', 'Location camion', 'poste1', 15000, 'J-001');",
      );
      legacyDb.execute(
        "INSERT INTO people (id, sort_key, first_name) VALUES ('person1', 'V', 'Clara');",
      );
      legacyDb.dispose();

      final database = OcptProjectDatabase(File(filePath));

      // (a) every row the file already held survived.
      await expectCommonRowsSurvived(database);
      final entry = await database.select(database.ocptBudgetEntriesTable).getSingle();
      expect(entry.label, "Location camion");
      final person = await database.select(database.ocptPeopleTable).getSingle();
      expect(person.firstName, "Clara");

      // (b) `budget_revenues`/`budget_shares` didn't exist before this version: the migration
      // creates them fresh, empty — a project migrating onto this version names no taking and no
      // participant yet.
      expect(await database.select(database.ocptBudgetRevenuesTable).get(), isEmpty);
      expect(await database.select(database.ocptBudgetSharesTable).get(), isEmpty);

      // (c) the file's existing entry gained two null new columns: nothing here is reconstructed
      // onto it — an entry names no taking and pays no share it never recorded.
      expect(entry.revenueId, isNull);
      expect(entry.shareId, isNull);

      // (d) the file now says the current schema version.
      expect(await readSchemaVersion(database), 28);

      // (e) and every new table and column is usable, foreign keys included: a revenue, a share
      // naming the existing person, and the existing entry naming both.
      await database
          .into(database.ocptBudgetRevenuesTable)
          .insert(
            OcptBudgetRevenuesTableCompanion.insert(
              id: "revenue1",
              date: DateTime.utc(2026, 5, 15),
              label: "Vente VOD",
              amountCents: const Value(80000),
            ),
          );
      await database
          .into(database.ocptBudgetSharesTable)
          .insert(
            OcptBudgetSharesTableCompanion.insert(
              id: "share1",
              personId: const Value("person1"),
              label: "Réalisatrice",
              sharePermille: const Value(300),
            ),
          );
      await (database.update(
        database.ocptBudgetEntriesTable,
      )..where((table) => table.id.equals("entry1"))).write(
        const OcptBudgetEntriesTableCompanion(
          revenueId: Value("revenue1"),
          shareId: Value("share1"),
        ),
      );

      final revenue = await database.select(database.ocptBudgetRevenuesTable).getSingle();
      expect(revenue.amountCents, 80000);
      expect(revenue.status, OcptBudgetRevenueStatus.expected);

      final share = await database.select(database.ocptBudgetSharesTable).getSingle();
      expect(share.personId, "person1");
      expect(share.sharePermille, 300);
      expect(share.reinvestPermille, 0);

      final updatedEntry = await database.select(database.ocptBudgetEntriesTable).getSingle();
      expect(updatedEntry.revenueId, "revenue1");
      expect(updatedEntry.shareId, "share1");

      await database.close();
    },
  );

  test('a v19 database migrates on, gaining an empty role_candidates', () async {
    final filePath = p.join(tempDir.path, 'legacy_v19.ocpt');

    final legacyDb = sqlite3.sqlite3.open(filePath);
    legacyDb.execute(_v19Ddl);
    legacyDb.execute('PRAGMA user_version = 19;');
    seedCommonRows(legacyDb);

    // A role and a person the file already held, so the new table can actually be written against
    // them rather than merely existing.
    legacyDb.execute(
      "INSERT INTO roles (id, name, kind, sort_key) VALUES ('role1', 'CLARA', 'speaking', 'a');",
    );
    legacyDb.execute("INSERT INTO people (id, first_name) VALUES ('person1', 'Camille');");
    legacyDb.dispose();

    final database = OcptProjectDatabase(File(filePath));

    // (a) every row the file already held survived — the migration adds a table and touches
    // nothing else.
    await expectCommonRowsSurvived(database);
    expect((await database.select(database.ocptRolesTable).getSingle()).name, "CLARA");
    expect((await database.select(database.ocptPeopleTable).getSingle()).firstName, "Camille");

    // (b) the new table is there and **empty**: a project that predates it kept the people it saw
    // for a part somewhere this app has never been able to read, and nothing is deduced from
    // `roles.personId` — a role cast by hand was never a candidacy.
    expect(await database.select(database.ocptRoleCandidatesTable).get(), isEmpty);

    // (c) and it is usable, foreign keys included.
    await database
        .into(database.ocptRoleCandidatesTable)
        .insert(
          OcptRoleCandidatesTableCompanion.insert(
            id: 'candidate1',
            roleId: 'role1',
            personId: 'person1',
            notes: const Value("Très juste sur la dernière séquence"),
          ),
        );
    final candidate = await database.select(database.ocptRoleCandidatesTable).getSingle();
    expect(candidate.roleId, 'role1');
    expect(candidate.personId, 'person1');
    expect(candidate.status, OcptRoleCandidateStatus.seen);
    expect(candidate.auditionedOn, isNull);
    expect(candidate.isDeleted, isFalse);

    // (d) the file now says the current schema version.
    expect(await readSchemaVersion(database), 28);

    await database.close();
  });

  test('a v20 database migrates on, gaining what an audition needs', () async {
    final filePath = p.join(tempDir.path, 'legacy_v20.ocpt');

    final legacyDb = sqlite3.sqlite3.open(filePath);
    legacyDb.execute(_v19Ddl);
    legacyDb.execute(_v20RoleCandidatesDdl);
    legacyDb.execute('PRAGMA user_version = 20;');
    seedCommonRows(legacyDb);

    legacyDb.execute(
      "INSERT INTO people (id, first_name, last_name) VALUES ('person1', 'Léa', 'Petit');",
    );
    legacyDb.execute(
      "INSERT INTO roles (id, name, kind, sort_key) VALUES ('role1', 'CLARA', 'speaking', 'a');",
    );
    legacyDb.execute(
      "INSERT INTO shooting_days (id, date, sort_key, is_deleted) VALUES "
      "('day1', '2026-03-02T00:00:00.000', 'a', 0);",
    );
    legacyDb.execute(
      "INSERT INTO shooting_slots (id, shooting_day_id, sort_key, is_deleted) VALUES "
      "('slot1', 'day1', 'a', 0);",
    );
    legacyDb.execute(
      "INSERT INTO shooting_day_blocks (id, shooting_day_id, slot_id, sort_key, kind, is_deleted) "
      "VALUES ('block1', 'day1', 'slot1', 'a', 'meal', 0);",
    );
    legacyDb.dispose();

    final database = OcptProjectDatabase(File(filePath));

    // (a) every row the file already held survived.
    await expectCommonRowsSurvived(database);

    // (b) the block it already held is untouched: nothing is deduced from what a block was called.
    expect(
      (await database.select(database.ocptShootingDayBlocksTable).getSingle()).kind,
      OcptShootingBlockKind.meal,
    );

    // (c) the new table is there and usable: a candidacy named on an audition, which is what a
    // session of auditions is planned with.
    await database
        .into(database.ocptRoleCandidatesTable)
        .insert(
          OcptRoleCandidatesTableCompanion.insert(
            id: 'candidacy1',
            roleId: 'role1',
            personId: 'person1',
          ),
        );
    await (database.update(
      database.ocptShootingDayBlocksTable,
    )..where((table) => table.id.equals('block1'))).write(
      const OcptShootingDayBlocksTableCompanion(kind: Value(OcptShootingBlockKind.audition)),
    );
    await database
        .into(database.ocptShootingBlockCandidatesTable)
        .insert(
          OcptShootingBlockCandidatesTableCompanion.insert(
            id: 'convocation1',
            blockId: 'block1',
            roleCandidateId: 'candidacy1',
          ),
        );
    expect(
      (await database.select(database.ocptShootingBlockCandidatesTable).getSingle())
          .roleCandidateId,
      'candidacy1',
    );

    // (d) the file now says the current schema version.
    expect(await readSchemaVersion(database), 28);

    await database.close();
  });

  test('a file written by an unmerged build loses what it alone carried', () async {
    // The only files that can hold `shooting_days.kind`, `shooting_day_blocks.role_candidate_id`,
    // `shooting_day_blocks.role_id` or `shooting_slot_candidates` are the ones this branch was
    // developed against: a day was briefly given a kind, an audition block the candidacy it saw and
    // then the single part it saw, and a candidate was briefly convoked on the whole slot — all of
    // it taken back out before any of it merged. The migration therefore asks the file what it
    // holds rather than trusting its version number.
    final filePath = p.join(tempDir.path, 'legacy_unmerged.ocpt');

    final legacyDb = sqlite3.sqlite3.open(filePath);
    legacyDb.execute(_v19Ddl);
    legacyDb.execute(_v20RoleCandidatesDdl);
    legacyDb.execute(_v21ShootingDayKindDdl);
    legacyDb.execute(
      'ALTER TABLE "shooting_day_blocks" ADD COLUMN "role_candidate_id" TEXT NULL '
      'REFERENCES role_candidates (id);',
    );
    legacyDb.execute(
      'ALTER TABLE "shooting_day_blocks" ADD COLUMN "role_id" TEXT NULL REFERENCES roles (id);',
    );
    legacyDb.execute(_v22ShootingSlotCandidatesDdl);
    legacyDb.execute('PRAGMA user_version = 22;');
    seedCommonRows(legacyDb);

    legacyDb.execute(
      "INSERT INTO shooting_days (id, date, sort_key, kind, is_deleted) VALUES "
      "('day1', '2026-03-02T00:00:00.000', 'a', 'casting', 0);",
    );
    legacyDb.execute(
      "INSERT INTO shooting_slots (id, shooting_day_id, sort_key, is_deleted) VALUES "
      "('slot1', 'day1', 'a', 0);",
    );
    legacyDb.execute(
      "INSERT INTO shooting_day_blocks (id, shooting_day_id, slot_id, sort_key, kind, is_deleted) "
      "VALUES ('block1', 'day1', 'slot1', 'a', 'audition', 0);",
    );
    legacyDb.dispose();

    final database = OcptProjectDatabase(File(filePath));

    // (a) the day and its timetable survive: what the day was called a "casting day" is now said by
    // the audition block it holds, which is untouched.
    await expectCommonRowsSurvived(database);
    final day = await database.select(database.ocptShootingDaysTable).getSingle();
    expect(day.id, 'day1');
    final block = await database.select(database.ocptShootingDayBlocksTable).getSingle();
    expect(block.kind, OcptShootingBlockKind.audition);

    // (b) and every column and table only that build ever wrote is gone from the file itself.
    final dayColumns = await database.customSelect('PRAGMA table_info(shooting_days)').get();
    expect(dayColumns.map((row) => row.data['name']), isNot(contains('kind')));
    final blockColumns = await database
        .customSelect('PRAGMA table_info(shooting_day_blocks)')
        .get();
    expect(blockColumns.map((row) => row.data['name']), isNot(contains('role_candidate_id')));
    expect(blockColumns.map((row) => row.data['name']), isNot(contains('role_id')));
    final tables = await database
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
        .get();
    expect(tables.map((row) => row.data['name']), isNot(contains('shooting_slot_candidates')));

    // (c) and the table that replaces it is there, hanging off the audition that survived.
    expect(await database.select(database.ocptShootingBlockCandidatesTable).get(), isEmpty);

    expect(await readSchemaVersion(database), 28);

    await database.close();
  });

  test('a project with no schedule opens unchanged at the current schema', () async {
    // A file written by the very build that adds the schedule mode: `onCreate` alone, no upgrade
    // path involved. Nobody has planned a day yet, and opening it must neither invent one nor
    // touch anything else about the project.
    final filePath = p.join(tempDir.path, 'no_schedule.ocpt');
    final database = OcptProjectDatabase(File(filePath));

    await database
        .into(database.ocptProjectInfoTable)
        .insert(
          OcptProjectInfoTableCompanion.insert(
            name: "My Movie",
            createdAt: createdAt,
            appVersionAtCreation: "0.1.0",
            pageFormat: OcptPageFormat.a4,
          ),
        );
    await database
        .into(database.ocptScreenplaysTable)
        .insert(
          OcptScreenplaysTableCompanion.insert(id: "s1", title: "Draft", updatedAt: updatedAt),
        );

    expect(await database.select(database.ocptShootingDaysTable).get(), isEmpty);
    expect(await database.select(database.ocptShootingSlotsTable).get(), isEmpty);
    expect(await database.select(database.ocptShootingSlotCrewTable).get(), isEmpty);
    expect(await database.select(database.ocptShootingSlotCastTable).get(), isEmpty);
    expect(await database.select(database.ocptShootingDayBlocksTable).get(), isEmpty);
    expect(await database.select(database.ocptShootingSlotGuestsTable).get(), isEmpty);
    expect(await database.select(database.ocptShootingDayEventsTable).get(), isEmpty);

    final projectInfo = await database.select(database.ocptProjectInfoTable).getSingle();
    expect(projectInfo.name, "My Movie");

    final screenplay = await database.select(database.ocptScreenplaysTable).getSingle();
    expect(screenplay.title, "Draft");

    expect(await readSchemaVersion(database), 28);

    await database.close();
  });
}
