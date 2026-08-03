// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_person_position.dart';
import 'package:open_cine_prod_tools/types/ocpt_image_rights_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_unavailability_slot.dart';

/// A single skill of a person: a driving licence, a language, an instrument — a chip on the person
/// sheet, and the thing an assistant director searches on.
///
/// Not one of the nine model files the resources mode plan enumerates by name: it exists only as a
/// nested shape of [OcptPerson], exactly as `person_skills` only ever surfaces through a person's
/// own sheet.
class OcptPersonSkill extends Equatable {
  /// The stable, unique id of this skill entry (a UUID).
  final String id;

  /// The person who has this skill.
  final String personId;

  /// The skill itself, free text (e.g. "Permis B", "Anglais courant", "Piano").
  final String label;

  /// Class constructor
  const OcptPersonSkill({required this.id, required this.personId, required this.label});

  /// Builds an [OcptPersonSkill] from its stored [row].
  factory OcptPersonSkill.fromRow(OcptPersonSkillRow row) =>
      OcptPersonSkill(id: row.id, personId: row.personId, label: row.label);

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() => "OcptPersonSkill(id: $id, label: $label)";

  /// Object properties
  @override
  List<Object?> get props => [id, personId, label];
}

/// A stretch of time a person is known to be unavailable, with a reason. See [OcptPersonSkill]'s
/// doc comment for why this has no file of its own either, and
/// `OcptPersonUnavailabilitiesTable`'s for why it is a date range crossed with a slot.
class OcptPersonUnavailability extends Equatable {
  /// The stable, unique id of this unavailability (a UUID).
  final String id;

  /// The person who is unavailable.
  final String personId;

  /// The first date this unavailability covers.
  final DateTime startDate;

  /// The last date this unavailability covers, inclusive; the same as [startDate] for one day.
  final DateTime endDate;

  /// Which part of each covered day this unavailability takes.
  final OcptUnavailabilitySlot slot;

  /// The start of the window in minutes from midnight, or null unless [slot] is
  /// [OcptUnavailabilitySlot.custom].
  final int? startMinute;

  /// The end of the window in minutes from midnight, or null unless [slot] is
  /// [OcptUnavailabilitySlot.custom].
  final int? endMinute;

  /// Why this person is unavailable, free multi-line text.
  final String reason;

  /// Class constructor
  const OcptPersonUnavailability({
    required this.id,
    required this.personId,
    required this.startDate,
    required this.endDate,
    required this.slot,
    required this.startMinute,
    required this.endMinute,
    required this.reason,
  });

  /// Builds an [OcptPersonUnavailability] from its stored [row].
  factory OcptPersonUnavailability.fromRow(OcptPersonUnavailabilityRow row) =>
      OcptPersonUnavailability(
        id: row.id,
        personId: row.personId,
        startDate: row.startDate,
        endDate: row.endDate,
        slot: row.slot,
        startMinute: row.startMinute,
        endMinute: row.endMinute,
        reason: row.reason,
      );

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptPersonUnavailability(id: $id, startDate: $startDate, endDate: $endDate, slot: $slot)";

  /// Object properties
  @override
  List<Object?> get props => [
    id,
    personId,
    startDate,
    endDate,
    slot,
    startMinute,
    endMinute,
    reason,
  ];
}

/// The address book: one row per human involved in the production, joined with their
/// [positions], [skills] and [unavailabilities] — a person is never shown as a bare row, since
/// what the person sheet needs is always the whole picture at once.
///
/// `displayName`, `initials`, `age` and `isMinor` are all **derived**, never stored: a stored
/// "15 ans" would be wrong within a year, and a stored display name could drift out of sync with
/// the `firstName`/`lastName` it was built from. They are plain getters rather than fields
/// computed once at construction (unlike, say, `OcptShot.code`): every value they need is already
/// held by this object, so nothing external has to be threaded through `fromRow` to compute them,
/// and `age`/`isMinor` change with the passage of time alone, not with an edit.
class OcptPerson extends Equatable {
  /// The stable, unique id of this person (a UUID).
  final String id;

  /// The person's first name, free text.
  final String firstName;

  /// The person's last name, free text.
  final String lastName;

  /// The person's email address, free text.
  final String email;

  /// The person's phone number, free text.
  final String phone;

  /// The street part of the person's postal address, free text. See `OcptPeopleTable.addressLine1`
  /// for why an address is six fields rather than one.
  final String addressLine1;

  /// The second line of the person's postal address, free text.
  final String addressLine2;

  /// The person's postal code, free text.
  final String postalCode;

  /// The person's city, free text.
  final String city;

  /// The person's region, state, province or county, free text.
  final String region;

  /// The person's country, free text.
  final String country;

  /// Indexes `ocptCoveragePalette`, so this person keeps one avatar colour everywhere.
  final int colorIndex;

  /// The person's date of birth, or null if unknown. See the class doc comment for [age].
  final DateTime? birthDate;

  /// The legal framing to observe when this person is a minor, free text.
  final String minorNotes;

  /// Whether this person can travel to set on their own. Tri-state: null means "not asked yet".
  final bool? isTransportAutonomous;

  /// Where this person stays during the shoot, free text.
  final String accommodationNotes;

