// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';
import 'dart:typed_data';

/// The table [_crc32] reduces one byte at a time against, built once.
final _crc32Table = List<int>.generate(256, (n) {
  var c = n;
  for (var k = 0; k < 8; k++) {
    c = (c & 1) != 0 ? (0xEDB88320 ^ (c >> 1)) : (c >> 1);
  }
  return c;
});

/// The CRC-32 of [bytes], as every PNG chunk trailer needs.
int _crc32(List<int> bytes) {
  var c = 0xFFFFFFFF;
  for (final b in bytes) {
    c = _crc32Table[(c ^ b) & 0xFF] ^ (c >> 8);
  }
  return c ^ 0xFFFFFFFF;
}

/// [value] as four big-endian bytes, the width every PNG chunk length and CRC field uses.
List<int> _uint32(int value) => [
  (value >> 24) & 0xFF,
  (value >> 16) & 0xFF,
  (value >> 8) & 0xFF,
  value & 0xFF,
];

/// One length-prefixed, CRC-terminated PNG chunk of [type] wrapping [data].
List<int> _pngChunk(String type, List<int> data) {
  final typeBytes = type.codeUnits;
  final out = BytesBuilder()
    ..add(_uint32(data.length))
    ..add(typeBytes)
    ..add(data)
    ..add(_uint32(_crc32([...typeBytes, ...data])));
  return out.toBytes();
}

/// Writes a plain two-tone placeholder PNG at [path]: [topColor] over most of the frame,
/// [bottomColor] along its bottom edge — legible enough as a storyboard frame or a floor-plan
/// underlay in a screenshot, encoded here from raw pixels so the seed script needs no binary asset
/// file of its own. Each call re-creates its file, exactly the "referenced by path, not embedded"
/// shape (ADR 0013) every other photo and document in the project follows — this is simply the
/// path's own source of truth instead of a file the repository carries.
Future<void> writePlaceholderImage({
  required String path,
  required int width,
  required int height,
  required int topColor,
  required int bottomColor,
}) async {
  final raw = BytesBuilder();
  for (var y = 0; y < height; y++) {
    raw.addByte(0); // no per-scanline filter
    final color = y < height * 0.85 ? topColor : bottomColor;
    final r = (color >> 16) & 0xFF;
    final g = (color >> 8) & 0xFF;
    final b = color & 0xFF;
    for (var x = 0; x < width; x++) {
      raw.addByte(r);
      raw.addByte(g);
      raw.addByte(b);
    }
  }

  final ihdr = BytesBuilder()
    ..add(_uint32(width))
    ..add(_uint32(height))
    ..addByte(8) // bit depth
    ..addByte(2) // colour type: truecolour (RGB)
    ..addByte(0)
    ..addByte(0)
    ..addByte(0);

  final png = BytesBuilder()
    ..add(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
    ..add(_pngChunk("IHDR", ihdr.toBytes()))
    ..add(_pngChunk("IDAT", ZLibEncoder().convert(raw.toBytes())))
    ..add(_pngChunk("IEND", const []));

  final file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsBytes(png.toBytes());
}
