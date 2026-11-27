<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# Changelog

## 0.5.1

Fixes for lost projects on Windows, the director line and failed exports.

- Windows: the recent projects, the settings and the sharing keys kept by
  0.3.1 and earlier reappear. 0.4.0 and 0.5.0 looked for them in a renamed
  folder and started empty; 0.5.1 brings them over once at start-up, merging
  them with what 0.4.0 or 0.5.0 saved since, and leaves the old folder as it
  was.
- Schedule exports: the call sheet, the shooting plan, the day out of days
  and the one-line schedule read "Directed by" followed by every director of
  the project ("A, B and C"), instead of the first director alone.
- Notices: a failed export, and any other failed action, shows in a red-tinted
  notice with a warning icon instead of looking like a success. An export
  failure suggests checking that the file isn't open in another application.
- Project files stay at format 5: 0.4.0, 0.5.0 and 0.5.1 open each other's
  files.

## 0.5.0

The styled editor shows the screenplay's notes in a margin.

- Notes: a `[[note]]` is a speech bubble in its line, and its text sits in a
  card in a margin beside the page, level with that line, in page simulation
  as in fluid mode. Clicking a bubble or a card selects the note and lets you
  write in it straight away: Enter or Escape goes back to the screenplay,
  Shift+Enter starts a new line in the note, and Ctrl+Z undoes the whole edit
  of a note in one step. Insert note opens an empty card, a note left empty is
  removed, and the card has its own Remove note button. A note over several
  lines goes in the margin too.
- Narrow windows: when there is no room for the margin, a click on a bubble
  opens the note in a popover under it, or above it near the bottom.
- Find and replace: the search covers the notes, tints the bubble of a note
  holding a match and opens its card or popover on the current match. Replace
  and Replace all work inside the notes, and leave unchanged a note that could
  not hold the replacement (`]]`, `/*` or `*/`).
- Find bar: Enter moves from match to match again, the focus staying in the
  find or the replace field.
- Fountain: an escaped `\[[` whose `]]` sits on a later line keeps its
  backslash in the styled editor instead of turning into a note.
- Guide: the screenplay page explains the notes.
- Project files stay at format 5: 0.4.0 and 0.5.0 open each other's files.

## 0.4.0

The screenplay gains dual dialogue, notes from the menu and a page zoom.

- Dual dialogue: a speech whose character name ends with `^` is set side by
  side with the speech before it in the preview, the PDF, the sides, the
  scenario coverage and the breakdown's script, and a pair that does not fit
  moves whole to the next page. The styled editor keeps the two speeches one
  under the other, joined by a bracket in the margin, and pairs or unpairs a
  speech from the right-click menu, the format controls or Ctrl+Alt+D.
- Page zoom: the styled page and the raw mode's paper preview zoom from 50 %
  to 200 %, or fit the width of the window, from the status bar, Ctrl and the
  mouse wheel, or Ctrl and +, − or 0. The pagination never changes with the
  zoom, and the zoom is remembered.
- Notes: the styled editor's right-click menu inserts a `[[note]]` at the
  caret or around a selection, and removes the note the caret is in.
- Commented-out text: a line inside a boneyard or a note is kept as written and
  dimmed, and a note at the start or end of a scene heading, a character cue or
  a transition no longer changes the line's type.
- Fountain: a character cue may carry a lowercase extension
  (`HANS (on the radio)`), and a cue forced with `@` (`@McCLANE`) keeps its own
  case in the editor, the preview, the PDF, the breakdown and the coverage. The
  styled editor no longer rewrites a section's level (`##`) or drops the title
  page keys beyond the six standard ones (`Copyright`, `Revision`…).
- Docks: choosing the right dock's tab already shown no longer closes the dock.
- Floor plans: a selected arrow can be deleted from the plan itself, through
  the handle beside its tip.
- Linux and Windows: the window is titled Open Cine Prod Tools.
- Guide: the collaboration pages match the app's screens and labels again.
- Project files stay at format 5: 0.3.1 and 0.4.0 open each other's files.

## 0.3.1

Fixes for edits that could be lost, a sync failure and the floor plans.

- Edits: a value typed just before "Back to projects" in the schedule, the
  budget or the breakdown is now saved, as is one typed in the schedule before
  opening the project settings, or in a schedule time field when the window is
  resized.
