# The workspace

<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: CC-BY-4.0
-->

As soon as a project is open, you are in the **workspace**: the same frame around every
production tool. It has four zones.

## The four zones

- **The toolbar, at the top.** On the left, the project title and the **episode selector**; in
  the centre, the actions of the active mode; on the right, the workspace's fixed controls: the
  mode name, **Export**, the two buttons that open or close the side panels, the **save**
  control (a spinner turns while saving), the **project settings**, **Help** and the **⋮** menu.
  A control a mode does not use simply does not appear.
- **The side panels (docks).** On the left and right, panels you open, close and resize by
  dragging their edge. Their content depends on the mode.
- **The centre**, where the active mode's work happens.
- **The status bar, at the bottom**, showing live counters (number of pages, scenes, shots…)
  depending on the mode.

## The mode switcher

A band at the bottom of the window picks the mode. The six modes are laid out in the order the
work flows:

1. **Screenplay** (write);
2. **Breakdown**;
3. **Shot list**;
4. **Resources**;
5. **Schedule**;
6. **Budget** (which reads every other mode's figures, so it comes last).

Click an entry to change mode; all are always available. The application **remembers the last
mode used** and returns to it when you reopen the project.

## The episode selector

When a project holds several episodes, the selector placed just after the title picks the
episode the current mode shows. It appears only when useful: it is hidden for a single-episode
project, and hidden in **Schedule** (which reads every episode at once) and **Budget** (which is
not split by episode).

Changing episode **reloads the mode afresh**: the current selection (a highlighted shot, the
scroll position…) is lost on each change. On opening, a project always starts on the first
episode.

## Saving and versions

The application saves as you go; the save indicator in the toolbar turns while saving. To set
deliberate milestones — snapshots you can restore — use **project versions**, described in
[Project versions](../concepts/project-versions.md).
