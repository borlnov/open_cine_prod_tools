// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// The Fountain text of the demonstration screenplay, written for the purpose so the images carry
/// no third-party work.
const demoFountainText = '''
Title: The Last Ferry
Credit: Written by
Author: A demonstration screenplay
Draft date: September 2026

INT. HARBOUR CAFE - DAWN

Rain drums on the window. NORA, 40s, coat still dripping, sets a leather satchel on the counter.

The cafe is empty but for the CAFE OWNER, who polishes the same glass he has been polishing for an hour.

NORA
One coffee. And the schedule for the ferry.

OWNER
The ferry left. Storm's coming.

Nora unclasps the satchel. Inside, a folded nautical chart and a brass compass that has seen better decades.

NORA
Then I'll need a boat.

INT. HARBOUR CAFE - CONTINUOUS

The OWNER puts down the glass. He looks at the compass for a long moment.

OWNER
There's a man at the end of the pier. He has a boat. He won't take you.

NORA
He will.

She leaves a banknote under the saucer and walks out into the rain.

EXT. PIER - DAWN

Wind. The planks are slick. At the far end, a battered fishing boat rides the swell, and beside it, MARTIN, 60s, in a yellow oilskin, coiling a rope with hands that know the work.

NORA
They tell me you have a boat.

MARTIN
They tell you wrong. I have a wreck that floats.

She unfolds the nautical chart against the wind and holds it out. Martin does not take it.

MARTIN
Nobody crosses today.

NORA
I am not asking to cross. I am asking to be put down on the island and left there.

Martin looks at the chart. At the pencil ring drawn around a rock nobody lives on.

EXT. FISHING BOAT - SEA - MORNING

Grey water, no horizon. The boat digs into the swell. Nora braces against the wheelhouse, the satchel held shut with both hands.

Martin watches the compass swing, and holds his course anyway.

MARTIN
Whatever is out there, it waited this long.
''';

/// One crew member of the demonstration project's address book: their name and the catalogue
/// position they hold.
typedef DemoCrewSeed = ({String firstName, String lastName, String positionId});

/// The crew the demonstration project convokes, in the order the address book lists them.
const demoCrew = <DemoCrewSeed>[
  (firstName: "Camille", lastName: "Ferrand", positionId: "director"),
  (firstName: "Yanis", lastName: "Berthier", positionId: "firstAssistantDirector"),
  (firstName: "Elsa", lastName: "Marchand", positionId: "directorOfPhotography"),
  (firstName: "Nadia", lastName: "Lefèvre", positionId: "scriptSupervisor"),
  (firstName: "Tomás", lastName: "Ruiz", positionId: "soundEngineer"),
  (firstName: "Hugo", lastName: "Danet", positionId: "gaffer"),
  (firstName: "Marion", lastName: "Vidal", positionId: "makeupArtist"),
  (firstName: "Paul", lastName: "Ozanne", positionId: "productionManager"),
];

/// The actors the demonstration project casts, by the screenplay character they play.
const demoCast = <String, ({String firstName, String lastName})>{
  "NORA": (firstName: "Léa", lastName: "Combes"),
  "OWNER": (firstName: "Gilbert", lastName: "Kervella"),
  "MARTIN": (firstName: "André", lastName: "Le Gall"),
};
