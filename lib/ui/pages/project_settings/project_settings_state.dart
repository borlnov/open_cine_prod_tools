// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_mileage_rate.dart';
import 'package:open_cine_prod_tools/models/ocpt_episode.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_move_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_screenplay_language.dart';

/// The state of `OcptProjectSettingsBloc`.
class OcptProjectSettingsState extends BlocStateForMixin<OcptProjectSettingsState> {
  /// Whether the project's currency and page format are still being loaded from the database.
  final bool isLoading;

  /// The absolute path to the currently open project's file, shown by the `Project file` card.
  final String projectFilePath;

  /// Whether the `Project file` card's own `Show in folder` action is offered — withheld only on
  /// mobile, where there is no such affordance (`OcptExportManager.isMobile`); the path itself is
  /// still shown there.
  final bool isShowInFolderAvailable;

  /// Whether the `Project file` card's own `Move…` action is offered — withheld on mobile (no
  /// native save-file dialog there) and while [isMoveWithheldByHosting] is true. Never true while
  /// the open project sits under a read-only version preview either, though the page that reaches
  /// this one is never shown at all in that state.
  final bool isMoveAvailable;

  /// Whether [isMoveAvailable] is false specifically because an in-app-hosted relay currently holds
  /// this project's `.relay.sqlite` sidecar open — the one case among [isMoveAvailable]'s reasons
  /// the card explains with a hint, since the other two (mobile, preview) are the ordinary
  /// affordance-withheld shape the rest of the app already uses with no explanation at all.
  final bool isMoveWithheldByHosting;

  /// Whether the last `Show in folder` could not open the folder, until the page has said so — see
  /// `OcptProjectSettingsShowInFolderFailureDismissedEvent`.
  final bool isShowInFolderFailed;

  /// The status of the last `Move…` attempt that failed, or null once the page has shown it — see
  /// `OcptProjectSettingsMoveErrorDismissedEvent`.
  final OcptProjectMoveStatus? moveError;

  /// The current project's currency, as an ISO 4217 code.
  final String currencyCode;

  /// The current project's page format.
  final OcptPageFormat pageFormat;

  /// The current project's minimum rest between two shooting days, in minutes
  /// (`project_info.minimumRestMinutes`), or null while nobody has recorded one.
  final int? minimumRestMinutes;

  /// The current project's default VAT rate, in basis points
  /// (`project_info.defaultVatRateBasisPoints`), or null while nobody has recorded one.
  final int? defaultVatRateBasisPoints;

  /// The current project's price of one meal, in cents (`project_info.mealPriceCents`), or null
  /// while nobody has recorded one.
  final int? mealPriceCents;

  /// The current project's price of the buffet, in cents (`project_info.snackPriceCents` — the
  /// column keeps the schema's own name, though what it prices is the buffet, not a snack, in the
  /// trade's own words), or null while nobody has recorded one.
  final int? buffetPriceCents;

  /// The current project's screenplay language (`project_info.screenplayLanguage`), or null while
  /// nobody has recorded one.
  final OcptScreenplayLanguage? screenplayLanguage;

  /// The project's live episodes, in `sortKey` order — what the `Episodes` card lists, re-read
  /// after every mutation it makes so the card always shows what the database holds.
  final List<OcptEpisode> episodes;

  /// The project's own mileage rates (`budget_mileage_rates`), in `sortKey` order — what the
  /// `Mileage rates` card lists, re-read after every mutation it makes so the card always shows
  /// what the database holds. Empty on a fresh project: nothing seeds it
  /// (`OcptBudgetFinancingService`'s own doc comment).
  final List<OcptBudgetMileageRate> mileageRates;

  /// The project's currently learned words (`project_dictionary_words`, tombstones filtered out),
  /// sorted case-insensitively — what the dictionary section's count line and
  /// `OcptProjectDictionaryDialog` both read, re-read after every edit the dialog reports so the
  /// section always shows what the database holds.
  final List<String> dictionaryWords;

