import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'detector.dart';
import 'models.dart';
import 'overlay.dart';

/// Callback when a new detection result is available.
typedef OnDetectionResult = void Function(DetectionResult result);

/// Callback to build a stats/info widget from the latest result.
typedef StatsWidgetBuilder = Widget Function(
  BuildContext context,
  DetectionResult? result,
);

/// Real-time camera detection widget.
///
/// Displays the camera preview with aspect-ratio-preserving fit and overlays
/// detection bounding boxes. The camera image is never stretched or cropped.
///
/// ## Basic usage
/// ```dart
/// LumeVisionCamera(
///   detector: myDetector,
///   cameraDescription: cameras.first,
/// )
/// ```
///
/// ## Customized
/// ```dart
/// LumeVisionCamera(
///   detector: myDetector,
///   cameraDescription: cameras.first,
///   visibleLabels: {'person', 'car'},
///   minConfidence: 0.5,
///   overlayStyle: DetectionOverlayStyle(borderWidth: 3),
///   onDetection: (result) => print('Found ${result.objects.length} objects'),
///   statsBuilder: (context, result) => Text('FPS: ${result?.fps.toStringAsFixed(1)}'),
/// )
/// ```
class LumeVisionCamera extends StatefulWidget {
  /// The initialized detector to use for inference.
  final LumeVisionDetector detector;

  /// Camera to use.
  final CameraDescription cameraDescription;

  /// Resolution preset for the camera.
  final ResolutionPreset resolutionPreset;

  /// Labels to filter. Empty = show all.
  final Set<String> visibleLabels;

  /// Minimum confidence to display.
  final double minConfidence;

  /// Style for the default overlay.
  final DetectionOverlayStyle overlayStyle;

  /// Custom detection widget builder (replaces default overlay).
  final DetectionWidgetBuilder? detectionBuilder;

  /// Custom label builder.
  final DetectionLabelBuilder? labelBuilder;

  /// Called on each new detection result.
  final OnDetectionResult? onDetection;

  /// Builder for a stats/info widget overlaid on the camera.
  final StatsWidgetBuilder? statsBuilder;

  /// Position of the stats widget.
  final Alignment statsAlignment;

  /// Whether to start detecting immediately.
  final bool autoStart;

  /// Whether to mirror the preview (useful for front camera).
  final bool mirror;

  const LumeVisionCamera({
    super.key,
    required this.detector,
    required this.cameraDescription,
    this.resolutionPreset = ResolutionPreset.medium,
    this.visibleLabels = const {},
    this.minConfidence = 0.0,
    this.overlayStyle = const DetectionOverlayStyle(),
    this.detectionBuilder,
    this.labelBuilder,
    this.onDetection,
    this.statsBuilder,
    this.statsAlignment = Alignment.topLeft,
    this.autoStart = true,
    this.mirror = false,
  });

  @override
  State<LumeVisionCamera> createState() => LumeVisionCameraState();
}

/// Public state so users can call [startDetection] / [stopDetection].
class LumeVisionCameraState extends State<LumeVisionCamera>
    with WidgetsBindingObserver {
  CameraController? _controller;
  bool _detecting = false;
  bool _isStreaming = false;
  DetectionResult? _lastResult;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopStream();
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      _stopStream();
      _controller?.dispose();
      _controller = null;
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    _controller = CameraController(
      widget.cameraDescription,
      widget.resolutionPreset,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    try {
      await _controller!.initialize();
      if (!mounted) return;
      setState(() {});

      if (widget.autoStart) {
        startDetection();
      }
    } catch (e) {
      debugPrint('LumeVisionCamera: Failed to initialize camera: $e');
    }
  }

  /// Start processing camera frames for detection.
  void startDetection() {
    if (_isStreaming || _controller == null || !_controller!.value.isInitialized) {
      return;
    }
    _detecting = true;
    _isStreaming = true;
    _controller!.startImageStream(_onCameraFrame);
  }

  /// Stop processing camera frames.
  void stopDetection() {
    _detecting = false;
    _stopStream();
    if (mounted) setState(() {});
  }

  void _stopStream() {
    if (_isStreaming && _controller != null && _controller!.value.isInitialized) {
      try {
        _controller!.stopImageStream();
      } catch (_) {}
    }
    _isStreaming = false;
  }

  Future<void> _onCameraFrame(CameraImage image) async {
    if (!_detecting || !widget.detector.isInitialized) return;

    final result = await widget.detector.detectFromCamera(image);
    if (result == null || !mounted) return;

    setState(() => _lastResult = result);
    widget.onDetection?.call(result);
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final cameraAspect = _controller!.value.aspectRatio;
        final containerAspect = constraints.maxWidth / constraints.maxHeight;

        double previewWidth, previewHeight;

        if (containerAspect > cameraAspect) {
          // Container is wider → fit by height
          previewHeight = constraints.maxHeight;
          previewWidth = previewHeight * cameraAspect;
        } else {
          // Container is taller → fit by width
          previewWidth = constraints.maxWidth;
          previewHeight = previewWidth / cameraAspect;
        }

        Widget preview = SizedBox(
          width: previewWidth,
          height: previewHeight,
          child: CameraPreview(_controller!),
        );

        if (widget.mirror) {
          preview = Transform.flip(flipX: true, child: preview);
        }

        // Filter detections
        final detections = _lastResult?.objects.where((d) {
          if (d.confidence < widget.minConfidence) return false;
          if (widget.visibleLabels.isNotEmpty &&
              !widget.visibleLabels.contains(d.label)) {
            return false;
          }
          return true;
        }).toList() ?? [];

        return Center(
          child: SizedBox(
            width: previewWidth,
            height: previewHeight,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Camera preview
                preview,

                // Detection overlay
                if (detections.isNotEmpty)
                  LumeVisionOverlay(
                    detections: detections,
                    style: widget.overlayStyle,
                    detectionBuilder: widget.detectionBuilder,
                    labelBuilder: widget.labelBuilder,
                  ),

                // Stats widget
                if (widget.statsBuilder != null)
                  Align(
                    alignment: widget.statsAlignment,
                    child: widget.statsBuilder!(context, _lastResult),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
