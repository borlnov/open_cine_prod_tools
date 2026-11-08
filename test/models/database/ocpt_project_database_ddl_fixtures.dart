// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

// The verbatim `CREATE TABLE` fixtures of every frozen stable schema, which the project database
// migration test migrates forward and compares with `onCreate`
// (`docs/adr/0029-schema-versions-frozen-at-stable-releases.md`).

import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';

/// The verbatim schema version 1 `CREATE TABLE` statements — the shape the 0.1.0 release froze,
/// captured from a fresh [OcptProjectDatabase.memory]'s own `sqlite_master` (schema version 2's
/// `onCreate` output) with the two tables `onUpgrade` creates from 1 to 2 (`sync_relay_cursors`,
/// `sync_pairings`) removed, and `budget_lines`'s own `in_kind_resource_id` column — the one
/// `onUpgrade` adds — stripped back out; per `OcptProjectDatabase.migration`'s own doc comment,
/// those are the only differences between the two versions. No stable `.ocpt` file has ever carried
/// a different shape than this: schema version 1 carries no earlier migration history of its own
/// (`docs/adr/0029-schema-versions-frozen-at-stable-releases.md`), so this is also, verbatim, the
/// very first schema a real project file was ever written in.
const v1Ddl = <String>[
  'CREATE TABLE "assets" ("id" TEXT NOT NULL, "kind" TEXT NOT NULL, "path" TEXT NOT NULL, "label" '
      'TEXT NOT NULL DEFAULT \'\', "added_at" TEXT NOT NULL, "sort_key" TEXT NOT NULL DEFAULT '
      '\'\', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), '
      '"person_id" TEXT NULL, "location_id" TEXT NULL REFERENCES locations (id), '
      '"element_id" TEXT NULL REFERENCES elements (id), "budget_entry_id" TEXT NULL '
      'REFERENCES budget_entries (id), "valid_from" TEXT NULL, "valid_until" TEXT '
      'NULL, PRIMARY KEY ("id"))',
  'CREATE TABLE "breakdown_tags" ("id" TEXT NOT NULL, "scene_id" TEXT NOT NULL REFERENCES scenes '
      '(id), "target_kind" TEXT NOT NULL, "element_id" TEXT NULL REFERENCES elements (id), '
      '"role_id" TEXT NULL REFERENCES roles (id), "set_id" TEXT NULL REFERENCES sets (id), '
      '"start_offset" INTEGER NOT NULL, "end_offset" INTEGER NOT NULL, "tagged_text" TEXT '
      'NOT NULL, "needs_check" INTEGER NOT NULL DEFAULT 0 CHECK ("needs_check" IN (0, '
      '1)), "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, '
      '1)), PRIMARY KEY ("id"))',
  'CREATE TABLE "budget_allowances" ("id" TEXT NOT NULL, "sort_key" TEXT NOT NULL DEFAULT \'\', '
      '"is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), "person_id" TEXT '
      'NULL REFERENCES people (id), "kind" TEXT NOT NULL DEFAULT \'travel\', "label" TEXT NOT '
      'NULL DEFAULT \'\', "date" TEXT NULL, "end_date" TEXT NULL, "quantity_milli" INTEGER '
      'NOT NULL DEFAULT 0, "unit_amount_milli_cents" INTEGER NOT NULL DEFAULT 0, '
      '"notes" TEXT NOT NULL DEFAULT \'\', PRIMARY KEY ("id"))',
  'CREATE TABLE "budget_commitments" ("id" TEXT NOT NULL, "sort_key" TEXT NOT NULL DEFAULT \'\', '
      '"is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), "due_date" TEXT '
      'NULL, "label" TEXT NOT NULL, "poste_id" TEXT NOT NULL REFERENCES budget_postes (id), '
      '"amount_cents" INTEGER NOT NULL DEFAULT 0, "is_tax_inclusive" INTEGER NOT NULL '
      'DEFAULT 1 CHECK ("is_tax_inclusive" IN (0, 1)), "vat_rate_basis_points" INTEGER '
      'NULL, "status" TEXT NOT NULL DEFAULT \'quoteAccepted\', "line_id" TEXT NULL '
      'REFERENCES budget_lines (id), PRIMARY KEY ("id"))',
  'CREATE TABLE "budget_entries" ("id" TEXT NOT NULL, "sort_key" TEXT NOT NULL DEFAULT \'\', '
      '"is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), "date" TEXT NOT '
      'NULL, "label" TEXT NOT NULL, "poste_id" TEXT NULL REFERENCES budget_postes (id), '
      '"debit_cents" INTEGER NOT NULL DEFAULT 0, "credit_cents" INTEGER NOT NULL DEFAULT '
      '0, "is_tax_inclusive" INTEGER NOT NULL DEFAULT 1 CHECK ("is_tax_inclusive" IN '
      '(0, 1)), "vat_rate_basis_points" INTEGER NULL, "voucher_number" TEXT NOT '
      'NULL DEFAULT \'\', "resource_id" TEXT NULL REFERENCES budget_resources '
      '(id), "revenue_id" TEXT NULL REFERENCES budget_revenues (id), '
      '"share_id" TEXT NULL REFERENCES budget_shares (id), '
      '"commitment_id" TEXT NULL REFERENCES budget_commitments '
      '(id), "person_id" TEXT NULL, PRIMARY KEY ("id"))',
  'CREATE TABLE "budget_lines" ("id" TEXT NOT NULL, "sort_key" TEXT NOT NULL DEFAULT \'\', '
      '"is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), "poste_id" TEXT NOT '
      'NULL REFERENCES budget_postes (id), "label" TEXT NOT NULL, "quantity_milli" INTEGER NOT '
      'NULL DEFAULT 1000, "unit" TEXT NOT NULL DEFAULT \'\', "unit_amount_cents" INTEGER '
      'NOT NULL DEFAULT 0, "is_tax_inclusive" INTEGER NOT NULL DEFAULT 1 CHECK '
      '("is_tax_inclusive" IN (0, 1)), "vat_rate_basis_points" INTEGER NULL, '
      '"element_id" TEXT NULL REFERENCES elements (id), "provision_key" TEXT '
      'NULL, "provision_digest" TEXT NULL, "notes" TEXT NOT NULL DEFAULT '
      '\'\', PRIMARY KEY ("id"))',
  'CREATE TABLE "budget_mileage_rates" ("id" TEXT NOT NULL, "sort_key" TEXT NOT NULL DEFAULT \'\', '
      '"is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), "label" TEXT NOT '
      'NULL, "rate_per_km_milli_cents" INTEGER NOT NULL DEFAULT 0, PRIMARY KEY ("id"))',
  'CREATE TABLE "budget_postes" ("id" TEXT NOT NULL, "sort_key" TEXT NOT NULL DEFAULT \'\', '
      '"is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), "code" TEXT NOT '
      'NULL DEFAULT \'\', "label" TEXT NOT NULL, "simple_label" TEXT NULL, '
      '"estimate_to_complete_cents" INTEGER NULL, PRIMARY KEY ("id"))',
  'CREATE TABLE "budget_resources" ("id" TEXT NOT NULL, "sort_key" TEXT NOT NULL DEFAULT \'\', '
      '"is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), "group_kind" TEXT '
      'NOT NULL DEFAULT \'subsidy\', "person_id" TEXT NULL, "label" TEXT NOT NULL, '
      '"amount_cents" INTEGER NOT NULL DEFAULT 0, "status" TEXT NOT NULL DEFAULT '
      '\'pending\', "is_reimbursable" INTEGER NOT NULL DEFAULT 0 CHECK '
      '("is_reimbursable" IN (0, 1)), "notes" TEXT NOT NULL DEFAULT \'\', PRIMARY '
      'KEY ("id"))',
  'CREATE TABLE "budget_revenues" ("id" TEXT NOT NULL, "sort_key" TEXT NOT NULL DEFAULT \'\', '
      '"is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), "date" TEXT NOT '
      'NULL, "label" TEXT NOT NULL, "amount_cents" INTEGER NOT NULL DEFAULT 0, "status" TEXT '
      'NOT NULL DEFAULT \'expected\', "notes" TEXT NOT NULL DEFAULT \'\', PRIMARY KEY '
      '("id"))',
  'CREATE TABLE "budget_shares" ("id" TEXT NOT NULL, "sort_key" TEXT NOT NULL DEFAULT \'\', '
      '"is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), "person_id" TEXT '
      'NULL, "label" TEXT NOT NULL, "share_permille" INTEGER NOT NULL DEFAULT 0, '
      '"reinvest_permille" INTEGER NOT NULL DEFAULT 0, "notes" TEXT NOT NULL DEFAULT \'\', '
      'PRIMARY KEY ("id"))',
  'CREATE TABLE "elements" ("id" TEXT NOT NULL, "sort_key" TEXT NOT NULL DEFAULT \'\', '
      '"is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), "category" TEXT NOT '
      'NULL, "sub_category" TEXT NOT NULL DEFAULT \'\', "name" TEXT NOT NULL, "code" TEXT NOT '
      'NULL DEFAULT \'\', "quantity" TEXT NOT NULL DEFAULT \'\', "source_kind" TEXT NOT '
      'NULL, "owner_person_id" TEXT NULL, "owner_notes" TEXT NOT NULL DEFAULT \'\', '
      '"brought_by_person_id" TEXT NULL, "storage_notes" TEXT NOT NULL DEFAULT '
      '\'\', "status" TEXT NOT NULL DEFAULT \'toFind\', "is_secured" INTEGER '
      'NOT NULL DEFAULT 0 CHECK ("is_secured" IN (0, 1)), '
      '"is_ready_for_shoot" INTEGER NOT NULL DEFAULT 0 CHECK '
      '("is_ready_for_shoot" IN (0, 1)), "is_returned" INTEGER NOT '
      'NULL DEFAULT 0 CHECK ("is_returned" IN (0, 1)), "cost" '
      'INTEGER NULL, "purpose_notes" TEXT NOT NULL DEFAULT '
      '\'\', "notes" TEXT NOT NULL DEFAULT \'\', '
      '"photo_asset_id" TEXT NULL, PRIMARY KEY '
      '("id"))',
  'CREATE TABLE "local_erasures" ("person_id" TEXT NOT NULL REFERENCES people (id), "erased_at" '
      'TEXT NOT NULL, PRIMARY KEY ("person_id"))',
  'CREATE TABLE "location_availabilities" ("id" TEXT NOT NULL, "location_id" TEXT NOT NULL '
      'REFERENCES locations (id), "start_date" TEXT NOT NULL, "end_date" TEXT NOT NULL, "weekdays" '
      'INTEGER NOT NULL DEFAULT 127, "slot" TEXT NOT NULL DEFAULT \'fullDay\', "start_minute" '
      'INTEGER NULL, "end_minute" INTEGER NULL, "kind" TEXT NOT NULL DEFAULT '
      '\'available\', "note" TEXT NOT NULL DEFAULT \'\', "is_deleted" INTEGER NOT NULL '
      'DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"))',
  'CREATE TABLE "locations" ("id" TEXT NOT NULL, "name" TEXT NOT NULL, "color_index" INTEGER NOT '
      'NULL DEFAULT 0, "address_line1" TEXT NOT NULL DEFAULT \'\', "address_line2" TEXT NOT NULL '
      'DEFAULT \'\', "postal_code" TEXT NOT NULL DEFAULT \'\', "city" TEXT NOT NULL DEFAULT '
      '\'\', "region" TEXT NOT NULL DEFAULT \'\', "country" TEXT NOT NULL DEFAULT \'\', '
      '"latitude" REAL NULL, "longitude" REAL NULL, "contact_person_id" TEXT NULL, '
      '"contact_notes" TEXT NOT NULL DEFAULT \'\', "permit_status" TEXT NOT NULL '
      'DEFAULT \'toRequest\', "permit_label" TEXT NOT NULL DEFAULT \'\', '
      '"permit_date" TEXT NULL, "permit_asset_id" TEXT NULL, '
      '"parking_notes" TEXT NOT NULL DEFAULT \'\', "power_notes" TEXT '
      'NOT NULL DEFAULT \'\', "facilities_notes" TEXT NOT NULL '
      'DEFAULT \'\', "constraints_notes" TEXT NOT NULL DEFAULT '
      '\'\', "notes" TEXT NOT NULL DEFAULT \'\', '
      '"sort_key" TEXT NOT NULL DEFAULT \'\', '
      '"is_deleted" INTEGER NOT NULL DEFAULT 0 '
      'CHECK ("is_deleted" IN (0, 1)), PRIMARY '
      'KEY ("id"))',
  'CREATE TABLE "people" ("id" TEXT NOT NULL, "sort_key" TEXT NOT NULL DEFAULT \'\', "is_deleted" '
      'INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), "first_name" TEXT NOT NULL '
      'DEFAULT \'\', "last_name" TEXT NOT NULL DEFAULT \'\', "email" TEXT NOT NULL DEFAULT '
      '\'\', "phone" TEXT NOT NULL DEFAULT \'\', "address_line1" TEXT NOT NULL DEFAULT '
      '\'\', "address_line2" TEXT NOT NULL DEFAULT \'\', "postal_code" TEXT NOT NULL '
      'DEFAULT \'\', "city" TEXT NOT NULL DEFAULT \'\', "region" TEXT NOT NULL '
      'DEFAULT \'\', "country" TEXT NOT NULL DEFAULT \'\', "color_index" '
      'INTEGER NOT NULL DEFAULT 0, "birth_date" TEXT NULL, "minor_notes" '
      'TEXT NOT NULL DEFAULT \'\', "max_daily_presence_minutes" '
      'INTEGER NULL, "is_transport_autonomous" INTEGER NULL CHECK '
      '("is_transport_autonomous" IN (0, 1)), '
      '"accommodation_notes" TEXT NOT NULL DEFAULT \'\', '
      '"travel_notes" TEXT NOT NULL DEFAULT \'\', '
      '"dietary_notes" TEXT NOT NULL DEFAULT \'\', '
      '"allergies" TEXT NOT NULL DEFAULT \'\', '
      '"measurement_height" TEXT NOT NULL '
      "DEFAULT '', "
      '"measurement_chest" TEXT '
      "NOT NULL DEFAULT '', "
      '"measurement_waist" '
      'TEXT NOT NULL '
      'DEFAULT '
      "'', "
      '"measurement_hips" TEXT NOT NULL DEFAULT \'\', "size_top" TEXT NOT NULL DEFAULT \'\', '
      '"size_bottom" TEXT NOT NULL DEFAULT \'\', "size_shoes" TEXT NOT NULL DEFAULT \'\', '
      '"hmc_notes" TEXT NOT NULL DEFAULT \'\', "image_rights_status" TEXT NOT NULL DEFAULT '
      '\'notApplicable\', "image_rights_date" TEXT NULL, "image_rights_asset_id" TEXT '
      'NULL REFERENCES assets (id), "photo_asset_id" TEXT NULL REFERENCES assets '
      '(id), "notes" TEXT NOT NULL DEFAULT \'\', "commute_km_milli" INTEGER '
      'NULL, "mileage_rate_id" TEXT NULL REFERENCES budget_mileage_rates '
      '(id), PRIMARY KEY ("id"))',
  'CREATE TABLE "person_positions" ("id" TEXT NOT NULL, "person_id" TEXT NOT NULL REFERENCES '
      'people (id), "position_id" TEXT NOT NULL DEFAULT \'\', "custom_label" TEXT NOT NULL DEFAULT '
      '\'\', "sort_key" TEXT NOT NULL DEFAULT \'\', "is_deleted" INTEGER NOT NULL DEFAULT 0 '
      'CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"))',
  'CREATE TABLE "person_skills" ("id" TEXT NOT NULL, "person_id" TEXT NOT NULL REFERENCES people '
      '(id), "label" TEXT NOT NULL DEFAULT \'\', "sort_key" TEXT NOT NULL DEFAULT \'\', '
      '"is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY '
      '("id"))',
  'CREATE TABLE "person_unavailabilities" ("id" TEXT NOT NULL, "person_id" TEXT NOT NULL '
      'REFERENCES people (id), "start_date" TEXT NOT NULL, "end_date" TEXT NOT NULL, "slot" TEXT '
      'NOT NULL DEFAULT \'fullDay\', "start_minute" INTEGER NULL, "end_minute" INTEGER NULL, '
      '"reason" TEXT NOT NULL DEFAULT \'\', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK '
      '("is_deleted" IN (0, 1)), PRIMARY KEY ("id"))',
  'CREATE TABLE "project_dictionary_words" ("id" TEXT NOT NULL, "word" TEXT NOT NULL, "is_deleted" '
      'INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"))',
  'CREATE TABLE "project_info" ("id" INTEGER NOT NULL DEFAULT 1, "name" TEXT NOT NULL, '
      '"created_at" TEXT NOT NULL, "app_version_at_creation" TEXT NOT NULL, '
      '"migrated_by_app_version" TEXT NULL, "page_format" TEXT NOT NULL, "currency_code" TEXT '
      'NOT NULL DEFAULT \'EUR\', "settings_json" TEXT NULL, "minimum_rest_minutes" INTEGER '
      'NULL, "screenplay_language" TEXT NULL, "default_vat_rate_basis_points" INTEGER '
      'NULL, "meal_price_cents" INTEGER NULL, "snack_price_cents" INTEGER NULL, '
      '"is_budget_simplified" INTEGER NULL CHECK ("is_budget_simplified" IN '
      '(0, 1)), "current_version_id" TEXT NULL REFERENCES project_versions '
      '(id), PRIMARY KEY ("id"))',
  'CREATE TABLE "project_versions" ("id" TEXT NOT NULL, "name" TEXT NOT NULL, "note" TEXT NOT NULL '
      'DEFAULT \'\', "created_at" TEXT NOT NULL, "app_version" TEXT NOT NULL, "payload_format" '
      'INTEGER NOT NULL, "payload" TEXT NOT NULL, "summary_json" TEXT NOT NULL, '
      '"created_by_device_id" TEXT NOT NULL, "content_digest" TEXT NULL, PRIMARY KEY '
      '("id"))',
  'CREATE TABLE "role_candidates" ("id" TEXT NOT NULL, "role_id" TEXT NOT NULL REFERENCES roles '
      '(id), "person_id" TEXT NOT NULL REFERENCES people (id), "status" TEXT NOT NULL DEFAULT '
      '\'seen\', "auditioned_on" TEXT NULL, "notes" TEXT NOT NULL DEFAULT \'\', "sort_key" '
      'TEXT NOT NULL DEFAULT \'\', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK '
      '("is_deleted" IN (0, 1)), PRIMARY KEY ("id"))',
  'CREATE TABLE "role_elements" ("id" TEXT NOT NULL, "role_id" TEXT NOT NULL REFERENCES roles '
      '(id), "element_id" TEXT NOT NULL REFERENCES elements (id), "notes" TEXT NOT NULL DEFAULT '
      '\'\', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY '
      'KEY ("id"))',
  'CREATE TABLE "role_episodes" ("id" TEXT NOT NULL, "role_id" TEXT NOT NULL REFERENCES roles '
      '(id), "screenplay_id" TEXT NOT NULL REFERENCES screenplays (id), "is_deleted" INTEGER NOT '
      'NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"))',
  'CREATE TABLE "roles" ("id" TEXT NOT NULL, "name" TEXT NOT NULL, "sort_key" TEXT NOT NULL '
      'DEFAULT \'\', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), '
      '"person_id" TEXT NULL REFERENCES people (id), "kind" TEXT NOT NULL, '
      '"is_from_screenplay" INTEGER NOT NULL DEFAULT 0 CHECK ("is_from_screenplay" IN (0, '
      '1)), "orphaned_name" TEXT NULL, "casting_notes" TEXT NOT NULL DEFAULT \'\', '
      'PRIMARY KEY ("id"))',
  'CREATE TABLE "row_field_versions" ("table_name" TEXT NOT NULL, "row_id" TEXT NOT NULL, '
      '"column_name" TEXT NOT NULL, "version" INTEGER NOT NULL, "device_id" TEXT NOT NULL, PRIMARY '
      'KEY ("table_name", "row_id", "column_name"))',
  'CREATE TABLE "scene_breakdowns" ("id" TEXT NOT NULL, "scene_id" TEXT NOT NULL REFERENCES scenes '
      '(id), "status" TEXT NOT NULL DEFAULT \'toDo\', "notes" TEXT NOT NULL DEFAULT \'\', '
      '"is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY '
      '("id"))',
  'CREATE TABLE "scene_elements" ("id" TEXT NOT NULL, "scene_id" TEXT NOT NULL REFERENCES scenes '
      '(id), "element_id" TEXT NOT NULL REFERENCES elements (id), "quantity" TEXT NOT NULL DEFAULT '
      '\'\', "notes" TEXT NOT NULL DEFAULT \'\', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK '
      '("is_deleted" IN (0, 1)), PRIMARY KEY ("id"))',
  'CREATE TABLE "scene_sets" ("id" TEXT NOT NULL, "scene_id" TEXT NOT NULL REFERENCES scenes (id), '
      '"set_id" TEXT NOT NULL REFERENCES sets (id), "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK '
      '("is_deleted" IN (0, 1)), PRIMARY KEY ("id"))',
  'CREATE TABLE "scenes" ("id" TEXT NOT NULL, "screenplay_id" TEXT NOT NULL REFERENCES screenplays '
      '(id), "position" INTEGER NOT NULL, "heading" TEXT NOT NULL, "scene_number" TEXT NULL, '
      '"char_start" INTEGER NOT NULL, "char_end" INTEGER NOT NULL, "is_deleted" INTEGER NOT '
      'NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"))',
  'CREATE TABLE "screenplay_snapshots" ("id" TEXT NOT NULL, "screenplay_id" TEXT NOT NULL '
      'REFERENCES screenplays (id), "created_at" TEXT NOT NULL, "reason" TEXT NOT NULL, '
      '"fountain_text" TEXT NOT NULL, "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK '
      '("is_deleted" IN (0, 1)), PRIMARY KEY ("id"))',
  'CREATE TABLE "screenplays" ("id" TEXT NOT NULL, "title" TEXT NOT NULL, "fountain_text" TEXT NOT '
      'NULL DEFAULT \'\', "updated_at" TEXT NOT NULL, "number" INTEGER NOT NULL DEFAULT 1, '
      '"sort_key" TEXT NOT NULL DEFAULT \'\', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK '
      '("is_deleted" IN (0, 1)), PRIMARY KEY ("id"))',
  'CREATE TABLE "sets" ("id" TEXT NOT NULL, "location_id" TEXT NOT NULL REFERENCES locations (id), '
      '"code" TEXT NOT NULL DEFAULT \'\', "name" TEXT NOT NULL, "notes" TEXT NOT NULL DEFAULT '
      '\'\', "sort_key" TEXT NOT NULL DEFAULT \'\', "is_deleted" INTEGER NOT NULL DEFAULT 0 '
      'CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"))',
  'CREATE TABLE "shooting_block_candidates" ("id" TEXT NOT NULL, "block_id" TEXT NOT NULL '
      'REFERENCES shooting_day_blocks (id), "role_candidate_id" TEXT NOT NULL REFERENCES '
      'role_candidates (id), "sort_key" TEXT NOT NULL DEFAULT \'\', "notes" TEXT NOT NULL '
      'DEFAULT \'\', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, '
      '1)), PRIMARY KEY ("id"))',
  'CREATE TABLE "shooting_day_blocks" ("id" TEXT NOT NULL, "shooting_day_id" TEXT NOT NULL '
      'REFERENCES shooting_days (id), "sort_key" TEXT NOT NULL DEFAULT \'\', "slot_id" TEXT NOT '
      'NULL REFERENCES shooting_slots (id), "kind" TEXT NOT NULL DEFAULT \'shot\', "shot_id" '
      'TEXT NULL REFERENCES shots (id), "scene_id" TEXT NULL REFERENCES scenes (id), '
      '"label" TEXT NOT NULL DEFAULT \'\', "duration_minutes" INTEGER NULL, '
      '"anchor_minute" INTEGER NULL, "notes" TEXT NOT NULL DEFAULT \'\', '
      '"crew_note" TEXT NOT NULL DEFAULT \'\', "is_deleted" INTEGER NOT NULL '
      'DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"))',
  'CREATE TABLE "shooting_day_events" ("id" TEXT NOT NULL, "shooting_day_id" TEXT NOT NULL '
      'REFERENCES shooting_days (id), "minute" INTEGER NOT NULL, "label" TEXT NOT NULL DEFAULT '
      '\'\', "notes" TEXT NOT NULL DEFAULT \'\', "sort_key" TEXT NOT NULL DEFAULT \'\', '
      '"is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY '
      '("id"))',
  'CREATE TABLE "shooting_days" ("id" TEXT NOT NULL, "date" TEXT NOT NULL, "sort_key" TEXT NOT '
      'NULL DEFAULT \'\', "status" TEXT NOT NULL DEFAULT \'planned\', "crew_note" TEXT NOT NULL '
      'DEFAULT \'\', "weather_note" TEXT NOT NULL DEFAULT \'\', "notes" TEXT NOT NULL DEFAULT '
      '\'\', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), '
      'PRIMARY KEY ("id"))',
  'CREATE TABLE "shooting_slot_cast" ("id" TEXT NOT NULL, "slot_id" TEXT NOT NULL REFERENCES '
      'shooting_slots (id), "role_id" TEXT NOT NULL REFERENCES roles (id), "sort_key" TEXT NOT '
      'NULL DEFAULT \'\', "notes" TEXT NOT NULL DEFAULT \'\', "is_deleted" INTEGER NOT NULL '
      'DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"))',
  'CREATE TABLE "shooting_slot_crew" ("id" TEXT NOT NULL, "slot_id" TEXT NOT NULL REFERENCES '
      'shooting_slots (id), "sort_key" TEXT NOT NULL DEFAULT \'\', "person_id" TEXT NOT NULL '
      'REFERENCES people (id), "position_id" TEXT NOT NULL DEFAULT \'\', "custom_label" TEXT '
      'NOT NULL DEFAULT \'\', "notes" TEXT NOT NULL DEFAULT \'\', "is_deleted" INTEGER NOT '
      'NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"))',
  'CREATE TABLE "shooting_slot_guests" ("id" TEXT NOT NULL, "slot_id" TEXT NOT NULL REFERENCES '
      'shooting_slots (id), "person_id" TEXT NULL REFERENCES people (id), "free_name" TEXT NOT '
      'NULL DEFAULT \'\', "reason" TEXT NOT NULL DEFAULT \'\', "notes" TEXT NOT NULL DEFAULT '
      '\'\', "sort_key" TEXT NOT NULL DEFAULT \'\', "is_deleted" INTEGER NOT NULL DEFAULT '
      '0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"))',
  'CREATE TABLE "shooting_slots" ("id" TEXT NOT NULL, "shooting_day_id" TEXT NOT NULL REFERENCES '
      'shooting_days (id), "sort_key" TEXT NOT NULL DEFAULT \'\', "label" TEXT NOT NULL DEFAULT '
      '\'\', "location_id" TEXT NULL REFERENCES locations (id), "set_id" TEXT NULL REFERENCES '
      'sets (id), "anchor_edge" TEXT NOT NULL DEFAULT \'start\', "anchor_minute" INTEGER '
      'NULL, "anchor_slot_id" TEXT NULL REFERENCES shooting_slots (id), "notes" TEXT '
      'NOT NULL DEFAULT \'\', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK '
      '("is_deleted" IN (0, 1)), PRIMARY KEY ("id"))',
  'CREATE TABLE "shot_characters" ("shot_id" TEXT NOT NULL REFERENCES shots (id), "character_name" '
      'TEXT NOT NULL, "position" INTEGER NOT NULL, "sort_key" TEXT NOT NULL DEFAULT \'\', '
      '"is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY '
      '("shot_id", "character_name"))',
  'CREATE TABLE "shot_coverages" ("id" TEXT NOT NULL, "shot_id" TEXT NOT NULL REFERENCES shots '
      '(id), "scene_id" TEXT NOT NULL REFERENCES scenes (id), "start_offset" INTEGER NOT NULL, '
      '"end_offset" INTEGER NOT NULL, "covered_text_digest" TEXT NOT NULL, "is_deleted" '
      'INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"))',
  'CREATE TABLE "shots" ("id" TEXT NOT NULL, "screenplay_id" TEXT NOT NULL REFERENCES screenplays '
      '(id), "scene_id" TEXT NULL REFERENCES scenes (id), "orphaned_heading" TEXT NULL, "position" '
      'INTEGER NOT NULL, "sort_key" TEXT NOT NULL DEFAULT \'\', "shot_size" TEXT NOT NULL '
      'DEFAULT \'\', "abbreviation" TEXT NOT NULL DEFAULT \'\', "framing" TEXT NOT NULL '
      'DEFAULT \'\', "camera_move" TEXT NOT NULL DEFAULT \'\', "lens" TEXT NOT NULL '
      'DEFAULT \'\', "recording_format" TEXT NOT NULL DEFAULT \'\', '
      '"estimated_duration_ms" INTEGER NULL, "shooting_day" TEXT NULL, '
      '"planned_takes" INTEGER NULL, "sound" TEXT NOT NULL DEFAULT \'\', '
      '"status" TEXT NOT NULL DEFAULT \'toShoot\', "difficulty_set" '
      'INTEGER NOT NULL DEFAULT 1, "difficulty_camera" INTEGER NOT '
      'NULL DEFAULT 1, "difficulty_acting" INTEGER NOT NULL '
      'DEFAULT 1, "difficulty_sound" INTEGER NOT NULL '
      'DEFAULT 1, "notes" TEXT NOT NULL DEFAULT \'\', '
      '"location_notes" TEXT NOT NULL DEFAULT '
      '\'\', "needs_check" INTEGER NOT NULL '
      'DEFAULT 0 CHECK ("needs_check" IN '
      '(0, 1)), "check_reason" TEXT '
      'NULL, "is_deleted" INTEGER '
      'NOT NULL DEFAULT 0 '
      'CHECK ("is_deleted" '
      'IN (0, 1)), '
      'PRIMARY KEY '
      '("id"))',
];