  /// Whether at least one field was changed since the page opened.
  ///
  /// This is what the page hands back to whichever mode pushed it, through
  /// `OcptRouterManager.pop<bool>`, so that mode knows whether it is worth reloading anything of
  /// its own (the screenplay repaginating on a page-format change, say) — every field here writes
  /// the moment it changes, so there is nothing left to flush on the way out. **The schedule mode
  /// depends on this flag for [minimumRestMinutes] specifically**: it re-reads the project's own
  /// minimum on `OcptScheduleProjectSettingsChangedEvent`, which fires exactly when this page pops
  /// with `hasChanged` true, so a rest-minimum edit that failed to set it would leave the rest-time
  /// alert stale until the next full load.
  final bool hasChanged;

  /// Class constructor
  const OcptProjectSettingsState({
    required this.isLoading,
    required this.projectFilePath,
    required this.isShowInFolderAvailable,
    required this.isMoveAvailable,
    required this.isMoveWithheldByHosting,
    this.isShowInFolderFailed = false,
    this.moveError,
    required this.currencyCode,
    required this.pageFormat,
    required this.minimumRestMinutes,
    required this.defaultVatRateBasisPoints,
    required this.mealPriceCents,
    required this.buffetPriceCents,
    required this.screenplayLanguage,
    required this.episodes,
    required this.mileageRates,
    required this.dictionaryWords,
    required this.hasChanged,
  });

  /// The initial state, shown for the brief moment before the load completes: [currencyCode] and
  /// [pageFormat] are placeholders never actually rendered, since the page shows a spinner while
  /// [isLoading].
  const OcptProjectSettingsState.init()
    : isLoading = true,
      projectFilePath = "",
      isShowInFolderAvailable = false,
      isMoveAvailable = false,
      isMoveWithheldByHosting = false,
      isShowInFolderFailed = false,
      moveError = null,
      currencyCode = "",
      pageFormat = OcptPageFormat.usLetter,
      minimumRestMinutes = null,
      defaultVatRateBasisPoints = null,
      mealPriceCents = null,
      buffetPriceCents = null,
      screenplayLanguage = null,
      episodes = const [],
      mileageRates = const [],
      dictionaryWords = const [],
      hasChanged = false;

  /// {@macro act_flutter_utility.BlocStateForMixin.copyWith}
  ///
  /// [minimumRestMinutes] legitimately goes back to null while the page is open (the field is
  /// cleared), so it has its own [forceMinimumRestMinutesValue] flag rather than a bare nullable
  /// parameter, which could never tell "leave it alone" apart from "clear it". [screenplayLanguage]
  /// carries exactly the same problem — picking "None" in the dropdown is as real a gesture as
  /// clearing the rest field is — so it gets the same treatment, [forceScreenplayLanguageValue].
  /// [defaultVatRateBasisPoints], [mealPriceCents] and [buffetPriceCents] all get the identical
  /// treatment for the identical reason, one force flag each.
  @override
  OcptProjectSettingsState copyWith({
    bool? isLoading,
    String? projectFilePath,
    bool? isShowInFolderAvailable,
    bool? isMoveAvailable,
    bool? isMoveWithheldByHosting,
    bool? isShowInFolderFailed,
    OcptProjectMoveStatus? moveError,
    bool forceMoveErrorValue = false,
    String? currencyCode,
    OcptPageFormat? pageFormat,
    int? minimumRestMinutes,
    bool forceMinimumRestMinutesValue = false,
    int? defaultVatRateBasisPoints,
    bool forceDefaultVatRateBasisPointsValue = false,
    int? mealPriceCents,
    bool forceMealPriceCentsValue = false,
    int? buffetPriceCents,
    bool forceBuffetPriceCentsValue = false,
    OcptScreenplayLanguage? screenplayLanguage,
    bool forceScreenplayLanguageValue = false,
    List<OcptEpisode>? episodes,
    List<OcptBudgetMileageRate>? mileageRates,
    List<String>? dictionaryWords,
    bool? hasChanged,
  }) => OcptProjectSettingsState(
    isLoading: isLoading ?? this.isLoading,
    projectFilePath: projectFilePath ?? this.projectFilePath,
    isShowInFolderAvailable: isShowInFolderAvailable ?? this.isShowInFolderAvailable,
    isMoveAvailable: isMoveAvailable ?? this.isMoveAvailable,
    isMoveWithheldByHosting: isMoveWithheldByHosting ?? this.isMoveWithheldByHosting,
    isShowInFolderFailed: isShowInFolderFailed ?? this.isShowInFolderFailed,
    moveError: moveError ?? (forceMoveErrorValue ? null : this.moveError),
    currencyCode: currencyCode ?? this.currencyCode,
    pageFormat: pageFormat ?? this.pageFormat,
    minimumRestMinutes:
        minimumRestMinutes ?? (forceMinimumRestMinutesValue ? null : this.minimumRestMinutes),
    defaultVatRateBasisPoints:
        defaultVatRateBasisPoints ??
        (forceDefaultVatRateBasisPointsValue ? null : this.defaultVatRateBasisPoints),
    mealPriceCents: mealPriceCents ?? (forceMealPriceCentsValue ? null : this.mealPriceCents),
    buffetPriceCents:
        buffetPriceCents ?? (forceBuffetPriceCentsValue ? null : this.buffetPriceCents),
    screenplayLanguage:
        screenplayLanguage ?? (forceScreenplayLanguageValue ? null : this.screenplayLanguage),
    episodes: episodes ?? this.episodes,
    mileageRates: mileageRates ?? this.mileageRates,
    dictionaryWords: dictionaryWords ?? this.dictionaryWords,
    hasChanged: hasChanged ?? this.hasChanged,
  );

