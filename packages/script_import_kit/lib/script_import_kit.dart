// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// A pure Dart reader turning the screenplay files a production is actually
/// sent — a Final Draft `.fdx`, a legacy Celtx `.celtx` — into Fountain
/// text.
library;

export 'package:script_import_kit/src/models/script_import_exception.dart';
export 'package:script_import_kit/src/models/script_import_failure.dart';
export 'package:script_import_kit/src/models/script_import_format.dart';
export 'package:script_import_kit/src/models/script_import_result.dart';
export 'package:script_import_kit/src/readers/celtx_script_reader.dart';
export 'package:script_import_kit/src/readers/fdx_script_reader.dart';
export 'package:script_import_kit/src/script_importer.dart';
