import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:lume/src/rust/api/image_ops.dart' as rust;

/// Immutable image wrapper with a fluent API for chaining operations.
///
/// Every mutation returns a **new** [LumeImage] — the original is never
/// modified, so you can branch pipelines freely.
///
/// ```dart
/// final result = LumeImage.fromFile(file)
///   .resize(width: 800, height: 600)
///   .grayscale()
///   .blur(sigma: 1.5)
///   .bytes;
/// ```
class LumeImage {
  final Uint8List _bytes;

  const LumeImage._(this._bytes);

  // -------------------------------------------------------------------------
  // Factories / Constructors
  // -------------------------------------------------------------------------

  /// Create from raw encoded bytes (png, jpeg, webp, etc.).
  factory LumeImage.fromBytes(Uint8List bytes) => LumeImage._(bytes);

  /// Create by reading a [File] synchronously.
  factory LumeImage.fromFile(File file) => LumeImage._(file.readAsBytesSync());

  /// Create by reading a [File] asynchronously.
  static Future<LumeImage> fromFileAsync(File file) async =>
      LumeImage._(await file.readAsBytes());

  /// Create from a file path string.
  factory LumeImage.fromPath(String path) => LumeImage.fromFile(File(path));

  /// Create from a file path string asynchronously.
  static Future<LumeImage> fromPathAsync(String path) =>
      LumeImage.fromFileAsync(File(path));

  /// Create from a Flutter asset (e.g. `'assets/images/photo.png'`).
  static Future<LumeImage> fromAsset(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    return LumeImage._(data.buffer.asUint8List());
  }

  /// Create a blank image filled with a solid color.
  factory LumeImage.blank({
    required int width,
    required int height,
    int r = 0,
    int g = 0,
    int b = 0,
    int a = 255,
  }) => LumeImage._(
    rust.createBlank(width: width, height: height, r: r, g: g, b: b, a: a),
  );

  /// Create from another [LumeImage] (explicit copy).
  factory LumeImage.from(LumeImage other) =>
      LumeImage._(Uint8List.fromList(other._bytes));

  // -------------------------------------------------------------------------
  // Accessors
  // -------------------------------------------------------------------------

  /// The raw encoded bytes.
  Uint8List get bytes => _bytes;

  /// Image metadata (width, height, format, size in bytes).
  rust.LumeImageInfo get info => rust.getImageInfo(imageBytes: _bytes);

  /// Shorthand for [info.width].
  int get width => info.width;

  /// Shorthand for [info.height].
  int get height => info.height;

  /// Shorthand for [info.format].
  String get format => info.format;

  /// Size in bytes of the encoded data.
  int get sizeBytes => _bytes.length;

  // -------------------------------------------------------------------------
  // Resize
  // -------------------------------------------------------------------------

  /// Resize keeping aspect ratio by default.
  LumeImage resize({
    required int width,
    required int height,
    bool keepAspectRatio = true,
  }) => LumeImage._(
    rust.resize(
      imageBytes: _bytes,
      width: width,
      height: height,
      keepAspectRatio: keepAspectRatio,
    ),
  );

  /// Resize with a specific filter algorithm.
  ///
  /// [filter]: `nearest`, `bilinear`, `cubic`, `gaussian`, `lanczos3`.
  LumeImage resizeWithFilter({
    required int width,
    required int height,
    required String filter,
  }) => LumeImage._(
    rust.resizeWithFilter(
      imageBytes: _bytes,
      width: width,
      height: height,
      filter: filter,
    ),
  );

  /// Fast thumbnail that fits inside [maxWidth]×[maxHeight].
  LumeImage thumbnail({required int maxWidth, required int maxHeight}) =>
      LumeImage._(
        rust.thumbnail(
          imageBytes: _bytes,
          maxWidth: maxWidth,
          maxHeight: maxHeight,
        ),
      );

  /// Exact-size thumbnail (may distort).
  LumeImage thumbnailExact({required int width, required int height}) =>
      LumeImage._(
        rust.thumbnailExact(imageBytes: _bytes, width: width, height: height),
      );

  // -------------------------------------------------------------------------
  // Crop
  // -------------------------------------------------------------------------

  /// Crop a rectangular region starting at ([x], [y]).
  LumeImage crop({
    required int x,
    required int y,
    required int width,
    required int height,
  }) => LumeImage._(
    rust.crop(imageBytes: _bytes, x: x, y: y, width: width, height: height),
  );

