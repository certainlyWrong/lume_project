import 'package:flutter/material.dart';

import 'models.dart';

/// Signature for building a custom widget per detected object.
///
/// [object] is the detection, [rect] is the bounding box in pixel coordinates
/// relative to the overlay widget.
typedef DetectionWidgetBuilder = Widget Function(
  BuildContext context,
  DetectedObject object,
  Rect rect,
);

/// Signature for building a custom label widget.
typedef DetectionLabelBuilder = Widget Function(
  BuildContext context,
  DetectedObject object,
);

/// Default color palette for detection classes.
const _defaultColors = <Color>[
  Color(0xFFFF6B6B),
  Color(0xFF4ECDC4),
  Color(0xFFFFE66D),
  Color(0xFF95E1D3),
  Color(0xFFF38181),
  Color(0xFFAA96DA),
  Color(0xFFFCBF49),
  Color(0xFF2EC4B6),
  Color(0xFFE76F51),
  Color(0xFF606C38),
];

/// Style configuration for the default detection overlay.
class DetectionOverlayStyle {
  /// Border width for bounding boxes.
  final double borderWidth;

  /// Border radius for bounding boxes.
  final double borderRadius;

  /// Font size for labels.
  final double labelFontSize;

  /// Padding inside the label background.
  final EdgeInsets labelPadding;

  /// Whether to show confidence percentage.
  final bool showConfidence;

  /// Whether to show the label text.
  final bool showLabel;

  /// Custom color map: classIndex → Color.
  /// Falls back to [_defaultColors] palette.
  final Map<int, Color>? colorMap;

  /// Fixed color for all detections (overrides colorMap).
  final Color? fixedColor;

  /// Label background opacity.
  final double labelBackgroundOpacity;

  const DetectionOverlayStyle({
    this.borderWidth = 2.5,
    this.borderRadius = 4.0,
    this.labelFontSize = 12.0,
    this.labelPadding = const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    this.showConfidence = true,
    this.showLabel = true,
    this.colorMap,
    this.fixedColor,
    this.labelBackgroundOpacity = 0.75,
  });
}

/// Paints detection bounding boxes and labels over the camera preview.
///
/// This widget should be sized to match the camera preview area exactly.
/// Bounding boxes use normalized coordinates [0..1] from [DetectedObject].
///
/// ## Customization
///
/// **Default rendering** — uses [DetectionOverlayStyle]:
/// ```dart
/// LumeVisionOverlay(
///   detections: result.objects,
///   style: DetectionOverlayStyle(borderWidth: 3, showConfidence: true),
/// )
/// ```
///
/// **Fully custom** — use [detectionBuilder]:
/// ```dart
/// LumeVisionOverlay(
///   detections: result.objects,
///   detectionBuilder: (context, object, rect) {
///     return Positioned.fromRect(
///       rect: rect,
///       child: MyCustomWidget(object),
///     );
///   },
/// )
/// ```
class LumeVisionOverlay extends StatelessWidget {
  /// Detected objects to render.
  final List<DetectedObject> detections;

  /// Style for the default rendering. Ignored if [detectionBuilder] is set.
  final DetectionOverlayStyle style;

  /// Optional custom builder for each detection.
  /// When provided, replaces the default box+label rendering entirely.
  final DetectionWidgetBuilder? detectionBuilder;

  /// Optional custom label builder.
  /// When provided, replaces the default label widget but keeps the box.
  final DetectionLabelBuilder? labelBuilder;

  /// Labels to show. If non-empty, only these labels are rendered.
  final Set<String> visibleLabels;

  /// Minimum confidence to render.
  final double minConfidence;

  const LumeVisionOverlay({
    super.key,
    required this.detections,
    this.style = const DetectionOverlayStyle(),
    this.detectionBuilder,
    this.labelBuilder,
    this.visibleLabels = const {},
    this.minConfidence = 0.0,
  });

  Color _colorForClass(int classIndex) {
    if (style.fixedColor != null) return style.fixedColor!;
    if (style.colorMap != null && style.colorMap!.containsKey(classIndex)) {
      return style.colorMap![classIndex]!;
    }
    return _defaultColors[classIndex % _defaultColors.length];
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;

        final filtered = detections.where((d) {
          if (d.confidence < minConfidence) return false;
          if (visibleLabels.isNotEmpty && !visibleLabels.contains(d.label)) {
            return false;
          }
          return true;
        }).toList();

        if (detectionBuilder != null) {
          return Stack(
            children: filtered.map((d) {
              final rect = Rect.fromLTRB(
                d.boundingBox.left * width,
                d.boundingBox.top * height,
                d.boundingBox.right * width,
                d.boundingBox.bottom * height,
              );
              return detectionBuilder!(context, d, rect);
            }).toList(),
          );
        }

        return CustomPaint(
          size: Size(width, height),
          painter: _DetectionPainter(
            detections: filtered,
            style: style,
            colorForClass: _colorForClass,
          ),
          child: Stack(
            children: filtered.map((d) {
              final left = d.boundingBox.left * width;
              final top = d.boundingBox.top * height;
              final color = _colorForClass(d.classIndex);

              if (labelBuilder != null) {
                return Positioned(
                  left: left,
                  top: top - 20,
                  child: labelBuilder!(context, d),
                );
              }

              if (!style.showLabel && !style.showConfidence) {
                return const SizedBox.shrink();
              }

              final labelText = [
                if (style.showLabel) d.label,
                if (style.showConfidence)
                  '${(d.confidence * 100).toStringAsFixed(0)}%',
              ].join(' ');

              return Positioned(
                left: left,
                top: (top - 22).clamp(0, height - 22),
                child: Container(
                  padding: style.labelPadding,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: style.labelBackgroundOpacity),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(style.borderRadius),
                      topRight: Radius.circular(style.borderRadius),
                    ),
                  ),
                  child: Text(
                    labelText,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: style.labelFontSize,
                      fontWeight: FontWeight.w600,
                      height: 1.0,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

class _DetectionPainter extends CustomPainter {
  final List<DetectedObject> detections;
  final DetectionOverlayStyle style;
  final Color Function(int) colorForClass;

  _DetectionPainter({
    required this.detections,
    required this.style,
    required this.colorForClass,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final d in detections) {
      final color = colorForClass(d.classIndex);
      final rect = Rect.fromLTRB(
        d.boundingBox.left * size.width,
        d.boundingBox.top * size.height,
        d.boundingBox.right * size.width,
        d.boundingBox.bottom * size.height,
      );

      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = style.borderWidth;

      if (style.borderRadius > 0) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(style.borderRadius)),
          paint,
        );
      } else {
        canvas.drawRect(rect, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DetectionPainter old) =>
      old.detections != detections;
}
