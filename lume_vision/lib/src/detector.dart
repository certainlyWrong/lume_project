import 'dart:typed_data';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter_ort_plugin/flutter_ort_plugin.dart';

import 'coco_labels.dart';
import 'models.dart';
import 'preprocessor.dart';

/// YOLO object detector powered by ONNX Runtime.
///
/// Handles model loading, preprocessing, inference, and postprocessing.
///
/// ```dart
/// final detector = LumeVisionDetector(
///   config: DetectorConfig(modelPath: 'assets/yolov8n.onnx'),
/// );
/// await detector.initialize();
/// final result = detector.detectFromCamera(cameraImage);
/// detector.dispose();
/// ```
class LumeVisionDetector {
  final DetectorConfig config;
  final YoloPreprocessor _preprocessor;

  OrtSessionWrapper? _session;
  OrtIsolateSession? _isolateSession;
  bool _initialized = false;
  bool _busy = false;

  late final List<String> _labels;

  LumeVisionDetector({required this.config})
    : _preprocessor = YoloPreprocessor(inputSize: config.inputSize);

  /// Whether the detector has been initialized.
  bool get isInitialized => _initialized;

  /// Whether the detector is currently running inference.
  bool get isBusy => _busy;

  /// The labels used by this detector.
  List<String> get labels => _labels;

  /// The preprocessor (exposes letterbox padding info).
  YoloPreprocessor get preprocessor => _preprocessor;

  /// Initialize the ONNX Runtime and load the model.
  ///
  /// Must be called before any detection methods.
  Future<void> initialize() async {
    if (_initialized) return;

    _labels = config.labels ?? cocoLabels;

    final runtime = OnnxRuntime.instance;
    runtime.initialize();
    runtime.createEnvironment();

    if (config.useIsolate) {
      _isolateSession = await OrtIsolateSession.create(
        OrtIsolateSessionConfig(modelPath: config.modelPath),
      );
    } else {
      if (config.isAsset) {
        _session = OrtSessionWrapper.create(config.modelPath);
      } else {
        _session = OrtSessionWrapper.create(config.modelPath);
      }
    }

    _initialized = true;
  }

  /// Run detection on a [CameraImage] frame.
  ///
  /// Returns null if the detector is busy (previous frame still processing).
  Future<DetectionResult?> detectFromCamera(CameraImage image) async {
    if (!_initialized || _busy) return null;
    _busy = true;

    try {
      final preSw = Stopwatch()..start();
      final tensor = _preprocessor.preprocessCameraImage(image);
      preSw.stop();

      final result = await _runInference(tensor, preSw.elapsedMilliseconds);

      return result;
    } finally {
      _busy = false;
    }
  }

  /// Run detection on raw image bytes (PNG/JPEG).
  Future<DetectionResult?> detectFromBytes(Uint8List imageBytes) async {
    if (!_initialized || _busy) return null;
    _busy = true;

    try {
      final preSw = Stopwatch()..start();
      final tensor = _preprocessor.preprocessImageBytes(imageBytes);
      preSw.stop();

      return await _runInference(tensor, preSw.elapsedMilliseconds);
    } finally {
      _busy = false;
    }
  }

  Future<DetectionResult> _runInference(
    Float32List tensor,
    int preprocessMs,
  ) async {
    final infSw = Stopwatch()..start();

    late final List<Float32List> outputs;

    if (config.useIsolate && _isolateSession != null) {
      final input = OrtIsolateInput(
        shape: [1, 3, config.inputSize, config.inputSize],
        data: tensor,
      );
      // YOLOv8/v11 output: [1, 84, 8400] for COCO (4 bbox + 80 classes)
      final numClasses = _labels.length;
      final numAnchors = 8400;
      final outputSize = (4 + numClasses) * numAnchors;

      outputs = await _isolateSession!.runFloat(
        {_isolateSession!.inputNames.first: input},
        [outputSize],
      );
    } else if (_session != null) {
      final runtime = OnnxRuntime.instance;
      final inputValue = OrtValueWrapper.fromFloat(runtime, [
        1,
        3,
        config.inputSize,
        config.inputSize,
      ], tensor);

      final numClasses = _labels.length;
      final numAnchors = 8400;
      final outputSize = (4 + numClasses) * numAnchors;

      outputs = _session!.runFloat(
        {_session!.inputNames.first: inputValue},
        [outputSize],
      );
      inputValue.release();
    } else {
      throw StateError('No session available');
    }

    infSw.stop();

    final postSw = Stopwatch()..start();
    final objects = _postprocess(outputs.first);
    postSw.stop();

    return DetectionResult(
      objects: objects,
      inferenceTimeMs: infSw.elapsedMilliseconds,
      preprocessTimeMs: preprocessMs,
      postprocessTimeMs: postSw.elapsedMilliseconds,
      inputSize: Size(config.inputSize.toDouble(), config.inputSize.toDouble()),
    );
  }

