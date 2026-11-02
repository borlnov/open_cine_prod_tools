// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_asset_ref.dart';
import 'package:open_cine_prod_tools/types/ocpt_asset_kind.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_location_sheet_photos_card.dart';

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve.
Widget _wrapInApp(Widget child) => MaterialApp(
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: Scaffold(body: SizedBox(width: 900, height: 900, child: child)),
);

/// A scouting photo of the location, referencing [path].
OcptAssetRef _photo(String id, String path) => OcptAssetRef(
  id: id,
  kind: OcptAssetKind.locationPhoto,
  path: path,
  label: "",
  addedAt: DateTime(2026),
  personId: null,
  locationId: "location-1",
  elementId: null,
  validFrom: null,
  validUntil: null,
);

/// Find the photo tiles of the card, which are private to its file.
Finder _tiles() =>
    find.byWidgetPredicate((widget) => widget.runtimeType.toString() == "_OcptPhotoTile");

/// Get the state of the tile showing the photo whose path is [path].
State _stateOfTileShowing(WidgetTester tester, String path) {
  final tile = find.ancestor(of: find.byTooltip(path), matching: _tiles());

  return (tester.element(tile) as StatefulElement).state;
}

void main() {
  testWidgets("removing a photo leaves the other tiles on their own state", (tester) async {
    final first = _photo("photo-1", "/missing/first.jpg");
    final second = _photo("photo-2", "/missing/second.jpg");
    final third = _photo("photo-3", "/missing/third.jpg");

    Widget card(List<OcptAssetRef> photos) => _wrapInApp(
      OcptLocationSheetPhotosCard(
        photos: photos,
        onPhotoAddRequested: null,
        onPhotoRemoved: (_) {},
      ),
    );

    await tester.pumpWidget(card([first, second, third]));
    final secondState = _stateOfTileShowing(tester, second.path);
    final thirdState = _stateOfTileShowing(tester, third.path);

    await tester.pumpWidget(card([second, third]));

    expect(_tiles(), findsNWidgets(2));
    expect(find.byTooltip(first.path), findsNothing);
    expect(_stateOfTileShowing(tester, second.path), same(secondState));
    expect(_stateOfTileShowing(tester, third.path), same(thirdState));
  });
}