/// The verbatim schema version 2 `CREATE TABLE` statements — the shape the 0.2.0 release froze, the
/// one a real 0.2.0 `.ocpt` file was left with. It is [v1Ddl] plus exactly what
/// `OcptProjectDatabase.migration`'s `from < 2` step adds and nothing else: [_v2BudgetLinesDdl]
/// replaces v1's `budget_lines` with its `in_kind_resource_id` column, and the two local,
/// never-synchronised sync tables are appended. `shot_characters` still carries its frozen v2
/// `{shotId, characterName}` key — schema version 3 is what reshapes it. Assembled from [v1Ddl] by
/// hand rather than through drift, for the same reason [v1Ddl] itself is: a fixture of the frozen
/// shape, not another way of asking drift to build the current one.
final v2Ddl = <String>[
  for (final statement in v1Ddl)
    if (statement.startsWith('CREATE TABLE "budget_lines" (')) _v2BudgetLinesDdl else statement,
  _v2SyncPairingsDdl,
  _v2SyncRelayCursorsDdl,
];

/// v1's `budget_lines` with `in_kind_resource_id` added — the one column schema version 2's
/// `onUpgrade` adds to the table (`OcptProjectDatabase.migration`).
const _v2BudgetLinesDdl =
    'CREATE TABLE "budget_lines" ("id" TEXT NOT NULL, "sort_key" TEXT NOT NULL DEFAULT \'\', '
    '"is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), "poste_id" TEXT '
    'NOT NULL REFERENCES budget_postes (id), "label" TEXT NOT NULL, "quantity_milli" '
    'INTEGER NOT NULL DEFAULT 1000, "unit" TEXT NOT NULL DEFAULT \'\', '
    '"unit_amount_cents" INTEGER NOT NULL DEFAULT 0, "is_tax_inclusive" INTEGER '
    'NOT NULL DEFAULT 1 CHECK ("is_tax_inclusive" IN (0, 1)), '
    '"vat_rate_basis_points" INTEGER NULL, "element_id" TEXT NULL '
    'REFERENCES elements (id), "in_kind_resource_id" TEXT NULL '
    'REFERENCES budget_resources (id), "provision_key" TEXT NULL, '
    '"provision_digest" TEXT NULL, "notes" TEXT NOT NULL '
    'DEFAULT \'\', PRIMARY KEY ("id"))';

