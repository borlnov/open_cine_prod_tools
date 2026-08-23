// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_project_version_codec.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_version_payload.dart';
import 'package:open_cine_prod_tools/types/ocpt_asset_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_day_part_slot.dart';
import 'package:open_cine_prod_tools/types/ocpt_image_rights_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_candidate_status.dart';
import 'package:open_cine_prod_tools/utils/ocpt_erased_person_scrub.dart';

void main() {
  const codec = OcptProjectVersionCodec();

  /// A person row with every column carrying something, so a scrub that forgot one shows.
  const richPerson = OcptPersonRow(
    id: "person-1",
    isDeleted: false,
    sortKey: "V",
    firstName: "Clara",
    lastName: "Martin",
    email: "clara@example.com",
    phone: "0102030405",
    addressLine1: "12 rue des Lilas",
    addressLine2: "Bâtiment B",
    postalCode: "75011",
    city: "Paris",
    region: "Île-de-France",
    country: "France",
    colorIndex: 2,
    minorNotes: "Accompanied by a parent",
    maxDailyPresenceMinutes: 480,
    isTransportAutonomous: true,
    accommodationNotes: "Chez Camille",
    travelNotes: "Carte jeune SNCF",
    dietaryNotes: "Vegetarian",
    allergies: "Peanuts",
    measurementHeight: "168",
    measurementChest: "88",
    measurementWaist: "68",
    measurementHips: "94",
    sizeTop: "38",
    sizeBottom: "M",
    sizeShoes: "39",
    hmcNotes: "Redhead wig",
    imageRightsStatus: OcptImageRightsStatus.signed,
    imageRightsAssetId: "asset-1",
    photoAssetId: "asset-2",
    notes: "Lead actress",
    commuteKmMilli: 1484000,
    mileageRateId: "rate-1",
  );

  /// A payload holding [richPerson], everything hanging off them, and one row that is somebody
  /// else's business entirely.
  OcptProjectVersionPayload buildPayload() => OcptProjectVersionPayload(
    screenplays: const [],
    scenes: const [],
    shots: const [],
    shotCharacters: const [],
    shotCoverages: const [],
    people: [
      richPerson,
      const OcptPersonRow(
        id: "person-2",
        isDeleted: false,
        sortKey: "k",
        firstName: "Sam",
        lastName: "Roche",
        email: "sam@example.com",
        phone: "",
        addressLine1: "",
        addressLine2: "",
        postalCode: "",
        city: "",
        region: "",
        country: "",
        colorIndex: 3,
        minorNotes: "",
        accommodationNotes: "",
        travelNotes: "",
        dietaryNotes: "",
        allergies: "",
        measurementHeight: "",
        measurementChest: "",
        measurementWaist: "",
        measurementHips: "",
        sizeTop: "",
        sizeBottom: "",
        sizeShoes: "",
        hmcNotes: "",
        imageRightsStatus: OcptImageRightsStatus.notApplicable,
        notes: "",
      ),
    ],
    personPositions: const [
      OcptPersonPositionRow(
        id: "position-1",
        isDeleted: false,
        personId: "person-1",
        positionId: "director",
        customLabel: "",
        sortKey: "V",
      ),
    ],
    personSkills: const [
      OcptPersonSkillRow(
        id: "skill-1",
        isDeleted: false,
        personId: "person-1",
        label: "Driving licence B",
        sortKey: "V",
      ),
      OcptPersonSkillRow(
        id: "skill-2",
        personId: "person-2",
        label: "Horse riding",
        sortKey: "k",
        isDeleted: false,
      ),
    ],
    personUnavailabilities: [
      OcptPersonUnavailabilityRow(
        id: "unavailability-1",
        isDeleted: false,
        personId: "person-1",
        startDate: DateTime.utc(2026, 4, 2),
        endDate: DateTime.utc(2026, 4, 3),
        slot: OcptDayPartSlot.fullDay,
        reason: "Hospital appointment",
      ),
    ],
    roles: const [],
    roleEpisodes: const [],
    locations: const [],
    locationAvailabilities: const [],
    sets: const [],
    sceneSets: const [],
    elements: const [],
    sceneElements: const [],
    roleElements: const [],
    roleCandidates: [
      OcptRoleCandidateRow(
        id: "candidate-1",
        roleId: "role-1",
        personId: "person-1",
        status: OcptRoleCandidateStatus.retained,
        auditionedOn: DateTime.utc(2026, 2, 12),
        notes: "Fragile in the audition, exactly right for the part",
        sortKey: "V",
        isDeleted: false,
      ),
      const OcptRoleCandidateRow(
        id: "candidate-2",
        roleId: "role-1",
        personId: "person-2",
        status: OcptRoleCandidateStatus.seen,
        notes: "Too old for it",
        sortKey: "k",
        isDeleted: false,
      ),
    ],
    assets: [
      OcptAssetRow(
        id: "asset-1",
        isDeleted: false,
        kind: OcptAssetKind.document,
        path: "/home/benoit/docs/cession-droits-Clara-Martin.pdf",
        label: "Cession de droits",
        addedAt: DateTime.utc(2026, 3),
        sortKey: "V",
        personId: "person-1",
      ),
      OcptAssetRow(
        id: "asset-3",
        isDeleted: false,
        kind: OcptAssetKind.locationPhoto,
        path: "/home/benoit/photos/entrepot.jpg",
        label: "Entrepôt, façade",
        addedAt: DateTime.utc(2026, 3),
        sortKey: "k",
        locationId: "location-1",
      ),
    ],
    breakdownTags: const [],
    sceneBreakdowns: const [],
    shootingDays: const [],
    shootingSlots: const [],
    shootingSlotCrew: const [],
    shootingSlotCast: const [],
    shootingDayBlocks: const [],
    shootingSlotGuests: const [],
    shootingDayEvents: const [],
    projectDictionaryWords: const [],
    budgetPostes: const [],
    budgetLines: const [],
    budgetEntries: const [],
    budgetCommitments: const [],
    budgetResources: const [],
    budgetMileageRates: const [],
    budgetRevenues: const [],
    budgetShares: const [],
    budgetAllowances: const [],
    rowFieldVersions: const [],
    pageSetup: const OcptPageSetup(
      format: OcptPageFormat.a4,
      margins: FountainPageMargins(
        leftInches: 1.5,
        rightInches: 1,
        topInches: 0.75,
        bottomInches: 1.25,
      ),
    ),
    settingsJson: null,
    currencyCode: "EUR",
    minimumRestMinutes: null,
    screenplayLanguage: null,
    shootingBlockCandidates: const [],
    defaultVatRateBasisPoints: null,
    mealPriceCents: null,
    snackPriceCents: null,
    isBudgetSimplified: null,
  );

  /// [payload] as the stored JSON of a version, which is what the scrub actually reads.
  Map<String, dynamic> encodedPayloadOf(OcptProjectVersionPayload payload) =>
      jsonDecode(codec.encode(payload)) as Map<String, dynamic>;

  /// The `people` row [id] of [payload], as JSON.
  Map<String, dynamic> personOf(Map<String, dynamic> payload, String id) =>
      (payload["people"] as List<dynamic>).cast<Map<String, dynamic>>().firstWhere(
        (row) => row["id"] == id,
      );

  /// The row of the [list] of [payload] whose `id` is [id], as JSON.
  Map<String, dynamic> rowOf(Map<String, dynamic> payload, String list, String id) =>
      (payload[list] as List<dynamic>).cast<Map<String, dynamic>>().firstWhere(
        (row) => row["id"] == id,
      );

  group("the rule covers what the codec writes", () {
    test("every people key is named by exactly one rule", () {
      final person = personOf(encodedPayloadOf(buildPayload()), "person-1");

      // This is what keeps this scrub in step with the two typed ones by hand: a column added to
      // `people` without a word said here fails at this line rather than travelling to somebody
      // else's machine because nobody thought of it.
      for (final key in person.keys) {
        final namedBy = [
          if (ocptErasedPersonKeptKeys.contains(key)) "kept",
          if (ocptErasedPersonBlankedKeys.contains(key)) "blanked",
          if (ocptErasedPersonNulledKeys.contains(key)) "nulled",
          if (key == "isDeleted" || key == "imageRightsStatus") "forced",
        ];

        expect(
          namedBy,
          hasLength(1),
          reason: "the people payload key '$key' is named by $namedBy rules instead of exactly one",
        );
      }
    });
  });

  group("scrubbing an erased person", () {
    test("keeps only the id, the sort key and the colour, and raises the tombstone", () {
      final scrubbed = ocptScrubErasedPeopleFromPayload(
        payload: encodedPayloadOf(buildPayload()),
        erasedPersonIds: {"person-1"},
      );

      final person = personOf(scrubbed.payload, "person-1");
      expect(scrubbed.changed, isTrue);
      expect(person["id"], "person-1");
      expect(person["sortKey"], "V");
      expect(person["colorIndex"], 2);
      expect(person["isDeleted"], isTrue);
      expect(person["imageRightsStatus"], "notApplicable");

      for (final key in ocptErasedPersonBlankedKeys) {
        expect(person[key], "", reason: "the people key '$key' was expected to be blanked");
      }
      for (final key in ocptErasedPersonNulledKeys) {
        expect(person[key], isNull, reason: "the people key '$key' was expected to be nulled");
      }
    });

    test("leaves everybody else exactly as they were", () {
      final original = encodedPayloadOf(buildPayload());
      final scrubbed = ocptScrubErasedPeopleFromPayload(
        payload: original,
        erasedPersonIds: {"person-1"},
      );

      expect(personOf(scrubbed.payload, "person-2"), personOf(original, "person-2"));
      expect(
        rowOf(scrubbed.payload, "personSkills", "skill-2"),
        rowOf(original, "personSkills", "skill-2"),
      );
    });

    test("blanks and tombstones what hangs off them, and only that", () {
      final original = encodedPayloadOf(buildPayload());
      final scrubbed = ocptScrubErasedPeopleFromPayload(
        payload: original,
        erasedPersonIds: {"person-1"},
      );

      final skill = rowOf(scrubbed.payload, "personSkills", "skill-1");
      expect(skill["label"], "");
      expect(skill["isDeleted"], isTrue);

      final unavailability = rowOf(scrubbed.payload, "personUnavailabilities", "unavailability-1");
      expect(unavailability["reason"], "");
      expect(unavailability["isDeleted"], isTrue);

      // A position holds a position id and nothing personal, so it is tombstoned and left alone.
      final position = rowOf(scrubbed.payload, "personPositions", "position-1");
      expect(position["positionId"], "director");
      expect(position["isDeleted"], isTrue);

      // A candidacy is the one link table that holds something about the person: what somebody
      // wrote about them at an audition goes with the rest of it.
      final candidacy = rowOf(scrubbed.payload, "roleCandidates", "candidate-1");
      expect(candidacy["notes"], "");
      expect(candidacy["isDeleted"], isTrue);
      // The status and the date stay: they say nothing about the person on a row that no longer
      // names anybody, and nothing in this schema is ever hard-deleted.
      expect(candidacy["status"], "retained");
      expect(candidacy["auditionedOn"], isNotNull);

      // Somebody else's candidacy for the very same part travels through untouched.
      final otherCandidacy = rowOf(scrubbed.payload, "roleCandidates", "candidate-2");
      expect(otherCandidacy["notes"], "Too old for it");
      expect(otherCandidacy["isDeleted"], isFalse);
    });

    test("blanks the path and the label of their assets, and leaves a location's alone", () {
      final original = encodedPayloadOf(buildPayload());
      final scrubbed = ocptScrubErasedPeopleFromPayload(
        payload: original,
        erasedPersonIds: {"person-1"},
      );

      // An absolute path names the person and says where a document about them sits: blanking the
      // row without emptying it would leave the leak wide open.
      final theirs = rowOf(scrubbed.payload, "assets", "asset-1");
      expect(theirs["path"], "");
      expect(theirs["label"], "");
      expect(theirs["isDeleted"], isTrue);

      expect(rowOf(scrubbed.payload, "assets", "asset-3"), rowOf(original, "assets", "asset-3"));
    });

    test("leaves a nullable foreign key null rather than empty", () {
      final scrubbed = ocptScrubErasedPeopleFromPayload(
        payload: encodedPayloadOf(buildPayload()),
        erasedPersonIds: {"person-1"},
      );

      // `people` references `assets` and that reference is enforced: an empty string here is a
      // reference to an asset whose id is "", which fails at the write rather than reading oddly.
      final person = personOf(scrubbed.payload, "person-1");
      expect(person["photoAssetId"], isNull);
      expect(person["imageRightsAssetId"], isNull);
      expect(person["mileageRateId"], isNull);
    });

    test("a scrubbed payload still decodes, and the person comes back blank", () {
      final scrubbed = ocptScrubErasedPeopleFromPayload(
        payload: encodedPayloadOf(buildPayload()),
        erasedPersonIds: {"person-1"},
      );

      final decoded = codec.decode(jsonEncode(scrubbed.payload));
      final payload = decoded.value;

      expect(payload, isNotNull);
      final person = payload!.people.firstWhere((row) => row.id == "person-1");
      expect(person.firstName, "");
      expect(person.lastName, "");
      expect(person.phone, "");
      expect(person.allergies, "");
      expect(person.birthDate, isNull);
      expect(person.photoAssetId, isNull);
      expect(person.imageRightsStatus, OcptImageRightsStatus.notApplicable);
      expect(person.isDeleted, isTrue);
    });
  });

  group("scrubbing nothing", () {
    test("an empty erasure list leaves the payload untouched, identically", () {
      final original = encodedPayloadOf(buildPayload());
      final scrubbed = ocptScrubErasedPeopleFromPayload(
        payload: original,
        erasedPersonIds: const {},
      );

      expect(scrubbed.changed, isFalse);
      expect(identical(scrubbed.payload, original), isTrue);
    });

    test("an erasure naming nobody this payload holds changes nothing", () {
      final scrubbed = ocptScrubErasedPeopleFromPayload(
        payload: encodedPayloadOf(buildPayload()),
        erasedPersonIds: {"person-404"},
      );

      expect(scrubbed.changed, isFalse);
    });
  });

  group("a key the rule has never heard of", () {
    test("is emptied by the type of what it holds rather than left alone", () {
      final payload = encodedPayloadOf(buildPayload());
      final people = (payload["people"] as List<dynamic>).cast<Map<String, dynamic>>();
      // The column somebody adds to `people` next, before this file has heard of it.
      people.firstWhere((row) => row["id"] == "person-1")
        ..["socialSecurityNumber"] = "1 84 12 75 116 001 42"
        ..["shoeWidth"] = 3;

      final scrubbed = ocptScrubErasedPeopleFromPayload(
        payload: payload,
        erasedPersonIds: {"person-1"},
      );

      final person = personOf(scrubbed.payload, "person-1");
      expect(person["socialSecurityNumber"], "");
      expect(person["shoeWidth"], isNull);
    });
  });
}
