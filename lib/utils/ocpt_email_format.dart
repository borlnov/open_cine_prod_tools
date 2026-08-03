// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// The shape an email address is checked against: something, an `@`, a domain with at least one
/// dot in it, and no whitespace anywhere.
///
/// Deliberately **not** RFC 5322: the full grammar accepts quoted local parts, comments and IP
/// literals that no production's address book has ever held, and implementing it would flag
/// nothing a person would recognise as a mistake. What this catches is what people actually
/// mistype — a missing `@`, a stray space, a truncated domain.
///
/// Requiring the dot is the one deliberate strictness: `clara@gmail` is far more often a
/// half-typed address than an intranet host, and the check is advisory anyway (see
/// [ocptEmailLooksWellFormed]).
final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s.]+(\.[^@\s.]+)+$');

/// Whether [value] looks like an email address, ignoring the whitespace around it.
///
/// **An empty [value] is well-formed**: no email address is a normal state in an address book, and
/// only a value somebody actually typed can be wrong.
///
/// This is a hint, never a gate. Every field of the person sheet autosaves as it is typed, so a
/// check that refused a write would refuse nearly every keystroke of a value being entered; the
/// value is always stored exactly as typed, and the UI flags it once the field loses the focus.
bool ocptEmailLooksWellFormed(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty || _emailPattern.hasMatch(trimmed);
}
