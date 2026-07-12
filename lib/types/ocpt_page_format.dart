// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <benoit.rolandeau@allcircuits.com>
//
// SPDX-License-Identifier: Apache-2.0

/// The physical page format used to paginate a project's screenplays.
///
/// This is chosen once, when the project is created, and stored in
/// `project_info.pageFormat`.
enum OcptPageFormat {
  /// The US Letter format (8.5 x 11 in), the de facto standard in the US screenwriting industry.
  usLetter,

  /// The A4 format (210 x 297 mm), the standard used in most of the rest of the world.
  a4,
}
