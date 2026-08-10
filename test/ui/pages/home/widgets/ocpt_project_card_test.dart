// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_recent_project_model.dart';
import 'package:open_cine_prod_tools/ui/pages/home/home_state.dart';
import 'package:open_cine_prod_tools/ui/pages/home/widgets/ocpt_project_card.dart';

/// Builds an [OcptProjectCard] for a project at [path], themed and localized as the app does,
/// holding [episodeCount] episodes (null, as [OcptRecentProjectModel.episodeCount] itself
/// defaults to, for an entry that never recorded one).
Widget _buildCard(String path, {int? episodeCount}) => MaterialApp(
  theme: ocptTheme.lightThemeData,
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: OcptProjectCard(
    entry: OcptHomeRecentProjectEntry(
      project: OcptRecentProjectModel(
        path: path,
        name: 'Project',
        lastOpenedAt: DateTime(2026),
        episodeCount: episodeCount,
      ),
      exists: true,
    ),
    onTap: () {},
    onRemove: () {},
  ),
);

/// Reads the poster's tint from a pumped [_buildCard] tree: the fully opaque [ColoredBox], as
/// opposed to the transparent ones Material widgets paint internally.
Color _posterTintOf(WidgetTester tester) => tester
    .widgetList<ColoredBox>(find.byType(ColoredBox))
    .singleWhere((box) => box.color.a == 1.0)
    .color;

void main() {
  testWidgets('the same project path always yields the same tint', (tester) async {
    const path = '/home/user/projects/glass-paths.ocpt';

    await tester.pumpWidget(_buildCard(path));
    final firstTint = _posterTintOf(tester);

    await tester.pumpWidget(_buildCard(path));
    final secondTint = _posterTintOf(tester);

    expect(firstTint, secondTint);
  });

  testWidgets('the card shows the hand cursor over its clickable surface', (tester) async {
    // The card is a custom InkWell rather than a button, so it only shows a click affordance on
    // Linux and Windows if it asks for [ocptClickableCursor] itself.
    await tester.pumpWidget(_buildCard('/home/user/projects/glass-paths.ocpt'));

    final inkWell = tester.widget<InkWell>(find.byType(InkWell).first);
    expect(inkWell.mouseCursor, ocptClickableCursor);
  });

  testWidgets('different project paths spread across the tint palette', (tester) async {
    final paths = List.generate(8, (index) => '/home/user/projects/project-$index.ocpt');
    final tints = <Color>{};

    for (final path in paths) {
      await tester.pumpWidget(_buildCard(path));
      tints.add(_posterTintOf(tester));
    }

    expect(tints.length, greaterThan(1));
  });

  testWidgets('a project holding several episodes draws the badge with its count', (tester) async {
    await tester.pumpWidget(
      _buildCard('/home/user/projects/glass-paths.ocpt', episodeCount: 3),
    );

    final tr = Tr.of(tester.element(find.byType(OcptProjectCard)));
    expect(find.text(tr.homeProjectEpisodeCount(3)), findsOneWidget);
  });

  testWidgets('a single-episode project draws no badge', (tester) async {
    await tester.pumpWidget(
      _buildCard('/home/user/projects/glass-paths.ocpt', episodeCount: 1),
    );

    final tr = Tr.of(tester.element(find.byType(OcptProjectCard)));
    expect(find.text(tr.homeProjectEpisodeCount(1)), findsNothing);
  });

  testWidgets('an entry with no recorded episode count draws no badge', (tester) async {
    // An entry parsed from JSON written by an older version of the app, which never recorded
    // one — null means "unknown", not "one episode".
    await tester.pumpWidget(_buildCard('/home/user/projects/glass-paths.ocpt'));

    final tr = Tr.of(tester.element(find.byType(OcptProjectCard)));
    expect(find.text(tr.homeProjectEpisodeCount(1)), findsNothing);
    expect(find.text(tr.homeProjectEpisodeCount(2)), findsNothing);
  });
}
