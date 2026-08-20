// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// A pure Dart reader turning the screenplay files a production is actually
/// sent — a Final Draft `.fdx` — into Fountain text.
library;

export 'src/models/script_import_exception.dart';
export 'src/models/script_import_format.dart';
export 'src/models/script_import_result.dart';
export 'src/readers/fdx_script_reader.dart';
export 'src/script_importer.dart';
