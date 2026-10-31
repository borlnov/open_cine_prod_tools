<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# 0034 - One bloc per view inside a production mode

## Status

Accepted. Amends [ADR-0006](0006-workspace-shell-as-a-slot-widget.md) on one point: a production
mode owns a mode bloc and one bloc per view, not a single bloc.

## Context

ADR 0006 made the shell a slot widget and a mode the sole owner of its bloc. Six modes later, those
blocs stood between 1,690 and 3,787 lines (the shot list's the largest), past the 1,000 lines per
file the ACT coding standards allow, and a mode's widget file had grown to 2,465 lines beside them.
Moving the handlers' domain logic into services was tried first and bought 5 to 10 %: the
handlers were already thin, a read of the state, a service call and an emit. `part` files, mixins
that slice one bloc by domain and controller classes that receive `emit` were ruled out: they move
the lines without giving any of them an owner.

What a mode's views genuinely share is narrow and can be named. The **data**: the exports read three
snapshots after a flush, the inspector reads three, a version preview reloads all of them with one
hook, and deleting a shot invalidates all three. The **selection**: a sequence, a shot and a set
are one chain, and a panel, a symbol or an arrow only ever belongs to the shot currently shown. The
**chrome**: docks, tabs, columns, the centre view. And the two project mixins (versions, package),
which a mode answers once. Everything else belongs to one surface: its own selection, its tool, its
preferences, the edits typed into it and the writes it triggers.

## Decision

Inside a production mode, a **mode bloc** owns the data, the shared selection, the chrome, the two
project mixins and the contract to write what is pending; and there is **one view bloc per view**,
a view being a surface with its own selection or its own writes (a central view, a tab, a group of
the inspector, the export panel, or a function that cuts across views such as the spell-checker).
A view that is only a rendering of the same data, with no selection and no writes of its own, has
no bloc.

The rules, checked against the code:

- A view bloc takes the mode bloc at construction, reads its state when it needs it and never
  copies it. It never references a sibling, and the mode never references a view except as the
  `OcptPendingWritesFlusher` it registered.
- A write is the service, then `await modeBloc.reload({scopes})`, then the view's own emit, so the
  mode's state holds a row before the view selects it. The scopes are a value of the mode's own
  enum (`OcptShotListReloadScope`), read by a `switch` that names every value.
- The mode counts `reloadEpoch` and `selectionEpoch`, moved by every emit that replaces data or
  changes the selection, with a cause (`OcptShotListSelectionCause`) saying why. A view reacts to
  a rise, in a handler that waits for nothing, so the mode's change and the view's reaction land in
  the same turn of the event loop.
- Every read of the shared data that ends in an emit goes through `runSerially`, one at a time.
- A view holding typed edits registers a flusher; each view has its own debounce, and the mode asks
  all of them before anything that needs the database up to date.
- Views are built with the mode (`lazy: false`) so that every flusher exists; a widget that reads
  two blocs reads the mode and its view.
- The shared machinery is `MixinOcptModeBloc`, `MixinOcptModeState`, `AbsOcptViewBloc`,
  `MixinOcptAwaitedEvent` and `OcptPendingWritesFlusher` in `lib/ui/pages/workspace/blocs/`. Their
  doc comments are the rules for writing the next one.

The shot list is the first mode split this way, into seven blocs: `OcptShotListBloc` and the export,
storyboard, inspector, floor plan sets, floor plan canvas and floor plan placements blocs. Its
widget file was split the same way, a widget per view.

## Consequences

About thirty blocs instead of six, and a widget that shows two views reads two blocs. A view can
lag the mode by a frame; derived reads that tolerate a stale id, and the awaited reload, absorb it.
Each view's debounce is its own, so two edits typed in two views a second apart are written two
seconds after each one, not both two seconds after the last. A mode keeps a suite of scenarios
that drives the mode widget from the outside, written before the split, as the contract the split
must not change.

A new synchronised table, a new reload scope or a new way to move the selection now touches the
mode's enum, its hook and every view's reaction, which is the point: the places to think about are
listed by the compiler.

## Alternatives considered

- `part` files, domain mixins or controller classes: move lines, give them no owner.
- Extracting more into services: tried, 5 to 10 %.
- A waiver of the line limit for the six blocs: the limit is what makes a file readable.
- Each view bloc owning its own snapshot: the exports, the inspector and the version preview would
  have to read siblings, or a widget would orchestrate a flush and gather three states.
- One pending-edit map and one debounce for the mode: simpler for the shot list, but a mode with
  six maps would keep their writers in the mode bloc.
- A workspace-wide bloc holding every mode's state: rejected in ADR 0006.
