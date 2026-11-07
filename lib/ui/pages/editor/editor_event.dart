// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// The events of the screenplay editor, one sealed hierarchy per domain, all extending the
/// abstract `OcptEditorEvent`.
library;

export 'package:open_cine_prod_tools/ui/pages/editor/events/editor_base_event.dart';
export 'package:open_cine_prod_tools/ui/pages/editor/events/editor_document_event.dart';
export 'package:open_cine_prod_tools/ui/pages/editor/events/editor_io_event.dart';
export 'package:open_cine_prod_tools/ui/pages/editor/events/editor_search_event.dart';
export 'package:open_cine_prod_tools/ui/pages/editor/events/editor_spell_check_event.dart';
export 'package:open_cine_prod_tools/ui/pages/editor/events/editor_statistics_event.dart';
export 'package:open_cine_prod_tools/ui/pages/editor/events/editor_workspace_event.dart';
