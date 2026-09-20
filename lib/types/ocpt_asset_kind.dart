// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// What subject an `assets` row's referenced file illustrates or documents.
///
/// See `docs/adr/0013-binary-assets-referenced-by-path.md`: the row holds a path, never bytes, and
/// this is what a reader uses to know which owner column of the row to expect populated and what
/// kind of thumbnail to attempt.
enum OcptAssetKind {
  /// A person's headshot/photo.
  personPhoto,

  /// A location's scouting photo.
  locationPhoto,

  /// An element's photo.
  elementPhoto,

  /// A document: a signed image rights release, a filming permit, or similar paperwork.
  document,

  /// A till receipt, an invoice PDF or a bank slip standing as the voucher of a journal entry
  /// (`budget_entries`).
  receipt,

  /// A storyboard panel's imported frame (`storyboard_panels.imageAssetId`).
  ///
  /// Sets **none** of `assets`' four owner columns: the panel's own `imageAssetId` is the only link,
  /// the way `people.photoAssetId` is — see `OcptAssetsTable`'s own doc comment, amended by
  /// `docs/adr/0013-binary-assets-referenced-by-path.md`'s storyboard follow-up
  /// (`docs/plans/storyboard.md`, §2) to say these two kinds set none.
  storyboardPanelImage,

  /// A floor plan set's underlay photo or plan (`floor_plan_sets.underlayAssetId`).
  ///
  /// Sets none of the four owner columns either, for the same reason [storyboardPanelImage] does.
  floorPlanUnderlay,
}
