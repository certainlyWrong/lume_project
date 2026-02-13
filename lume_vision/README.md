# Lume Vision

Real-time YOLO object detection for Flutter using ONNX Runtime and Lume image processing.

## Features

- **Real-time detection** — Process camera frames at 15-30 FPS on mobile
- **YOLOv8/v11 compatible** — Works with standard ONNX-exported YOLO models
- **Aspect ratio preserved** — Letterbox preprocessing, no image stretching
- **Flexible filtering** — Filter by label names and confidence thresholds
- **Customizable overlays** — Default styled boxes or fully custom widget builders
- **Background inference** — Optional isolate-based processing to keep UI smooth
- **Cross-platform** — Android, iOS, Linux support via ONNX Runtime

## Installation

Add to `pubspec.yaml`:

```yaml
dependencies:
  lume_vision: ^0.0.1
```

### Prerequisites

1. **YOLO ONNX model** — Export your model:

   ```bash
   yolo export model=yolov8n.pt format=onnx opset=12
   ```

   Place the `.onnx` file in your app's `assets/models/` folder.

2. **Camera permissions** — Add to `AndroidManifest.xml`:
   ```xml
   <uses-permission android:name="android.permission.CAMERA" />
   ```
   And `Info.plist` for iOS.

## Quick Start

```dart
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:lume_vision/lume_vision.dart';

late List<CameraDescription> cameras;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final detector = LumeVisionDetector(
      config: const DetectorConfig(
        modelPath: 'assets/models/yolov8n.onnx',
        isAsset: true,
        inputSize: 640,
        confidenceThreshold: 0.45,
      ),
    );

    return MaterialApp(
      home: Scaffold(
        body: FutureBuilder(
          future: detector.initialize(),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            return LumeVisionCamera(
              detector: detector,
              cameraDescription: cameras.first,
              visibleLabels: {'person', 'car', 'dog'},
              minConfidence: 0.5,
              statsBuilder: (context, result) => Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  result != null
                      ? '${result.objects.length} objects • ${result.fps.toStringAsFixed(1)} FPS'
                      : 'Initializing...',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
```

## API Reference

### LumeVisionDetector

Main detection engine powered by ONNX Runtime.

```dart
final detector = LumeVisionDetector(
  config: DetectorConfig(
    modelPath: 'assets/yolov8n.onnx',
    isAsset: true,
    inputSize: 640,
    confidenceThreshold: 0.45,
    nmsThreshold: 0.5,
    maxDetections: 100,
    useIsolate: true,
  ),
);

await detector.initialize();

// Detect from camera frame
final result = await detector.detectFromCamera(cameraImage);

// Detect from image file
final result = await detector.detectFromBytes(imageBytes);

detector.dispose();
```

### LumeVisionCamera

Camera widget with real-time overlay.

```dart
LumeVisionCamera(
  detector: detector,
  cameraDescription: cameras.first,
  visibleLabels: {'person', 'car'},
  minConfidence: 0.5,
  overlayStyle: DetectionOverlayStyle(
    borderWidth: 3,
    showConfidence: true,
  ),
  statsBuilder: (context, result) => Text('FPS: ${result?.fps ?? 0}'),
)
```

## Dependencies

- [camera](https://pub.dev/packages/camera) — Camera access
- [flutter_ort_plugin](https://pub.dev/packages/flutter_ort_plugin) — ONNX Runtime
- [lume](https://pub.dev/packages/lume) — Image preprocessing

## License

MIT
