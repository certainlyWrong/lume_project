import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:lume/src/lume_image.dart';

/// An [ImageProvider] backed by a [LumeImage].
///
/// Use this to plug a processed image directly into any Flutter widget that
/// accepts an [ImageProvider] — e.g. [Image], [DecorationImage],
/// [CircleAvatar], etc.
///
/// ```dart
/// Image(image: LumeImageProvider(myLumeImage))
/// ```
class LumeImageProvider extends ImageProvider<LumeImageProvider> {
  final LumeImage lumeImage;
  final double scale;

  LumeImageProvider(this.lumeImage, {this.scale = 1.0});

  @override
  Future<LumeImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<LumeImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    LumeImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode),
      scale: key.scale,
    );
  }

  Future<ui.Codec> _loadAsync(
    LumeImageProvider key,
    ImageDecoderCallback decode,
  ) async {
    final Uint8List bytes = key.lumeImage.bytes;
    final ui.ImmutableBuffer buffer = await ui.ImmutableBuffer.fromUint8List(
      bytes,
    );
    return decode(buffer);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! LumeImageProvider) return false;
    return lumeImage.bytes == other.lumeImage.bytes && scale == other.scale;
  }

  @override
  int get hashCode => Object.hash(lumeImage.bytes.hashCode, scale);

  @override
  String toString() =>
      '${objectRuntimeType(this, 'LumeImageProvider')}(${lumeImage.info.format}, scale: $scale)';
}