  /// Copy this state as loaded with the project's file location and settings.
  OcptProjectSettingsState copyToLoaded({
    required String projectFilePath,
    required bool isShowInFolderAvailable,
    required bool isMoveAvailable,
    required bool isMoveWithheldByHosting,
    required String currencyCode,
    required OcptPageFormat pageFormat,
    required int? minimumRestMinutes,
    required int? defaultVatRateBasisPoints,
    required int? mealPriceCents,
    required int? buffetPriceCents,
    required OcptScreenplayLanguage? screenplayLanguage,
    required List<OcptEpisode> episodes,
    required List<OcptBudgetMileageRate> mileageRates,
    required List<String> dictionaryWords,
  }) => copyWith(
    isLoading: false,
    projectFilePath: projectFilePath,
    isShowInFolderAvailable: isShowInFolderAvailable,
    isMoveAvailable: isMoveAvailable,
    isMoveWithheldByHosting: isMoveWithheldByHosting,
    currencyCode: currencyCode,
    pageFormat: pageFormat,
    minimumRestMinutes: minimumRestMinutes,
    forceMinimumRestMinutesValue: minimumRestMinutes == null,
    defaultVatRateBasisPoints: defaultVatRateBasisPoints,
    forceDefaultVatRateBasisPointsValue: defaultVatRateBasisPoints == null,
    mealPriceCents: mealPriceCents,
    forceMealPriceCentsValue: mealPriceCents == null,
    buffetPriceCents: buffetPriceCents,
    forceBuffetPriceCentsValue: buffetPriceCents == null,
    screenplayLanguage: screenplayLanguage,
    forceScreenplayLanguageValue: screenplayLanguage == null,
    episodes: episodes,
    mileageRates: mileageRates,
    dictionaryWords: dictionaryWords,
  );

  /// Copy this state with the failure to show the file in its folder flagged.
  OcptProjectSettingsState copyWithShowInFolderFailed() => copyWith(isShowInFolderFailed: true);

  /// Copy this state with the show-in-folder failure dismissed.
  OcptProjectSettingsState copyWithShowInFolderFailureDismissed() =>
      copyWith(isShowInFolderFailed: false);

  /// Copy this state with the failed move reported through [moveError].
  OcptProjectSettingsState copyWithMoveError({required OcptProjectMoveStatus moveError}) =>
      copyWith(moveError: moveError);

  /// Copy this state with the project file now at [projectFilePath] and any move error cleared.
  OcptProjectSettingsState copyWithMoved({required String projectFilePath}) =>
      copyWith(projectFilePath: projectFilePath, forceMoveErrorValue: true);

  /// Copy this state with the move error dismissed.
  OcptProjectSettingsState copyWithMoveErrorDismissed() => copyWith(forceMoveErrorValue: true);

  /// Copy this state with the project's [currencyCode] edited.
  OcptProjectSettingsState copyWithCurrencyCode({required String currencyCode}) =>
      copyWith(currencyCode: currencyCode, hasChanged: true);

  /// Copy this state with the project's [pageFormat] edited.
  OcptProjectSettingsState copyWithPageFormat({required OcptPageFormat pageFormat}) =>
      copyWith(pageFormat: pageFormat, hasChanged: true);

