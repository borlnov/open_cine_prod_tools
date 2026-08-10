// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_episode.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_workspace_episode_label.dart';

/// Pumps a throwaway widget to get hold of a real [Tr], `Tr.of` needing a mounted widget tree to
/// resolve — mirrors `ocpt_resources_labels_test.dart`'s own helper.
Future<Tr> _buildTr(WidgetTester tester) async {
  late Tr tr;

  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: const [
        Tr.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: Tr.delegate.supportedLocales,
      home: Builder(
        builder: (context) {
          tr = Tr.of(context);
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  await tester.pumpAndSettle();

  return tr;
}

void main() {
  testWidgets("a titled episode reads its number and its title", (tester) async {
    final tr = await _buildTr(tester);
    const episode = OcptEpisode(id: "ep-1", number: 1, title: "Le départ");

    expect(
      ocptWorkspaceEpisodeLabelOf(tr, episode),
      tr.workspaceEpisodeTitledLabel(1, "Le départ"),
    );
    expect(ocptWorkspaceEpisodeLabelOf(tr, episode), "1. Le départ");
  });

  testWidgets("an untitled episode reads the localized Episode {number}", (tester) async {
    final tr = await _buildTr(tester);
    const episode = OcptEpisode(id: "ep-3", number: 3, title: "");

    expect(ocptWorkspaceEpisodeLabelOf(tr, episode), tr.workspaceEpisodeUntitledLabel(3));
  });
}
