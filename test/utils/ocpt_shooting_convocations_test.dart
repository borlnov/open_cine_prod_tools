// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/utils/ocpt_shooting_convocations.dart';

void main() {
  group("one slot, one person", () {
    test("arrival and departure read off the slot's own bounds", () {
      const slot = OcptConvocationSlot(
        id: "slot-1",
        startMinute: 480,
        endMinute: 600,
        shootingStartMinute: 500,
        shootingEndMinute: 590,
        hasFilmingBlock: true,
        personIds: {"person-1"},
        uncastRoleIds: {},
        guestPersonIds: {},
        guestFreeNames: {},
      );

      final result = ocptComputeDayConvocations(slots: const [slot]);

      final convocation = result.single;
      expect(convocation.personId, "person-1");
      expect(convocation.roleId, isNull);
      expect(convocation.arrivalMinute, 480);
      expect(convocation.patStartMinute, 500);
      expect(convocation.patEndMinute, 590);
      expect(convocation.departureMinute, 600);
      expect(convocation.slotIds, ["slot-1"]);
    });
  });

  group("a person on two slots", () {
    test("arrival is the earliest, departure the latest, one PAT band spans both with a gap", () {
      const morning = OcptConvocationSlot(
        id: "slot-morning",
        startMinute: 480, // 08:00
        endMinute: 720, // 12:00
        shootingStartMinute: 510, // 08:30
        shootingEndMinute: 690, // 11:30
        hasFilmingBlock: true,
        personIds: {"person-1"},
        uncastRoleIds: {},
        guestPersonIds: {},
        guestFreeNames: {},
      );
      const evening = OcptConvocationSlot(
        id: "slot-evening",
        startMinute: 1080, // 18:00
        endMinute: 1260, // 21:00
        shootingStartMinute: 1110, // 18:30
        shootingEndMinute: 1230, // 20:30
        hasFilmingBlock: true,
        personIds: {"person-1"},
        uncastRoleIds: {},
        guestPersonIds: {},
        guestFreeNames: {},
      );

      final result = ocptComputeDayConvocations(slots: const [morning, evening]);

      final convocation = result.single;
      expect(convocation.arrivalMinute, 480);
      // The band spans from the morning's own first shot to the evening's own last, gaps between
      // the two slots included — it is not clipped to either slot alone.
      expect(convocation.patStartMinute, 510);
      expect(convocation.patEndMinute, 1230);
      expect(convocation.departureMinute, 1260);
      expect(convocation.slotIds, ["slot-morning", "slot-evening"]);
    });
  });

  group("a person on a preparation-only slot", () {
    test("has an arrival and a departure but no PAT band at all", () {
      const slot = OcptConvocationSlot(
        id: "slot-1",
        startMinute: 480,
        endMinute: 540,
        shootingStartMinute: null,
        shootingEndMinute: null,
        hasFilmingBlock: true,
        personIds: {"person-1"},
        uncastRoleIds: {},
        guestPersonIds: {},
        guestFreeNames: {},
      );

      final result = ocptComputeDayConvocations(slots: const [slot]);

      final convocation = result.single;
      expect(convocation.arrivalMinute, 480);
      expect(convocation.departureMinute, 540);
      expect(convocation.patStartMinute, isNull);
      expect(convocation.patEndMinute, isNull);
    });
  });

  group("a slot with no block at all", () {
    test("ends at its own start minute", () {
      const slot = OcptConvocationSlot(
        id: "slot-1",
        startMinute: 480,
        endMinute: null,
        shootingStartMinute: null,
        shootingEndMinute: null,
        hasFilmingBlock: true,
        personIds: {"person-1"},
        uncastRoleIds: {},
        guestPersonIds: {},
        guestFreeNames: {},
      );

      final result = ocptComputeDayConvocations(slots: const [slot]);

      final convocation = result.single;
      expect(convocation.arrivalMinute, 480);
      expect(convocation.departureMinute, 480);
    });
  });

  group("an uncast role", () {
    test("gets its own row, named by the role rather than by nobody", () {
      const slot = OcptConvocationSlot(
        id: "slot-1",
        startMinute: 480,
        endMinute: 600,
        shootingStartMinute: 500,
        shootingEndMinute: 590,
        hasFilmingBlock: true,
        personIds: {},
        uncastRoleIds: {"role-1"},
        guestPersonIds: {},
        guestFreeNames: {},
      );

      final result = ocptComputeDayConvocations(slots: const [slot]);

      final convocation = result.single;
      expect(convocation.personId, isNull);
      expect(convocation.roleId, "role-1");
      expect(convocation.arrivalMinute, 480);
    });
  });

  group("a night slot crossing midnight", () {
    test("minutes past 1440 are never taken modulo anything", () {
      const slot = OcptConvocationSlot(
        id: "slot-1",
        startMinute: 1140, // 19:00
        endMinute: 1620, // 03:00 the next morning
        shootingStartMinute: 1140,
        shootingEndMinute: 1620,
        hasFilmingBlock: true,
        personIds: {"person-1"},
        uncastRoleIds: {},
        guestPersonIds: {},
        guestFreeNames: {},
      );

      final result = ocptComputeDayConvocations(slots: const [slot]);

      final convocation = result.single;
      expect(convocation.arrivalMinute, 1140);
      expect(convocation.patStartMinute, 1140);
      expect(convocation.patEndMinute, 1620);
      expect(convocation.departureMinute, 1620);
    });
  });

  group("the result is sorted deterministically", () {
    test("by arrival minute, ties broken by personId ?? roleId", () {
      const early = OcptConvocationSlot(
        id: "slot-early",
        startMinute: 420,
        endMinute: 480,
        shootingStartMinute: null,
        shootingEndMinute: null,
        hasFilmingBlock: true,
        personIds: {"person-b"},
        uncastRoleIds: {},
        guestPersonIds: {},
        guestFreeNames: {},
      );
      const tiedOne = OcptConvocationSlot(
        id: "slot-tied-1",
        startMinute: 480,
        endMinute: 540,
        shootingStartMinute: null,
        shootingEndMinute: null,
        hasFilmingBlock: true,
        personIds: {"person-z"},
        uncastRoleIds: {},
        guestPersonIds: {},
        guestFreeNames: {},
      );
      const tiedTwo = OcptConvocationSlot(
        id: "slot-tied-2",
        startMinute: 480,
        endMinute: 540,
        shootingStartMinute: null,
        shootingEndMinute: null,
        hasFilmingBlock: true,
        personIds: {"person-a"},
        uncastRoleIds: {},
        guestPersonIds: {},
        guestFreeNames: {},
      );

      final result = ocptComputeDayConvocations(slots: const [tiedOne, early, tiedTwo]);

      expect(result.map((convocation) => convocation.personId), [
        "person-b",
        "person-a",
        "person-z",
      ]);
    });
  });

  group("an empty slots list", () {
    test("answers no convocation at all", () {
      expect(ocptComputeDayConvocations(slots: const []), isEmpty);
    });
  });

  group("a guest on a slot carrying shooting blocks", () {
    test("gets an arrival and a departure but never a PAT band", () {
      const slot = OcptConvocationSlot(
        id: "slot-1",
        startMinute: 480,
        endMinute: 600,
        shootingStartMinute: 500,
        shootingEndMinute: 590,
        hasFilmingBlock: true,
        personIds: {},
        uncastRoleIds: {},
        guestPersonIds: {"guest-person-1"},
        guestFreeNames: {},
      );

      final result = ocptComputeDayConvocations(slots: const [slot]);

      final convocation = result.single;
      expect(convocation.isGuest, isTrue);
      expect(convocation.guestPersonId, "guest-person-1");
      expect(convocation.personId, isNull);
      expect(convocation.roleId, isNull);
      expect(convocation.arrivalMinute, 480);
      expect(convocation.departureMinute, 600);
      // The slot carries a shooting block, and still the guest reads no band at all: a guest does
      // not shoot, and a band would say they were waiting to.
      expect(convocation.patStartMinute, isNull);
      expect(convocation.patEndMinute, isNull);
    });
  });

  group("a guest linked to two slots of one day", () {
    test("reads one convocation spanning both", () {
      const morning = OcptConvocationSlot(
        id: "slot-morning",
        startMinute: 480,
        endMinute: 720,
        shootingStartMinute: 510,
        shootingEndMinute: 690,
        hasFilmingBlock: true,
        personIds: {},
        uncastRoleIds: {},
        guestPersonIds: {"guest-person-1"},
        guestFreeNames: {},
      );
      const evening = OcptConvocationSlot(
        id: "slot-evening",
        startMinute: 1080,
        endMinute: 1260,
        shootingStartMinute: 1110,
        shootingEndMinute: 1230,
        hasFilmingBlock: true,
        personIds: {},
        uncastRoleIds: {},
        guestPersonIds: {"guest-person-1"},
        guestFreeNames: {},
      );

      final result = ocptComputeDayConvocations(slots: const [morning, evening]);

      final convocation = result.single;
      expect(convocation.isGuest, isTrue);
      expect(convocation.arrivalMinute, 480);
      expect(convocation.departureMinute, 1260);
      expect(convocation.patStartMinute, isNull);
      expect(convocation.patEndMinute, isNull);
      expect(convocation.slotIds, ["slot-morning", "slot-evening"]);
    });
  });

  group("a person convoked as crew and attending the same day as a guest", () {
    test("reads as two separate convocations", () {
      const slot = OcptConvocationSlot(
        id: "slot-1",
        startMinute: 480,
        endMinute: 600,
        shootingStartMinute: 500,
        shootingEndMinute: 590,
        hasFilmingBlock: true,
        personIds: {"person-1"},
        uncastRoleIds: {},
        guestPersonIds: {"person-1"},
        guestFreeNames: {},
      );

      final result = ocptComputeDayConvocations(slots: const [slot]);

      expect(result, hasLength(2));
      final crewConvocation = result.firstWhere((convocation) => !convocation.isGuest);
      final guestConvocation = result.firstWhere((convocation) => convocation.isGuest);
      expect(crewConvocation.personId, "person-1");
      expect(crewConvocation.patStartMinute, 500);
      expect(guestConvocation.guestPersonId, "person-1");
      expect(guestConvocation.patStartMinute, isNull);
    });
  });

  group("a free-named guest", () {
    test("is grouped by its verbatim name, never normalised", () {
      const slot = OcptConvocationSlot(
        id: "slot-1",
        startMinute: 480,
        endMinute: 600,
        shootingStartMinute: null,
        shootingEndMinute: null,
        hasFilmingBlock: true,
        personIds: {},
        uncastRoleIds: {},
        guestPersonIds: {},
        guestFreeNames: {"Jean Dupont"},
      );

      final result = ocptComputeDayConvocations(slots: const [slot]);

      final convocation = result.single;
      expect(convocation.isGuest, isTrue);
      expect(convocation.guestFreeName, "Jean Dupont");
      expect(convocation.guestPersonId, isNull);
    });
  });

  group("what a band is called", () {
    test("a slot carrying a shot reads a PAT band", () {
      const slot = OcptConvocationSlot(
        id: "slot-1",
        startMinute: 480,
        endMinute: 1080,
        shootingStartMinute: 510,
        shootingEndMinute: 1050,
        hasFilmingBlock: true,
        personIds: {"person-1"},
        uncastRoleIds: {},
        guestPersonIds: {},
        guestFreeNames: {},
      );

      expect(ocptComputeDayConvocations(slots: const [slot]).single.isPatBand, isTrue);
    });

    test("a slot whose work is rehearsals alone reads a presence band, not a PAT one", () {
      // *Prêt à tourner* is the hour somebody must be ready for a take, and a day of rehearsals has
      // none to be ready for — the band is real, the word is not.
      const slot = OcptConvocationSlot(
        id: "slot-1",
        startMinute: 480,
        endMinute: 720,
        shootingStartMinute: 480,
        shootingEndMinute: 720,
        hasFilmingBlock: false,
        personIds: {"person-1"},
        uncastRoleIds: {},
        guestPersonIds: {},
        guestFreeNames: {},
      );

      final convocation = ocptComputeDayConvocations(slots: const [slot]).single;
      expect(convocation.patStartMinute, 480);
      expect(convocation.patEndMinute, 720);
      expect(convocation.isPatBand, isFalse);
    });

    test("one filming slot among several makes the whole band a PAT one", () {
      // The band spans both, so the word has to answer for both: somebody who rehearses in the
      // morning and shoots in the afternoon is due ready to shoot.
      const rehearsal = OcptConvocationSlot(
        id: "slot-morning",
        startMinute: 480,
        endMinute: 720,
        shootingStartMinute: 480,
        shootingEndMinute: 720,
        hasFilmingBlock: false,
        personIds: {"person-1"},
        uncastRoleIds: {},
        guestPersonIds: {},
        guestFreeNames: {},
      );
      const shooting = OcptConvocationSlot(
        id: "slot-afternoon",
        startMinute: 780,
        endMinute: 1080,
        shootingStartMinute: 780,
        shootingEndMinute: 1080,
        hasFilmingBlock: true,
        personIds: {"person-1"},
        uncastRoleIds: {},
        guestPersonIds: {},
        guestFreeNames: {},
      );

      final convocation = ocptComputeDayConvocations(
        slots: const [rehearsal, shooting],
      ).single;
      expect(convocation.patStartMinute, 480);
      expect(convocation.patEndMinute, 1080);
      expect(convocation.isPatBand, isTrue);
    });

    test("a candidate never reads a PAT band, whatever the day beside them shoots", () {
      // The one case the day cannot answer for: the unit films all afternoon and this person is
      // there for twenty minutes to be seen.
      const shooting = OcptConvocationSlot(
        id: "slot-1",
        startMinute: 540,
        endMinute: 1080,
        shootingStartMinute: 540,
        shootingEndMinute: 1080,
        hasFilmingBlock: true,
        personIds: {"person-1"},
        uncastRoleIds: {},
        guestPersonIds: {},
        guestFreeNames: {},
      );
      const audition = OcptConvocationAudition(
        slotId: "slot-1",
        startMinute: 560,
        endMinute: 580,
        roleCandidateIds: {"candidacy-1"},
      );

      final result = ocptComputeDayConvocations(
        slots: const [shooting],
        auditions: const [audition],
      );

      expect(result.firstWhere((c) => c.personId != null).isPatBand, isTrue);
      expect(result.firstWhere((c) => c.isCandidate).isPatBand, isFalse);
    });
  });

  group("a candidate seen for a part", () {
    test("every figure is read off the audition that sees them, not off the unit's day", () {
      // The whole point of ADR 0024: the slot runs 09:00 to 18:00 and sees eleven other people,
      // while this candidate is expected at 09:20 for twenty minutes — and reads exactly that.
      const slot = OcptConvocationSlot(
        id: "slot-1",
        startMinute: 540, // 09:00
        endMinute: 1080, // 18:00
        shootingStartMinute: 540,
        shootingEndMinute: 1080,
        hasFilmingBlock: true,
        personIds: {},
        uncastRoleIds: {},
        guestPersonIds: {},
        guestFreeNames: {},
      );
      const audition = OcptConvocationAudition(
        slotId: "slot-1",
        startMinute: 560, // 09:20
        endMinute: 580, // 09:40
        roleCandidateIds: {"candidacy-1"},
      );

      final result = ocptComputeDayConvocations(
        slots: const [slot],
        auditions: const [audition],
      );

      final convocation = result.single;
      expect(convocation.isCandidate, isTrue);
      expect(convocation.isGuest, isFalse);
      expect(convocation.roleCandidateId, "candidacy-1");
      expect(convocation.personId, isNull);
      expect(convocation.arrivalMinute, 560);
      expect(convocation.patStartMinute, 560);
      expect(convocation.patEndMinute, 580);
      expect(convocation.departureMinute, 580);
      expect(convocation.slotIds, ["slot-1"]);
    });

    test("one block naming two candidacies convokes both, each on the same hour", () {
      // Two actors of two different parts read together: one block, two rows, two convocations.
      const audition = OcptConvocationAudition(
        slotId: "slot-1",
        startMinute: 600,
        endMinute: 640,
        roleCandidateIds: {"candidacy-marie", "candidacy-julien"},
      );

      final result = ocptComputeDayConvocations(slots: const [], auditions: const [audition]);

      expect(result, hasLength(2));
      for (final convocation in result) {
        expect(convocation.arrivalMinute, 600);
        expect(convocation.departureMinute, 640);
        expect(convocation.patStartMinute, 600);
        expect(convocation.patEndMinute, 640);
      }
    });

    test("a candidacy named on two auditions of one day reads one convocation spanning both", () {
      // The same joining rule a person on two slots already gets, one table across — gap included.
      const morning = OcptConvocationAudition(
        slotId: "slot-1",
        startMinute: 560,
        endMinute: 580,
        roleCandidateIds: {"candidacy-1"},
      );
      const afternoon = OcptConvocationAudition(
        slotId: "slot-1",
        startMinute: 900,
        endMinute: 930,
        roleCandidateIds: {"candidacy-1"},
      );

      final result = ocptComputeDayConvocations(
        slots: const [],
        auditions: const [morning, afternoon],
      );

      final convocation = result.single;
      expect(convocation.arrivalMinute, 560);
      expect(convocation.patStartMinute, 560);
      expect(convocation.patEndMinute, 930);
      expect(convocation.departureMinute, 930);
      // Deduplicated: two auditions of one slot are still one unit to turn up on.
      expect(convocation.slotIds, ["slot-1"]);
    });

    test("two candidacies of one person on one day are two convocations", () {
      // The whole reason this arm names a candidacy rather than a person: somebody seen for two
      // parts is coming twice, at two different hours, about two different things.
      const morning = OcptConvocationAudition(
        slotId: "slot-morning",
        startMinute: 540,
        endMinute: 600,
        roleCandidateIds: {"candidacy-marie"},
      );
      const afternoon = OcptConvocationAudition(
        slotId: "slot-afternoon",
        startMinute: 900,
        endMinute: 960,
        roleCandidateIds: {"candidacy-julie"},
      );

      final result = ocptComputeDayConvocations(
        slots: const [],
        auditions: const [morning, afternoon],
      );

      expect(result, hasLength(2));
      expect(result.map((convocation) => convocation.roleCandidateId), [
        "candidacy-marie",
        "candidacy-julie",
      ]);
      expect(result.first.slotIds, ["slot-morning"]);
      expect(result.last.slotIds, ["slot-afternoon"]);
    });

    test("a slot carrying auditions convokes nobody by itself", () {
      // A slot no longer names a candidate at all: with no audition handed in, the day's whole
      // casting session convokes nobody, and nothing is invented from the slot's own hours.
      const slot = OcptConvocationSlot(
        id: "slot-1",
        startMinute: 540,
        endMinute: 600,
        shootingStartMinute: 540,
        shootingEndMinute: 600,
        hasFilmingBlock: true,
        personIds: {},
        uncastRoleIds: {},
        guestPersonIds: {},
        guestFreeNames: {},
      );

      final result = ocptComputeDayConvocations(slots: const [slot]);

      expect(result, isEmpty);
    });
  });
}