- Budget: paying a quote line directly, an in-kind resource with its
  counterpart line, and a taking or share with its fields are each saved in
  one go, never half. An in-kind resource created from the journal's entry
  dialog now gets its counterpart line too.
- Resources: an edit that fails to save stays pending and is reported, instead
  of being dropped. Erasing a person now takes them off the roles they were
  cast in, in the schedule and the exports too. People erased with an earlier
  version stay cast: remove them from their roles by hand.
- Sync: creating a storyboard annotation in a shared project no longer takes
  the sync offline for good.
- Versions: restoring a version now brings back the budget's simplified mode
  and the allowances' history.
- Projects: when the open project cannot be closed, opening another one now
  says so instead of calling the new file corrupted, and a failed open or
  creation leaves nothing half-open behind.
- Floor plans: a camera's field-of-view handle no longer jumps to its widest
  angle when the camera faces left, and an underlay photo is laid out
  correctly.
- Styled editor: spelling mistakes are underlined as soon as the editor opens.
- Breakdown: Escape closes a tag's popover without clicking its field first.
- Sharing: the hosting reconcile notice can be dismissed.
- Logs: the diagnostics log no longer records project titles, file names or
  project content.
- Project files move to format 5: opening an earlier project upgrades it after
  a confirmation, keeping a copy of the original, and 0.3.0 can no longer open
  the upgraded file.

## 0.3.0

The shot list gains a storyboard and floor plans, each with its own PDF.

- Shot list: a `Table · Board · Floor plans` switch swaps the centre of the
  mode between the shot table and two new views sharing the same scene tree,
  dock and selected shot.
- Storyboard: a shot holds several panels, each an imported JPEG or PNG
  referenced by its path, with a comment, reordered by dragging, and shown at
  the shot's own recording ratio beside a card recalling its size, framing and
  camera move. Movement arrows, camera-move arrows and labels mark up a frame.
- Floor plans: a top-down, schematic plan in metres of each Resources set,
  shared by every sequence linked to it. Walls, doors and furniture belong to
  the set, re-dressing and the breakdown's props to one sequence, and cameras
  (numbered after their shot, with an adjustable field of view), characters,
  lights and arrows to one shot. Moving or deleting a shared element asks
  whether it applies everywhere or only here, leaving a restorable override.
  An underlay photo, a scale bar, distances, an onion skin of the neighbouring
  shots and per-layer visibility help stage the shot. A set's sheet in
  Resources shows whether it has a plan and opens it in the shot list.
- Exports: a storyboard PDF, with a choice of shots per page and each
  sequence's floor plans appended on request, and a floor plans PDF with one
  plan per shot that has a camera placed.
- Project files move to a new format: opening an earlier project upgrades it
  after a confirmation, keeping a copy of the original, and an earlier version
  of the app can no longer open the upgraded file.

## 0.2.4

Projects saved where you choose and never overwritten, a complete French crew,
and schedule and editor fixes.

- Projects: a new project could silently destroy an existing one of the same
  name — it was written straight into the Downloads folder. On desktop, New
  project and the screenplay import now show a save dialog, opening in the last
  folder a project went to, and joining a shared project asks for a folder.
  Picking an existing file is refused rather than overwritten. On a tablet or
  phone, a new project takes the first free name (`Name (2)`, …) instead.
- Project settings: a new Project file card shows where the project lives, with
  Show in folder and Move… actions. A move carries the project's sync data
  along and keeps it in the recent projects.
- Resources: the crew positions now follow the French film production
  collective agreement — 83 positions in 13 departments instead of 20 in 6,
  with the unit manager, casting and construction among them — picked from a
  searchable dialog that finds a position by its feminine as well. Existing
  positions keep their meaning. The call sheet gains the unit department and
  lists every on-set department.
- Resources: a candidate added to a role now starts as *spotted*, the first
  step of the casting, rather than *seen*.
- Schedule: an audition's "Candidate" picker offers the candidates of a role the
  slot also convokes again, and no picker opens empty any more — each says why
  it has nothing to offer.
- Schedule: a PAT band now covers filming alone, so auditions or rehearsals
  before the shots no longer bring the unit's PAT time forward, on the
  convocations as on the call sheet.
