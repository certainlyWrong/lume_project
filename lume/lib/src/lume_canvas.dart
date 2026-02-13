import 'dart:typed_data';
import 'dart:ui' show Color;

import 'package:lume/src/lume_image.dart';
import 'package:lume/src/rust/api/imageproc_ops.dart' as proc;

/// Advanced image processing powered by `imageproc`.
///
/// [LumeCanvas] wraps a [LumeImage] and exposes computer-vision and
/// drawing operations. Every mutation returns a **new** instance.
///
/// ```dart
/// final result = LumeCanvas(myImage)
///   .canny(low: 50, high: 150)
///   .dilate(radius: 2)
///   .drawFilledCircle(cx: 100, cy: 100, radius: 30, color: Colors.red)
///   .toLumeImage();
/// ```
class LumeCanvas {
  final Uint8List _bytes;

  LumeCanvas._(this._bytes);

  /// Wrap a [LumeImage] for advanced processing.
  factory LumeCanvas(LumeImage image) => LumeCanvas._(image.bytes);

  /// Create from raw bytes.
  factory LumeCanvas.fromBytes(Uint8List bytes) => LumeCanvas._(bytes);

  /// Convert back to a [LumeImage].
  LumeImage toLumeImage() => LumeImage.fromBytes(_bytes);

  /// The raw encoded bytes.
  Uint8List get bytes => _bytes;

  // =========================================================================
  // Filters
  // =========================================================================

  /// Gaussian blur (works on RGBA).
  LumeCanvas gaussianBlur({required double sigma}) =>
      LumeCanvas._(proc.gaussianBlur(imageBytes: _bytes, sigma: sigma));

  /// Median filter (grayscale). Good for salt-and-pepper noise removal.
  LumeCanvas medianFilter({required int xRadius, required int yRadius}) =>
      LumeCanvas._(
        proc.medianFilter(
          imageBytes: _bytes,
          xRadius: xRadius,
          yRadius: yRadius,
        ),
      );

  /// Bilateral filter (grayscale). Edge-preserving smoothing.
  LumeCanvas bilateralFilter({
    required int windowSize,
    required double sigmaColor,
    required double sigmaSpatial,
  }) => LumeCanvas._(
    proc.bilateralFilter(
      imageBytes: _bytes,
      windowSize: windowSize,
      sigmaColor: sigmaColor,
      sigmaSpatial: sigmaSpatial,
    ),
  );

  /// Box filter (grayscale).
  LumeCanvas boxFilter({required int xRadius, required int yRadius}) =>
      LumeCanvas._(
        proc.boxFilter(imageBytes: _bytes, xRadius: xRadius, yRadius: yRadius),
      );

  /// 3×3 sharpen kernel (grayscale).
  LumeCanvas sharpen3x3() => LumeCanvas._(proc.sharpen3X3(imageBytes: _bytes));

  /// Gaussian-based unsharp mask (grayscale).
  LumeCanvas sharpenGaussian({required double sigma, required double amount}) =>
      LumeCanvas._(
        proc.sharpenGaussian(imageBytes: _bytes, sigma: sigma, amount: amount),
      );

  /// Laplacian edge-detection filter (grayscale).
  LumeCanvas laplacianFilter() =>
      LumeCanvas._(proc.laplacianFilter(imageBytes: _bytes));

  // =========================================================================
  // Edge detection
  // =========================================================================

  /// Canny edge detector (grayscale output).
  LumeCanvas canny({required double low, required double high}) => LumeCanvas._(
    proc.canny(imageBytes: _bytes, lowThreshold: low, highThreshold: high),
  );

  /// Sobel gradient magnitudes (grayscale output).
  LumeCanvas sobelGradients() =>
      LumeCanvas._(proc.sobelGradients(imageBytes: _bytes));

  // =========================================================================
  // Contrast / Threshold
  // =========================================================================

  /// Adaptive threshold (grayscale).
  LumeCanvas adaptiveThreshold({required int blockRadius}) => LumeCanvas._(
    proc.adaptiveThreshold(imageBytes: _bytes, blockRadius: blockRadius),
  );

