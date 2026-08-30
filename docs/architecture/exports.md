<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# Architecture — the exports

How a document leaves the app — and how the project itself does: the panel every mode reaches its
exports from, the card grid that panel and the home page's `Import…` modal are both built on, the
manager owning the twenty services, the door a foreign screenplay comes in through, and the
scenario coverage PDF. Each mode's own documents are described in that mode's file; the package a
whole project travels as is `foundations.md`'s, this file covering only where the two gestures
sit.

- **Every export in the app is reached from one place**: the toolbar's own `Export` control, in
  every mode that prints something, opening `OcptWorkspaceExportDialog<T>`
  (`lib/ui/pages/workspace/widgets/`, generic over the mode's own export enum) — a scrolling
  two-column grid of cards, one per document, each naming it, saying in a line what it is, and
  wearing its format as a trailing label. The control is built by the shell rather than handed in,
  so an export is the same gesture in the same place in every mode, and `onExportRequested` is
  nullable like every other chrome slot — a mode with nothing at all to print would show **no
  button** rather than a disabled one, though every mode today wires the control, if only for the
  project package card below. The panel **only asks** — it pops the picked value and nothing
  else, the mode then opening that document's own options dialog from its own context. What it pops
  is a sealed `OcptWorkspaceExportPick<T>` (`lib/models/`), `document(T)` or `projectPackage`,
  rather than a bare `T?`: every mode's call site already switched on the pick, so the standing card
  below costs one branch each instead of one enum value each.
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
  export only ever reading — the one card that is not a document being the exception below. What the
  `⋮` keeps is the screenplay's import-and-replace, its two
  display toggles, its page setup and its title page; the other four modes keep `Reset panel layout`
  alone, which is thin but honest.

- **The project itself is a card in that panel**, below the documents grid, behind a divider and
  under its own short heading, because nobody *reads* it — it is the project, as one `.ocptz`
  somebody can send (ADR 0021, and `foundations.md` for what travels inside one). The **dialog owns
  that card**, in every mode, rather than each mode declaring it: five modes each adding a
  `projectPackage` value to their own enum would let its wording, its position and its availability
  drift apart mode by mode, the same reasoning that makes the end of the toolbar the shell's own
  chrome. Picking it pops `OcptWorkspaceExportProjectPackagePick`, which the mode's bloc answers
  through `MixinOcptProjectPackageBloc`: flush the pending writes, scan the referenced files, open
  `OcptConfirmDialog` when some are gone, then the native save dialog and the write, reported in a
  SnackBar like every other export outcome — and no bloc holds a `Tr`, the notice travelling as an
  `OcptProjectPackageNotice` the mode words through `ocptProjectPackageNoticeMessage`.
  Under a **version preview** that card alone is drawn **unavailable with a reason** rather than
  withheld, and it is the one place the app's "withhold, don't disable" rule yields: what it would
  export is the working copy on disk, which is not what is on screen, while every other export under
  a preview writes exactly what *is* — leaving it clickable with a caveat would make it the odd one
  out in the one way that matters, and a card that vanished would make the panel lie about what
  exists. ADR 0021 records the exception with its argument so it is not read later as a slip.
  The **budget mode prints four documents** — the quote and the financing plan as PDFs, the cash
  journal as an XLSX workbook, the financial report as a PDF — through
  `OcptWorkspaceExportDialog<OcptBudgetExportDocument>`, above that standing project-package card.
  It is the mode where the "greyed and inert, never hidden" rule earns its keep most often: each of
  the four names a real state in which it cannot print (no poste, no resource, no entry), and each
  says so on its own card rather than disappearing (`budget.md`).
  The **same flow with no project open** is a home page project card's `⋮` `Export…`
  (`OcptHomeBloc` mixes the very same mixin in, answering `flushPendingProjectWrites` with a no-op):
  sending a project should not require opening it first, and it is the only way to export one whose
  file is at an older format without migrating it. The entry is inert for a card whose file is gone,
  as the card itself already is.

- The card grid is not the export panel's own: `OcptCardChoiceDialog<T>` + `OcptCardChoiceEntry`
  (`lib/ui/widgets/`, `lib/models/`) is the shape the app asks "which one of these?" in, and
  `OcptWorkspaceExportDialog` is its export-flavoured caller — keeping its title, its message, its
  greyed-and-inert unavailability semantics and the standing project card above.
  `OcptWorkspaceExportEntry<T>` is expressed in terms of `OcptCardChoiceEntry`. The other caller is
  the home header's single **`Import…`** button, opening a modal of two cards, `A project`
  (`.ocptz`) and `A screenplay` (`.fountain, .fdx, .celtx`, joined from
  `OcptScriptImportService.importableExtensions` rather than written out, so a fourth format
  cannot be added without the card saying so): the two gestures are named side by side where
  somebody compares them, laid out the same way, and the header keeps four controls
  instead of growing to five, two of which would have started with the same word. Picking
  `A project` runs pick the `.ocptz` (`FileSelectorManager`), pick a **parent folder**
  (`OcptSaveLocationService.pickDirectory`), unpack into `<project name>/` inside it — a folder of
  that name already there is a clear refusal, never an overwrite — then state the skipped files and
  open the project **through the compatibility gate** (`foundations.md`, ADR 0022), exactly as
  tapping a recent project card would.

- **A screenplay enters the app through one door, and it takes three formats**:
  `OcptExportManager.pickAndReadScreenplay` — the home modal's `A screenplay` card, which turns the
  file into a new project, and the screenplay mode's own `⋮ Import and replace…`, which replaces
  the selected episode's text behind a pre-import snapshot (`screenplay.md`). The native selector
  filters on `OcptScriptImportService.importableExtensions` (`.fountain` first, it being the app's
  source of truth, then `.fdx` and `.celtx`), and what comes back is Fountain text whichever was
  picked: an `.fdx` and a `.celtx` are converted as they are read, by `script_import_kit`
  (ADR 0023, and `screenplay.md` for what each conversion carries and loses). The conversion is
  **one way** — nothing in the app writes either format — and `OcptImportedFountainModel` keeps its
  name because its text *is* Fountain by the time anyone sees it, its `sourceFileName` still
  feeding `OcptFountainIoService.suggestedProjectName` so that the converted title page's `Title`
  names the new project by itself, for all three formats.
- The result is a `ResultWithStatus<OcptScreenplayImportStatus, OcptImportedFountainModel>`
  (`lib/types/`) rather than a nullable model, because once a file can be **refused for not being a
  screenplay**, "nothing came back" no longer tells that apart from a cancelled dialog: `ok`,
  `cancelled`, `unreadableFile`, `ioError`. `cancelled` is a silent no-op everywhere — the OS
  dialog already reported a selection that failed, and a cancellation is not something to state
  back. The other two share one sentence to the user, whether the bytes never came back or came
  back as something that is not a screenplay: the home page raises it as a transient
  `OcptHomeState.screenplayImportError` (cleared by its own `copyWith` flag, exactly as
  `projectPackageImportError` is) and the editor as an `OcptEditorIoNoticeKind.importUnreadable`
  notice, distinct from the `importFailed` that stays the *write* failure — and an import that
  could not be read **replaces nothing**, leaving the screenplay on screen as it was.
- The kit knows neither ACT nor `Tr`, so **`OcptScriptImportService` is where a
  `ScriptImportException` becomes an app-side status**: it hands `.fountain` bytes to
  `OcptFountainIoService.decodeFountainBytes` and everything else to `ScriptImporter`, returning
  the refusal with the exception as the result's `extraInfo` for the manager to log. It holds no
  dialog, no file system access and not even a logger, which is what makes it a `const` service
  testable on its bytes alone. An extension the app does not import reaching it is that same
  refusal: the native dialog filters those out, so one arriving here is a file somebody renamed by
  hand.

- A suggested file name is built in one place, `ocptExportFileNameOf`
  (`lib/managers/export/services/ocpt_export_file_name.dart`):
  `<projectName>[ - <suffix>][ - <episodeTag>].<extension>`, each part dropped rather than leaving a
  dangling `" - "`. The **episode tag** (`ep. 2`) comes last, right before the extension, and is
  present **only while the project holds more than one episode** (ADR 0019) — the exports scoped to
  the selected episode (the screenplay PDF, the coverage, the shot list workbook, the breakdown
  sheets and workbook) would otherwise overwrite each other when two episodes are saved into one
  folder. It is the rule `OcptSidesPdfService.sidesFileName`'s own day tag already followed, for the
  same reason.

- `OcptExportManager` (`lib/managers/export/`) owns getting a project's documents in and out of the
  app: the native open dialog, and twenty services it owns (RFL18) — `OcptFountainIoService`
  (bytes ↔ text, suggested file names), `OcptScriptImportService` (the three importable formats in
  and Fountain text out, above), `OcptPdfExportService` (the screenplay PDF),
  `OcptShotListXlsxExportService`, `OcptScenarioCoveragePdfService`,
  `OcptResourcesXlsxExportService`, `OcptContactListPdfService`, `OcptBreakdownSheetsPdfService`,
  `OcptBreakdownXlsxExportService`, `OcptCallSheetPdfService`, `OcptShootingPlanPdfService`,
  `OcptShootingPlanXlsxExportService`, `OcptDayOutOfDaysPdfService`,
  `OcptOneLineSchedulePdfService`, `OcptSidesPdfService`, `OcptBudgetQuotePdfService`,
  `OcptBudgetFinancingPlanPdfService`, `OcptBudgetCashJournalXlsxExportService`,
  `OcptBudgetFinancialReportPdfService` (each described under its own mode below)
  and `OcptSaveLocationService` (wraps `file_selector`'s `getSaveLocation`, a **direct** dependency
  kept in sync with the version `act_file_transfer_manager` already resolves transitively, for the
  native "save as" dialog every export goes through — no export ever writes to a default location
  silently; its `pickDirectory` is the same promise for the exports that write **several** files).
  The twelve PDF services share one `OcptCourierPrimeFontsLoader` (handed to each by the manager, so
  the 4 embedded TTFs are decoded once) and one `OcptScriptPagePainter` — the two script exports
  **and the sides** for the positioned line drawing the three of them start from, the breakdown
  sheets, the contact list and the table-shaped schedule documents for its metrics and fonts alone,
  their pages flowing rather than typeset. **A workbook takes no painter and no font loader at
  all**: `excel_community` builds it in memory with no page geometry of its own, which is why the
  five of them are `const` services where every PDF one is constructed with the shared loader. An
  export writing into a folder reports an `OcptCallSheetExportResult` rather than a path: some files
  landing and others not is a third outcome, and it must never read as success — somebody would go
  unwarned about a day they are called on. The home page's `Import…` modal, the screenplay's own `⋮`
  import-and-replace and every export card go through the manager; the
  screenplay text itself is always written through `OcptScreenplayService.saveScreenplayText`, never
  by hand.

- **On mobile, the write funnel hands the bytes to the OS share sheet instead of a picked save
  location.** `file_selector`'s `getSaveLocation`/`getDirectoryPath` have no Android or iOS
  implementation, so `OcptExportManager`'s single write funnel branches on `PlatformManager.isMobile`
  (`foundations.md`): desktop keeps `getSaveLocation`/`getDirectoryPath` → `File.writeAsBytes`
  unchanged, mobile writes the bytes to a `path_provider` temp file and hands it — every file at
  once, for the folder-batch exports — to `OcptShareService` (`lib/managers/export/services/`, a
  thin `share_plus` wrapper reached through the manager rather than `globalGetIt()`, so a test can
  replace it exactly as `OcptSaveLocationService` already is). Every export method now returns a
  sealed `OcptExportOutcome` (`lib/types/`) — `OcptExportSaved(path)` or `OcptExportShared()` —
  rather than a nullable path, since a null return still means "cancelled or failed" but a
  successful one no longer always names a path; the success notice degrades accordingly, from
  "saved to `<path>`" on desktop to "Shared" on mobile, each mode's `IoNotice` carrying a
  `wasShared` flag rather than assuming a path is always there to word. A `Rect? shareAnchor`,
  resolved from the tapped export control's own `RenderBox` (`ocptExportShareAnchorOf`,
  `lib/ui/utils/`, a manager seeing no `BuildContext` of its own) and threaded through every export
  event, is the popover source the OS share sheet needs on an iPad or a Mac; the phone toolbar's
  folded overflow entry hands down null, having no control of its own to anchor from.

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
