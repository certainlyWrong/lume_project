import 'dart:ui';

/// A single detected object from YOLO inference.
class DetectedObject {
  /// Bounding box in normalized coordinates [0..1].
  final Rect boundingBox;

  /// Class label (e.g. "person", "car").
  final String label;

  /// Class index from the model output.
  final int classIndex;

  /// Confidence score [0..1].
  final double confidence;

  const DetectedObject({
    required this.boundingBox,
    required this.label,
    required this.classIndex,
    required this.confidence,
  });

  @override
  String toString() =>
      'DetectedObject($label, ${(confidence * 100).toStringAsFixed(1)}%, '
      'box: [${boundingBox.left.toStringAsFixed(3)}, '
      '${boundingBox.top.toStringAsFixed(3)}, '
      '${boundingBox.width.toStringAsFixed(3)}, '
      '${boundingBox.height.toStringAsFixed(3)}])';
}

/// Result of a single detection pass.
class DetectionResult {
  /// All detected objects (before label filtering).
  final List<DetectedObject> objects;

  /// Inference time in milliseconds.
  final int inferenceTimeMs;

  /// Preprocessing time in milliseconds.
  final int preprocessTimeMs;

  /// Postprocessing time in milliseconds.
  final int postprocessTimeMs;

  /// Input image size used for inference.
  final Size inputSize;

  const DetectionResult({
    required this.objects,
    required this.inferenceTimeMs,
    this.preprocessTimeMs = 0,
    this.postprocessTimeMs = 0,
    this.inputSize = const Size(640, 640),
  });

  /// Total pipeline time.
  int get totalTimeMs => preprocessTimeMs + inferenceTimeMs + postprocessTimeMs;

  /// Approximate FPS based on total pipeline time.
  double get fps => totalTimeMs > 0 ? 1000.0 / totalTimeMs : 0;

  /// Filter results by label names.
  DetectionResult filterByLabels(Set<String> labels) {
    if (labels.isEmpty) return this;
    return DetectionResult(
      objects: objects.where((o) => labels.contains(o.label)).toList(),
      inferenceTimeMs: inferenceTimeMs,
      preprocessTimeMs: preprocessTimeMs,
      postprocessTimeMs: postprocessTimeMs,
      inputSize: inputSize,
    );
  }

  /// Filter results by minimum confidence.
  DetectionResult filterByConfidence(double minConfidence) {
    return DetectionResult(
      objects: objects.where((o) => o.confidence >= minConfidence).toList(),
      inferenceTimeMs: inferenceTimeMs,
      preprocessTimeMs: preprocessTimeMs,
      postprocessTimeMs: postprocessTimeMs,
      inputSize: inputSize,
    );
  }
}

/// Configuration for the YOLO detector.
class DetectorConfig {
  /// Path to the ONNX model file.
  final String modelPath;

  /// Whether [modelPath] is a Flutter asset path.
  final bool isAsset;

  /// Model input size (width = height, typically 640).
  final int inputSize;

  /// Confidence threshold for detections.
  final double confidenceThreshold;

  /// IoU threshold for Non-Maximum Suppression.
  final double nmsThreshold;

  /// Maximum number of detections to return.
  final int maxDetections;

  /// Class labels. If null, uses COCO 80-class labels.
  final List<String>? labels;

  /// Number of threads for inference (0 = ORT default).
  final int numThreads;

  /// Whether to use background isolate for inference.
  final bool useIsolate;

  const DetectorConfig({
    required this.modelPath,
    this.isAsset = true,
    this.inputSize = 640,
    this.confidenceThreshold = 0.45,
    this.nmsThreshold = 0.5,
    this.maxDetections = 100,
    this.labels,
    this.numThreads = 0,
    this.useIsolate = true,
  });

  DetectorConfig copyWith({
    String? modelPath,
    bool? isAsset,
    int? inputSize,
    double? confidenceThreshold,
    double? nmsThreshold,
    int? maxDetections,
    List<String>? labels,
    int? numThreads,
    bool? useIsolate,
  }) {
    return DetectorConfig(
      modelPath: modelPath ?? this.modelPath,
      isAsset: isAsset ?? this.isAsset,
      inputSize: inputSize ?? this.inputSize,
      confidenceThreshold: confidenceThreshold ?? this.confidenceThreshold,
      nmsThreshold: nmsThreshold ?? this.nmsThreshold,
      maxDetections: maxDetections ?? this.maxDetections,
      labels: labels ?? this.labels,
      numThreads: numThreads ?? this.numThreads,
      useIsolate: useIsolate ?? this.useIsolate,
    );
  }
}
