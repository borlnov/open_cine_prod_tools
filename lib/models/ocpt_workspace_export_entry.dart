// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/models/ocpt_card_choice_entry.dart';

/// One card of `OcptWorkspaceExportDialog<T>`: the descriptor of a single document a mode knows
/// how to print, generic over that mode's own export enum.
///
/// The export panel's own name for [OcptCardChoiceEntry], which is the same card the home page's
/// `Import…` modal is built from: a document is one thing a dialog offers among a few, and the
/// only difference between the two dialogs is the words and what they hand back. The name is kept
/// where a mode declares its documents, since that is what a mode is describing there.
typedef OcptWorkspaceExportEntry<T> = OcptCardChoiceEntry<T>;
