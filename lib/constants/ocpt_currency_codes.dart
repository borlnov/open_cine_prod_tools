// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// The ISO 4217 currency codes the project settings page's picker offers.
///
/// A short, curated list rather than every code `intl` knows about: these are the currencies a
/// short film shot with this app is actually likely to be budgeted in. Each code's symbol and
/// display name come from `intl`'s own `NumberFormat.simpleCurrency`, never from an ARB key — the
/// codes themselves are data, and `intl` already knows how to present them in every supported
/// locale.
const List<String> ocptCurrencyCodes = ["EUR", "USD", "GBP", "CHF", "CAD", "AUD", "JPY"];
