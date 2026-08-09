// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// How a shot's own display code splits into the two halves every printed document reads it by.
///
/// A shot is coded `<sceneNumber>/<rank>` — `12/3` being the third shot of sequence 12 — and the
/// documents that print one never print the whole code: a call sheet's own `SEQ` and `PLANS`
/// columns, a shooting plan's sequence grid and its `Plan` column each name one half, the other
/// being already said by the row or the column they sit in. That split is stated **here**, in one
/// pure file both the manager layer's PDF services and `lib/models/`'s own pure layouts import: it
/// used to live in `ocpt_schedule_pdf_shared.dart`, which a `lib/models/` file may not depend on
/// (dependencies never reference their dependents), and the alternative — each side splitting the
/// code its own way — is exactly how two documents come to disagree about which shot they are
/// naming.
///
/// A code carrying no `/` at all is returned whole by both halves: it is a shot the app never
/// coded, and printing it verbatim says more than printing an empty cell.
library;

import 'package:open_cine_prod_tools/models/ocpt_shot.dart';

/// The scene-number half of [shot]'s own `<sceneNumber>/<rank>` display code — what a call sheet's
/// own `SEQ` column and a shooting plan's own sequence grid read a shot's scene off.
String ocptShotSceneNumberOf(OcptShot shot) =>
    shot.code.contains("/") ? shot.code.split("/").first : shot.code;

/// The per-scene rank half of [shot]'s own `<sceneNumber>/<rank>` display code — what a call sheet's
/// own `PLANS` column and a shooting plan's own `Plan`/sequence-grid cells read, since whichever one
/// is naming it already says the scene.
String ocptShotRankOf(OcptShot shot) =>
    shot.code.contains("/") ? shot.code.split("/").last : shot.code;
