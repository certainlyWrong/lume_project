import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:lume/lume.dart';

// Interesting points to cycle through
const _targets = [
  (x: -0.7453, y: 0.1127), // Seahorse Valley
  (x: -0.1011, y: 0.9563), // Elephant Valley
  (x: -1.2500, y: 0.0000), // Antenna tip
  (x: -0.7463, y: 0.1102), // Mini Mandelbrot
  (x: 0.2501, y: 0.0000), // Cusp
  (x: -0.1624, y: 1.0340), // Spiral arm
];

// Duration of each zoom cycle in seconds before resetting
const _cycleDuration = 18.0;
// Fade duration in seconds (fade out at end, fade in at start)
const _fadeDuration = 1.5;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RustLib.init();
  runApp(const MandelbrotApp());
}

class MandelbrotApp extends StatelessWidget {
  const MandelbrotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mandelbrot + Lume',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

// =============================================================================
// Home — choose between the two demos
// =============================================================================

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mandelbrot + Lume')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.auto_awesome,
                size: 80,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'Mandelbrot Fractal',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Rendered with GLSL shaders, processed with Lume',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              _DemoCard(
                icon: Icons.gradient,
                title: 'GLSL Shader Puro',
                subtitle:
                    'Fractal renderizado em tempo real com fragment shader',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PureShaderDemo()),
                ),
              ),
              const SizedBox(height: 16),
              _DemoCard(
                icon: Icons.auto_fix_high,
                title: 'GLSL + Lume Processing',
                subtitle:
                    'Shader capturado e processado com filtros Lume em tempo real',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LumeProcessedDemo()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DemoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _DemoCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 12,
        ),
        leading: Icon(
          icon,
          size: 36,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: Text(title, style: Theme.of(context).textTheme.titleMedium),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

// =============================================================================
// Demo 1 — Pure GLSL shader with auto-zoom
// =============================================================================

class PureShaderDemo extends StatefulWidget {
  const PureShaderDemo({super.key});

  @override
  State<PureShaderDemo> createState() => _PureShaderDemoState();
}

class _PureShaderDemoState extends State<PureShaderDemo>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  ui.FragmentShader? _shader;
  bool _isLoading = true;
  bool _autoZoom = true;

  int _targetIndex = 0;
  double _cycleTime = 0;
  double _zoom = 3.0;
  double _offsetX = _targets[0].x;
  double _offsetY = _targets[0].y;
  int _maxIter = 200;
  double _fade = 1.0;
  double _colorShift = 0.0;

  @override
  void initState() {
    super.initState();
    _loadShader();
    _ticker = createTicker((duration) {
      if (_autoZoom) {
        final totalElapsed = duration.inMilliseconds / 1000.0;
        _cycleTime = totalElapsed % _cycleDuration;

        // Current target
        _targetIndex = (totalElapsed ~/ _cycleDuration) % _targets.length;
        final t = _targets[_targetIndex];
        _offsetX = t.x;
        _offsetY = t.y;

        // Exponential zoom within cycle
        _zoom = 3.0 * math.exp(-_cycleTime * 0.8);

        // Increase iterations as we zoom deeper
        _maxIter = (200 + _cycleTime * 40).clamp(200, 1000).toInt();

        // Color shift per target for variety
        _colorShift = _targetIndex.toDouble();

        // Fade: in at start, out at end
        if (_cycleTime < _fadeDuration) {
          _fade = _cycleTime / _fadeDuration;
        } else if (_cycleTime > _cycleDuration - _fadeDuration) {
          _fade = (_cycleDuration - _cycleTime) / _fadeDuration;
        } else {
          _fade = 1.0;
        }
        _fade = _fade.clamp(0.0, 1.0);
      }
      setState(() {});
    });
    _ticker.start();
  }

  Future<void> _loadShader() async {
    final program = await ui.FragmentProgram.fromAsset(
      'shaders/mandelbrot.frag',
    );
    _shader = program.fragmentShader();
    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _shader?.dispose();
    super.dispose();
  }

  Future<void> _saveImage() async {
    if (_shader == null) return;
    final wasAutoZoom = _autoZoom;
    _autoZoom = false;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = Size(1920, 1080);

    _shader!
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, _offsetX)
      ..setFloat(3, _offsetY)
      ..setFloat(4, _zoom)
      ..setFloat(5, _maxIter.toDouble())
      ..setFloat(6, _colorShift)
      ..setFloat(7, 1.0);

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..shader = _shader,
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      size.width.toInt(),
      size.height.toInt(),
    );
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return;

    final bytes = byteData.buffer.asUint8List();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final dir = Directory('${Directory.current.path}/screenshots');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final path = '${dir.path}/mandelbrot_$timestamp.png';
    File(path).writeAsBytesSync(bytes);

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Saved to $path')));
    }
    _autoZoom = wasAutoZoom;
  }

  @override
  Widget build(BuildContext context) {
    final target = _targets[_targetIndex];
    final zoomLevel = 3.0 / _zoom;
    return Scaffold(
      appBar: AppBar(
        title: const Text('GLSL Shader Puro'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save_alt),
            onPressed: _saveImage,
            tooltip: 'Salvar imagem',
          ),
          IconButton(
            icon: Icon(_autoZoom ? Icons.pause : Icons.play_arrow),
            onPressed: () => setState(() => _autoZoom = !_autoZoom),
            tooltip: _autoZoom ? 'Pausar' : 'Continuar',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            child: Text(
              'Zoom: ${zoomLevel.toStringAsFixed(0)}x  •  '
              'Iter: $_maxIter  •  '
              'Point ${_targetIndex + 1}/${_targets.length}: '
              '(${target.x.toStringAsFixed(4)}, ${target.y.toStringAsFixed(4)})',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : CustomPaint(
                    size: Size.infinite,
                    painter: _MandelbrotPainter(
                      shader: _shader!,
                      zoom: _zoom,
                      offsetX: _offsetX,
                      offsetY: _offsetY,
                      maxIter: _maxIter,
                      colorShift: _colorShift,
                      fade: _fade,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Demo 2 — GLSL + Lume processing with auto-zoom
// =============================================================================

class LumeProcessedDemo extends StatefulWidget {
  const LumeProcessedDemo({super.key});

  @override
  State<LumeProcessedDemo> createState() => _LumeProcessedDemoState();
}

class _LumeProcessedDemoState extends State<LumeProcessedDemo>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  ui.FragmentShader? _shader;
  bool _isLoading = true;
  bool _autoZoom = true;

  int _targetIndex = 0;
  double _cycleTime = 0;
  double _zoom = 3.0;
  double _offsetX = _targets[0].x;
  double _offsetY = _targets[0].y;
  int _maxIter = 200;
  double _fade = 1.0;
  double _colorShift = 0.0;

  // Lume
  Uint8List? _lumeResult;
  String _lumeInfo = '';
  bool _processing = false;
  int _selectedFilter = 0;

  final _filterNames = [
    'Grayscale + Contrast',
    'Edge Detection (Canny)',
    'Sharpen + Invert',
    'Gaussian Blur',
    'Sobel Gradients',
    'Otsu Threshold',
  ];

  @override
  void initState() {
    super.initState();
    _loadShader();
    _ticker = createTicker((duration) {
      if (_autoZoom) {
        final totalElapsed = duration.inMilliseconds / 1000.0;
        _cycleTime = totalElapsed % _cycleDuration;
        _targetIndex = (totalElapsed ~/ _cycleDuration) % _targets.length;
        final t = _targets[_targetIndex];
        _offsetX = t.x;
        _offsetY = t.y;
        _zoom = 3.0 * math.exp(-_cycleTime * 0.8);
        _maxIter = (200 + _cycleTime * 40).clamp(200, 1000).toInt();
        _colorShift = _targetIndex.toDouble();
        if (_cycleTime < _fadeDuration) {
          _fade = _cycleTime / _fadeDuration;
        } else if (_cycleTime > _cycleDuration - _fadeDuration) {
          _fade = (_cycleDuration - _cycleTime) / _fadeDuration;
        } else {
          _fade = 1.0;
        }
        _fade = _fade.clamp(0.0, 1.0);
      }
      setState(() {});
    });
    _ticker.start();
  }

  Future<void> _loadShader() async {
    final program = await ui.FragmentProgram.fromAsset(
      'shaders/mandelbrot.frag',
    );
    _shader = program.fragmentShader();
    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _shader?.dispose();
    super.dispose();
  }

  Future<void> _captureAndProcess() async {
    if (_shader == null || _processing) return;
    setState(() => _processing = true);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const captureSize = Size(600, 600);

    _shader!
      ..setFloat(0, captureSize.width)
      ..setFloat(1, captureSize.height)
      ..setFloat(2, _offsetX)
      ..setFloat(3, _offsetY)
      ..setFloat(4, _zoom)
      ..setFloat(5, _maxIter.toDouble())
      ..setFloat(6, _colorShift)
      ..setFloat(7, 1.0);

    canvas.drawRect(
      Rect.fromLTWH(0, 0, captureSize.width, captureSize.height),
      Paint()..shader = _shader,
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      captureSize.width.toInt(),
      captureSize.height.toInt(),
    );
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      setState(() => _processing = false);
      return;
    }

    final originalBytes = byteData.buffer.asUint8List();
    final lumeImg = LumeImage.fromBytes(originalBytes);
    final sw = Stopwatch()..start();

    late LumeImage processed;
    switch (_selectedFilter) {
      case 0:
        processed = lumeImg.grayscale().adjustContrast(1.5);
        break;
      case 1:
        processed = LumeCanvas(lumeImg).canny(low: 40, high: 120).toLumeImage();
        break;
      case 2:
        processed = lumeImg.sharpen(sigma: 2.0, threshold: 5).invertColors();
        break;
      case 3:
        processed = LumeCanvas(lumeImg).gaussianBlur(sigma: 5.0).toLumeImage();
        break;
      case 4:
        processed = LumeCanvas(lumeImg).sobelGradients().toLumeImage();
        break;
      case 5:
        processed = LumeCanvas(lumeImg).otsuThreshold().toLumeImage();
        break;
      default:
        processed = lumeImg;
    }

    sw.stop();
    final result = processed.toPng();

    setState(() {
      _lumeResult = result.bytes;
      _lumeInfo =
          '${_filterNames[_selectedFilter]}\n'
          '${result.width}×${result.height}  •  ${result.sizeBytes} bytes\n'
          'Processed in ${sw.elapsedMilliseconds}ms';
      _processing = false;
    });
  }

  Future<void> _saveShader() async {
    if (_shader == null) return;
    final wasAutoZoom = _autoZoom;
    _autoZoom = false;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = Size(1920, 1080);

    _shader!
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, _offsetX)
      ..setFloat(3, _offsetY)
      ..setFloat(4, _zoom)
      ..setFloat(5, _maxIter.toDouble())
      ..setFloat(6, _colorShift)
      ..setFloat(7, 1.0);

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..shader = _shader,
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      size.width.toInt(),
      size.height.toInt(),
    );
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return;

    final bytes = byteData.buffer.asUint8List();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final dir = Directory('${Directory.current.path}/screenshots');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final path = '${dir.path}/mandelbrot_shader_$timestamp.png';
    File(path).writeAsBytesSync(bytes);

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Shader saved to $path')));
    }
    _autoZoom = wasAutoZoom;
  }

  Future<void> _saveLumeResult() async {
    if (_lumeResult == null) return;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final dir = Directory('${Directory.current.path}/screenshots');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final path = '${dir.path}/mandelbrot_lume_$timestamp.png';
    File(path).writeAsBytesSync(_lumeResult!);

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lume result saved to $path')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GLSL + Lume'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save_alt),
            onPressed: _saveShader,
            tooltip: 'Salvar shader',
          ),
          IconButton(
            icon: Icon(_autoZoom ? Icons.pause : Icons.play_arrow),
            onPressed: () => setState(() => _autoZoom = !_autoZoom),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            child: Text(
              'Zoom: ${(3.0 / _zoom).toStringAsFixed(0)}x  •  '
              'Iter: $_maxIter  •  '
              'Point ${_targetIndex + 1}/${_targets.length}',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),

          Expanded(
            flex: 3,
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : CustomPaint(
                    size: Size.infinite,
                    painter: _MandelbrotPainter(
                      shader: _shader!,
                      zoom: _zoom,
                      offsetX: _offsetX,
                      offsetY: _offsetY,
                      maxIter: _maxIter,
                      colorShift: _colorShift,
                      fade: _fade,
                    ),
                  ),
          ),

          // Filter selector + capture button
          Container(
            padding: const EdgeInsets.all(12),
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            child: Row(
              children: [
                Expanded(
                  child: DropdownButton<int>(
                    value: _selectedFilter,
                    isExpanded: true,
                    dropdownColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    items: List.generate(
                      _filterNames.length,
                      (i) => DropdownMenuItem(
                        value: i,
                        child: Text(
                          _filterNames[i],
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ),
                    onChanged: (v) => setState(() => _selectedFilter = v ?? 0),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _processing ? null : _captureAndProcess,
                  icon: _processing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_fix_high),
                  label: const Text('Process'),
                ),
              ],
            ),
          ),

          // Lume result (bottom)
          Expanded(
            flex: 2,
            child: _lumeResult == null
                ? Center(
                    child: Text(
                      'Pause and tap "Process" to apply Lume filters',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Image.memory(
                            _lumeResult!,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _lumeInfo,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 8),
                              FilledButton.icon(
                                onPressed: _saveLumeResult,
                                icon: const Icon(Icons.save_alt, size: 16),
                                label: const Text('Save'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Shared painter
// =============================================================================

class _MandelbrotPainter extends CustomPainter {
  final ui.FragmentShader shader;
  final double zoom;
  final double offsetX;
  final double offsetY;
  final int maxIter;
  final double colorShift;
  final double fade;

  _MandelbrotPainter({
    required this.shader,
    required this.zoom,
    required this.offsetX,
    required this.offsetY,
    required this.maxIter,
    this.colorShift = 0.0,
    this.fade = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, offsetX)
      ..setFloat(3, offsetY)
      ..setFloat(4, zoom)
      ..setFloat(5, maxIter.toDouble())
      ..setFloat(6, colorShift)
      ..setFloat(7, fade);

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..shader = shader,
    );
  }

  @override
  bool shouldRepaint(covariant _MandelbrotPainter old) =>
      old.zoom != zoom ||
      old.offsetX != offsetX ||
      old.offsetY != offsetY ||
      old.maxIter != maxIter ||
      old.colorShift != colorShift ||
      old.fade != fade;
}