- Screenplay: clicking a scene in the side panel lands on its heading in both
  the styled and the raw editor, even deep into a long screenplay; finding the
  next match lands the same way.
- A few labels lose a stray "+" next to an add icon.

## 0.2.3

A single, editable set control in the breakdown, and a delete action that
stands out across the resources.

- Breakdown: the scene sheet's two set controls — one to link an existing set,
  one to create a new one under an automatic name — are now a single "+ Set"
  popover that links an existing set or creates one under a name you can type,
  pre-filled with the scene heading's place but editable before you save. A
  just-created set is no longer stranded in the catalogue under a name you
  could not change.
- Resources: each sheet's delete action is now a solid red button rather than a
  plain text one, so the sheet's one irreversible action stands out at a glance.

## 0.2.2

Smoother passage tagging in the breakdown and the shot list, and a clearer
French label.

- Breakdown and shot list: a passage selection can now be cancelled — press
  Escape or click the sheet away from any word — instead of being stranded
  after the first click.
- Breakdown: the highlight now hugs the tagged words, leaving the sentence's
  own punctuation out, and stays lit while the tag popover is open, so the
  selection, the popover and a placed tag all read the same passage.
- French: the "Décoration" element category is renamed "Habillage du décor",
  so it no longer clashes with a set ("décor") or the art department.
- The guide now explains creating a set — a décor — and its location from the
  breakdown's own scene sheet.

## 0.2.1

A shot's characters become the production's roles, and the user guide is
versioned.

- Shot list: a shot's characters are now the production's roles rather than free
  text. A shot's cast is picked from the roles, a role shared across several
  shots is flagged, and roles can be merged or deleted with their attachments
  following along. Entering a mode surfaces a role that needs attention.
- The online user guide is now versioned: its navigation bar shows the guide's
  version, and a reader can browse the guide for an earlier release.

## 0.2.0

Collaboration and sync, a mobile-usable app, and a balanced budget in-kind
contribution.

- Collaboration and sync: offline-first sharing of a project between several
  people, backed by a self-hostable, domain-blind relay with live push and
  presence; pairing a device by scanning a QR code or opening a link; a
  portable on-set server and in-app relay hosting for a production with no
  outside network; and a sync status indicator in the workspace shell.
- The app is now usable on tablets and phones, with an Android build alongside
  the desktop ones.
- Budget mode: an in-kind contribution now balances against a counterpart
  quote line, so valuing it nets the needs and the resources it is measured
  against back to zero.
- The collaboration and sync end-user guide.

## 0.1.0

First stable release. One project is one local SQLite file (`.ocpt`) holding one
or several episodes, with the Fountain text as the source of truth, and a
workspace shell around six production modes reached from a bottom mode switcher.

- Screenplay mode: a styled block editor with the real screenplay layout and a
  raw Fountain view with a paper-simulated preview, Courier Prime throughout,
  scene numbers, a collapsible scene list, and a syntax guide. Spell checking
  (English and French) with a per-project dictionary.
- Screenplay import from Fountain, Final Draft (`.fdx`) and Celtx (`.celtx`);
  Fountain and PDF export, the PDF with page numbers, optional scene numbers and
  embedded Courier Prime.
- Shot list (découpage technique) with per-shot coverage of the scenario, and a
  scenario coverage export showing, page by page, what the shots still leave out.
- Resources mode: the cast reconciled against the screenplay's speaking
  characters, casting candidates weighed per role, the locations with their sets
  and permits, and a catalogue of the physical elements, all exported to XLSX.
- Breakdown mode (dépouillement): the script tagged scene by scene against the
  resources catalogue, with per-scene progress and sheets.
- Schedule mode: the shooting schedule as chained blocks with pinned anchors,
  standing alerts, several views, and PDF and XLSX exports.
- Budget mode: the quote against the CNC nomenclature, the cash journal it is
  measured against, the financing and catering plan, the revenue sharing, and
  their four documents.
- Named project versions of the whole project, a portable project package, and a
  compatibility gate every project file is opened through.
- Desktop packaging for Linux and Windows (macOS built by CI), a system-following
  light/dark theme, autosave, and English (`en_GB`) and French interfaces.
