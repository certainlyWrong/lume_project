import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:lume/lume.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RustLib.init();
  runApp(const LumeExampleApp());
}

class LumeExampleApp extends StatelessWidget {
  const LumeExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lume Examples',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const ExampleGallery(),
    );
  }
}

// =============================================================================
// Gallery — lists all demo categories
// =============================================================================

class ExampleGallery extends StatelessWidget {
  const ExampleGallery({super.key});

  @override
  Widget build(BuildContext context) {
    final demos = <_DemoEntry>[
      _DemoEntry(
        'Basic Transforms',
        Icons.transform,
        const BasicTransformsDemo(),
      ),
      _DemoEntry('Color Operations', Icons.palette, const ColorOpsDemo()),
      _DemoEntry('Filters (imageproc)', Icons.blur_on, const FiltersDemo()),
      _DemoEntry('Edge Detection', Icons.auto_graph, const EdgeDetectionDemo()),
      _DemoEntry('Morphology', Icons.grain, const MorphologyDemo()),
      _DemoEntry('Drawing', Icons.draw, const DrawingDemo()),
      _DemoEntry('Compose & Tile', Icons.grid_view, const ComposeDemo()),
      _DemoEntry('Format Conversion', Icons.swap_horiz, const FormatDemo()),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Lume Examples')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: demos.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final d = demos[i];
          return ListTile(
            leading: Icon(d.icon, color: Theme.of(context).colorScheme.primary),
            title: Text(d.title),
            trailing: const Icon(Icons.chevron_right),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            tileColor: Theme.of(context).colorScheme.surfaceContainerHigh,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => d.page),
            ),
          );
        },
      ),
    );
  }
}

class _DemoEntry {
  final String title;
  final IconData icon;
  final Widget page;
  const _DemoEntry(this.title, this.icon, this.page);
}

// =============================================================================
// Shared: generate a test image in memory (gradient with shapes)
// =============================================================================