  /// Otsu automatic threshold (grayscale).
  LumeCanvas otsuThreshold() =>
      LumeCanvas._(proc.otsuThreshold(imageBytes: _bytes));

  /// Fixed threshold (grayscale). Set [invert] to reverse black/white.
  LumeCanvas threshold({required int value, bool invert = false}) =>
      LumeCanvas._(
        proc.threshold(imageBytes: _bytes, value: value, invert: invert),
      );

  /// Histogram equalization (grayscale).
  LumeCanvas equalizeHistogram() =>
      LumeCanvas._(proc.equalizeHistogram(imageBytes: _bytes));

  /// Stretch contrast (grayscale).
  LumeCanvas stretchContrast({
    required int inputLower,
    required int inputUpper,
    required int outputLower,
    required int outputUpper,
  }) => LumeCanvas._(
    proc.stretchContrast(
      imageBytes: _bytes,
      inputLower: inputLower,
      inputUpper: inputUpper,
      outputLower: outputLower,
      outputUpper: outputUpper,
    ),
  );

  // =========================================================================
  // Morphology
  // =========================================================================

  /// Dilate foreground pixels (grayscale).
  LumeCanvas dilate({required int radius}) =>
      LumeCanvas._(proc.dilate(imageBytes: _bytes, radius: radius));

  /// Erode foreground pixels (grayscale).
  LumeCanvas erode({required int radius}) =>
      LumeCanvas._(proc.erode(imageBytes: _bytes, radius: radius));

  /// Morphological open (erode then dilate).
  LumeCanvas morphologicalOpen({required int radius}) =>
      LumeCanvas._(proc.morphologicalOpen(imageBytes: _bytes, radius: radius));

  /// Morphological close (dilate then erode).
  LumeCanvas morphologicalClose({required int radius}) =>
      LumeCanvas._(proc.morphologicalClose(imageBytes: _bytes, radius: radius));

  // =========================================================================
  // Geometric transformations
  // =========================================================================

  /// Rotate by arbitrary angle (radians) around center.
  LumeCanvas rotateAboutCenter({
    required double theta,
    Color backgroundColor = const Color(0x00000000),
  }) => LumeCanvas._(
    proc.rotateAboutCenter(
      imageBytes: _bytes,
      theta: theta,
      bgR: (backgroundColor.r * 255.0).round().clamp(0, 255),
      bgG: (backgroundColor.g * 255.0).round().clamp(0, 255),
      bgB: (backgroundColor.b * 255.0).round().clamp(0, 255),
      bgA: (backgroundColor.a * 255.0).round().clamp(0, 255),
    ),
  );

  /// Translate (shift) the image by ([tx], [ty]) pixels.
  LumeCanvas translate({required int tx, required int ty}) =>
      LumeCanvas._(proc.translate(imageBytes: _bytes, tx: tx, ty: ty));

  // =========================================================================
  // Noise
  // =========================================================================

  /// Add Gaussian noise.
  LumeCanvas gaussianNoise({
    required double mean,
    required double stddev,
    required BigInt seed,
  }) => LumeCanvas._(
    proc.gaussianNoise(
      imageBytes: _bytes,
      mean: mean,
      stddev: stddev,
      seed: seed,
    ),
  );

  /// Add salt-and-pepper noise.
  LumeCanvas saltAndPepperNoise({required double rate, required BigInt seed}) =>
      LumeCanvas._(
        proc.saltAndPepperNoise(imageBytes: _bytes, rate: rate, seed: seed),
      );

  // =========================================================================
  // Seam carving
  // =========================================================================

  /// Content-aware width reduction via seam carving.
  LumeCanvas seamCarveWidth({required int newWidth}) =>
      LumeCanvas._(proc.seamCarveWidth(imageBytes: _bytes, newWidth: newWidth));

  // =========================================================================
  // Drawing
  // =========================================================================

