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
