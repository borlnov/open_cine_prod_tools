// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/managers/logging/ocpt_file_logging_manager.dart';

/// The stable keys `LoggerManager.addExternalLogger`/`removeExternalLogger` take — an external
/// logger no call site other than [OcptFileLoggingManager] itself ever adds or removes.
enum OcptExternalLoggerKey {
  /// The [OcptFileExternalLogger] [OcptFileLoggingManager] may register, when `logs.file.enabled`
  /// is true.
  file,
}
