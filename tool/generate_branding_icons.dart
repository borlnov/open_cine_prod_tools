// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// Rasterizes the application mark held in `assets/branding/` into the PNG masters the launcher
/// icon generator (`dart run icons_launcher:create`) and the Debian packaging consume.
///
/// The mark is nothing but rounded rectangles, so it is rasterized here from its own geometry
/// rather than through an image toolchain: the icons can be regenerated on any machine with a Dart
/// SDK, with no ImageMagick/Inkscape to install and no hand-retouched binary to keep in sync with
/// the SVGs.
///
/// Run it from the repository root:
///
/// ```sh
/// dart run tool/generate_branding_icons.dart
/// ```
library;

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

/// The accent colour of the mark's container, the app's own `#6C5CE7` seed colour.
const _accentColor = _Rgb(0x6C, 0x5C, 0xE7);

/// The colour every shape drawn over the container wears.
const _markColor = _Rgb(0xFF, 0xFF, 0xFF);

/// The side of the square the mark is authored in, matching the SVGs' `76 76` viewBox.
const double _canvasUnits = 76;

/// The directory the generated masters are written to, relative to the repository root.
const _outputDirectoryPath = "assets/branding/icons";

/// The shapes the mark is made of, in the SVGs' own coordinates: three perforations on the left,
/// and the screenplay page on the right.
///
/// The page is a 4 unit wide stroke centred on its rectangle, so it is drawn as the ring between a
/// rectangle grown by half the stroke and one shrunk by the same amount.
const _marks = <_Shape>[
  _Fill(_RoundedRect(left: 15, top: 20, width: 9, height: 9, radius: 2)),
  _Fill(_RoundedRect(left: 15, top: 34, width: 9, height: 9, radius: 2)),
  _Fill(_RoundedRect(left: 15, top: 48, width: 9, height: 9, radius: 2)),
  _Stroke(_RoundedRect(left: 33, top: 20, width: 28, height: 37, radius: 4), strokeWidth: 4),
];

/// The bounding box of [_marks], stroke included: the box a container-less rendering fits into its
/// canvas.
const _marksBounds = _RoundedRect(left: 15, top: 18, width: 48, height: 41, radius: 0);

/// The share of an Android adaptive foreground layer's canvas the drawing may occupy: the system
/// masks that layer down to roughly its central two thirds, and animates it beyond that.
const double _adaptiveSafeFraction = 0.6;

/// The masters to generate.
///
/// The rounded, transparent-cornered master is what Windows, Android and macOS expect (each
/// platform applies its own masking, if any), and the 512 px one of the same kind is the Debian
/// package's `hicolor` icon. iOS gets a full-bleed opaque master instead: it rounds the icon itself
/// and rejects any transparency, so the container is stretched to the whole canvas there. The last
/// one is Android's adaptive foreground layer, drawn over an accent-coloured background layer, so
/// it carries the marks alone.
const _masters = <_MasterSpec>[
  _MasterSpec(fileName: "ocpt_icon_1024.png", sidePixels: 1024, style: _MarkStyle.rounded),
  _MasterSpec(fileName: "ocpt_icon_ios_1024.png", sidePixels: 1024, style: _MarkStyle.fullBleed),
  _MasterSpec(fileName: "ocpt_icon_512.png", sidePixels: 512, style: _MarkStyle.rounded),
  _MasterSpec(
    fileName: "ocpt_icon_adaptive_foreground_1024.png",
    sidePixels: 1024,
    style: _MarkStyle.marksOnly,
  ),
];

/// Rasterizes every entry of [_masters] and writes it under [_outputDirectoryPath].
void main() {
  final outputDirectory = Directory(_outputDirectoryPath)..createSync(recursive: true);

  for (final master in _masters) {
    final pixels = _renderMark(sidePixels: master.sidePixels, style: master.style);
    final file = File("${outputDirectory.path}/${master.fileName}");
    file.writeAsBytesSync(_encodePng(pixels: pixels, width: master.sidePixels));

    stdout.writeln("Wrote ${file.path} (${master.sidePixels}x${master.sidePixels})");
  }
}

