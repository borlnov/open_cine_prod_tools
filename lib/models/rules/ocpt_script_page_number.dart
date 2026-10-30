// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// The distance from a script page's top physical edge to its page-number annotation, in inches.
///
/// Fixed regardless of the configured top margin (unlike the body text, which starts at the
/// margin), matching how professional screenwriting software places the page number in the header
/// band rather than tying it to the body's own margin.
const double ocptScriptPageNumberTopInches = 0.5;

/// The annotation a script page whose 1-based number among script pages is [scriptPageNumber]
/// prints at its top right, or null when that page prints none.
///
/// The professional convention this states once: a page number reads `N.`, the title page is not a
/// script page and is therefore never counted, and the first script page stays unnumbered — so the
/// first annotation any screenplay ever shows is `2.`.
///
/// Both front-ends of the same screenplay read it: `OcptScriptPagePainter` for every exported PDF,
/// and the styled editor's page-simulation sheets for the very same pages on screen. A number shown
/// on screen that disagreed with the number printed on paper would be worse than no number at all,
/// which is why neither of them restates the rule.
String? ocptScriptPageNumberLabelOf(int scriptPageNumber) =>
    scriptPageNumber >= 2 ? "$scriptPageNumber." : null;
