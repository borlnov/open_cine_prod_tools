// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'resources_mode_scenarios_test_doubles.dart';

/// How long a scenario lets the mode's 2 s field-edit debounce run out.
const _debounceElapsed = Duration(milliseconds: 2500);

/// How long a scenario waits while staying clear of the 2 s field-edit debounce.
const _beforeDebounce = Duration(milliseconds: 300);

/// Run the tests of the resources mode fields scenarios.
void main() {
  final harness = ResourcesScenarioHarness();

  setUpAll(harness.setUpAll);
  setUp(harness.setUp);
  tearDown(harness.tearDown);

  /// Lets the mode's debounce run out and the write behind it settle.
  Future<void> waitForDebounce(WidgetTester tester) async {
    await tester.pump(_debounceElapsed);
    await tester.pumpAndSettle();
  }

  /// Reads the text a [TextField] currently shows.
  String shownIn(WidgetTester tester, Finder field) =>
      tester.widget<TextField>(field).controller!.text;

  testWidgets("a typed person field shows at once, reaches the database when its debounce runs "
      "out, and then the list", (tester) async {
    final aliceId = await harness.seedPerson("Alice");
    await harness.mount(tester);
    final tr = harness.trOf(tester);
    await harness.tap(tester, find.text("Alice"));

    await harness.type(tester, harness.fieldHinted(tr.resourcesFirstNameHint), "Alicia");
    await tester.pump(_beforeDebounce);

    expect(shownIn(tester, harness.fieldHinted(tr.resourcesFirstNameHint)), "Alicia");
    expect((await harness.readPeople()).single.firstName, "Alice");
    expect(harness.inList(find.text("Alicia")), findsNothing);

    await waitForDebounce(tester);

    final person = (await harness.readPeople()).single;
    expect(person.id, aliceId);
    expect(person.firstName, "Alicia");
    expect(harness.inList(find.text("Alicia")), findsOneWidget);
  });

  testWidgets("a typed role note and a typed candidate note ride one debounce, and an unrelated "
      "write in between neither loses nor writes them", (tester) async {
    final roleId = await harness.seedRole("Ghost");
    final aliceId = await harness.seedPerson("Alice", lastName: "Smith");
    final bobId = await harness.seedPerson("Bob", lastName: "Jones");
    await harness.seedCandidate(roleId, aliceId);
    await harness.mount(tester);
    final tr = harness.trOf(tester);
    await harness.openTab(tester, tr.resourcesTabRoles);
    await harness.tap(tester, find.text("Ghost"));

    await harness.type(tester, harness.fieldHinted(tr.resourcesRoleCastingNotesHint), "Agent: Zoe");
    await harness.openCandidateNote(tester);
    await harness.type(tester, harness.candidateNoteField(), "Great voice");
    await tester.pump(_beforeDebounce);
    expect((await harness.readRoles()).singleWhere((r) => r.id == roleId).castingNotes, isEmpty);

    // A second candidate is written at once and reloads the catalogue under the pending notes.
    await harness.tapOpening(tester, find.text(tr.resourcesAddCandidateToRoleAction));
    await harness.tapQuickly(tester, find.text("Bob Jones").last);
    expect((await harness.readCandidates())[roleId], hasLength(2));
    expect(shownIn(tester, harness.fieldHinted(tr.resourcesRoleCastingNotesHint)), "Agent: Zoe");
    expect((await harness.readRoles()).singleWhere((r) => r.id == roleId).castingNotes, isEmpty);

    await waitForDebounce(tester);

    final role = (await harness.readRoles()).singleWhere((r) => r.id == roleId);
    expect(role.castingNotes, "Agent: Zoe");
    final candidates = (await harness.readCandidates())[roleId]!;
    expect(candidates.firstWhere((c) => c.person.id == aliceId).notes, "Great voice");
    expect(candidates.firstWhere((c) => c.person.id == bobId).notes, isEmpty);
  });

  testWidgets("a typed location field and a typed set field ride one debounce", (tester) async {
    final locationId = await harness.seedLocation("Cave");
    final setId = await harness.seedSet(locationId, "Back room");
    await harness.mount(tester);
    final tr = harness.trOf(tester);
    await harness.openTab(tester, tr.resourcesTabLocations);
    await harness.tap(tester, find.text("Cave"));

    await harness.type(tester, harness.fieldHinted(tr.resourcesLocationNameHint), "Grotto");
    await harness.type(tester, harness.fieldLabelled(tr.resourcesSetNameLabel), "Front room");
    await tester.pump(_beforeDebounce);
    expect((await harness.readLocations()).single.name, "Cave");

    await waitForDebounce(tester);

    final location = (await harness.readLocations()).single;
    expect(location.id, locationId);
    expect(location.name, "Grotto");
    expect(location.sets.single.id, setId);
    expect(location.sets.single.name, "Front room");
    expect(find.text("Grotto"), findsWidgets);
  });

  testWidgets("a typed element field is written when its debounce runs out", (tester) async {
    await harness.seedElement("Lamp");
    await harness.mount(tester);
    final tr = harness.trOf(tester);
    await harness.openTab(tester, tr.resourcesTabElements);
    await harness.tap(tester, find.textContaining("Lamp"));

    await harness.type(tester, harness.fieldHinted(tr.resourcesElementNameHint), "Lantern");
    await harness.type(tester, harness.fieldLabelled(tr.resourcesElementQuantityLabel), "3");
    await tester.pump(_beforeDebounce);
    expect((await harness.readElements()).single.name, "Lamp");

    await waitForDebounce(tester);

    final element = (await harness.readElements()).single;
    expect(element.name, "Lantern");
    expect(element.quantity, "3");
  });

  testWidgets("a typed person field is written at once by a change of tab, of selection, or by "
      "adding another person", (tester) async {
    await harness.seedPerson("Alice");
    await harness.seedPerson("Bob");
    await harness.mount(tester);
    final tr = harness.trOf(tester);
    final firstName = harness.fieldHinted(tr.resourcesFirstNameHint);
    await harness.tap(tester, find.text("Alice"));

    // A change of tab.
    await harness.type(tester, firstName, "Alicia");
    await harness.tapQuickly(tester, find.text(tr.resourcesTabRoles));
    await tester.pump();
    expect((await harness.readPeople()).map((p) => p.firstName), contains("Alicia"));

    // A change of selection.
    await harness.openTab(tester, tr.resourcesTabPeople);
    await harness.tap(tester, find.text("Bob"));
    await harness.type(tester, firstName, "Bobby");
    await harness.tapQuickly(tester, find.text("Alicia"));
    await tester.pump();
    expect((await harness.readPeople()).map((p) => p.firstName), contains("Bobby"));

    // Another person added.
    await harness.type(tester, firstName, "Alicia B");
    await harness.tapQuickly(tester, find.text(tr.resourcesAddPersonAction));
    await tester.pump();
    expect((await harness.readPeople()).map((p) => p.firstName), contains("Alicia B"));
  });

  testWidgets("a typed location field is written at once by a change of selection", (tester) async {
    await harness.seedLocation("Cave");
    await harness.seedLocation("Harbour");
    await harness.mount(tester);
    final tr = harness.trOf(tester);
    await harness.openTab(tester, tr.resourcesTabLocations);
    await harness.tap(tester, find.text("Cave"));

    await harness.type(tester, harness.fieldHinted(tr.resourcesLocationNameHint), "Grotto");
    await harness.tapQuickly(tester, find.text("Harbour"));
    await tester.pump();

    expect((await harness.readLocations()).map((l) => l.name), ["Grotto", "Harbour"]);
  });

  testWidgets("a typed role, element and candidate field is written at once by a change of "
      "selection", (tester) async {
    final roleId = await harness.seedRole("Ghost");
    await harness.seedRole("Wraith");
    final aliceId = await harness.seedPerson("Alice", lastName: "Smith");
    await harness.seedCandidate(roleId, aliceId);
    await harness.seedElement("Lamp");
    await harness.seedElement("Rope");
    await harness.mount(tester);
    final tr = harness.trOf(tester);

    await harness.openTab(tester, tr.resourcesTabRoles);
    await harness.tap(tester, find.text("Ghost"));
    await harness.type(tester, harness.fieldHinted(tr.resourcesRoleCastingNotesHint), "Zoe");
    await harness.openCandidateNote(tester);
    await harness.type(tester, harness.candidateNoteField(), "Voice");
    await harness.tapQuickly(tester, find.text("Wraith"));
    await tester.pump();
    expect((await harness.readRoles()).singleWhere((r) => r.id == roleId).castingNotes, "Zoe");
    expect((await harness.readCandidates())[roleId]!.single.notes, "Voice");

    await harness.openTab(tester, tr.resourcesTabElements);
    await harness.tap(tester, find.textContaining("Lamp"));
    await harness.type(tester, harness.fieldHinted(tr.resourcesElementNameHint), "Lantern");
    await harness.tapQuickly(tester, find.textContaining("Rope"));
    await tester.pump();
    expect((await harness.readElements()).map((e) => e.name), contains("Lantern"));
  });

  for (final sheet in <(String, Future<void> Function(WidgetTester), Future<bool> Function())>[
    (
      "person",
      (tester) async {
        final tr = harness.trOf(tester);
        await harness.tap(tester, find.text("Alice"));
        await harness.type(tester, harness.fieldHinted(tr.resourcesFirstNameHint), "Alicia");
      },
      () async => (await harness.readPeople()).any((person) => person.firstName == "Alicia"),
    ),
    (
      "role and candidate",
      (tester) async {
        final tr = harness.trOf(tester);
        await harness.openTab(tester, tr.resourcesTabRoles);
        await harness.tap(tester, find.text("Ghost"));
        await harness.type(tester, harness.fieldHinted(tr.resourcesRoleCastingNotesHint), "Zoe");
        await harness.openCandidateNote(tester);
        await harness.type(tester, harness.candidateNoteField(), "Voice");
      },
      () async {
        final role = (await harness.readRoles()).firstWhere((r) => r.name == "Ghost");
        final candidates = (await harness.readCandidates())[role.id]!;
        return role.castingNotes == "Zoe" && candidates.single.notes == "Voice";
      },
    ),
    (
      "location and set",
      (tester) async {
        final tr = harness.trOf(tester);
        await harness.openTab(tester, tr.resourcesTabLocations);
        await harness.tap(tester, find.text("Cave"));
        await harness.type(tester, harness.fieldHinted(tr.resourcesLocationNameHint), "Grotto");
        await harness.type(tester, harness.fieldLabelled(tr.resourcesSetNameLabel), "Front");
      },
      () async {
        final location = (await harness.readLocations()).single;
        return location.name == "Grotto" && location.sets.single.name == "Front";
      },
    ),
    (
      "element",
      (tester) async {
        final tr = harness.trOf(tester);
        await harness.openTab(tester, tr.resourcesTabElements);
        await harness.tap(tester, find.textContaining("Lamp"));
        await harness.type(tester, harness.fieldHinted(tr.resourcesElementNameHint), "Lantern");
      },
      () async => (await harness.readElements()).single.name == "Lantern",
    ),
  ]) {
    testWidgets("leaving the mode right after typing in the ${sheet.$1} sheet writes what was "
        "typed", (tester) async {
      await harness.seedPerson("Alice");
      final roleId = await harness.seedRole("Ghost");
      await harness.seedCandidate(roleId, await harness.seedPerson("Zed"));
      final locationId = await harness.seedLocation("Cave");
      await harness.seedSet(locationId, "Back room");
      await harness.seedElement("Lamp");
      await harness.mount(tester);

      await sheet.$2(tester);
      await harness.unmount(tester);

      // The write is real file I/O the fake clock does not drive: give it bounded real time.
      var isWritten = false;
      for (var attempt = 0; attempt < 100 && !isWritten; attempt++) {
        isWritten = (await tester.runAsync(sheet.$3))!;
        if (!isWritten) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
        }
      }
      expect(isWritten, isTrue);
    });
  }

  testWidgets("removing a set drops its pending edit but not another record's, which the shared "
      "debounce still writes", (tester) async {
    final locationId = await harness.seedLocation("Cave");
    await harness.seedSet(locationId, "Back room");
    await harness.mount(tester);
    final tr = harness.trOf(tester);
    await harness.openTab(tester, tr.resourcesTabLocations);
    await harness.tap(tester, find.text("Cave"));

    await harness.type(tester, harness.fieldHinted(tr.resourcesLocationNameHint), "Grotto");
    await harness.type(tester, harness.fieldLabelled(tr.resourcesSetNameLabel), "Front room");
    await harness.tapQuickly(tester, find.byTooltip(tr.resourcesRemoveSetTooltip));
    await waitForDebounce(tester);

    final location = (await harness.readLocations()).single;
    expect(location.name, "Grotto");
    expect(location.sets, isEmpty);
    expect(find.text(tr.resourcesWriteError), findsNothing);
  });

  testWidgets("removing a candidate keeps the role note that is still waiting for its debounce", (
    tester,
  ) async {
    final roleId = await harness.seedRole("Ghost");
    final aliceId = await harness.seedPerson("Alice", lastName: "Smith");
    await harness.seedCandidate(roleId, aliceId);
    await harness.mount(tester);
    final tr = harness.trOf(tester);
    await harness.openTab(tester, tr.resourcesTabRoles);
    await harness.tap(tester, find.text("Ghost"));

    await harness.type(tester, harness.fieldHinted(tr.resourcesRoleCastingNotesHint), "Zoe");
    await harness.openCandidateNote(tester);
    await harness.type(tester, harness.candidateNoteField(), "Voice");
    await harness.tapOpening(tester, find.byTooltip(tr.resourcesRoleCandidateActionsTooltip));
    await harness.tapOpening(tester, find.text(tr.resourcesRemoveCandidateAction));
    await harness.tapQuickly(tester, find.text(tr.resourcesDeleteConfirmDeleteAction));
    await waitForDebounce(tester);

    expect(await harness.readCandidates(), isEmpty);
    expect((await harness.readRoles()).singleWhere((r) => r.id == roleId).castingNotes, "Zoe");
  });

  testWidgets("deleting a person drops the field typed on their sheet without writing it", (
    tester,
  ) async {
    await harness.seedPerson("Alice");
    await harness.mount(tester);
    final tr = harness.trOf(tester);
    await harness.tap(tester, find.text("Alice"));

    await harness.type(tester, harness.fieldHinted(tr.resourcesFirstNameHint), "Alicia");
    await harness.tapScrolled(tester, find.text(tr.resourcesDeletePersonAction));
    await harness.confirmDialog(tester, tr.resourcesDeleteConfirmDeleteAction);
    await waitForDebounce(tester);

    expect(await harness.readPeople(), isEmpty);
    expect(find.text(tr.resourcesWriteError), findsNothing);
    expect(harness.inList(find.text("Alicia")), findsNothing);
  });

  testWidgets("a write the database refuses shows the error once, and a typed field that cannot "
      "be written stays on screen, pending", (tester) async {
    await harness.seedPerson("Alice");
    await harness.mount(tester);
    final tr = harness.trOf(tester);
    await harness.tap(tester, find.text("Alice"));

    await harness.database.customStatement("ALTER TABLE people RENAME TO people_gone");
    try {
      await harness.type(tester, harness.fieldHinted(tr.resourcesFirstNameHint), "Alicia");
      expect(shownIn(tester, harness.fieldHinted(tr.resourcesFirstNameHint)), "Alicia");
      await waitForDebounce(tester);

      expect(find.text(tr.resourcesWriteError), findsOneWidget);
      expect(shownIn(tester, harness.fieldHinted(tr.resourcesFirstNameHint)), "Alicia");

      // The notice goes away with its SnackBar and the mode keeps answering.
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      expect(find.text(tr.resourcesWriteError), findsNothing);

      await harness.tap(tester, find.text(tr.resourcesAddPersonAction));
      expect(find.text(tr.resourcesWriteError), findsOneWidget);
    } finally {
      await harness.database.customStatement("ALTER TABLE people_gone RENAME TO people");
    }

    expect((await harness.readPeople()).single.firstName, "Alice");
  });
}
