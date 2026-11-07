import 'dart:typed_data';
import 'dart:ui' as ui;

import 'face_ncnn_ffi.dart';

class FacePhotoResult {
  FacePhotoResult({required this.emb, required this.box, required this.score});
  final Float32List emb;
  final FaceBox box;
  final double score;
}

/// Decode photo bytes → face embedding + box (thử vài kích thước).
Future<FacePhotoResult> detectEmbedFromPhotoBytes(
  Uint8List bytes, {
  int maxSide = 720,
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

  final targets = <({int? tw, int? th})>[
    (tw: null, th: null),
    (tw: maxSide, th: null),
    (tw: 480, th: null),
    (tw: 320, th: null),
  ];

  FacePhotoResult? best;
  int lastCount = 0;

  for (final t in targets) {
    final img = await decodeAt(t.tw, t.th);
    // Bỏ ảnh quá nhỏ / quá lớn sau decode
    if (img.width < 64 || img.height < 64) continue;
    if (img.width > 2000 || img.height > 2000) continue;

    final bd = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (bd == null) continue;
    final r = FaceNcnn.instance.infer(
      bd.buffer.asUint8List(),
      img.width,
      img.height,
    );
    lastCount = r.count;
    if (r.count < 0) {
      throw StateError('Nhận diện lỗi (mã ${r.count}). Thử lại.');
    }
    if (r.emb != null && r.box != null) {
      final score = r.box!.score;
      if (best == null || score > best.score) {
        best = FacePhotoResult(emb: r.emb!, box: r.box!, score: score);
      }
      // Đủ tốt thì dừng sớm
      if (score >= 0.7) break;
    }
  }

  if (best == null) {
    throw StateError(
      lastCount == 0
          ? 'Không thấy khuôn mặt.\n'
              'Đưa cả mặt vào khung, nhìn thẳng, đủ sáng.'
          : 'Phát hiện mặt nhưng không lấy được đặc trưng.\nThử ảnh khác.',
    );
  }
  return best;
}

Future<Float32List> embeddingFromPhotoBytes(
  Uint8List bytes, {
  int maxSide = 720,
}) async {
  final r = await detectEmbedFromPhotoBytes(bytes, maxSide: maxSide);
  return r.emb;
}