  /// Draw a line segment.
  LumeCanvas drawLine({
    required int x1,
    required int y1,
    required int x2,
    required int y2,
    required Color color,
  }) => LumeCanvas._(
    proc.drawLine(
      imageBytes: _bytes,
      x1: x1,
      y1: y1,
      x2: x2,
      y2: y2,
      r: (color.r * 255.0).round().clamp(0, 255),
      g: (color.g * 255.0).round().clamp(0, 255),
      b: (color.b * 255.0).round().clamp(0, 255),
      a: (color.a * 255.0).round().clamp(0, 255),
    ),
  );

  /// Draw an anti-aliased line segment.
  LumeCanvas drawAntialiasedLine({
    required int x1,
    required int y1,
    required int x2,
    required int y2,
    required Color color,
  }) => LumeCanvas._(
    proc.drawAntialiasedLine(
      imageBytes: _bytes,
      x1: x1,
      y1: y1,
      x2: x2,
      y2: y2,
      r: (color.r * 255.0).round().clamp(0, 255),
      g: (color.g * 255.0).round().clamp(0, 255),
      b: (color.b * 255.0).round().clamp(0, 255),
      a: (color.a * 255.0).round().clamp(0, 255),
    ),
  );

  /// Draw a hollow rectangle.
  LumeCanvas drawHollowRect({
    required int x,
    required int y,
    required int width,
    required int height,
    required Color color,
  }) => LumeCanvas._(
    proc.drawHollowRect(
      imageBytes: _bytes,
      x: x,
      y: y,
      width: width,
      height: height,
      r: (color.r * 255.0).round().clamp(0, 255),
      g: (color.g * 255.0).round().clamp(0, 255),
      b: (color.b * 255.0).round().clamp(0, 255),
      a: (color.a * 255.0).round().clamp(0, 255),
    ),
  );

  /// Draw a filled rectangle.
  LumeCanvas drawFilledRect({
    required int x,
    required int y,
    required int width,
    required int height,
    required Color color,
  }) => LumeCanvas._(
    proc.drawFilledRect(
      imageBytes: _bytes,
      x: x,
      y: y,
      width: width,
      height: height,
      r: (color.r * 255.0).round().clamp(0, 255),
      g: (color.g * 255.0).round().clamp(0, 255),
      b: (color.b * 255.0).round().clamp(0, 255),
      a: (color.a * 255.0).round().clamp(0, 255),
    ),
  );

  /// Draw a hollow circle.
  LumeCanvas drawHollowCircle({
    required int cx,
    required int cy,
    required int radius,
    required Color color,
  }) => LumeCanvas._(
    proc.drawHollowCircle(
      imageBytes: _bytes,
      cx: cx,
      cy: cy,
      radius: radius,
      r: (color.r * 255.0).round().clamp(0, 255),
      g: (color.g * 255.0).round().clamp(0, 255),
      b: (color.b * 255.0).round().clamp(0, 255),
      a: (color.a * 255.0).round().clamp(0, 255),
    ),
  );

  /// Draw a filled circle.
  LumeCanvas drawFilledCircle({
    required int cx,
    required int cy,
    required int radius,
    required Color color,
  }) => LumeCanvas._(
    proc.drawFilledCircle(
      imageBytes: _bytes,
      cx: cx,
      cy: cy,
      radius: radius,
      r: (color.r * 255.0).round().clamp(0, 255),
      g: (color.g * 255.0).round().clamp(0, 255),
      b: (color.b * 255.0).round().clamp(0, 255),
      a: (color.a * 255.0).round().clamp(0, 255),
    ),
  );

  /// Draw a hollow ellipse.
  LumeCanvas drawHollowEllipse({
    required int cx,
    required int cy,
    required int widthRadius,
    required int heightRadius,
    required Color color,
  }) => LumeCanvas._(
    proc.drawHollowEllipse(
      imageBytes: _bytes,
      cx: cx,
      cy: cy,
      widthRadius: widthRadius,
      heightRadius: heightRadius,
      r: (color.r * 255.0).round().clamp(0, 255),
      g: (color.g * 255.0).round().clamp(0, 255),
      b: (color.b * 255.0).round().clamp(0, 255),
      a: (color.a * 255.0).round().clamp(0, 255),
    ),
  );