/// The local, never-synchronised pairing table schema version 2's `onUpgrade` creates.
const _v2SyncPairingsDdl =
    'CREATE TABLE "sync_pairings" ("project_id" TEXT NOT NULL, "relay_base_url" TEXT NOT NULL, '
    'PRIMARY KEY ("project_id"))';

/// The local, never-synchronised relay-cursor table schema version 2's `onUpgrade` creates.
const _v2SyncRelayCursorsDdl =
    'CREATE TABLE "sync_relay_cursors" ("relay_id" TEXT NOT NULL, "last_applied_sequence" INTEGER '
    'NOT NULL DEFAULT 0, "outbox_high_water_mark" INTEGER NOT NULL DEFAULT 0, PRIMARY KEY '
    '("relay_id"))';

/// The verbatim schema version 3 `CREATE TABLE` statements — the shape the 0.2.1 release froze, the
/// one a real 0.2.1 `.ocpt` file is left with. It is [v2Ddl] with [_v3ShotCharactersDdl] replacing
/// v2's `shot_characters`: the only difference schema version 3's `ocptMigrateToSchemaV3` step
/// makes, reshaping the table from its frozen v2 `{shotId, characterName}` key to `{shotId,
/// roleId}` (`docs/adr/0030-a-shots-characters-are-the-productions-roles.md`). Assembled from
/// [v2Ddl] by hand rather than through drift, for the same reason [v1Ddl] itself is: a fixture of
/// the frozen shape, not another way of asking drift to build the current one.
final v3Ddl = <String>[
  for (final statement in v2Ddl)
    if (statement.startsWith('CREATE TABLE "shot_characters" ('))
      _v3ShotCharactersDdl
    else
      statement,
];

