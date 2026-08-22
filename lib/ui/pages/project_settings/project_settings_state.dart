// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_mileage_rate.dart';
import 'package:open_cine_prod_tools/models/ocpt_episode.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/types/ocpt_screenplay_language.dart';

/// The state of `OcptProjectSettingsBloc`.
class OcptProjectSettingsState extends BlocStateForMixin<OcptProjectSettingsState> {
  /// Whether the project's currency and page format are still being loaded from the database.
  final bool isLoading;

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

  /// The current project's price of one snack, in cents (`project_info.snackPriceCents`), or null
  /// while nobody has recorded one.
  final int? snackPriceCents;

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
    required this.currencyCode,
    required this.pageFormat,
    required this.minimumRestMinutes,
    required this.defaultVatRateBasisPoints,
    required this.mealPriceCents,
    required this.snackPriceCents,
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
      currencyCode = "",
      pageFormat = OcptPageFormat.usLetter,
      minimumRestMinutes = null,
      defaultVatRateBasisPoints = null,
      mealPriceCents = null,
      snackPriceCents = null,
      screenplayLanguage = null,
      episodes = const [],
      mileageRates = const [],
      dictionaryWords = const [],
      hasChanged = false;

  /// {@macro act_flutter_utility.BlocStateForMixin.copyWith}
  ///
  /// [minimumRestMinutes] legitimately goes back to null while the page is open (the field is
  /// cleared), so it has its own [clearMinimumRestMinutes] flag rather than a bare nullable
  /// parameter, which could never tell "leave it alone" apart from "clear it".
  /// [screenplayLanguage] carries exactly the same problem — picking "None" in the dropdown is as
  /// real a gesture as clearing the rest field is — so it gets the same treatment,
  /// [clearScreenplayLanguage]. [defaultVatRateBasisPoints], [mealPriceCents] and [snackPriceCents]
  /// all get the identical treatment for the identical reason, one clearing flag each.
  @override
  OcptProjectSettingsState copyWith({
    bool? isLoading,
    String? currencyCode,
    OcptPageFormat? pageFormat,
    int? minimumRestMinutes,
    bool clearMinimumRestMinutes = false,
    int? defaultVatRateBasisPoints,
    bool clearDefaultVatRateBasisPoints = false,
    int? mealPriceCents,
    bool clearMealPriceCents = false,
    int? snackPriceCents,
    bool clearSnackPriceCents = false,
    OcptScreenplayLanguage? screenplayLanguage,
    bool clearScreenplayLanguage = false,
    List<OcptEpisode>? episodes,
    List<OcptBudgetMileageRate>? mileageRates,
    List<String>? dictionaryWords,
    bool? hasChanged,
  }) => OcptProjectSettingsState(
    isLoading: isLoading ?? this.isLoading,
    currencyCode: currencyCode ?? this.currencyCode,
    pageFormat: pageFormat ?? this.pageFormat,
    minimumRestMinutes: clearMinimumRestMinutes
        ? null
        : (minimumRestMinutes ?? this.minimumRestMinutes),
    defaultVatRateBasisPoints: clearDefaultVatRateBasisPoints
        ? null
        : (defaultVatRateBasisPoints ?? this.defaultVatRateBasisPoints),
    mealPriceCents: clearMealPriceCents ? null : (mealPriceCents ?? this.mealPriceCents),
    snackPriceCents: clearSnackPriceCents ? null : (snackPriceCents ?? this.snackPriceCents),
    screenplayLanguage: clearScreenplayLanguage
        ? null
        : (screenplayLanguage ?? this.screenplayLanguage),
    episodes: episodes ?? this.episodes,
    mileageRates: mileageRates ?? this.mileageRates,
    dictionaryWords: dictionaryWords ?? this.dictionaryWords,
    hasChanged: hasChanged ?? this.hasChanged,
  );

  /// {@macro act_flutter_utility.BlocStateForMixin.props}
  @override
  List<Object?> get props => [
    ...super.props,
    isLoading,
    currencyCode,
    pageFormat,
    minimumRestMinutes,
    defaultVatRateBasisPoints,
    mealPriceCents,
    snackPriceCents,
    screenplayLanguage,
    episodes,
    mileageRates,
    dictionaryWords,
    hasChanged,
  ];
}