Future<Uint8List> _generateTestImage({int w = 200, int h = 200}) async {
  final recorder = ui.PictureRecorder();
  final c = Canvas(recorder);

  // Gradient background
  for (int x = 0; x < w; x++) {
    final t = x / w;
    final color = Color.lerp(Colors.blue, Colors.orange, t)!;
    c.drawLine(
      Offset(x.toDouble(), 0),
      Offset(x.toDouble(), h.toDouble()),
      Paint()..color = color,
    );
  }

  // White circle
  c.drawCircle(Offset(w / 2, h / 2), w * 0.25, Paint()..color = Colors.white);

  // Red rectangle
  c.drawRect(
    Rect.fromLTWH(w * 0.1, h * 0.1, w * 0.3, h * 0.2),
    Paint()..color = Colors.red.withValues(alpha: 0.7),
  );

  final picture = recorder.endRecording();
  final image = await picture.toImage(w, h);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

// =============================================================================
// Shared: demo scaffold with before/after grid
// =============================================================================

class DemoScaffold extends StatelessWidget {
  final String title;
  final List<_ImageResult> results;

  const DemoScaffold({super.key, required this.title, required this.results});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.85,
        ),
        itemCount: results.length,
        itemBuilder: (context, i) {
          final r = results[i];
          return Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: Image.memory(r.bytes, fit: BoxFit.contain)),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Text(
                    r.label,
                    style: Theme.of(context).textTheme.labelSmall,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ImageResult {
  final String label;
  final Uint8List bytes;
  const _ImageResult(this.label, this.bytes);
}

// =============================================================================
// Async demo page wrapper
// =============================================================================

class AsyncDemoPage extends StatefulWidget {
  final String title;
  final Future<List<_ImageResult>> Function() builder;

  const AsyncDemoPage({super.key, required this.title, required this.builder});

  @override
  State<AsyncDemoPage> createState() => _AsyncDemoPageState();
}

class _AsyncDemoPageState extends State<AsyncDemoPage> {
  late Future<List<_ImageResult>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.builder();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<_ImageResult>>(
      future: _future,
      builder: (context, snap) {
        if (snap.hasError) {
          return Scaffold(
            appBar: AppBar(title: Text(widget.title)),
            body: Center(child: Text('Error: ${snap.error}')),
          );
        }
        if (!snap.hasData) {
          return Scaffold(
            appBar: AppBar(title: Text(widget.title)),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        return DemoScaffold(title: widget.title, results: snap.data!);
      },
    );
  }
}

// =============================================================================
// 1. Basic Transforms
// =============================================================================

class BasicTransformsDemo extends StatelessWidget {
  const BasicTransformsDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return AsyncDemoPage(
      title: 'Basic Transforms',
      builder: () async {
        final png = await _generateTestImage();
        final img = LumeImage.fromBytes(png);

        return [
          _ImageResult('Original', img.bytes),
          _ImageResult(
            'Resize 100×100',
            img.resize(width: 100, height: 100).bytes,
          ),
          _ImageResult(
            'Crop 80×80 @(60,60)',
            img.crop(x: 60, y: 60, width: 80, height: 80).bytes,
          ),
          _ImageResult('Rotate 90°', img.rotate(degrees: 90).bytes),
          _ImageResult('Rotate 180°', img.rotate(degrees: 180).bytes),
          _ImageResult('Flip Horizontal', img.flipHorizontal().bytes),
          _ImageResult('Flip Vertical', img.flipVertical().bytes),
          _ImageResult(
            'Thumbnail 60×60',
            img.thumbnail(maxWidth: 60, maxHeight: 60).bytes,
          ),
        ];
      },
    );
  }
}

// =============================================================================
// 2. Color Operations
// =============================================================================

class ColorOpsDemo extends StatelessWidget {
  const ColorOpsDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return AsyncDemoPage(
      title: 'Color Operations',
      builder: () async {
        final png = await _generateTestImage();
        final img = LumeImage.fromBytes(png);

        return [
          _ImageResult('Original', img.bytes),
          _ImageResult('Grayscale', img.grayscale().bytes),
          _ImageResult('Brightness +60', img.adjustBrightness(60).bytes),
          _ImageResult('Brightness -60', img.adjustBrightness(-60).bytes),
          _ImageResult('Contrast +0.8', img.adjustContrast(0.8).bytes),
          _ImageResult('Invert Colors', img.invertColors().bytes),
          _ImageResult('Hue Rotate 90°', img.hueRotate(degrees: 90).bytes),
          _ImageResult('Hue Rotate 180°', img.hueRotate(degrees: 180).bytes),
        ];
      },
    );
  }
}

// =============================================================================
// 3. Filters (imageproc)
// =============================================================================

class FiltersDemo extends StatelessWidget {
  const FiltersDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return AsyncDemoPage(
      title: 'Filters (imageproc)',
      builder: () async {
        final png = await _generateTestImage();
        final img = LumeImage.fromBytes(png);
        final canvas = LumeCanvas(img);

        return [
          _ImageResult('Original', img.bytes),
          _ImageResult(
            'Gaussian Blur σ=3',
            canvas.gaussianBlur(sigma: 3.0).bytes,
          ),
          _ImageResult(
            'Gaussian Blur σ=8',
            canvas.gaussianBlur(sigma: 8.0).bytes,
          ),
          _ImageResult('Sharpen 3×3', canvas.sharpen3x3().bytes),
          _ImageResult(
            'Sharpen Gaussian',
            canvas.sharpenGaussian(sigma: 1.0, amount: 3.0).bytes,
          ),
          _ImageResult('Laplacian', canvas.laplacianFilter().bytes),
          _ImageResult(
            'Box Filter 3×3',
            canvas.boxFilter(xRadius: 3, yRadius: 3).bytes,
          ),
          _ImageResult(
            'Median Filter 2×2',
            canvas.medianFilter(xRadius: 2, yRadius: 2).bytes,
          ),
        ];
      },
    );
  }
}

