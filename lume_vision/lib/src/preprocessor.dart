import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:lume/lume.dart';

/// Converts camera frames into normalized Float32List tensors for YOLO input.
///
/// YOLO expects input in NCHW format: [1, 3, H, W] with values in [0..1].
/// This preprocessor handles:
/// - YUV/BGRA → PNG conversion via camera
/// - Letterbox resize (preserves aspect ratio, pads with gray)
/// - HWC → CHW transpose
/// - Normalization to [0..1]
class YoloPreprocessor {
  final int inputSize;

  /// Letterbox padding offsets (for mapping detections back to original coords).
  double padX = 0;
  double padY = 0;
  double scale = 1.0;

  /// Original image dimensions before preprocessing.
  int originalWidth = 0;
  int originalHeight = 0;

  YoloPreprocessor({this.inputSize = 640});

  /// Preprocess a [CameraImage] into a YOLO-ready Float32List tensor.
  ///
  /// Returns the tensor in NCHW format [1, 3, inputSize, inputSize].
  Float32List preprocessCameraImage(CameraImage image) {
    originalWidth = image.width;
    originalHeight = image.height;

    // Convert YUV420/BGRA planes to a single RGBA byte buffer via Lume
    final Uint8List rgbaBytes = _cameraImageToRgba(image);

    return _rgbaToTensor(rgbaBytes, image.width, image.height);
  }

  /// Preprocess raw PNG/JPEG bytes into a YOLO-ready tensor.
  Float32List preprocessImageBytes(Uint8List imageBytes) {
    final lumeImage = LumeImage.fromBytes(imageBytes);
    final info = lumeImage.info();
    originalWidth = info.width;
    originalHeight = info.height;

    // Decode to RGBA via Lume
    final rgba = lumeImage.toRgba8();
    return _rgbaToTensor(rgba, info.width, info.height);
  }

  /// Convert RGBA pixels to a letterboxed, normalized CHW tensor.
  Float32List _rgbaToTensor(Uint8List rgba, int width, int height) {
    // Calculate letterbox dimensions
    final double scaleW = inputSize / width;
    final double scaleH = inputSize / height;
    scale = scaleW < scaleH ? scaleW : scaleH;

    final int newW = (width * scale).round();
    final int newH = (height * scale).round();

    padX = (inputSize - newW) / 2.0;
    padY = (inputSize - newH) / 2.0;

    final int padLeft = padX.round();
    final int padTop = padY.round();

    // Create output tensor: NCHW [1, 3, inputSize, inputSize]
    final tensor = Float32List(1 * 3 * inputSize * inputSize);

    // Fill with letterbox gray (114/255 ≈ 0.447)
    const double gray = 114.0 / 255.0;
    tensor.fillRange(0, tensor.length, gray);

    // Bilinear resize + normalize + CHW layout
    for (int y = 0; y < newH; y++) {
      for (int x = 0; x < newW; x++) {
        // Map back to source coordinates
        final double srcX = x / scale;
        final double srcY = y / scale;

        final int sx = srcX.round().clamp(0, width - 1);
        final int sy = srcY.round().clamp(0, height - 1);

        final int srcIdx = (sy * width + sx) * 4; // RGBA

        if (srcIdx + 2 >= rgba.length) continue;

        final double r = rgba[srcIdx] / 255.0;
        final double g = rgba[srcIdx + 1] / 255.0;
        final double b = rgba[srcIdx + 2] / 255.0;

        final int dx = x + padLeft;
        final int dy = y + padTop;

        if (dx >= inputSize || dy >= inputSize) continue;

        // CHW layout: channel * H * W + y * W + x
        tensor[0 * inputSize * inputSize + dy * inputSize + dx] = r;
        tensor[1 * inputSize * inputSize + dy * inputSize + dx] = g;
        tensor[2 * inputSize * inputSize + dy * inputSize + dx] = b;
      }
    }

    return tensor;
  }

  /// Convert detection coordinates from model space back to original image space.
  ///
  /// Input [x], [y] are in model input coordinates [0..inputSize].
  /// Returns normalized coordinates [0..1] relative to original image.
  ({double x, double y}) modelToOriginal(double x, double y) {
    final ox = (x - padX) / scale / originalWidth;
    final oy = (y - padY) / scale / originalHeight;
    return (x: ox.clamp(0.0, 1.0), y: oy.clamp(0.0, 1.0));
  }

  /// Convert camera YUV420/BGRA to RGBA bytes.
  Uint8List _cameraImageToRgba(CameraImage image) {
    switch (image.format.group) {
      case ImageFormatGroup.yuv420:
        return _yuv420ToRgba(image);
      case ImageFormatGroup.bgra8888:
        return _bgra8888ToRgba(image);
      default:
        // Fallback: try treating as BGRA
        return _bgra8888ToRgba(image);
    }
  }

  Uint8List _yuv420ToRgba(CameraImage image) {
    final int width = image.width;
    final int height = image.height;
    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    final rgba = Uint8List(width * height * 4);

    for (int row = 0; row < height; row++) {
      for (int col = 0; col < width; col++) {
        final int yIndex = row * yPlane.bytesPerRow + col;
        final int uvRow = row >> 1;
        final int uvCol = col >> 1;

        int uIndex = uvRow * uPlane.bytesPerRow + uvCol;
        int vIndex = uvRow * vPlane.bytesPerRow + uvCol;

        // Handle pixel stride for interleaved UV planes (Android NV21/NV12)
        if (uPlane.bytesPerPixel != null && uPlane.bytesPerPixel! > 1) {
          uIndex = uvRow * uPlane.bytesPerRow + uvCol * uPlane.bytesPerPixel!;
          vIndex = uvRow * vPlane.bytesPerRow + uvCol * vPlane.bytesPerPixel!;
        }

        final int y = yPlane.bytes[yIndex];
        final int u = uIndex < uPlane.bytes.length ? uPlane.bytes[uIndex] : 128;
        final int v = vIndex < vPlane.bytes.length ? vPlane.bytes[vIndex] : 128;

        // YUV to RGB conversion (BT.601)
        int r = (y + 1.402 * (v - 128)).round().clamp(0, 255);
        int g = (y - 0.344136 * (u - 128) - 0.714136 * (v - 128)).round().clamp(
          0,
          255,
        );
        int b = (y + 1.772 * (u - 128)).round().clamp(0, 255);

        final int idx = (row * width + col) * 4;
        rgba[idx] = r;
        rgba[idx + 1] = g;
        rgba[idx + 2] = b;
        rgba[idx + 3] = 255;
      }
    }

    return rgba;
  }

  Uint8List _bgra8888ToRgba(CameraImage image) {
    final bytes = image.planes[0].bytes;
    final int width = image.width;
    final int height = image.height;
    final rgba = Uint8List(width * height * 4);

    for (int i = 0; i < width * height; i++) {
      final int srcIdx = i * 4;
      final int dstIdx = i * 4;
      rgba[dstIdx] = bytes[srcIdx + 2]; // R
      rgba[dstIdx + 1] = bytes[srcIdx + 1]; // G
      rgba[dstIdx + 2] = bytes[srcIdx]; // B
      rgba[dstIdx + 3] = 255; // A
    }

    return rgba;
  }
}
