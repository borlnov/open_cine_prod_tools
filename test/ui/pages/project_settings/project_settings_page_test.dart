// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/ui/pages/project_settings/project_settings_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/project_settings/project_settings_page.dart';
import 'package:open_cine_prod_tools/ui/pages/project_settings/widgets/ocpt_project_settings_currency_section.dart';
import 'package:open_cine_prod_tools/ui/pages/project_settings/widgets/ocpt_project_settings_episodes_section.dart';
import 'package:open_cine_prod_tools/ui/pages/project_settings/widgets/ocpt_project_settings_minimum_rest_section.dart';
import 'package:open_cine_prod_tools/ui/pages/project_settings/widgets/ocpt_project_settings_page_format_section.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_workspace_episode_label.dart';
import 'package:open_cine_prod_tools/ui/widgets/ocpt_confirm_dialog.dart';
import 'package:open_cine_prod_tools/utils/ocpt_minimum_rest.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// The navigator [_wrapWithLocalization] mounts, so [_RecordingRouterManager.pop] can close a
/// dialog opened through `showDialog` (the episodes card's own `OcptConfirmDialog`) exactly as the
/// real `GoRouter.pop` would — both push onto the very same root `Navigator`. See
/// `test/ui/pages/workspace/modes/breakdown/breakdown_mode_test.dart`'s own instance of the same
/// pattern.
final _navigatorKey = GlobalKey<NavigatorState>();

/// A router manager whose [pop] records the call — the back button test reads it directly, since
/// this page test pumps [OcptProjectSettingsView] directly, without a real GoRouter for it to
/// operate on — and also pops [_navigatorKey]'s own navigator when it can, so a dialog opened
/// through `showDialog` genuinely closes.
class _RecordingRouterManager extends OcptRouterManager {
  /// Whether [pop] was called at all.
  bool wasPopped = false;

  /// The value [pop] was last called with.
  Object? poppedResult;

  @override
  void pop<Y extends Object?>([Y? result]) {
    wasPopped = true;
    poppedResult = result;

    final navigator = _navigatorKey.currentState;
    if (navigator != null && navigator.canPop()) {
      navigator.pop(result);
    }
  }
}

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve in tests, and
/// [_navigatorKey] so [_RecordingRouterManager.pop] can close a dialog opened through
/// `showDialog`.
Widget _wrapWithLocalization(Widget child) => MaterialApp(
  navigatorKey: _navigatorKey,
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: child,
);

