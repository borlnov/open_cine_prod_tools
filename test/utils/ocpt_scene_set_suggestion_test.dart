// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/models/ocpt_location.dart';
import 'package:open_cine_prod_tools/models/ocpt_set.dart';
import 'package:open_cine_prod_tools/types/ocpt_permit_status.dart';
import 'package:open_cine_prod_tools/utils/ocpt_scene_set_suggestion.dart';

/// Builds a set of location `l1` named [name].
OcptSet _set({required String id, required String name}) =>
    OcptSet(id: id, locationId: "l1", code: "", name: name, notes: "", sceneIds: const []);

/// Builds a location named [name] holding [sets].
OcptLocation _location({
  required String id,
  required String name,
  required List<OcptSet> sets,
}) => OcptLocation(
  id: id,
  name: name,
  colorIndex: 0,
  addressLine1: "",
  addressLine2: "",
  postalCode: "",
  city: "",
  region: "",
  country: "",
  latitude: null,
  longitude: null,
  contactPersonId: null,
  contactNotes: "",
  permitStatus: OcptPermitStatus.notNeeded,
  permitLabel: "",
  permitDate: null,
  permitAssetId: null,
  parkingNotes: "",
  powerNotes: "",
  facilitiesNotes: "",
  constraintsNotes: "",
  notes: "",
  sets: sets,
  photos: const [],
  permitDocument: null,
  availabilities: const [],
);

void main() {
  group("ocptSceneHeadingPlaceOf", () {
    test("drops the interior/exterior prefix and the time of day", () {
      expect(ocptSceneHeadingPlaceOf("INT. APPARTEMENT DE LÉA - NUIT"), "APPARTEMENT DE LÉA");
      expect(ocptSceneHeadingPlaceOf("EXT. JARDIN - JOUR"), "JARDIN");
      expect(ocptSceneHeadingPlaceOf("INT./EXT. VOITURE - CONTINU"), "VOITURE");
      expect(ocptSceneHeadingPlaceOf("I/E VOITURE - NUIT"), "VOITURE");
    });

    test("upper-cases and collapses whitespace", () {
      expect(ocptSceneHeadingPlaceOf("  int.   la  cuisine - jour "), "LA CUISINE");
    });

    test("keeps a heading that carries no time of day", () {
      expect(ocptSceneHeadingPlaceOf("INT. CUISINE"), "CUISINE");
    });

    test("a heading naming no place at all reduces to nothing", () {
      expect(ocptSceneHeadingPlaceOf("INT."), "");
    });
  });

  group("ocptSceneSetSuggestionOf", () {
    test("suggests the set whose name is the place the heading names", () {
      final locations = [
        _location(
          id: "l1",
          name: "La maison des Pains",
          sets: [_set(id: "s1", name: "Jardin"), _set(id: "s2", name: "Cuisine")],
        ),
      ];

      expect(
        ocptSceneSetSuggestionOf(heading: "INT. CUISINE - JOUR", locations: locations),
        "s2",
      );
    });

    test("an exact set name beats one that merely contains it", () {
      final locations = [
        _location(
          id: "l1",
          name: "La maison des Pains",
          sets: [_set(id: "s1", name: "Cuisine du hangar"), _set(id: "s2", name: "Cuisine")],
        ),
      ];

      expect(
        ocptSceneSetSuggestionOf(heading: "INT. CUISINE - JOUR", locations: locations),
        "s2",
      );
    });

    test("a heading naming a location suggests its only set", () {
      final locations = [
        _location(id: "l1", name: "Le hangar", sets: [_set(id: "s1", name: "Atelier")]),
      ];

      expect(ocptSceneSetSuggestionOf(heading: "EXT. LE HANGAR - NUIT", locations: locations), "s1");
    });

    test("a heading naming a location holding several sets suggests none of them", () {
      final locations = [
        _location(
          id: "l1",
          name: "Le hangar",
          sets: [_set(id: "s1", name: "Atelier"), _set(id: "s2", name: "Réserve")],
        ),
      ];

      // Only the user knows which of the two, and the app never picks for them.
      expect(ocptSceneSetSuggestionOf(heading: "EXT. LE HANGAR - NUIT", locations: locations), isNull);
    });

    test("nothing resembling the heading suggests nothing", () {
      final locations = [
        _location(id: "l1", name: "Le hangar", sets: [_set(id: "s1", name: "Atelier")]),
      ];

      expect(ocptSceneSetSuggestionOf(heading: "INT. GARE - JOUR", locations: locations), isNull);
    });

    test("a set with no name yet is never suggested", () {
      final locations = [
        _location(id: "l1", name: "Le hangar", sets: [_set(id: "s1", name: "")]),
      ];

      expect(ocptSceneSetSuggestionOf(heading: "INT. CUISINE - JOUR", locations: locations), isNull);
    });

    test("a two-letter set name is not matched by containment", () {
      final locations = [
        _location(id: "l1", name: "Le hangar", sets: [_set(id: "s1", name: "Le")]),
      ];

      // Below three characters, containment would suggest that set for nearly every heading.
      expect(ocptSceneSetSuggestionOf(heading: "INT. LE CLOS - JOUR", locations: locations), isNull);
    });
  });
}
