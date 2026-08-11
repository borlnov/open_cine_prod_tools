// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// The suggested file name for an export: `<projectName>[ - <suffix>][ - <episodeTag>].<extension>`.
///
/// [suffix] and [episodeTag] are each dropped — rather than leaving a dangling `" - "` — while
/// null or holding nothing but whitespace; a non-blank one is written trimmed. This is the one
/// implementation of the join every `…FileName` helper of this manager's services restated on its
/// own before this helper existed (`OcptScenarioCoveragePdfService.coverageFileName`,
/// `OcptBreakdownSheetsPdfService.sheetsFileName` and `OcptBreakdownXlsxExportService.xlsxFileName`
/// with a ternary, `OcptPdfExportService.pdfFileName`, `OcptFountainIoService.fountainFileName` and
/// `OcptShotListXlsxExportService.xlsxFileName` by plain interpolation) and now each of them
/// delegates to.
///
/// [episodeTag] always comes last, right before the extension — the selected episode's own tag
/// (`ep. 2`), present only while the open project holds more than one episode (issue #55, ADR
/// 0019) — mirroring `OcptSidesPdfService.sidesFileName`'s own day tag: two episodes' exports saved
/// into the same folder must not silently overwrite one another, exactly as two days' sides don't.
///
/// [projectName] is written verbatim, untrimmed: every caller already hands this helper a name it
/// trusts, and none of the six services this helper serves ever trimmed it either.
String ocptExportFileNameOf({
  required String projectName,
  String? suffix,
  String? episodeTag,
  required String extension,
}) {
  final trimmedSuffix = suffix?.trim() ?? "";
  final trimmedEpisodeTag = episodeTag?.trim() ?? "";

  final segments = [
    projectName,
    if (trimmedSuffix.isNotEmpty) trimmedSuffix,
    if (trimmedEpisodeTag.isNotEmpty) trimmedEpisodeTag,
  ];

  return "${segments.join(" - ")}.$extension";
}