void main() {
  late OcptPropertiesManager propertiesManager;
  late Directory tempDir;
  late OcptProjectsManager projectsManager;
  late _RecordingRouterManager routerManager;

  setUpAll(() async {
    // OcptProjectsManager logs through appLogger(), which requires a global manager instance to
    // be set; merely accessing it creates the (otherwise unused) singleton.
    OcptGlobalManager.instance;

    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    propertiesManager = OcptPropertiesManager();
    await propertiesManager.initLifeCycle();
  });

  setUp(() async {
    await propertiesManager.deleteAll();
    tempDir = await Directory.systemTemp.createTemp("ocpt_project_settings_page_test_");
    projectsManager = OcptProjectsManager(propertiesManager: propertiesManager);
    await projectsManager.initLifeCycle();
    await projectsManager.createProject(
      name: "My Movie",
      filePath: p.join(tempDir.path, "movie.ocpt"),
    );

    final managers = globalGetIt();
    if (managers.isRegistered<OcptRouterManager>()) {
      await managers.unregister<OcptRouterManager>();
    }
    routerManager = _RecordingRouterManager();
    managers.registerSingleton<OcptRouterManager>(routerManager);
  });

  tearDown(() async {
    await projectsManager.disposeLifeCycle();
    await tempDir.delete(recursive: true);
  });

  /// Pumps [OcptProjectSettingsView] backed by a fresh [OcptProjectSettingsBloc] reading/writing
  /// through [projectsManager], returning the bloc so tests can inspect its state.
  ///
  /// The surface is made tall enough for the episodes card's own rows to sit fully on screen
  /// (the default 800×600 clips them below the fold, `OcptPersonSheet`'s own test fixture facing
  /// the same thing): every affordance below has to actually be tappable, not merely present in
  /// the tree.
  Future<OcptProjectSettingsBloc> pumpView(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final bloc = OcptProjectSettingsBloc(projectsManager: projectsManager);
    addTearDown(bloc.close);

    await tester.pumpWidget(
      _wrapWithLocalization(
        BlocProvider<OcptProjectSettingsBloc>.value(
          value: bloc,
          child: const OcptProjectSettingsView(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    return bloc;
  }

  /// A finder scoped to the minimum rest section's own field, so it can't collide with the
  /// episodes card's own number and title fields — all three being plain `TextField`s on this
  /// page.
  Finder minimumRestField() => find.descendant(
    of: find.byType(OcptProjectSettingsMinimumRestSection),
    matching: find.byType(TextField),
  );

  /// A finder scoped to the episodes card, matching [inner] inside it alone.
  Finder inEpisodesSection(Finder inner) =>
      find.descendant(of: find.byType(OcptProjectSettingsEpisodesSection), matching: inner);

  /// Creates a second episode directly through the very service the bloc itself reaches for,
  /// returning its freshly minted id — the multi-episode fixture every reorder/delete test below
  /// builds on, extending [projectsManager]'s own single-screenplay project rather than a parallel
  /// one.
  Future<String> addEpisode({String title = "", int? number}) async {
    final id = await projectsManager.screenplayService.createEpisode(
      database: projectsManager.currentProject!.database,
      title: title,
      number: number,
    );
    return id!;
  }

  testWidgets("renders both sections with the project's current settings", (tester) async {
    await pumpView(tester);

    expect(find.byType(OcptProjectSettingsCurrencySection), findsOneWidget);
    expect(find.byType(OcptProjectSettingsPageFormatSection), findsOneWidget);
    expect(find.byType(OcptProjectSettingsMinimumRestSection), findsOneWidget);
    expect(find.byType(OcptProjectSettingsEpisodesSection), findsOneWidget);

    final context = tester.element(find.byType(OcptProjectSettingsView));
    final tr = Tr.of(context);
    expect(find.text(tr.projectSettingsPageTitle), findsOneWidget);

    // Asserts against whatever the manager actually seeded, not a hardcoded EUR: the device
    // locale running the test may suggest a different one.
    final currencyCode = await projectsManager.loadCurrentProjectCurrencyCode();
    final currencySymbol = NumberFormat.simpleCurrency(name: currencyCode).currencySymbol;
    expect(find.text("$currencyCode — $currencySymbol"), findsOneWidget);
  });

  testWidgets("picking a currency writes it to the project and marks the state changed", (
    tester,
  ) async {
    final bloc = await pumpView(tester);
    final initialCode = await projectsManager.loadCurrentProjectCurrencyCode();
    final otherCode = initialCode == "USD" ? "GBP" : "USD";
    final otherSymbol = NumberFormat.simpleCurrency(name: otherCode).currencySymbol;

    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text("$otherCode — $otherSymbol").last);
    await tester.pumpAndSettle();

    expect(bloc.state.currencyCode, otherCode);
    expect(bloc.state.hasChanged, isTrue);
    expect(await projectsManager.loadCurrentProjectCurrencyCode(), otherCode);
  });

  testWidgets("picking a page format writes it to the project and marks the state changed", (
    tester,
  ) async {
    final bloc = await pumpView(tester);
    final initialFormat = await projectsManager.loadCurrentProjectPageFormat();
    final otherFormat = initialFormat == OcptPageFormat.usLetter
        ? OcptPageFormat.a4
        : OcptPageFormat.usLetter;

    await tester.tap(find.byType(DropdownButton<OcptPageFormat>));
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(OcptProjectSettingsView));
    final tr = Tr.of(context);
    final otherLabel = otherFormat == OcptPageFormat.a4
        ? tr.editorPageSetupA4Option
        : tr.editorPageSetupUsLetterOption;
    await tester.tap(find.text(otherLabel).last);
    await tester.pumpAndSettle();

    expect(bloc.state.pageFormat, otherFormat);
    expect(bloc.state.hasChanged, isTrue);
    expect(await projectsManager.loadCurrentProjectPageFormat(), otherFormat);
  });

  testWidgets("shows the project's currently recorded minimum rest, in hours", (tester) async {
    await projectsManager.saveCurrentProjectMinimumRestMinutes(90);

    await pumpView(tester);

    expect(find.text(ocptMinimumRestHoursTextOf(90)), findsOneWidget);
  });

  testWidgets("typing a minimum rest in hours writes the minutes it makes to the project", (
    tester,
  ) async {
    final bloc = await pumpView(tester);

    await tester.enterText(minimumRestField(), "11");
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(bloc.state.minimumRestMinutes, 660);
    expect(bloc.state.hasChanged, isTrue);
    expect(await projectsManager.loadCurrentProjectMinimumRestMinutes(), 660);
  });

  testWidgets("a committed minimum rest can be typed over again", (tester) async {
    await projectsManager.saveCurrentProjectMinimumRestMinutes(660);
    final bloc = await pumpView(tester);

    // What the field shows after a commit is what it accepts back: the digits alone, the unit
    // being the field's own suffix.
    expect(find.text("11"), findsOneWidget);

    await tester.enterText(minimumRestField(), "12,5");
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(bloc.state.minimumRestMinutes, 750);
    expect(await projectsManager.loadCurrentProjectMinimumRestMinutes(), 750);
    expect(find.text("12.5"), findsOneWidget);
  });

  testWidgets("clearing the minimum rest writes null to the project", (tester) async {
    await projectsManager.saveCurrentProjectMinimumRestMinutes(660);
    final bloc = await pumpView(tester);

    await tester.enterText(minimumRestField(), "");
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(bloc.state.minimumRestMinutes, isNull);
    expect(bloc.state.hasChanged, isTrue);
    expect(await projectsManager.loadCurrentProjectMinimumRestMinutes(), isNull);
  });

  testWidgets("a zero or negative minimum rest is rejected and nothing is written", (
    tester,
  ) async {
    await projectsManager.saveCurrentProjectMinimumRestMinutes(90);
    final bloc = await pumpView(tester);

    await tester.enterText(minimumRestField(), "-5");
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(bloc.state.minimumRestMinutes, 90);
    expect(bloc.state.hasChanged, isFalse);
    expect(await projectsManager.loadCurrentProjectMinimumRestMinutes(), 90);
    // The field reverts to the last committed value's own reading.
    expect(find.text(ocptMinimumRestHoursTextOf(90)), findsOneWidget);
  });

  testWidgets("tapping the back arrow pops with whether anything changed", (tester) async {
    final bloc = await pumpView(tester);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(routerManager.wasPopped, isTrue);
    expect(routerManager.poppedResult, bloc.state.hasChanged);
    expect(routerManager.poppedResult, isFalse);
  });

  testWidgets("popping after a change hands back true", (tester) async {
    await pumpView(tester);
    final initialFormat = await projectsManager.loadCurrentProjectPageFormat();
    final otherFormat = initialFormat == OcptPageFormat.usLetter
        ? OcptPageFormat.a4
        : OcptPageFormat.usLetter;

    await tester.tap(find.byType(DropdownButton<OcptPageFormat>));
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(OcptProjectSettingsView));
    final tr = Tr.of(context);
    final otherLabel = otherFormat == OcptPageFormat.a4
        ? tr.editorPageSetupA4Option
        : tr.editorPageSetupUsLetterOption;
    await tester.tap(find.text(otherLabel).last);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(routerManager.poppedResult, isTrue);
  });

  testWidgets("the episodes card lists the project's episodes in order", (tester) async {
    final secondId = await addEpisode(title: "Les falaises");

    final bloc = await pumpView(tester);

    expect(bloc.state.episodes.map((episode) => episode.id).toList(), [
      bloc.state.episodes.first.id,
      secondId,
    ]);
    final fields = tester.widgetList<TextField>(inEpisodesSection(find.byType(TextField))).toList();
    // Two rows, number field then title field each: the seeded episode ("My Movie", numbered 1 by
    // `OcptProjectsManager.createProject`) first, the freshly added one second.
    expect(fields[0].controller!.text, "1");
    expect(fields[1].controller!.text, "My Movie");
    expect(fields[2].controller!.text, "2");
    expect(fields[3].controller!.text, "Les falaises");
  });

  testWidgets("tapping + Add appends a new episode", (tester) async {
    final bloc = await pumpView(tester);
    final tr = Tr.of(tester.element(find.byType(OcptProjectSettingsView)));

    await tester.tap(find.widgetWithText(OutlinedButton, tr.projectSettingsEpisodeAddAction));
    await tester.pumpAndSettle();

    expect(bloc.state.episodes.length, 2);
    expect(bloc.state.episodes.last.number, 2);
    expect(bloc.state.hasChanged, isTrue);
    final episodesInDatabase = await projectsManager.screenplayService.loadEpisodes(
      database: projectsManager.currentProject!.database,
    );
    expect(episodesInDatabase.length, 2);
  });

  testWidgets("renaming and renumbering an episode writes it to the project", (tester) async {
    final bloc = await pumpView(tester);
    final rowFields = inEpisodesSection(find.byType(TextField));

    await tester.enterText(rowFields.at(1), "Le départ");
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    await tester.enterText(rowFields.at(0), "5");
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(bloc.state.episodes.single.title, "Le départ");
    expect(bloc.state.episodes.single.number, 5);
    expect(bloc.state.hasChanged, isTrue);
    final episodesInDatabase = await projectsManager.screenplayService.loadEpisodes(
      database: projectsManager.currentProject!.database,
    );
    expect(episodesInDatabase.single.title, "Le départ");
    expect(episodesInDatabase.single.number, 5);
  });

  testWidgets("the up and down controls reorder episodes without renumbering them", (tester) async {
    final secondId = await addEpisode(title: "Les falaises");
    final bloc = await pumpView(tester);
    final firstId = bloc.state.episodes.first.id;
    expect(bloc.state.episodes.map((episode) => episode.id).toList(), [firstId, secondId]);

    final tr = Tr.of(tester.element(find.byType(OcptProjectSettingsView)));
    await tester.tap(find.byTooltip(tr.projectSettingsEpisodeMoveDownTooltip).first);
    await tester.pumpAndSettle();

    expect(bloc.state.episodes.map((episode) => episode.id).toList(), [secondId, firstId]);
    expect(bloc.state.hasChanged, isTrue);
    // `sortKey` alone changed — the printed numbers are untouched by a reorder.
    expect(bloc.state.episodes.firstWhere((episode) => episode.id == firstId).number, 1);
    expect(bloc.state.episodes.firstWhere((episode) => episode.id == secondId).number, 2);
  });

  testWidgets("the up control is withheld on the first row and the down control on the last", (
    tester,
  ) async {
    await addEpisode(title: "Les falaises");
    await pumpView(tester);
    final tr = Tr.of(tester.element(find.byType(OcptProjectSettingsView)));

    // `find.byTooltip` matches the `Tooltip` wrapping an `IconButton`, not the button itself, so
    // its own `onPressed` (null being exactly what "withheld" means here) is read off a widget
    // predicate instead.
    final upButtons = tester
        .widgetList<IconButton>(
          find.byWidgetPredicate(
            (widget) => widget is IconButton && widget.tooltip == tr.projectSettingsEpisodeMoveUpTooltip,
          ),
        )
        .toList();
    final downButtons = tester
        .widgetList<IconButton>(
          find.byWidgetPredicate(
            (widget) =>
                widget is IconButton && widget.tooltip == tr.projectSettingsEpisodeMoveDownTooltip,
          ),
        )
        .toList();

    expect(upButtons[0].onPressed, isNull);
    expect(upButtons[1].onPressed, isNotNull);
    expect(downButtons[0].onPressed, isNotNull);
    expect(downButtons[1].onPressed, isNull);
  });

  testWidgets("the delete action is withheld on a project holding a single episode", (
    tester,
  ) async {
    await pumpView(tester);
    final tr = Tr.of(tester.element(find.byType(OcptProjectSettingsView)));

    expect(find.byTooltip(tr.projectSettingsEpisodeDeleteTooltip), findsNothing);
  });

  testWidgets("deleting an episode asks for confirmation, then removes it", (tester) async {
    final secondId = await addEpisode(title: "Les falaises");
    final bloc = await pumpView(tester);
    final tr = Tr.of(tester.element(find.byType(OcptProjectSettingsView)));
    final firstEpisode = bloc.state.episodes.first;

    await tester.tap(find.byTooltip(tr.projectSettingsEpisodeDeleteTooltip).first);
    await tester.pumpAndSettle();

    expect(find.byType(OcptConfirmDialog), findsOneWidget);
    expect(
      find.text(
        tr.projectSettingsDeleteEpisodeConfirmTitle(ocptWorkspaceEpisodeLabelOf(tr, firstEpisode)),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text(tr.projectSettingsDeleteEpisodeConfirmDeleteAction));
    await tester.pumpAndSettle();

    expect(bloc.state.episodes.single.id, secondId);
    expect(bloc.state.hasChanged, isTrue);
    final episodesInDatabase = await projectsManager.screenplayService.loadEpisodes(
      database: projectsManager.currentProject!.database,
    );
    expect(episodesInDatabase.single.id, secondId);
  });

  testWidgets("cancelling the delete confirmation leaves the episode in place", (tester) async {
    await addEpisode(title: "Les falaises");
    final bloc = await pumpView(tester);
    final tr = Tr.of(tester.element(find.byType(OcptProjectSettingsView)));

    await tester.tap(find.byTooltip(tr.projectSettingsEpisodeDeleteTooltip).first);
    await tester.pumpAndSettle();

    await tester.tap(find.text(tr.projectSettingsDeleteEpisodeConfirmCancelAction));
    await tester.pumpAndSettle();

    expect(bloc.state.episodes.length, 2);
    expect(bloc.state.hasChanged, isFalse);
  });
}
