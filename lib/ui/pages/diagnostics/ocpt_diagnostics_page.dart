// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/logging/ocpt_file_logging_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/ui/widgets/ocpt_diagnostics_log_list.dart';

/// The dedicated "Journaux (diagnostic)" screen, reached from Settings: the full
/// `OcptDiagnosticsManager` log — every category, not just one screen's own slice, unlike the
/// in-situ panels this screen replaced on the hosting panel and the Rejoindre screen
/// (`docs/architecture/sync.md`) — and the file logger's own log-file path.
class OcptDiagnosticsPage extends StatelessWidget {
  /// Class constructor
  const OcptDiagnosticsPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: BackButton(onPressed: () => globalGetIt().get<OcptRouterManager>().pop()),
      title: Text(Tr.of(context).diagnosticsLogTitle),
    ),
    body: const Column(
      children: [
        _OcptDiagnosticsLogFileRow(),
        Divider(height: 1),
        Expanded(child: OcptDiagnosticsLogList()),
      ],
    ),
  );
}

/// The screen's own top row: the file logger's own rotating log-file path, when file logging is
/// enabled, with a copy-path action — or [Tr.diagnosticsLogFileDisabled] when it is off in this
/// build.
///
/// Reads `OcptFileLoggingManager` through `globalGetIt()`, tolerating its absence exactly
/// `OcptDiagnosticsLogList`'s own reasoning: a test building this page over injected managers with
/// no reason to also register this one must not trip over it.
class _OcptDiagnosticsLogFileRow extends StatelessWidget {
  /// Class constructor
  const _OcptDiagnosticsLogFileRow();

  /// The file logger's own current log-file path, or null when file logging is disabled, its setup
  /// failed, or no `OcptFileLoggingManager` can be resolved at all.
  String? _resolveLogFilePath() {
    if (AbsGlobalManager.instance == null) {
      return null;
    }

    final managers = globalGetIt();

    return managers.isRegistered<OcptFileLoggingManager>()
        ? managers.get<OcptFileLoggingManager>().logFilePath
        : null;
  }

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final theme = Theme.of(context);
    final logFilePath = _resolveLogFilePath();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr.diagnosticsLogFileLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                if (logFilePath == null)
                  Text(
                    tr.diagnosticsLogFileDisabled,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  )
                else
                  SelectableText(
                    logFilePath,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: ocptMonospaceFontFamily,
                    ),
                  ),
              ],
            ),
          ),
          if (logFilePath != null)
            IconButton(
              tooltip: tr.diagnosticsLogFileCopyPath,
              icon: const Icon(Icons.copy_outlined),
              onPressed: () =>
                  unawaited(Clipboard.setData(ClipboardData(text: logFilePath))),
            ),
        ],
      ),
    );
  }
}
