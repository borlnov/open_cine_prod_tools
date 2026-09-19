// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// The file extensions the native picker offers when a photo is being referenced — a person's
/// headshot, a location's scouting photo, an element's picture.
///
/// Only what Flutter's own `Image` decodes: a reference the app cannot draw a thumbnail for would
/// look broken rather than referenced. See
/// `docs/adr/0013-binary-assets-referenced-by-path.md` — the file is never copied into the
/// project, so this list is a filter on the dialog, never a guarantee about what the path still
/// resolves to later.
const ocptImageFileExtensions = ["jpg", "jpeg", "png", "webp", "bmp", "gif"];

/// The file extensions the native picker offers when a document is being referenced — a signed
/// image-rights release, a granted filming permit.
///
/// Images are in the list beside `pdf`: a permit granted by email and photographed, or scanned to
/// a JPEG, is the ordinary case on a short film.
const ocptDocumentFileExtensions = ["pdf", ...ocptImageFileExtensions];

/// The file extensions the native picker offers when a storyboard panel's frame is being imported
/// or replaced.
///
/// Narrower than [ocptImageFileExtensions] on purpose (`docs/plans/storyboard.md`, §4.2, §8,
/// decision 5): the storyboard PDF embeds a panel's image bytes at render time, and the `pdf`
/// package only embeds JPEG and PNG, so a format this filter let through but that export couldn't
/// draw would work on screen and fail on paper. A frame in another format is converted before
/// import.
const ocptStoryboardPanelImageFileExtensions = ["jpg", "jpeg", "png"];