  /// YOLOv8/v11 postprocessing: parse output tensor → DetectedObject list.
  ///
  /// Output format: [1, (4 + numClasses), numAnchors]
  /// Transposed to per-anchor: [cx, cy, w, h, class0_conf, class1_conf, ...]
  List<DetectedObject> _postprocess(Float32List output) {
    final numClasses = _labels.length;
    const numAnchors = 8400;
    // Output is in [1, (4+numClasses), numAnchors] layout (column-major per anchor)
    // We need to read it as: for anchor j, feature i = output[i * numAnchors + j]

    final List<_RawDetection> rawDetections = [];

    for (int j = 0; j < numAnchors; j++) {
      // Find best class
      double maxConf = 0;
      int bestClass = 0;

      for (int c = 0; c < numClasses; c++) {
        final conf = output[(4 + c) * numAnchors + j];
        if (conf > maxConf) {
          maxConf = conf;
          bestClass = c;
        }
      }

      if (maxConf < config.confidenceThreshold) continue;

      // Extract bbox (cx, cy, w, h) in model input coordinates
      final cx = output[0 * numAnchors + j];
      final cy = output[1 * numAnchors + j];
      final w = output[2 * numAnchors + j];
      final h = output[3 * numAnchors + j];

      rawDetections.add(
        _RawDetection(
          cx: cx,
          cy: cy,
          w: w,
          h: h,
          confidence: maxConf,
          classIndex: bestClass,
        ),
      );
    }

    // Non-Maximum Suppression
    final nmsResult = _nms(rawDetections);

    // Convert to DetectedObject with normalized coordinates
    return nmsResult.map((d) {
      final topLeft = _preprocessor.modelToOriginal(
        d.cx - d.w / 2,
        d.cy - d.h / 2,
      );
      final bottomRight = _preprocessor.modelToOriginal(
        d.cx + d.w / 2,
        d.cy + d.h / 2,
      );

      return DetectedObject(
        boundingBox: Rect.fromLTRB(
          topLeft.x,
          topLeft.y,
          bottomRight.x,
          bottomRight.y,
        ),
        label: d.classIndex < _labels.length
            ? _labels[d.classIndex]
            : 'class_${d.classIndex}',
        classIndex: d.classIndex,
        confidence: d.confidence,
      );
    }).toList();
  }

  /// Greedy NMS per class.
  List<_RawDetection> _nms(List<_RawDetection> detections) {
    if (detections.isEmpty) return [];

    // Sort by confidence descending
    detections.sort((a, b) => b.confidence.compareTo(a.confidence));

    // Group by class
    final Map<int, List<_RawDetection>> byClass = {};
    for (final d in detections) {
      byClass.putIfAbsent(d.classIndex, () => []).add(d);
    }

    final List<_RawDetection> result = [];

    for (final group in byClass.values) {
      final kept = <_RawDetection>[];
      for (final candidate in group) {
        bool suppressed = false;
        for (final existing in kept) {
          if (_iou(candidate, existing) > config.nmsThreshold) {
            suppressed = true;
            break;
          }
        }
        if (!suppressed) {
          kept.add(candidate);
          if (result.length + kept.length >= config.maxDetections) break;
        }
      }
      result.addAll(kept);
      if (result.length >= config.maxDetections) break;
    }

    return result;
  }

  double _iou(_RawDetection a, _RawDetection b) {
    final aLeft = a.cx - a.w / 2;
    final aTop = a.cy - a.h / 2;
    final aRight = a.cx + a.w / 2;
    final aBottom = a.cy + a.h / 2;

    final bLeft = b.cx - b.w / 2;
    final bTop = b.cy - b.h / 2;
    final bRight = b.cx + b.w / 2;
    final bBottom = b.cy + b.h / 2;

    final interLeft = aLeft > bLeft ? aLeft : bLeft;
    final interTop = aTop > bTop ? aTop : bTop;
    final interRight = aRight < bRight ? aRight : bRight;
    final interBottom = aBottom < bBottom ? aBottom : bBottom;

    if (interLeft >= interRight || interTop >= interBottom) return 0;

    final interArea = (interRight - interLeft) * (interBottom - interTop);
    final aArea = a.w * a.h;
    final bArea = b.w * b.h;

    return interArea / (aArea + bArea - interArea);
  }

  /// Release all resources.
  Future<void> dispose() async {
    if (_isolateSession != null) {
      await _isolateSession!.dispose();
      _isolateSession = null;
    }
    if (_session != null) {
      _session!.dispose();
      _session = null;
    }
    _initialized = false;
  }
}

class _RawDetection {
  final double cx, cy, w, h;
  final double confidence;
  final int classIndex;

  _RawDetection({
    required this.cx,
    required this.cy,
    required this.w,
    required this.h,
    required this.confidence,
    required this.classIndex,
  });
}