  /// Travel logistics for this person, free text.
  final String travelNotes;

  /// Dietary requirements for catering, free text.
  final String dietaryNotes;

  /// Allergies, free text.
  final String allergies;

  /// Top/upper body clothing size, free text.
  final String sizeTop;

  /// Bottom clothing size, free text.
  final String sizeBottom;

  /// Shoe size, free text.
  final String sizeShoes;

  /// Hair/make-up/costume continuity notes, free multi-line text.
  final String hmcNotes;

  /// Where this person's image rights release stands.
  final OcptImageRightsStatus imageRightsStatus;

  /// The date [imageRightsStatus] last changed, or null.
  final DateTime? imageRightsDate;

  /// The signed release document, or null while there is none. → `OcptAssetRef`
  final String? imageRightsAssetId;

  /// This person's photo, or null while there is none. → `OcptAssetRef`
  final String? photoAssetId;

  /// Free-form notes about this person.
  final String notes;

  /// The crew positions this person holds on the film, in display order.
  final List<OcptPersonPosition> positions;

  /// This person's skills, in display order.
  final List<OcptPersonSkill> skills;

  /// The dates this person is known to be unavailable.
  final List<OcptPersonUnavailability> unavailabilities;

  /// Class constructor
  const OcptPerson({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.addressLine1,
    required this.addressLine2,
    required this.postalCode,
    required this.city,
    required this.region,
    required this.country,
    required this.colorIndex,
    required this.birthDate,
    required this.minorNotes,
    required this.isTransportAutonomous,
    required this.accommodationNotes,
    required this.travelNotes,
    required this.dietaryNotes,
    required this.allergies,
    required this.sizeTop,
    required this.sizeBottom,
    required this.sizeShoes,
    required this.hmcNotes,
    required this.imageRightsStatus,
    required this.imageRightsDate,
    required this.imageRightsAssetId,
    required this.photoAssetId,
    required this.notes,
    required this.positions,
    required this.skills,
    required this.unavailabilities,
  });

  /// Builds an [OcptPerson] from its stored [row], its already-ordered [positions] and [skills],
  /// and its [unavailabilities].
  factory OcptPerson.fromRow({
    required OcptPersonRow row,
    required List<OcptPersonPosition> positions,
    required List<OcptPersonSkill> skills,
    required List<OcptPersonUnavailability> unavailabilities,
  }) => OcptPerson(
    id: row.id,
    firstName: row.firstName,
    lastName: row.lastName,
    email: row.email,
    phone: row.phone,
    addressLine1: row.addressLine1,
    addressLine2: row.addressLine2,
    postalCode: row.postalCode,
    city: row.city,
    region: row.region,
    country: row.country,
    colorIndex: row.colorIndex,
    birthDate: row.birthDate,
    minorNotes: row.minorNotes,
    isTransportAutonomous: row.isTransportAutonomous,
    accommodationNotes: row.accommodationNotes,
    travelNotes: row.travelNotes,
    dietaryNotes: row.dietaryNotes,
    allergies: row.allergies,
    sizeTop: row.sizeTop,
    sizeBottom: row.sizeBottom,
    sizeShoes: row.sizeShoes,
    hmcNotes: row.hmcNotes,
    imageRightsStatus: row.imageRightsStatus,
    imageRightsDate: row.imageRightsDate,
    imageRightsAssetId: row.imageRightsAssetId,
    photoAssetId: row.photoAssetId,
    notes: row.notes,
    positions: positions,
    skills: skills,
    unavailabilities: unavailabilities,
  );

  /// [firstName] and [lastName], space-joined, either side dropped when empty.
  String get displayName => [
    firstName,
    lastName,
  ].where((part) => part.isNotEmpty).join(' ');

  /// The upper-cased first letter of [firstName] and of [lastName], concatenated; empty when both
  /// are empty.
  String get initials => [
    firstName,
    lastName,
  ].where((part) => part.isNotEmpty).map((part) => part[0].toUpperCase()).join();

  /// This person's age in whole years as of now, or null while [birthDate] is unknown.
  int? get age {
    final birth = birthDate;
    if (birth == null) {
      return null;
    }

    final now = DateTime.now();
    var years = now.year - birth.year;
    if (now.month < birth.month || (now.month == birth.month && now.day < birth.day)) {
      years--;
    }
    return years;
  }

  /// Whether this person is a minor (under 18) as of now, or null while [age] is unknown.
  bool? get isMinor {
    final currentAge = age;
    return currentAge == null ? null : currentAge < 18;
  }

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() => "OcptPerson(id: $id, displayName: $displayName)";

  /// Object properties
  @override
  List<Object?> get props => [
    id,
    firstName,
    lastName,
    email,
    phone,
    addressLine1,
    addressLine2,
    postalCode,
    city,
    region,
    country,
    colorIndex,
    birthDate,
    minorNotes,
    isTransportAutonomous,
    accommodationNotes,
    travelNotes,
    dietaryNotes,
    allergies,
    sizeTop,
    sizeBottom,
    sizeShoes,
    hmcNotes,
    imageRightsStatus,
    imageRightsDate,
    imageRightsAssetId,
    photoAssetId,
    notes,
    positions,
    skills,
    unavailabilities,
  ];
}
