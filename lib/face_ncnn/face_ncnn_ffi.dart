import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

typedef _InitNative = Int32 Function(
    Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>);
typedef _InitDart = int Function(
    Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>);

typedef _DetectNative = Int32 Function(Pointer<Uint8>, Int32, Int32,
    Pointer<Float>, Pointer<Float>, Pointer<Float>);
typedef _DetectDart = int Function(Pointer<Uint8>, int, int, Pointer<Float>,
    Pointer<Float>, Pointer<Float>);

typedef _CosNative = Float Function(Pointer<Float>, Pointer<Float>, Int32);
typedef _CosDart = double Function(Pointer<Float>, Pointer<Float>, int);

typedef _ReleaseNative = Void Function();
typedef _ReleaseDart = void Function();

class FaceBox {
  FaceBox(this.x1, this.y1, this.x2, this.y2, this.score);
  final double x1, y1, x2, y2, score;
}

class FaceNcnn {
  FaceNcnn._();
  static final FaceNcnn instance = FaceNcnn._();

  DynamicLibrary? _lib;
  _InitDart? _init;
  _DetectDart? _detect;
  _CosDart? _cosine;
  _ReleaseDart? _release;
  bool ready = false;

  Future<void> ensureLoaded() async {
    if (ready) return;
    try {
      _lib = _openLib();
    } catch (e) {
      throw StateError(
        'Không mở được thư viện NCNN native ($e). '
        'Android: dùng APK release. iOS: cần build có pod face_ncnn.',
      );
    }
    try {
      _init = _lib!.lookupFunction<_InitNative, _InitDart>('face_ncnn_init');
      _detect = _lib!
          .lookupFunction<_DetectNative, _DetectDart>('face_ncnn_detect_embed');
      _cosine = _lib!.lookupFunction<_CosNative, _CosDart>('face_ncnn_cosine');
      _release =
          _lib!.lookupFunction<_ReleaseNative, _ReleaseDart>('face_ncnn_release');
    } catch (e) {
      throw StateError(
        'Thiếu symbol face_ncnn_* trong app ($e).\n'
        'Bản IPA cũ chưa gắn native NCNN. Hãy cài APK Android '
        'hoặc IPA build mới (v1.0.5+) có face_ncnn.',
      );
    }

    final dir = await _prepareModels();
    final detP = p.join(dir, 'face_detect.param');
    final detB = p.join(dir, 'face_detect.bin');
    final recP = p.join(dir, 'mobilefacenet.param');
    final recB = p.join(dir, 'mobilefacenet.bin');

    final a = detP.toNativeUtf8();
    final b = detB.toNativeUtf8();
    final c = recP.toNativeUtf8();
    final d = recB.toNativeUtf8();
    try {
      final code = _init!(a, b, c, d);
      if (code != 0) {
        throw StateError('face_ncnn_init failed: $code');
      }
      ready = true;
      debugPrint('[FaceNcnn] ready');
    } finally {
      calloc.free(a);
      calloc.free(b);
      calloc.free(c);
      calloc.free(d);
    }
  }

  DynamicLibrary _openLib() {
    if (Platform.isAndroid) return DynamicLibrary.open('libface_ncnn.so');
    if (Platform.isIOS) return DynamicLibrary.process();
    if (Platform.isWindows) return DynamicLibrary.open('face_ncnn.dll');
    if (Platform.isMacOS) return DynamicLibrary.open('libface_ncnn.dylib');
    throw UnsupportedError('Unsupported platform');
  }

  Future<String> _prepareModels() async {
    final docs = await getApplicationSupportDirectory();
    // bump folder khi đổi model (YuNet → SCRFD-500m) để không dùng cache cũ
    final out = Directory(p.join(docs.path, 'ncnn_models_v2_scrfd500m'));
    if (!out.existsSync()) out.createSync(recursive: true);
    const files = [
      'face_detect.param',
      'face_detect.bin',
      'mobilefacenet.param',
      'mobilefacenet.bin',
    ];
    for (final f in files) {
      final dest = File(p.join(out.path, f));
      final data = await rootBundle.load('assets/models/$f');
      final bytes = data.buffer.asUint8List();
      if (dest.existsSync() && dest.lengthSync() == bytes.length) continue;
      await dest.writeAsBytes(bytes, flush: true);
    }
    return out.path;
  }

  /// RGBA8888 frame → largest face box + 128-d embedding.
  ({FaceBox? box, Float32List? emb, int count}) infer(
      Uint8List rgba, int width, int height) {
    if (!ready || _detect == null) {
      return (box: null, emb: null, count: 0);
    }
    final img = calloc<Uint8>(rgba.length);
    final box = calloc<Float>(4);
    final emb = calloc<Float>(128);
    final score = calloc<Float>(1);
    try {
      img.asTypedList(rgba.length).setAll(0, rgba);
      final n = _detect!(img, width, height, box, emb, score);
      if (n <= 0) return (box: null, emb: null, count: n);
      final fb = FaceBox(box[0], box[1], box[2], box[3], score[0]);
      final e = Float32List.fromList(emb.asTypedList(128));
      return (box: fb, emb: e, count: n);
    } finally {
      calloc.free(img);
      calloc.free(box);
      calloc.free(emb);
      calloc.free(score);
    }
  }

  double cosine(Float32List a, Float32List b) {
    if (!ready || _cosine == null) return 0;
    final pa = calloc<Float>(a.length);
    final pb = calloc<Float>(b.length);
    try {
      pa.asTypedList(a.length).setAll(0, a);
      pb.asTypedList(b.length).setAll(0, b);
      return _cosine!(pa, pb, a.length);
    } finally {
      calloc.free(pa);
      calloc.free(pb);
    }
  }

  void dispose() {
    _release?.call();
    ready = false;
  }
}
