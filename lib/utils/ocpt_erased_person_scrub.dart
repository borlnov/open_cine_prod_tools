// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// The `people` payload keys an erasure **keeps**: the row's identity, its place in the list and
/// the colour it is drawn with, none of which says anything about the person.
///
/// See [ocptScrubErasedPeopleFromPayload] for the whole rule and for what guards it.
const ocptErasedPersonKeptKeys = {"id", "sortKey", "colorIndex"};

/// The `people` payload keys an erasure **blanks to the empty string**: every text column that
/// held something about the person.
const ocptErasedPersonBlankedKeys = {
  "firstName",
  "lastName",
  "email",
  "phone",
  "addressLine1",
  "addressLine2",
  "postalCode",
  "city",
  "region",
  "country",
  "minorNotes",
  "accommodationNotes",
  "travelNotes",
  "dietaryNotes",
  "allergies",
  "measurementHeight",
  "measurementChest",
  "measurementWaist",
  "measurementHips",
  "sizeTop",
  "sizeBottom",
  "sizeShoes",
  "hmcNotes",
  "notes",
};

/// The `people` payload keys an erasure **sets to null**: the nullable ones, dates and foreign
/// keys among them.
///
/// A nullable foreign key (`imageRightsAssetId`, `photoAssetId`) has to go to null rather than to
/// the empty string the text columns take: `people` references `assets`, that reference is enforced
/// (`PRAGMA foreign_keys = ON`), and an empty string is a reference to an asset whose id is `""`.
/// It would fail at the write rather than merely reading oddly.
const ocptErasedPersonNulledKeys = {
  "birthDate",
  "maxDailyPresenceMinutes",
  "isTransportAutonomous",
  "imageRightsDate",
  "imageRightsAssetId",
  "photoAssetId",
  "commuteKmMilli",
  "mileageRateId",
};

/// The value the `imageRightsStatus` key takes on an erased person: the same
/// `OcptImageRightsStatus.notApplicable` the live erasure writes, by the name the payload stores an
/// enum under.
///
/// It is named here rather than blanked with the other text keys because the empty string is not a
/// value this column has: reading it back would throw instead of parsing.
const ocptErasedPersonImageRightsStatus = "notApplicable";

/// The payload key every synchronised row carries its tombstone in.
const _isDeletedKey = "isDeleted";

/// The payload key a row pointing at a person names them by.
const _personIdKey = "personId";

/// The `id` key, which is also how a `people` row names itself.
const _idKey = "id";

/// The `assets` payload keys an erasure blanks, on top of tombstoning the row.
///
/// An asset's `path` is personal data in its own right — an absolute path routinely names the
/// person (`…/cession-droits-Jean-Dupont.pdf`) and always says where a photograph of them sits —
/// and its `label` is free text somebody typed about them. The rest of the row is ids and dates
/// that say nothing on their own.
const ocptErasedAssetBlankedKeys = {"path", "label"};

/// The payload lists this scrub reaches into, each with the key naming the person it belongs to.
const _scrubbedChildLists = {
  "personPositions": _personIdKey,
  "personSkills": _personIdKey,
  "personUnavailabilities": _personIdKey,
  "assets": _personIdKey,
};

/// The keys blanked, per list, alongside the tombstone of a child row belonging to an erased
/// person.
///
/// `person_skills.label` and `person_unavailabilities.reason` routinely hold something personal (a
/// driving licence, a language, why they were away on a date), so an erasure empties them: it is
/// about what the file stops holding, not only about what a screen stops showing. A
/// `person_positions` row holds a position id and nothing personal, so it is only tombstoned.
const _scrubbedChildBlankedKeys = {
  "personPositions": <String>{},
  "personSkills": {"label"},
  "personUnavailabilities": {"reason"},
  "assets": ocptErasedAssetBlankedKeys,
};

