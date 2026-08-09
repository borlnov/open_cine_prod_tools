<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# Architecture — the exports

How a document leaves the app: the panel every mode reaches its exports from, the manager
owning the fifteen services, and the scenario coverage PDF. Each mode's own documents are
described in that mode's file.

- **Every export in the app is reached from one place**: the toolbar's own `Export` control, in
  every mode that prints something, opening `OcptWorkspaceExportDialog<T>`
  (`lib/ui/pages/workspace/widgets/`, generic over the mode's own export enum) — a scrolling
  two-column grid of cards, one per document, each naming it, saying in a line what it is, and
  wearing its format as a trailing label. The control is built by the shell rather than handed in,
  so an export is the same gesture in the same place in every mode, and `onExportRequested` is
  nullable like every other chrome slot: the budget mode, printing nothing, shows **no button at
  all** rather than a disabled one. The panel **only asks** — it pops the picked value and nothing
  else, the mode then opening that document's own options dialog from its own context.
  `OcptWorkspaceExportEntry<T>` (`lib/models/`, pure) is one card's descriptor (`value`, `title`,
  `description`, `formatLabel`, nullable `unavailableReason`) and carries no `Tr`, the mode
  resolving every word, as `OcptShotListXlsxLabels` already does for the services; `PDF`, `XLSX` and
  `.fountain` deliberately go through no ARB key, a format's name reading the same in both
  languages. A card's title is the **document's name** (`Feuilles de service`), never a sentence of
  action. A document that cannot be printed right now is a card **greyed and inert, its description
  replaced by the reason**, never a hidden one: the panel is a presentation of what this mode knows
  how to print, and a card that disappeared would make it lie about what exists — somebody who has
  never planned a day would never learn the app prints sides at all. The scope is the **active
  mode's own** documents (the whole project's would need one mode to trigger another's export, which
  nothing in this architecture does), and the panel stays offered **under a version preview**, an
  export only ever reading. What the `⋮` keeps is the screenplay's import-and-replace, its two
  display toggles, its page setup and its title page; the other four modes keep `Reset panel layout`
  alone, which is thin but honest.

- `OcptExportManager` (`lib/managers/export/`) owns getting a project's documents in and out of the
  app: the native open dialog, and fifteen services it owns (RFL18) — `OcptFountainIoService`
  (bytes ↔ text, suggested file names), `OcptPdfExportService` (the screenplay PDF),
  `OcptShotListXlsxExportService`, `OcptScenarioCoveragePdfService`,
  `OcptResourcesXlsxExportService`, `OcptContactListPdfService`, `OcptBreakdownSheetsPdfService`,
  `OcptBreakdownXlsxExportService`, `OcptCallSheetPdfService`, `OcptShootingPlanPdfService`,
  `OcptShootingPlanXlsxExportService`, `OcptDayOutOfDaysPdfService`,
  `OcptOneLineSchedulePdfService`, `OcptSidesPdfService` (each described under its own mode below)
  and `OcptSaveLocationService` (wraps `file_selector`'s `getSaveLocation`, a **direct** dependency
  kept in sync with the version `act_file_transfer_manager` already resolves transitively, for the
  native "save as" dialog every export goes through — no export ever writes to a default location
  silently; its `pickDirectory` is the same promise for the exports that write **several** files).
  The nine PDF services share one `OcptCourierPrimeFontsLoader` (handed to each by the manager, so
  the 4 embedded TTFs are decoded once) and one `OcptScriptPagePainter` — the two script exports
  **and the sides** for the positioned line drawing the three of them start from, the breakdown
  sheets, the contact list and the table-shaped schedule documents for its metrics and fonts alone,
  their pages flowing rather than typeset. **A workbook takes no painter and no font loader at
  all**: `excel_community` builds it in memory with no page geometry of its own, which is why the
  four of them are `const` services where every PDF one is constructed with the shared loader. An
  export writing into a folder reports an `OcptCallSheetExportResult` rather than a path: some files
  landing and others not is a third outcome, and it must never read as success — somebody would go
  unwarned about a day they are called on. The home page's "Import a screenplay…" action, the
  screenplay's own `⋮` import-and-replace and every export card go through the manager; the
  screenplay text itself is always written through `OcptScreenplayService.saveScreenplayText`, never
  by hand.

- Scenario coverage export: the screenplay printed as usual, with a coloured bar in the margin
  alongside every passage a shot covers. `OcptScenarioCoverageLayout.of(...)`
  (`lib/models/ocpt_scenario_coverage_layout.dart`, pure Dart, no `pdf` and no Flutter) holds every
  rule and every test — resolving each range's source offsets onto rows through the paginator's
  provenance, bridging unanchored lines, emitting one `OcptCoverageBarSegment` per (range × page it
  appears on), assigning lanes by a greedy interval colouring that fills the left margin then the
  right and shrinks its pitch before it lets bars share the outermost lane, ticking a boundary that
  falls mid-line, washing the passages no shot covers (`OcptCoverageGap`), and building the legend
  and summary rows. A shot's colour is `ocptCoverageColorAt(rank)` over the 16-entry
  `ocptCoveragePalette` (`lib/constants/`, ARGB ints so the palette stays usable on screen later),
  ranked **within its sequence**, so an export is deterministic and no two shots of one sequence
  share a colour. `OcptScenarioCoveragePdfService` only draws. Bar labels are
  `<abbreviation><code>`, the abbreviation being `shots.abbreviation` — deduced from the initials
  of the shot size's words the first time a shot size is committed while it is still empty, never
  overwritten afterwards. Its card in the export panel opens
  `OcptScenarioCoverageExportDialog` (page format, title page, scene numbers, legend page, summary
  page) through `OcptRouterManager`, and `OcptShotListScenarioCoverageExportRequestedEvent` flushes
  pending edits before handing the snapshot and the parsed document to the manager. Every heading
  the two extra pages print comes in as an `OcptScenarioCoverageLabels`, exactly as
  `OcptShotListXlsxLabels` does for the workbook — the manager and its services never see a `Tr`.