// =============================================================================
// 4. Edge Detection
// =============================================================================

class EdgeDetectionDemo extends StatelessWidget {
  const EdgeDetectionDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return AsyncDemoPage(
      title: 'Edge Detection',
      builder: () async {
        final png = await _generateTestImage();
        final img = LumeImage.fromBytes(png);
        final canvas = LumeCanvas(img);

        return [
          _ImageResult('Original', img.bytes),
          _ImageResult(
            'Canny (50, 150)',
            canvas.canny(low: 50, high: 150).bytes,
          ),
          _ImageResult('Canny (20, 80)', canvas.canny(low: 20, high: 80).bytes),
          _ImageResult('Sobel Gradients', canvas.sobelGradients().bytes),
          _ImageResult(
            'Adaptive Threshold',
            canvas.adaptiveThreshold(blockRadius: 5).bytes,
          ),
          _ImageResult('Otsu Threshold', canvas.otsuThreshold().bytes),
          _ImageResult('Threshold 128', canvas.threshold(value: 128).bytes),
          _ImageResult('Equalize Histogram', canvas.equalizeHistogram().bytes),
        ];
      },
    );
  }
}

// =============================================================================
// 5. Morphology
// =============================================================================

class MorphologyDemo extends StatelessWidget {
  const MorphologyDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return AsyncDemoPage(
      title: 'Morphology',
      builder: () async {
        final png = await _generateTestImage();
        final img = LumeImage.fromBytes(png);
        final binary = LumeCanvas(img).otsuThreshold();

        return [
          _ImageResult('Original', img.bytes),
          _ImageResult('Otsu (input)', binary.bytes),
          _ImageResult('Dilate r=2', binary.dilate(radius: 2).bytes),
          _ImageResult('Dilate r=5', binary.dilate(radius: 5).bytes),
          _ImageResult('Erode r=2', binary.erode(radius: 2).bytes),
          _ImageResult('Erode r=5', binary.erode(radius: 5).bytes),
          _ImageResult('Open r=3', binary.morphologicalOpen(radius: 3).bytes),
          _ImageResult('Close r=3', binary.morphologicalClose(radius: 3).bytes),
        ];
      },
    );
  }
}

// =============================================================================
// 6. Drawing
// =============================================================================