  // -------------------------------------------------------------------------
  // Rotate & Flip
  // -------------------------------------------------------------------------

  /// Rotate by [degrees] (must be a multiple of 90).
  LumeImage rotate({required int degrees}) =>
      LumeImage._(rust.rotate(imageBytes: _bytes, degrees: degrees));

  /// Flip horizontally.
  LumeImage flipHorizontal() =>
      LumeImage._(rust.flipHorizontal(imageBytes: _bytes));

  /// Flip vertically.
  LumeImage flipVertical() =>
      LumeImage._(rust.flipVertical(imageBytes: _bytes));

  // -------------------------------------------------------------------------
  // Color / filter operations
  // -------------------------------------------------------------------------

  /// Convert to grayscale.
  LumeImage grayscale() => LumeImage._(rust.grayscale(imageBytes: _bytes));

  /// Adjust brightness. Positive brightens, negative darkens.
  LumeImage adjustBrightness(int value) =>
      LumeImage._(rust.adjustBrightness(imageBytes: _bytes, value: value));

  /// Adjust contrast.
  LumeImage adjustContrast(double value) =>
      LumeImage._(rust.adjustContrast(imageBytes: _bytes, value: value));

  /// Gaussian blur.
  LumeImage blur({required double sigma}) =>
      LumeImage._(rust.blur(imageBytes: _bytes, sigma: sigma));

  /// Unsharp-mask sharpen.
  LumeImage sharpen({required double sigma, required int threshold}) =>
      LumeImage._(
        rust.sharpen(imageBytes: _bytes, sigma: sigma, threshold: threshold),
      );

  /// Invert all colors.
  LumeImage invertColors() =>
      LumeImage._(rust.invertColors(imageBytes: _bytes));

  /// Rotate the hue by [degrees].
  LumeImage hueRotate({required int degrees}) =>
      LumeImage._(rust.huerotate(imageBytes: _bytes, degrees: degrees));

  // -------------------------------------------------------------------------
  // Compose
  // -------------------------------------------------------------------------

  /// Overlay another image on top at position ([x], [y]).
  LumeImage overlay(LumeImage other, {int x = 0, int y = 0}) => LumeImage._(
    rust.overlay(baseBytes: _bytes, overlayBytes: other._bytes, x: x, y: y),
  );

  /// Tile this image into a grid of [cols]×[rows].
  LumeImage tile({required int cols, required int rows}) =>
      LumeImage._(rust.tile(imageBytes: _bytes, cols: cols, rows: rows));

  // -------------------------------------------------------------------------
  // Channel operations
  // -------------------------------------------------------------------------

  /// Extract a single channel as grayscale (0=R, 1=G, 2=B, 3=A).
  LumeImage extractChannel(int channel) =>
      LumeImage._(rust.extractChannel(imageBytes: _bytes, channel: channel));

  /// Get the color of a single pixel.
  rust.LumeColor getPixel(int x, int y) =>
      rust.getPixel(imageBytes: _bytes, x: x, y: y);

  // -------------------------------------------------------------------------
  // Format conversion
  // -------------------------------------------------------------------------

  /// Convert to another format: `png`, `jpeg`, `gif`, `webp`, `bmp`, `tiff`, `ico`.
  LumeImage convertFormat(String format) =>
      LumeImage._(rust.convertFormat(imageBytes: _bytes, targetFormat: format));

  /// Shorthand: convert to PNG.
  LumeImage toPng() => convertFormat('png');

  /// Shorthand: convert to JPEG.
  LumeImage toJpeg() => convertFormat('jpeg');

  /// Shorthand: convert to WebP.
  LumeImage toWebp() => convertFormat('webp');

  // -------------------------------------------------------------------------
  // Persistence
  // -------------------------------------------------------------------------

  /// Write to a [File] asynchronously.
  Future<File> writeToFile(File file) => file.writeAsBytes(_bytes);

  /// Write to a [File] synchronously.
  void writeToFileSync(File file) => file.writeAsBytesSync(_bytes);

  /// Write to a path string asynchronously.
  Future<File> saveTo(String path) => File(path).writeAsBytes(_bytes);

  /// Write to a path string synchronously.
  void saveToSync(String path) => File(path).writeAsBytesSync(_bytes);
}
