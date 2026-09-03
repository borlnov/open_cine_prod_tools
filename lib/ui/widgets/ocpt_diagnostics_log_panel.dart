// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' as intl;
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_diagnostics_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_diagnostics_entry.dart';

/// The maximum height of [OcptDiagnosticsLogPanel]'s own scrollable log list, once expanded.
const _maxLogHeight = 220.0;

/// The collapsed-by-default "Journaux (diagnostic)" section: a small window onto
/// `OcptDiagnosticsManager`'s own device-local ring buffer, so Benoit can see, on each device,
/// what the relay server (when hosting) and the sync client are doing — placed at the bottom of
/// the hosting panel (every category) and the Rejoindre screen
/// ([OcptDiagnosticsCategory.join]/[OcptDiagnosticsCategory.sync] only), so each device shows its
/// own logs where the action itself lives.
///
/// Reads `OcptDiagnosticsManager` through `globalGetIt()`, tolerating its absence — no global
/// manager instance at all, or one registered with no `OcptDiagnosticsManager` — by rendering the
/// same empty state a real, empty buffer would: most of this app's own widget tests build a page
/// straight over injected managers and blocs, with no reason to also register this one, and this
/// panel must not be what breaks them.
class OcptDiagnosticsLogPanel extends StatelessWidget {
  /// Restricts the entries shown to these categories, when given; every category otherwise.
  final Set<OcptDiagnosticsCategory>? categories;

  /// Class constructor
  const OcptDiagnosticsLogPanel({this.categories, super.key});

  /// The registered [OcptDiagnosticsManager], or null when none can be resolved — see this class's
  /// own doc comment for why that is a real, tolerated case rather than a programmer error.
  OcptDiagnosticsManager? _resolveManager() {
    if (AbsGlobalManager.instance == null) {
      return null;
    }

    final managers = globalGetIt();

    return managers.isRegistered<OcptDiagnosticsManager>()
        ? managers.get<OcptDiagnosticsManager>()
        : null;
  }

  /// [entries] filtered down to [categories], when given.
  List<OcptDiagnosticsEntry> _filtered(List<OcptDiagnosticsEntry> entries) {
    final wanted = categories;
    if (wanted == null) {
      return entries;
    }

    return [for (final entry in entries) if (wanted.contains(entry.category)) entry];
  }

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final manager = _resolveManager();

    return ExpansionTile(
      title: Text(tr.diagnosticsLogTitle),
      children: [
        if (manager == null)
          _OcptDiagnosticsEmptyBody(text: tr.diagnosticsEmpty)
        else
          StreamBuilder<List<OcptDiagnosticsEntry>>(
            initialData: manager.entries,
            stream: manager.entriesStream,
            builder: (context, snapshot) {
              final entries = _filtered(snapshot.data ?? manager.entries);

              return _OcptDiagnosticsBody(entries: entries, manager: manager);
            },
          ),
      ],
    );
  }
}

/// The panel's own body once a real [OcptDiagnosticsManager] is resolved: the copy-all/clear
/// toolbar and the bounded, scrollable, monospace log list, or [OcptDiagnosticsLogPanel]'s own
/// empty state when [entries] is empty.
class _OcptDiagnosticsBody extends StatelessWidget {
  /// Class constructor
  const _OcptDiagnosticsBody({required this.entries, required this.manager});

  /// The entries this body renders — already filtered to the panel's own [OcptDiagnosticsLogPanel.
  /// categories].
  final List<OcptDiagnosticsEntry> entries;

  /// The manager the toolbar's own copy/clear actions act on.
  final OcptDiagnosticsManager manager;

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            IconButton(
              tooltip: tr.diagnosticsCopyTooltip,
              icon: const Icon(Icons.copy_outlined),
              onPressed: entries.isEmpty
                  ? null
                  : () => unawaited(
                      Clipboard.setData(ClipboardData(text: _joinedText(entries))),
                    ),
            ),
            IconButton(
              tooltip: tr.diagnosticsClearTooltip,
              icon: const Icon(Icons.delete_outline),
              onPressed: entries.isEmpty ? null : manager.clear,
            ),
          ],
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: _maxLogHeight),
          child: entries.isEmpty
              ? _OcptDiagnosticsEmptyBody(text: tr.diagnosticsEmpty)
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: entries.length,
                  itemBuilder: (context, index) =>
                      _OcptDiagnosticsLine(entry: entries[index], theme: theme),
                ),
        ),
      ],
    );
  }

  /// Every [entries] line, joined by newlines — what the copy-all button puts on the clipboard.
  static String _joinedText(List<OcptDiagnosticsEntry> entries) =>
      entries.map(_lineText).join('\n');
}

/// [OcptDiagnosticsLogPanel]'s own empty state, shown both when no manager can be resolved at all
/// and when a real, resolved one simply holds nothing (yet) for the current filter.
class _OcptDiagnosticsEmptyBody extends StatelessWidget {
  /// Class constructor
  const _OcptDiagnosticsEmptyBody({required this.text});

  /// The message shown.
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }
}

/// One log line: `HH:mm:ss · CATEGORY · message`, tinted with [theme]'s own error colour for
/// [OcptDiagnosticsLevel.error] and a dimmer, still legible tone for
/// [OcptDiagnosticsLevel.warning] — [OcptDiagnosticsLevel.info] renders in the ordinary body
/// colour.
class _OcptDiagnosticsLine extends StatelessWidget {
  /// Class constructor
  const _OcptDiagnosticsLine({required this.entry, required this.theme});

  /// The entry this line renders.
  final OcptDiagnosticsEntry entry;

  /// The theme this line's own colours are read off.
  final ThemeData theme;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 16),
    child: Text(
      _lineText(entry),
      style: theme.textTheme.bodySmall?.copyWith(
        fontFamily: ocptMonospaceFontFamily,
        color: switch (entry.level) {
          OcptDiagnosticsLevel.error => theme.colorScheme.error,
          OcptDiagnosticsLevel.warning => theme.colorScheme.tertiary,
          OcptDiagnosticsLevel.info => theme.colorScheme.onSurfaceVariant,
        },
      ),
    ),
  );
}

/// One [entry]'s own text: `HH:mm:ss · CATEGORY · message`.
String _lineText(OcptDiagnosticsEntry entry) {
  final time = intl.DateFormat('HH:mm:ss').format(entry.time.toLocal());
  final category = entry.category.name.toUpperCase();

  return "$time · $category · ${entry.message}";
}