  /// Draw a filled ellipse.
  LumeCanvas drawFilledEllipse({
    required int cx,
    required int cy,
    required int widthRadius,
    required int heightRadius,
    required Color color,
  }) => LumeCanvas._(
    proc.drawFilledEllipse(
      imageBytes: _bytes,
      cx: cx,
      cy: cy,
      widthRadius: widthRadius,
      heightRadius: heightRadius,
      r: (color.r * 255.0).round().clamp(0, 255),
      g: (color.g * 255.0).round().clamp(0, 255),
      b: (color.b * 255.0).round().clamp(0, 255),
      a: (color.a * 255.0).round().clamp(0, 255),
    ),
  );

  /// Draw a filled polygon from a list of (x, y) points.
  LumeCanvas drawFilledPolygon({
    required List<(int, int)> points,
    required Color color,
  }) => LumeCanvas._(
    proc.drawFilledPolygon(
      imageBytes: _bytes,
      points: points.map((p) => proc.LumePoint(x: p.$1, y: p.$2)).toList(),
      r: (color.r * 255.0).round().clamp(0, 255),
      g: (color.g * 255.0).round().clamp(0, 255),
      b: (color.b * 255.0).round().clamp(0, 255),
      a: (color.a * 255.0).round().clamp(0, 255),
    ),
  );

  /// Draw a hollow polygon outline from a list of (x, y) points.
  LumeCanvas drawHollowPolygon({
    required List<(int, int)> points,
    required Color color,
  }) => LumeCanvas._(
    proc.drawHollowPolygon(
      imageBytes: _bytes,
      points: points.map((p) => proc.LumePoint(x: p.$1, y: p.$2)).toList(),
      r: (color.r * 255.0).round().clamp(0, 255),
      g: (color.g * 255.0).round().clamp(0, 255),
      b: (color.b * 255.0).round().clamp(0, 255),
      a: (color.a * 255.0).round().clamp(0, 255),
    ),
  );

  /// Draw a cubic Bézier curve.
  LumeCanvas drawCubicBezier({
    required double startX,
    required double startY,
    required double endX,
    required double endY,
    required double ctrl1X,
    required double ctrl1Y,
    required double ctrl2X,
    required double ctrl2Y,
    required Color color,
  }) => LumeCanvas._(
    proc.drawCubicBezier(
      imageBytes: _bytes,
      startX: startX,
      startY: startY,
      endX: endX,
      endY: endY,
      ctrl1X: ctrl1X,
      ctrl1Y: ctrl1Y,
      ctrl2X: ctrl2X,
      ctrl2Y: ctrl2Y,
      r: (color.r * 255.0).round().clamp(0, 255),
      g: (color.g * 255.0).round().clamp(0, 255),
      b: (color.b * 255.0).round().clamp(0, 255),
      a: (color.a * 255.0).round().clamp(0, 255),
    ),
  );

  /// Draw a small cross marker at ([cx], [cy]).
  LumeCanvas drawCross({
    required int cx,
    required int cy,
    required Color color,
  }) => LumeCanvas._(
    proc.drawCross(
      imageBytes: _bytes,
      cx: cx,
      cy: cy,
      r: (color.r * 255.0).round().clamp(0, 255),
      g: (color.g * 255.0).round().clamp(0, 255),
      b: (color.b * 255.0).round().clamp(0, 255),
      a: (color.a * 255.0).round().clamp(0, 255),
    ),
  );

  // =========================================================================
  // Analysis
  // =========================================================================

  /// Find contours in a grayscale/binary image.
  List<proc.LumeContour> findContours() =>
      proc.findContours(imageBytes: _bytes);

  /// Distance transform (grayscale).
  LumeCanvas distanceTransform() =>
      LumeCanvas._(proc.distanceTransform(imageBytes: _bytes));
}
