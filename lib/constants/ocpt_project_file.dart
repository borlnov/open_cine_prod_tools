// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// The extension a project file carries, without the leading dot.
///
/// Every project of this app is a single SQLite file wearing it, and three layers need to name it:
/// the manager creating and opening one, the open/save dialogs filtering on it, and the package
/// service writing the `.ocpt` it unpacks out of an archive. It lives here rather than on
/// `OcptProjectsManager` — where it used to, and where it still reads from through
/// `OcptProjectsManager.projectFileExtension` — because a service may not import the manager that
/// owns it, and an extension restated on the way down is one that can silently drift from the file
/// the rest of the app actually writes.
const ocptProjectFileExtension = "ocpt";
