<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# Architecture — the resources mode

Who shoots the film, where, and with what: the address book, the cast, the locations and
their sets, the elements catalogue, and the two documents the mode prints.

- Resources mode (`lib/ui/pages/workspace/modes/resources/`): who shoots the film, where, and with
  what. Four tabs in the left dock — people, roles, locations, elements — the selected record's
  editable sheet in the centre, and the shared `Versions` tab as the right dock's only tab (the
  sheet *is* the inspector). Its four services are `OcptPeopleService`, `OcptRoleIndexService`,
  `OcptLocationsService` and `OcptElementsService`, owned by `OcptProjectsManager` beside the shot
  list's own, and `OcptResourcesBloc` joins their four reads into one `OcptResourcesSnapshot` the
  way `OcptShotListBloc` builds its own.
  **A person is one row, whatever they do on the film**: `people` is the address book, and both the
  cast (`roles.personId`) and the crew positions (`person_positions`) are links onto it, never
  copies of a name — so the same person can be a role, a position and a location's owner at once. A
  `person_positions` row says only *that* someone holds a function; **when** they hold it is a
  per-slot fact the schedule mode owns, which is why no scope column exists here and why the sheet
  shows none — the two tables are joined the one way that says something
  (`ocptCrewPositionPrefillOf`, below), never by a second copy of one truth.
  **An element is anything that must be present on a day and is not a person** — one `elements`
  table with a category and a free sub-category rather than one table per department, because the
  tracking columns (owner, who brings it, secured, ready, returned, where) are the same whatever
  the item is.
  **What a role wears, carries and is made up with** is `role_elements`, `scene_elements`' sibling
  on the other side of the production: the same catalogue, linked from a role, with the same kind of
  per-link note and no quantity (a role wears the coat or they do not). It is **written from
  `OcptElementsService`** although the role sheet is where the user adds to it — the row is a link
  onto an element, it is loaded with the element it names on `OcptElement.roleLinks`, and the role
  sheet's own card scans the catalogue for the links naming its role rather than carrying a copy, so
  that card and the element sheet's reverse read-out cannot disagree.
  `OcptRoleIndexService.deleteRole` reaches for the one cascade it needs
  (`tombstoneRoleLinksOfRole`); neither deletion ever touches the **element**, a coat outliving the
  character who wore it. **No category restriction, and deliberately none**: a character's car,
  their dog and their stunt harness are facts about them exactly as their coat is, so the grouping
  by category is read-time work in the card, never a rule in the schema that a migration would have
  to undo the day it gets in the way. The element sheet reads it back as `Roles concerned` —
  read-only chips landing on that role's sheet, a plain tab-and-selection change inside one mode
  rather than an `OcptWorkspaceRevealRequest`. A role's things are added and removed from the role's
  sheet alone: offering the same edit from both ends would only invite the two to disagree.
  **A photo is a slot, not a field**: `OcptResourcesPhotoSlot` is the person sheet's header avatar
  and the element sheet's alike, and it is **one menu** — reference a photo, drop it, then the
  palette — because "what does this record look like?" is one question and the colour is the
  photo's *fallback* rather than a competing setting. A record with no colour of its own passes a
  null `currentColorIndex` and gets the photo entries alone: `elements` carries no `colorIndex`, an
  element being read by its category's colour. A person's photo is resolved once, by
  `OcptPersonAvatar`, so referencing one on the sheet shows it in the address book's list and on the
  role avatar too.
  Roles are **reconciled from the screenplay**, not typed from nothing: `OcptRoleIndexService`
  mirrors `OcptSceneIndexService` on the same save path — a speaking character with no row gets a
  `speaking` role, a role whose character disappeared keeps its casting and its notes and gains an
  `orphanedName` (`OcptRemovedRoleAlert`, the sibling of `OcptShotRemovedCharacterAlert`), and a
  hand-added `silent`/`extra` role is never touched. A rename reads as one disappearance and one
  appearance, repaired through the banner, exactly as a heading with no scene number is.
  **A role belongs to the production, not to a script** (ADR 0019): `roles` carries no
  `screenplayId`, and `role_episodes` records which episodes name it — a synchronised link table
  with **no `sortKey`**, a role's episodes being an unordered set of answers exactly as `scene_sets`
  is, read back in the episodes' own order. A character speaking in three episodes is therefore one
  row: one casting, one set of notes, one number, one identity in `shooting_slot_cast`.
  `reconcile` keeps its signature — one screenplay and its parsed document — but **only ever writes
  the links of that episode**, while matching by name across every live `isFromScreenplay` role of
  the project: a link is ensured, a link the episode no longer names is tombstoned, and
  `orphanedName` is set only once **no live link is left anywhere**. A character cut from episode 2
  but still speaking in episode 3 thus loses one link and stays cast; the removed-role banner still
  answers the rest. `OcptRole.number` is the rank among the **project's** live roles, still derived
  at read time and stored nowhere — one number across the series is what the shared schedule forces,
  a day covering episodes 2 and 5 printing one `RÔLES` column.
  The **roles tab shows the whole series**, each row wearing the episodes that name it: the other
  three tabs are already the production's, and a cast list hiding half the cast in a mode of shared
  catalogues would read as a bug. The same pills sit on the role sheet, **editable for a hand-added
  role alone** — a `silent`/`extra` role is named by no cue, so it is created on the selected episode
  and its pills are the one place in the app a `role_episodes` row is written by a gesture, while a
  role that came from the screenplay reads its pills out and offers no control.
  A scene is linked to a **set** (`scene_sets`, many-to-many — a continuous action is regularly
  covered in two) and to an **element** (`scene_elements`, the *dépouillement* link, carrying the
  quantity and the note that belong to that scene alone). `ocptSceneSetSuggestionOf`
  (`lib/utils/`, pure and tested) reduces a heading to the place it names and *offers* the best set
  at the top of the picker — never applied, since `INT. CUISINE` in two houses is two sets. A set's
  **location is not one of its fields**: it is what the set belongs to, chosen when it is created
  and changed only by moving the whole set (`OcptLocationsService.moveSetToLocation`, the sets
  card's own move control, which re-allocates the `sortKey` in the destination), so a set filed
  under the wrong house is repaired rather than deleted and retyped.
  A **code is the app's own**, never typed: `OcptElementsService.createElement` mints an element's
  (`ocptElementCodeOf`, `PRP-3`, numbered within its category) and `OcptLocationsService.createSet`
  mints a set's (`ocptSetCodeOf`, `A`, `B`, … `AA`, numbered across the whole project — a set has
  no category, so a constant prefix would say nothing, and the two shapes can never be confused for
  one another). Neither is among `OcptElementField`/`OcptSetField`'s entries and neither has a field
  on a sheet: `OcptResourcesCodeReadOut` reads it out. The one thing that ever rewrites one is a
  category change, and `updateElement` owns that rule rather than a bloc, so the breakdown's own
  category chips get it without knowing it exists — a prefix that stopped saying which department
  an item comes from could not be corrected by hand.
  Everything writes the moment it changes, except the sheets' typed free-text fields: those ride
  one 2 s debounce shared by the five `pending…FieldEdits` maps, flushed together on a selection
  change, a tab change, a version preview and the mode leaving the tree. A field may **flag** what
  it holds without refusing it (`ocptEmailFormatError`, `ocptCostCentsOf`, the coordinates): the
  sheets autosave as they are typed, so a field that refused an incomplete value would refuse
  nearly every keystroke.
  Each sheet ends on its own `Delete this …` action (`OcptResourcesDeleteAction`, which only asks),
  and the four of them are answered by one `OcptConfirmDialog` opened by the mode, as in the shot
  list and the breakdown; only the wording differs, and it is the caller's. The removed-role
  banner is the one exception: it deletes straight away, being that question itself.
  The toolbar's search toggle filters the active tab's list (`lib/utils/ocpt_resources_search.dart`,
  diacritic-folded so `lea` finds `Léa`), each list filtering itself because matching includes the
  localized labels a row shows; the header count then reports what is on screen while the status
  bar keeps counting the whole catalogue.
  The export panel offers **two** documents: the four-sheet workbook and the **contact list** —
  `OcptContactListPdfService`, the whole production's crew and cast on one circulated sheet, where a
  call sheet's own two directories only ever say who is on **one day**. Its unit is a **position
  held by somebody**, not a person: the crew is grouped by `OcptCrewDepartment` in the enum's own
  order, a person holding two positions is printed twice, once under each, and a free-label position
  (no `positionId`) is grouped last, having no department. The cast follows, one row per role in
  role-number order, an **uncast role still getting its row** with an em dash where the contact
  details would be: a part nobody has cast is exactly the line a production reads this document for.
  Four columns and deliberately no postal address: a home address is personal data, and this is the
  one document of the app that circulates to everybody. **Somebody who holds no position and plays
  no role appears nowhere** — that is the honest scope of "the crew and the cast", and widening it to
  every contact the project references (a location's owner, an element's lender) is a decision
  nobody has made. It is stamped by `ocptScheduleGeneratedAtStamp` like the schedule's own
  paperwork, a contact list being reissued as a crew settles, and its options dialog asks the page
  format alone.
