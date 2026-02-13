import 'package:flutter/widgets.dart';

import 'package:lume/src/lume_image.dart';
import 'package:lume/src/lume_image_provider.dart';

/// A convenience widget that renders a [LumeImage] directly.
///
/// Wraps [Image] with sensible defaults and exposes the most common
/// parameters. For full control, use [Image] with a [LumeImageProvider].
///
/// ```dart
/// LumeImageWidget(
///   image: myLumeImage.resize(width: 300, height: 300).grayscale(),
///   fit: BoxFit.cover,
/// )
/// ```
class LumeImageWidget extends StatelessWidget {
  final LumeImage image;
  final double scale;
  final BoxFit? fit;
  final double? width;
  final double? height;
  final AlignmentGeometry alignment;
  final ImageRepeat repeat;
  final FilterQuality filterQuality;

  const LumeImageWidget({
    super.key,
    required this.image,
    this.scale = 1.0,
    this.fit,
    this.width,
    this.height,
    this.alignment = Alignment.center,
    this.repeat = ImageRepeat.noRepeat,
    this.filterQuality = FilterQuality.low,
  });

  @override
  Widget build(BuildContext context) {
    return Image(
      image: LumeImageProvider(image, scale: scale),
      fit: fit,
      width: width,
      height: height,
      alignment: alignment,
      repeat: repeat,
      filterQuality: filterQuality,
    );
  }
}