  /// Copy this state with the minimum rest between two days edited, null when unset.
  OcptProjectSettingsState copyWithMinimumRestMinutes({required int? minimumRestMinutes}) =>
      copyWith(
        minimumRestMinutes: minimumRestMinutes,
        forceMinimumRestMinutesValue: minimumRestMinutes == null,
        hasChanged: true,
      );

  /// Copy this state with the default VAT rate edited, null when unset.
  OcptProjectSettingsState copyWithDefaultVatRate({required int? defaultVatRateBasisPoints}) =>
      copyWith(
        defaultVatRateBasisPoints: defaultVatRateBasisPoints,
        forceDefaultVatRateBasisPointsValue: defaultVatRateBasisPoints == null,
        hasChanged: true,
      );

  /// Copy this state with the price of a meal edited, null when unset.
  OcptProjectSettingsState copyWithMealPrice({required int? mealPriceCents}) => copyWith(
    mealPriceCents: mealPriceCents,
    forceMealPriceCentsValue: mealPriceCents == null,
    hasChanged: true,
  );

  /// Copy this state with the price of a buffet edited, null when unset.
  OcptProjectSettingsState copyWithBuffetPrice({required int? buffetPriceCents}) => copyWith(
    buffetPriceCents: buffetPriceCents,
    forceBuffetPriceCentsValue: buffetPriceCents == null,
    hasChanged: true,
  );

  /// Copy this state with the screenplay language edited, null when unset.
  OcptProjectSettingsState copyWithScreenplayLanguage({
    required OcptScreenplayLanguage? screenplayLanguage,
  }) => copyWith(
    screenplayLanguage: screenplayLanguage,
    forceScreenplayLanguageValue: screenplayLanguage == null,
    hasChanged: true,
  );

  /// Copy this state with the project dictionary's [dictionaryWords] edited.
  OcptProjectSettingsState copyWithDictionaryWords({required List<String> dictionaryWords}) =>
      copyWith(dictionaryWords: dictionaryWords, hasChanged: true);

  /// Copy this state with the [episodes] read again after an episode was added, which counts as
  /// a change only when [isAdded].
  OcptProjectSettingsState copyWithEpisodeAdded({
    required List<OcptEpisode> episodes,
    required bool isAdded,
  }) => copyWith(episodes: episodes, hasChanged: isAdded ? true : null);

  /// Copy this state with the [episodes] read again after an episode was deleted, which counts
  /// as a change only when [isDeleted].
  OcptProjectSettingsState copyWithEpisodeDeleted({
    required List<OcptEpisode> episodes,
    required bool isDeleted,
  }) => copyWith(episodes: episodes, hasChanged: isDeleted ? true : null);

  /// Copy this state with the [episodes] read again after one was edited or moved.
  OcptProjectSettingsState copyWithEpisodesChanged({required List<OcptEpisode> episodes}) =>
      copyWith(episodes: episodes, hasChanged: true);

  /// Copy this state with the [mileageRates] read again after a rate was added, which counts as a
  /// change only when [isAdded].
  OcptProjectSettingsState copyWithMileageRateAdded({
    required List<OcptBudgetMileageRate> mileageRates,
    required bool isAdded,
  }) => copyWith(mileageRates: mileageRates, hasChanged: isAdded ? true : null);

  /// Copy this state with the [mileageRates] read again after one was edited or deleted.
  OcptProjectSettingsState copyWithMileageRatesChanged({
    required List<OcptBudgetMileageRate> mileageRates,
  }) => copyWith(mileageRates: mileageRates, hasChanged: true);

  /// {@macro act_flutter_utility.BlocStateForMixin.props}
  @override
  List<Object?> get props => [
    ...super.props,
    isLoading,
    projectFilePath,
    isShowInFolderAvailable,
    isMoveAvailable,
    isMoveWithheldByHosting,
    isShowInFolderFailed,
    moveError,
    currencyCode,
    pageFormat,
    minimumRestMinutes,
    defaultVatRateBasisPoints,
    mealPriceCents,
    buffetPriceCents,
    screenplayLanguage,
    episodes,
    mileageRates,
    dictionaryWords,
    hasChanged,
  ];
}