/// v2's `shot_characters`, reshaped to `{shotId, roleId}` — the one table schema version 3's own
/// step touches (`OcptProjectDatabase.migration`).
const _v3ShotCharactersDdl =
    'CREATE TABLE "shot_characters" ("shot_id" TEXT NOT NULL REFERENCES shots (id), "role_id" TEXT '
    'NOT NULL REFERENCES roles (id), "position" INTEGER NOT NULL, "sort_key" TEXT NOT NULL '
    'DEFAULT \'\', "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), '
    'PRIMARY KEY ("shot_id", "role_id"))';

/// The verbatim schema version 4 `CREATE TABLE` statements — the shape the 0.3.0 release froze, the
/// one a real 0.3.0 `.ocpt` file is left with. It is [v3Ddl] plus exactly what schema version 4's
/// `ocptMigrateToSchemaV4` step adds and nothing else: the five storyboard and floor plan tables
/// below. Assembled from [v3Ddl] by hand rather than through drift, for the same reason [v1Ddl]
/// itself is: a fixture of the frozen shape, not another way of asking drift to build the current
/// one.
final v4Ddl = <String>[
  ...v3Ddl,
  _v4StoryboardPanelsDdl,
  _v4StoryboardAnnotationsDdl,
  _v4FloorPlanSetsDdl,
  _v4FloorPlanSymbolsDdl,
  _v4FloorPlanArrowsDdl,
];

