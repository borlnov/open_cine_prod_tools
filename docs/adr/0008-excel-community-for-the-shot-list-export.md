<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# 0008 - excel_community for the shot list export

## Status

Accepted

## Decision

The shot list is exported as an XLSX workbook written with **`excel_community`**, a direct
dependency of the application, wrapped by `OcptShotListXlsxExportService` under
`OcptExportManager` — the same shape the `.fountain` and PDF exports already use, so no call site
ever touches the spreadsheet library itself. Only that one service imports it; replacing it later
means rewriting a single file.

## Context

Every document of this project has to stay exportable to a human-readable, open format, and the
shot list is the one document a crew actually works from on set — in a spreadsheet, not in this
app. XLSX is what a production office already exchanges (the feature's own reference is a real
`Découpage technique.xlsx`), which rules out exporting only CSV.

Writing an XLSX by hand means building an OOXML package: a zip holding `[Content_Types].xml`,
the workbook and worksheet parts, and their relationship files. That is a well-documented format,
but it is a file format implementation, not shot list code.

The step's plan named `excel`, the best-known Dart spreadsheet package. It cannot be resolved in
this repository: its latest release (4.0.6) still depends on `archive ^3` and `xml >=5 <7`, while
`act_launcher_icon` — a dev dependency, through `icons_launcher` and `image` — requires
`archive ^4` and `xml ^7`. There is no version pair that satisfies both, so adding `excel` fails
version solving outright.

`excel_community` is the maintained community fork of that same package, MIT-licensed, with the
same API (`Excel.createExcel()`, `sheet.appendRow`, the `CellValue` hierarchy) and dependencies
updated to `archive ^4` / `xml ^7`. It resolves cleanly against everything already in the
pubspec.

## Consequences

The export is a few dozen lines of workbook building rather than an OOXML writer, and the sheet
can gain styling (bold headers and sequence separators today, column widths or a frozen header
row tomorrow) without any new format work.

In exchange, the app depends on a young fork: `excel_community` published its first releases in
2026 and has a fraction of `excel`'s history behind it. The risk is contained by the single
service boundary above, and by the fact that the workbook this app writes uses the plainest
possible corner of the API — text, integer and double cells, one sheet, no formulas, no charts.
If the fork stalls, the options are the same as today's, minus the resolution conflict: another
package, or a hand-written OOXML writer against the `archive` dependency already in the tree.

This ADR also records the first case where a plan's named dependency could not be used as
written. The deviation is a resolution constraint, not a preference.

## Alternatives considered

- **`excel` itself, by dropping `act_launcher_icon`**: would keep the dependency the plan named,
  at the cost of the tooling that regenerates every platform's launcher icon
  (`dart run icons_launcher:create`). Trading a documented, working branding workflow for a
  package name is a bad exchange, and the fork offers the same API anyway.
- **`excel_plus`**: also resolves and is actively published, but it is a separate lineage with its
  own API and an extra `csv_plus` dependency, where `excel_community` is a drop-in continuation of
  the package the plan asked for.
- **A hand-written OOXML writer over `archive`**: no third-party spreadsheet dependency at all,
  and full control of the output — but it puts a file format implementation, with its own escaping
  and packaging bugs, inside a shot list feature. Worth revisiting only if the fork is abandoned.
- **CSV instead of XLSX**: trivial to write with no dependency, but loses the sheet name, the
  header styling and the sequence grouping, and a comma-separated file is not what a production
  office exchanges.