/// [payload] — a project version payload decoded from its stored JSON — with every person of
/// [erasedPersonIds] scrubbed out of it, and a flag saying whether anything was actually changed.
///
/// This is the **third** implementation of one rule, and the only one that is not typed:
/// `OcptPeopleService.deletePerson` (with `OcptAssetsService.erasePersonAssets`) applies it to a
/// live row, `OcptProjectVersionsService._scrubErasedPeople` applies it to a decoded payload on its
/// way to a preview or a restore, and this one applies it to the stored JSON of a payload being
/// **copied out of the project** — the export of a portable package, which must not carry an erased
/// person's data to somebody else's machine. It reads the payload's own keys instead of the
/// schema's Dart types because a package may be built from a project file at **any** schema
/// version, including one this build would migrate: nothing here may assume a shape.
///
/// The three are kept in step by a test rather than by hand: it walks every key the codec writes
/// for a person and fails unless this file names it in exactly one of [ocptErasedPersonKeptKeys],
/// [ocptErasedPersonBlankedKeys], [ocptErasedPersonNulledKeys] or the two forced ones
/// ([_isDeletedKey], `imageRightsStatus`). A column added to `people` without a word here is caught
/// there, which is the failure this scrub cannot afford to discover on a user's machine.
///
/// A key this file has never heard of — the shape of an older payload format, or the very column
/// that test is about to complain about — is emptied by the type of the value it holds rather than
/// left alone: a string becomes empty, anything else becomes null. Leaking is the one outcome that
/// is not acceptable, so the fallback errs towards taking too much out.
///
/// The payload is **not** rewritten when [erasedPersonIds] is empty, or when it names nobody this
/// payload holds: the caller relies on that to leave a stored version byte-identical, digest
/// included, whenever there is nothing to scrub.
({Map<String, dynamic> payload, bool changed}) ocptScrubErasedPeopleFromPayload({
  required Map<String, dynamic> payload,
  required Set<String> erasedPersonIds,
}) {
  if (erasedPersonIds.isEmpty) {
    return (payload: payload, changed: false);
  }

  /// Whether [rows] holds at least one row naming an erased person through [personKey].
  bool namesErasedPerson(List<dynamic> rows, String personKey) =>
      rows.any((row) => row is Map<String, dynamic> && erasedPersonIds.contains(row[personKey]));

  var changed = false;
  final scrubbed = Map<String, dynamic>.from(payload);

  final people = payload["people"];
  if (people is List && namesErasedPerson(people, _idKey)) {
    scrubbed["people"] = [
      for (final row in people)
        if (row is Map<String, dynamic> && erasedPersonIds.contains(row[_idKey]))
          _scrubbedPersonRow(row)
        else
          row,
    ];
    changed = true;
  }

  for (final entry in _scrubbedChildLists.entries) {
    final rows = payload[entry.key];
    if (rows is! List || !namesErasedPerson(rows, entry.value)) {
      continue;
    }

    scrubbed[entry.key] = [
      for (final row in rows)
        if (row is Map<String, dynamic> && erasedPersonIds.contains(row[entry.value]))
          _scrubbedChildRow(row, blankedKeys: _scrubbedChildBlankedKeys[entry.key]!)
        else
          row,
    ];
    changed = true;
  }

  return (payload: scrubbed, changed: changed);
}

/// [row], a `people` payload row, with everything it said about the person taken out of it and its
/// tombstone raised.
///
/// The rule is stated as what is **kept** rather than as what is removed, so a column added to
/// `people` later is scrubbed by default instead of travelling because nobody thought of it.
Map<String, dynamic> _scrubbedPersonRow(Map<String, dynamic> row) => {
  for (final entry in row.entries)
    entry.key: switch (entry.key) {
      _isDeletedKey => true,
      "imageRightsStatus" => ocptErasedPersonImageRightsStatus,
      final key when ocptErasedPersonKeptKeys.contains(key) => entry.value,
      final key when ocptErasedPersonBlankedKeys.contains(key) => "",
      final key when ocptErasedPersonNulledKeys.contains(key) => null,
      _ => _emptiedByValueType(entry.value),
    },
};

/// [row], a row belonging to an erased person, tombstoned and with [blankedKeys] emptied.
Map<String, dynamic> _scrubbedChildRow(
  Map<String, dynamic> row, {
  required Set<String> blankedKeys,
}) => {
  for (final entry in row.entries)
    entry.key: switch (entry.key) {
      _isDeletedKey => true,
      final key when blankedKeys.contains(key) => "",
      _ => entry.value,
    },
};

/// The empty value of whatever [value] is: the empty string for a string, null for everything else.
///
/// The fallback of [ocptScrubErasedPeopleFromPayload] for a key it does not know — see its doc
/// comment for why erring towards taking too much out is the only acceptable direction here.
Object? _emptiedByValueType(Object? value) => value is String ? "" : null;
