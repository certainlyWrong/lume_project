/// Lume — high-performance image manipulation powered by Rust.
///
/// Two main interfaces:
///
/// - [LumeImage] — basic operations (resize, crop, rotate, color, format).
/// - [LumeCanvas] — advanced processing (edges, filters, morphology, drawing).
///
/// ```dart
/// import 'package:lume/lume.dart';
///
/// // Basic
/// final img = LumeImage.fromFile(file)
///   .resize(width: 800, height: 600)
///   .grayscale();
///
/// // Advanced
/// final canvas = LumeCanvas(img)
///   .canny(low: 50, high: 150)
///   .dilate(radius: 2)
///   .toLumeImage();
///
/// // Flutter integration
/// LumeImageWidget(image: img, fit: BoxFit.cover);
/// ```
library;

export 'src/lume_canvas.dart';
export 'src/lume_image.dart';
export 'src/lume_image_provider.dart';
export 'src/lume_image_widget.dart';
export 'src/rust/api/image_ops.dart' show LumeImageInfo, LumeColor;
export 'src/rust/api/imageproc_ops.dart' show LumePoint, LumeContour;
export 'src/rust/frb_generated.dart' show RustLib;
