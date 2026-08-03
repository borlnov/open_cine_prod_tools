// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_asset_ref.dart';
import 'package:open_cine_prod_tools/models/ocpt_set.dart';
import 'package:open_cine_prod_tools/types/ocpt_permit_status.dart';

/// A filming location, joined with its [sets]: a location sheet always shows the sets it holds
/// alongside its own fields, so nothing reads a location without them.
class OcptLocation extends Equatable {
  /// The stable, unique id of this location (a UUID).
  final String id;

  /// The location's display name.
  final String name;

  /// Indexes `ocptCoveragePalette`, so this location keeps one colour bar everywhere.
  final int colorIndex;

  /// The street part of the location's postal address, free text. See
  /// `OcptPeopleTable.addressLine1` for why an address is six fields rather than one.
  final String addressLine1;

  /// The second line of the location's postal address, free text.
  final String addressLine2;

  /// The location's postal code, free text.
  final String postalCode;

  /// The location's city, free text.
  final String city;

  /// The location's region, state, province or county, free text.
  final String region;

  /// The location's country, free text.
  final String country;

  /// The location's latitude, or null while it hasn't been pinned on a map.
  final double? latitude;

  /// The location's longitude, or null while it hasn't been pinned on a map.
  final double? longitude;

  /// The person to contact about this location, or null. → `OcptPerson`
  final String? contactPersonId;

  /// Free-text notes about the contact.
  final String contactNotes;

  /// Where this location's filming permit stands.
  final OcptPermitStatus permitStatus;

  /// The permit's own reference/label, free text.
  final String permitLabel;

  /// The date [permitStatus] last changed, or null.
  final DateTime? permitDate;

  /// The signed/granted permit document, or null while there is none. → `OcptAssetRef`
  final String? permitAssetId;

  /// Where vehicles and the production truck can park, free text.
  final String parkingNotes;

  /// What electrical power is available, free text.
  final String powerNotes;

  /// Facilities available on site, free text.
  final String facilitiesNotes;

  /// Constraints on shooting here, free text.
  final String constraintsNotes;

  /// Free-form notes about this location.
  final String notes;

  /// The sets ("décors") of this location, in display order.
  final List<OcptSet> sets;

  /// The scouting photos of this location, in display order, each a path this app never copies
  /// (see [OcptAssetRef]). Empty while none was referenced.
  final List<OcptAssetRef> photos;

  /// The document [permitAssetId] names, or null while there is none — or while the row it names
  /// is gone, which reads exactly the same way: no document to open.
  final OcptAssetRef? permitDocument;

  /// Class constructor
  const OcptLocation({
    required this.id,
    required this.name,
    required this.colorIndex,
    required this.addressLine1,
    required this.addressLine2,
    required this.postalCode,
    required this.city,
    required this.region,
    required this.country,
    required this.latitude,
    required this.longitude,
    required this.contactPersonId,
    required this.contactNotes,
    required this.permitStatus,
    required this.permitLabel,
    required this.permitDate,
    required this.permitAssetId,
    required this.parkingNotes,
    required this.powerNotes,
    required this.facilitiesNotes,
    required this.constraintsNotes,
    required this.notes,
    required this.sets,
    required this.photos,
    required this.permitDocument,
  });

  /// Builds an [OcptLocation] from its stored [row], its already-ordered [sets] and [photos], and
  /// the [permitDocument] its `permitAssetId` resolved to.
  factory OcptLocation.fromRow({
    required OcptLocationRow row,
    required List<OcptSet> sets,
    required List<OcptAssetRef> photos,
    required OcptAssetRef? permitDocument,
  }) =>
      OcptLocation(
        id: row.id,
        name: row.name,
        colorIndex: row.colorIndex,
        addressLine1: row.addressLine1,
        addressLine2: row.addressLine2,
        postalCode: row.postalCode,
        city: row.city,
        region: row.region,
        country: row.country,
        latitude: row.latitude,
        longitude: row.longitude,
        contactPersonId: row.contactPersonId,
        contactNotes: row.contactNotes,
        permitStatus: row.permitStatus,
        permitLabel: row.permitLabel,
        permitDate: row.permitDate,
        permitAssetId: row.permitAssetId,
        parkingNotes: row.parkingNotes,
        powerNotes: row.powerNotes,
        facilitiesNotes: row.facilitiesNotes,
        constraintsNotes: row.constraintsNotes,
        notes: row.notes,
        sets: sets,
        photos: photos,
        permitDocument: permitDocument,
      );

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() => "OcptLocation(id: $id, name: $name, setCount: ${sets.length})";

  /// Object properties
  @override
  List<Object?> get props => [
    id,
    name,
    colorIndex,
    addressLine1,
    addressLine2,
    postalCode,
    city,
    region,
    country,
    latitude,
    longitude,
    contactPersonId,
    contactNotes,
    permitStatus,
    permitLabel,
    permitDate,
    permitAssetId,
    parkingNotes,
    powerNotes,
    facilitiesNotes,
    constraintsNotes,
    notes,
    sets,
    photos,
    permitDocument,
  ];
}