/// Renders the mark in the given [style] into a straight (non premultiplied) RGBA buffer of
/// [sidePixels] squared.
Uint8List _renderMark({required int sidePixels, required _MarkStyle style}) {
  final container = switch (style) {
    _MarkStyle.rounded => const _RoundedRect(left: 4, top: 4, width: 68, height: 68, radius: 16),
    _MarkStyle.fullBleed => const _RoundedRect(
      left: 0,
      top: 0,
      width: _canvasUnits,
      height: _canvasUnits,
      radius: 0,
    ),
    _MarkStyle.marksOnly => null,
  };

  // The part of the mark's own coordinate space the canvas shows. Everything but the adaptive
  // foreground layer shows the whole authoring square; that one is zoomed and centred on the marks
  // instead, so they fill their safe area once the container is gone.
  final viewportSide = style == _MarkStyle.marksOnly
      ? _marksBounds.width / _adaptiveSafeFraction
      : _canvasUnits;
  final viewportLeft = style == _MarkStyle.marksOnly
      ? _marksBounds.left + _marksBounds.width / 2 - viewportSide / 2
      : 0.0;
  final viewportTop = style == _MarkStyle.marksOnly
      ? _marksBounds.top + _marksBounds.height / 2 - viewportSide / 2
      : 0.0;

  final unitsPerPixel = viewportSide / sidePixels;
  final pixels = Uint8List(sidePixels * sidePixels * 4);

  for (var row = 0; row < sidePixels; row++) {
    // Sampled at the centre of the pixel, the only point whose distance to a shape says how much
    // of that pixel the shape covers.
    final y = viewportTop + (row + 0.5) * unitsPerPixel;

    for (var column = 0; column < sidePixels; column++) {
      final x = viewportLeft + (column + 0.5) * unitsPerPixel;

      // Premultiplied accumulation, so an antialiased mark laid over an antialiased container
      // edge keeps both coverages instead of the topmost one alone.
      var red = 0.0;
      var green = 0.0;
      var blue = 0.0;
      var alpha = 0.0;

      void paint(double coverage, _Rgb color) {
        if (coverage <= 0) {
          return;
        }

        red = color.red / 255 * coverage + red * (1 - coverage);
        green = color.green / 255 * coverage + green * (1 - coverage);
        blue = color.blue / 255 * coverage + blue * (1 - coverage);
        alpha = coverage + alpha * (1 - coverage);
      }

      if (container != null) {
        paint(_coverageOf(container.distanceTo(x, y), unitsPerPixel), _accentColor);
      }

      for (final mark in _marks) {
        paint(_coverageOf(mark.distanceTo(x, y), unitsPerPixel), _markColor);
      }

      final offset = (row * sidePixels + column) * 4;
      // Back to straight alpha, the layout the PNG encoder below writes out.
      pixels[offset] = _toByte(alpha > 0 ? red / alpha : 0);
      pixels[offset + 1] = _toByte(alpha > 0 ? green / alpha : 0);
      pixels[offset + 2] = _toByte(alpha > 0 ? blue / alpha : 0);
      pixels[offset + 3] = _toByte(alpha);
    }
  }

  return pixels;
}

/// Turns the signed [distance] of a pixel centre to a shape's edge, in mark units, into how much
/// of that pixel the shape covers, antialiasing the edge over the width of one pixel
/// ([unitsPerPixel]).
double _coverageOf(double distance, double unitsPerPixel) =>
    (0.5 - distance / unitsPerPixel).clamp(0, 1);

/// Converts a 0..1 channel value into the 0..255 byte a PNG holds.
int _toByte(double value) => (value * 255).round().clamp(0, 255);

/// A shape of the mark, able to tell how far a point is from its edge (negative inside).
sealed class _Shape {
  /// Class constructor
  const _Shape();

  /// Returns the signed distance from the point ([x], [y]) to this shape's edge, in mark units.
  double distanceTo(double x, double y);
}

/// A filled rounded rectangle.
class _Fill extends _Shape {
  /// The filled rectangle.
  final _RoundedRect rect;

  /// Class constructor
  const _Fill(this.rect);

  @override
  double distanceTo(double x, double y) => rect.distanceTo(x, y);
}

/// The outline of a rounded rectangle, [strokeWidth] wide and centred on its edge.
class _Stroke extends _Shape {
  /// The stroked rectangle.
  final _RoundedRect rect;

  /// The width of the stroke, in mark units.
  final double strokeWidth;

  /// Class constructor
  const _Stroke(this.rect, {required this.strokeWidth});

  @override
  double distanceTo(double x, double y) => rect.distanceTo(x, y).abs() - strokeWidth / 2;
}

/// A rounded rectangle of the mark, in the SVGs' `76 76` coordinates.
class _RoundedRect {
  /// The distance from the left edge of the canvas.
  final double left;

