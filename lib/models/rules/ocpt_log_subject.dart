// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:path/path.dart' as p;

/// The name a log line gives the file at [path]: its base name, never the folder it sits in.
///
/// A path often holds the user's name (`/home/<user>/…`, `C:\Users\<user>\…`), and a log file is
/// something a user may be asked to send, so a line names the file and nothing around it. A null
/// [path] (no project open) reads `none`.
String ocptLogFileName(String? path) => path == null ? 'none' : p.basename(path);