/// The `storyboard_panels` table schema version 4's `onUpgrade` creates.
const _v4StoryboardPanelsDdl =
    'CREATE TABLE "storyboard_panels" ("id" TEXT NOT NULL, "shot_id" TEXT NOT NULL '
    'REFERENCES shots (id), "sort_key" TEXT NOT NULL DEFAULT \'\', "image_asset_id" TEXT '
    'NULL REFERENCES assets (id), "comment" TEXT NOT NULL DEFAULT \'\', "is_deleted" '
    'INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"))';

/// The `storyboard_annotations` table schema version 4's `onUpgrade` creates.
const _v4StoryboardAnnotationsDdl =
    'CREATE TABLE "storyboard_annotations" ("id" TEXT NOT NULL, "panel_id" TEXT NOT NULL '
    'REFERENCES storyboard_panels (id), "kind" TEXT NOT NULL, "sort_key" TEXT NOT NULL '
    'DEFAULT \'\', "x1" REAL NOT NULL, "y1" REAL NOT NULL, "x2" REAL NOT NULL, "y2" REAL '
    'NOT NULL, "text" TEXT NOT NULL DEFAULT \'\', "is_deleted" INTEGER NOT NULL DEFAULT 0 '
    'CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"))';

/// The `floor_plan_sets` table schema version 4's `onUpgrade` creates.
const _v4FloorPlanSetsDdl =
    'CREATE TABLE "floor_plan_sets" ("id" TEXT NOT NULL REFERENCES sets (id), '
    '"underlay_asset_id" TEXT NULL REFERENCES assets (id), "underlay_x_m" REAL NULL, '
    '"underlay_y_m" REAL NULL, "underlay_width_m" REAL NULL, "underlay_height_m" REAL '
    'NULL, "underlay_rotation_deg" REAL NULL, "is_deleted" INTEGER NOT NULL DEFAULT 0 '
    'CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"))';

