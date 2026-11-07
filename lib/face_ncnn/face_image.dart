import 'dart:typed_data';
import 'dart:ui' as ui;

import 'face_ncnn_ffi.dart';

/// Decode photo bytes → face embedding (resize lớn để detector ổn định hơn).
Future<Float32List> embeddingFromPhotoBytes(
  Uint8List bytes, {
  int maxSide = 720,
}) async {
  await FaceNcnn.instance.ensureLoaded();

  var codec = await ui.instantiateImageCodec(bytes);
  var frame = await codec.getNextFrame();
  var img = frame.image;

  if (img.width > maxSide || img.height > maxSide) {
    final landscape = img.width >= img.height;
    codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: landscape ? maxSide : null,
      targetHeight: landscape ? null : maxSide,
    );
    frame = await codec.getNextFrame();
    img = frame.image;
  }

  final bd = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
  if (bd == null) {
    throw StateError('Không đọc được ảnh. Thử ảnh khác.');
  }

  final r = FaceNcnn.instance.infer(
    bd.buffer.asUint8List(),
    img.width,
    img.height,
  );

  if (r.count < 0) {
    throw StateError('Nhận diện lỗi (mã ${r.count}). Thử lại.');
  }
  if (r.emb == null) {
    throw StateError(
      'Không thấy khuôn mặt trong ảnh.\n'
      'Hãy dùng ảnh rõ mặt, nhìn thẳng, đủ sáng.',
    );
  }
  return r.emb!;
}
