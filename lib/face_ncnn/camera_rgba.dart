import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

class RgbaFrame {
  RgbaFrame(this.bytes, this.width, this.height);
  final Uint8List bytes;
  final int width;
  final int height;
}

/// Convert [CameraImage] → RGBA8888, optionally downscaled so longest side ≤ [maxSide].
RgbaFrame? cameraImageToRgba(CameraImage image, {int maxSide = 640}) {
  if (image.width <= 0 || image.height <= 0 || image.planes.isEmpty) {
    return null;
  }

  final format = image.format.group;
  Uint8List rgba;
  try {
    if (format == ImageFormatGroup.bgra8888 ||
        (image.planes.length == 1 && image.planes[0].bytesPerPixel == 4)) {
      rgba = _bgraToRgba(image);
    } else if (format == ImageFormatGroup.yuv420 || image.planes.length >= 2) {
      rgba = _yuv420ToRgba(image);
    } else {
      debugPrint('[camera_rgba] unsupported format: $format planes=${image.planes.length}');
      return null;
    }
  } catch (e) {
    debugPrint('[camera_rgba] convert failed: $e');
    return null;
  }

  return _downscaleRgba(rgba, image.width, image.height, maxSide);
}

Uint8List _bgraToRgba(CameraImage image) {
  final plane = image.planes[0];
  final w = image.width;
  final h = image.height;
  final rowStride = plane.bytesPerRow;
  final src = plane.bytes;
  final out = Uint8List(w * h * 4);

  var di = 0;
  for (var y = 0; y < h; y++) {
    final row = y * rowStride;
    for (var x = 0; x < w; x++) {
      final si = row + x * 4;
      if (si + 3 >= src.length) break;
      out[di] = src[si + 2]; // R
      out[di + 1] = src[si + 1]; // G
      out[di + 2] = src[si]; // B
      out[di + 3] = src[si + 3]; // A
      di += 4;
    }
  }
  return out;
}

/// Basic BT.601 YUV420 (NV21/I420-ish) → RGBA. Good enough for face detect.
Uint8List _yuv420ToRgba(CameraImage image) {
  final w = image.width;
  final h = image.height;
  final yPlane = image.planes[0];
  final uPlane = image.planes.length > 1 ? image.planes[1] : yPlane;
  final vPlane = image.planes.length > 2 ? image.planes[2] : uPlane;

  final yBytes = yPlane.bytes;
  final uBytes = uPlane.bytes;
  final vBytes = vPlane.bytes;
  final yRow = yPlane.bytesPerRow;
  final uvRow = uPlane.bytesPerRow;
  final uvPix = uPlane.bytesPerPixel ?? 1;

  // NV21 often packs VU interleaved in plane[1] on Android when planes==2
  final nv21 = image.planes.length == 2;

  final out = Uint8List(w * h * 4);
  var di = 0;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final yi = y * yRow + x;
      final Y = yBytes[yi].clamp(0, 255);

      final uvx = x >> 1;
      final uvy = y >> 1;
      int U;
      int V;
      if (nv21) {
        final uvi = uvy * uvRow + uvx * 2;
        V = uBytes[uvi.clamp(0, uBytes.length - 1)];
        U = uBytes[(uvi + 1).clamp(0, uBytes.length - 1)];
      } else {
        final uvi = uvy * uvRow + uvx * uvPix;
        U = uBytes[uvi.clamp(0, uBytes.length - 1)];
        V = vBytes[uvi.clamp(0, vBytes.length - 1)];
      }

      final c = Y - 16;
      final d = U - 128;
      final e = V - 128;
      final r = ((298 * c + 409 * e + 128) >> 8).clamp(0, 255);
      final g = ((298 * c - 100 * d - 208 * e + 128) >> 8).clamp(0, 255);
      final b = ((298 * c + 516 * d + 128) >> 8).clamp(0, 255);

      out[di] = r;
      out[di + 1] = g;
      out[di + 2] = b;
      out[di + 3] = 255;
      di += 4;
    }
  }
  return out;
}

RgbaFrame _downscaleRgba(Uint8List src, int width, int height, int maxSide) {
  final longSide = width > height ? width : height;
  if (longSide <= maxSide) {
    return RgbaFrame(src, width, height);
  }

  final scale = maxSide / longSide;
  final nw = (width * scale).round().clamp(1, width);
  final nh = (height * scale).round().clamp(1, height);
  final out = Uint8List(nw * nh * 4);

  for (var y = 0; y < nh; y++) {
    final sy = (y * height / nh).floor().clamp(0, height - 1);
    for (var x = 0; x < nw; x++) {
      final sx = (x * width / nw).floor().clamp(0, width - 1);
      final si = (sy * width + sx) * 4;
      final di = (y * nw + x) * 4;
      out[di] = src[si];
      out[di + 1] = src[si + 1];
      out[di + 2] = src[si + 2];
      out[di + 3] = src[si + 3];
    }
  }
  return RgbaFrame(out, nw, nh);
}
