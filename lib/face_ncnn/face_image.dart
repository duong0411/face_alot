import 'dart:typed_data';
import 'dart:ui' as ui;

import 'face_ncnn_ffi.dart';

/// Decode photo bytes → face embedding (resize lớn để detector ổn định hơn).
Future<Float32List> embeddingFromPhotoBytes(
  Uint8List bytes, {
  int maxSide = 640,
}) async {
  await FaceNcnn.instance.ensureLoaded();

  Future<ui.Image> decodeAt(int? tw, int? th) async {
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: tw,
      targetHeight: th,
    );
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  var img = await decodeAt(null, null);
  if (img.width > maxSide || img.height > maxSide) {
    final landscape = img.width >= img.height;
    img = await decodeAt(
      landscape ? maxSide : null,
      landscape ? null : maxSide,
    );
  }

  // Thử kích thước gốc; nếu không thấy mặt, thử scale nhỏ hơn (selfie gần).
  final sizes = <ui.Image>[img];
  if (img.width > 480 && img.height > 480) {
    final landscape = img.width >= img.height;
    sizes.add(await decodeAt(
      landscape ? 480 : null,
      landscape ? null : 480,
    ));
  }

  Float32List? emb;
  for (final candidate in sizes) {
    final bd = await candidate.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (bd == null) continue;
    final r = FaceNcnn.instance.infer(
      bd.buffer.asUint8List(),
      candidate.width,
      candidate.height,
    );
    if (r.count < 0) {
      throw StateError('Nhận diện lỗi (mã ${r.count}). Thử lại.');
    }
    if (r.emb != null) {
      emb = r.emb;
      break;
    }
  }

  if (emb == null) {
    throw StateError(
      'Không thấy khuôn mặt trong ảnh.\n'
      'Hãy dùng ảnh rõ mặt, nhìn thẳng, đủ sáng, khoảng cách vừa phải.',
    );
  }
  return emb;
}