class DrawingDemo extends StatelessWidget {
  const DrawingDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return AsyncDemoPage(
      title: 'Drawing',
      builder: () async {
        final blank = LumeImage.blank(width: 200, height: 200, a: 255);
        final c = LumeCanvas(blank);

        final lines = c
            .drawLine(x1: 10, y1: 10, x2: 190, y2: 190, color: Colors.red)
            .drawLine(x1: 190, y1: 10, x2: 10, y2: 190, color: Colors.blue)
            .drawAntialiasedLine(
              x1: 100,
              y1: 10,
              x2: 100,
              y2: 190,
              color: Colors.green,
            );

        final rects = c
            .drawFilledRect(
              x: 20,
              y: 20,
              width: 70,
              height: 50,
              color: Colors.orange,
            )
            .drawHollowRect(
              x: 110,
              y: 20,
              width: 70,
              height: 50,
              color: Colors.cyan,
            );

        final circles = c
            .drawFilledCircle(cx: 60, cy: 130, radius: 40, color: Colors.purple)
            .drawHollowCircle(
              cx: 150,
              cy: 130,
              radius: 40,
              color: Colors.yellow,
            );

        final ellipses = c
            .drawFilledEllipse(
              cx: 100,
              cy: 100,
              widthRadius: 80,
              heightRadius: 40,
              color: Colors.teal,
            )
            .drawHollowEllipse(
              cx: 100,
              cy: 100,
              widthRadius: 40,
              heightRadius: 80,
              color: Colors.pink,
            );

        final polygons = c.drawFilledPolygon(
          points: [(100, 20), (180, 180), (20, 180)],
          color: Colors.amber,
        );

        final bezier = c.drawCubicBezier(
          startX: 10,
          startY: 100,
          endX: 190,
          endY: 100,
          ctrl1X: 60,
          ctrl1Y: 10,
          ctrl2X: 140,
          ctrl2Y: 190,
          color: Colors.lime,
        );

        final crosses = c
            .drawCross(cx: 50, cy: 50, color: Colors.red)
            .drawCross(cx: 100, cy: 100, color: Colors.green)
            .drawCross(cx: 150, cy: 150, color: Colors.blue);

        final combined = c
            .drawFilledRect(
              x: 10,
              y: 10,
              width: 180,
              height: 180,
              color: const Color(0xFF1A1A2E),
            )
            .drawFilledCircle(
              cx: 100,
              cy: 100,
              radius: 60,
              color: Colors.deepPurple,
            )
            .drawHollowCircle(cx: 100, cy: 100, radius: 80, color: Colors.amber)
            .drawLine(x1: 0, y1: 100, x2: 200, y2: 100, color: Colors.white)
            .drawLine(x1: 100, y1: 0, x2: 100, y2: 200, color: Colors.white)
            .drawCross(cx: 100, cy: 100, color: Colors.red);

        return [
          _ImageResult('Lines', lines.bytes),
          _ImageResult('Rectangles', rects.bytes),
          _ImageResult('Circles', circles.bytes),
          _ImageResult('Ellipses', ellipses.bytes),
          _ImageResult('Polygon', polygons.bytes),
          _ImageResult('Bézier Curve', bezier.bytes),
          _ImageResult('Cross Markers', crosses.bytes),
          _ImageResult('Combined', combined.bytes),
        ];
      },
    );
  }
}

// =============================================================================
// 7. Compose & Tile
// =============================================================================

class ComposeDemo extends StatelessWidget {
  const ComposeDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return AsyncDemoPage(
      title: 'Compose & Tile',
      builder: () async {
        final png = await _generateTestImage(w: 100, h: 100);
        final img = LumeImage.fromBytes(png);

        final small = LumeImage.blank(
          width: 40,
          height: 40,
          r: 255,
          g: 100,
          a: 255,
        );

        return [
          _ImageResult('Original', img.bytes),
          _ImageResult(
            'Overlay @(30,30)',
            img.overlay(small, x: 30, y: 30).bytes,
          ),
          _ImageResult('Overlay @(0,0)', img.overlay(small, x: 0, y: 0).bytes),
          _ImageResult('Tile 2×2', img.tile(cols: 2, rows: 2).bytes),
          _ImageResult('Tile 3×1', img.tile(cols: 3, rows: 1).bytes),
          _ImageResult('Tile 1×3', img.tile(cols: 1, rows: 3).bytes),
        ];
      },
    );
  }
}

// =============================================================================
// 8. Format Conversion
// =============================================================================

class FormatDemo extends StatelessWidget {
  const FormatDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return AsyncDemoPage(
      title: 'Format Conversion',
      builder: () async {
        final png = await _generateTestImage();
        final img = LumeImage.fromBytes(png);

        final asPng = img.toPng();
        final asJpeg = img.toJpeg();
        final asBmp = img.convertFormat('bmp');

        return [
          _ImageResult('PNG (${asPng.sizeBytes} bytes)', asPng.bytes),
          _ImageResult('JPEG (${asJpeg.sizeBytes} bytes)', asJpeg.bytes),
          _ImageResult('BMP (${asBmp.sizeBytes} bytes)', asBmp.bytes),
          _ImageResult(
            'Grayscale → PNG (${img.grayscale().toPng().sizeBytes} B)',
            img.grayscale().toPng().bytes,
          ),
        ];
      },
    );
  }
}