  /// The distance from the top edge of the canvas.
  final double top;

  /// The width of the rectangle.
  final double width;

  /// The height of the rectangle.
  final double height;

  /// The radius of the four corners.
  final double radius;

  /// Class constructor
  const _RoundedRect({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.radius,
  });

  /// Returns the signed distance from the point ([x], [y]) to this rectangle's edge, negative
  /// inside it and positive outside.
  double distanceTo(double x, double y) {
    final offsetX = (x - (left + width / 2)).abs() - (width / 2 - radius);
    final offsetY = (y - (top + height / 2)).abs() - (height / 2 - radius);

    final outside = sqrt(pow(max(offsetX, 0), 2) + pow(max(offsetY, 0), 2));
    final inside = min(max(offsetX, offsetY), 0);

    return outside + inside - radius;
  }
}

/// A straight 24 bit colour of the mark.
class _Rgb {
  /// The red channel, 0..255.
  final int red;

  /// The green channel, 0..255.
  final int green;

  /// The blue channel, 0..255.
  final int blue;

  /// Class constructor
  const _Rgb(this.red, this.green, this.blue);
}

/// How a master draws the mark.
enum _MarkStyle {
  /// The SVGs' own drawing: the inset rounded square, with fully transparent corners around it.
  rounded,

  /// The same drawing with its container stretched to the whole canvas, square-cornered and
  /// therefore fully opaque.
  fullBleed,

  /// The marks alone, without their container, zoomed and centred on the canvas.
  marksOnly,
}

/// One PNG master to generate.
class _MasterSpec {
  /// The name of the file written under [_outputDirectoryPath].
  final String fileName;

  /// The side of the square image, in pixels.
  final int sidePixels;

  /// How the mark is drawn on that image.
  final _MarkStyle style;

  /// Class constructor
  const _MasterSpec({required this.fileName, required this.sidePixels, required this.style});
}

/// Encodes a straight RGBA [pixels] buffer of [width] squared into an 8 bit RGBA PNG.
Uint8List _encodePng({required Uint8List pixels, required int width}) {
  // One filter byte (0, "no filter") in front of every row of the image.
  final raw = Uint8List(width * (width * 4 + 1));
  for (var row = 0; row < width; row++) {
    final rawOffset = row * (width * 4 + 1);
    raw[rawOffset] = 0;
    raw.setRange(rawOffset + 1, rawOffset + 1 + width * 4, pixels, row * width * 4);
  }

  final header = Uint8List(13);
  final headerView = ByteData.view(header.buffer);
  headerView.setUint32(0, width);
  headerView.setUint32(4, width);
  header[8] = 8; // Bit depth.
  header[9] = 6; // Colour type: truecolour with alpha.
  header[10] = 0; // Compression method: deflate.
  header[11] = 0; // Filter method: adaptive.
  header[12] = 0; // Interlace method: none.

  return Uint8List.fromList([
    // The PNG signature.
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
    ..._pngChunk("IHDR", header),
    ..._pngChunk("IDAT", Uint8List.fromList(ZLibCodec().encode(raw))),
    ..._pngChunk("IEND", Uint8List(0)),
  ]);
}

/// Builds one PNG chunk: the length of [data], its four letter [type], [data] itself, and the
/// CRC-32 of the two last fields.
List<int> _pngChunk(String type, Uint8List data) {
  final typeAndData = <int>[...type.codeUnits, ...data];

  final length = Uint8List(4);
  ByteData.view(length.buffer).setUint32(0, data.length);

  final crc = Uint8List(4);
  ByteData.view(crc.buffer).setUint32(0, _crc32(typeAndData));

  return [...length, ...typeAndData, ...crc];
}

/// The lazily built lookup table of [_crc32].
final _crc32Table = List<int>.generate(256, (index) {
  var value = index;
  for (var bit = 0; bit < 8; bit++) {
    value = (value & 1) != 0 ? 0xEDB88320 ^ (value >> 1) : value >> 1;
  }

  return value;
});

/// Returns the CRC-32 of [bytes], the checksum every PNG chunk ends with.
int _crc32(List<int> bytes) {
  var crc = 0xFFFFFFFF;
  for (final byte in bytes) {
    crc = _crc32Table[(crc ^ byte) & 0xFF] ^ (crc >> 8);
  }

  return crc ^ 0xFFFFFFFF;
}