/// The `floor_plan_symbols` table schema version 4's `onUpgrade` creates.
const _v4FloorPlanSymbolsDdl =
    'CREATE TABLE "floor_plan_symbols" ("id" TEXT NOT NULL, "set_id" TEXT NOT NULL '
    'REFERENCES floor_plan_sets (id), "scene_id" TEXT NULL REFERENCES scenes (id), '
    '"shot_id" TEXT NULL REFERENCES shots (id), "layer" TEXT NOT NULL, '
    '"overrides_symbol_id" TEXT NULL REFERENCES floor_plan_symbols (id), "sort_key" TEXT '
    'NOT NULL DEFAULT \'\', "x_m" REAL NOT NULL, "y_m" REAL NOT NULL, "rotation_deg" REAL '
    'NOT NULL DEFAULT 0.0, "width_m" REAL NULL, "height_m" REAL NULL, "fov_deg" REAL '
    'NULL, "fov_reach_m" REAL NULL, "label" TEXT NOT NULL DEFAULT \'\', '
    '"set_element_shape" TEXT NULL, "is_hidden" INTEGER NOT NULL DEFAULT 0 CHECK '
    '("is_hidden" IN (0, 1)), "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" '
    'IN (0, 1)), PRIMARY KEY ("id"))';

/// The `floor_plan_arrows` table schema version 4's `onUpgrade` creates.
const _v4FloorPlanArrowsDdl =
    'CREATE TABLE "floor_plan_arrows" ("id" TEXT NOT NULL, "set_id" TEXT NOT NULL '
    'REFERENCES floor_plan_sets (id), "shot_id" TEXT NOT NULL REFERENCES shots (id), '
    '"kind" TEXT NOT NULL, "from_symbol_id" TEXT NOT NULL REFERENCES floor_plan_symbols '
    '(id), "to_symbol_id" TEXT NOT NULL REFERENCES floor_plan_symbols (id), "label" TEXT '
    'NOT NULL DEFAULT \'\', "ctrl_x_m" REAL NULL, "ctrl_y_m" REAL NULL, "is_deleted" '
    'INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), PRIMARY KEY ("id"))';
