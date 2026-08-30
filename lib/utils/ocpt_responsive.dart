// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// The app's first width-breakpoint seam: below [ocptCompactWidthBreakpoint], the workspace shell's
/// two side docks stop fitting next to the centre column and reduce to edge drawers instead.
///
/// The number is the width below which the right dock's 300 px floor
/// (`OcptWorkspaceDock.resolveDockWidths`) can no longer coexist with the 320 px centre floor.
const double ocptCompactWidthBreakpoint = 816;

/// Tells whether [width] is narrow enough that the workspace shell should treat it as compact —
/// see [ocptCompactWidthBreakpoint].
///
/// A pure predicate so every call site (the shell, a mode, a test) agrees on the same boundary.
bool ocptIsCompactWidth(double width) => width < ocptCompactWidthBreakpoint;

/// The width at or below which a summoned side dock fills the whole row rather than sliding in as
/// an edge drawer — a phone, in Material 3's terms its "compact" window class.
///
/// Between this and [ocptCompactWidthBreakpoint] the docks no longer fit as persistent columns but
/// the row is still wide enough (a tablet, a split view, a narrow desktop window) to show a
/// summoned dock as an edge drawer over the centre, keeping some of the centre in view.
const double ocptPhoneWidthBreakpoint = 600;

/// The width, in pixels, a summoned side dock takes as an edge drawer above
/// [ocptPhoneWidthBreakpoint] — comfortably wider than the right dock's own 300 px floor
/// (`OcptWorkspaceDock.rightMinWidth`) while still leaving the centre visible beside it. A drawer
/// is never wider than the row itself.
const double ocptCompactDrawerWidth = 360;

/// The pixel width a summoned side dock should take over a row of [rowWidth] at a compact width:
/// the whole row on a phone ([ocptPhoneWidthBreakpoint] and below), an [ocptCompactDrawerWidth]
/// edge drawer above that, never wider than the row itself.
///
/// A pure function of the row width — the layout reduction is width-keyed, not platform-keyed, so
/// the workspace shell stays a pure presentational widget (the mobile-only concerns, touch density
/// and the scaled theme, are `PlatformManager`-keyed elsewhere).
double ocptCompactDrawerWidthFor(double rowWidth) {
  if (rowWidth <= ocptPhoneWidthBreakpoint) {
    return rowWidth;
  }
  return rowWidth < ocptCompactDrawerWidth ? rowWidth : ocptCompactDrawerWidth;
}
