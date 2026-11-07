import 'dart:async';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../core/api/face_api.dart';
import '../../core/config.dart';
import '../../core/mqtt/door_mqtt.dart';
import '../../face_ncnn/face_ncnn_ffi.dart';

/// NCNN trên máy → embedding → **identify 1:N trên MongoDB** (API public).
class FaceUnlockScreen extends StatefulWidget {
  const FaceUnlockScreen({super.key});

  @override
  State<FaceUnlockScreen> createState() => _FaceUnlockScreenState();
}

class _FaceUnlockScreenState extends State<FaceUnlockScreen> {
  CameraController? _cam;
  final _api = FaceApi();
  final _mqtt = DoorMqtt();
  Timer? _timer;
  String _status = 'Khởi tạo...';
  String? _lastName;
  double _lastScore = 0;
  List<dynamic> _topHits = [];
  int _gallerySize = 0;
  DateTime _lastOpen = DateTime.fromMillisecondsSinceEpoch(0);
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  Future<void> _setup() async {
    try {
      await FaceNcnn.instance.ensureLoaded();
      final list = await _api.list();
      _gallerySize = list.length;
      if (list.isEmpty) {
        setState(() =>
            _status = 'MongoDB gallery trống — đăng ký mặt trên server trước');
        return;
      }
      final cams = await availableCameras();
      final front = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cams.first,
      );
      final ctrl = CameraController(
        front,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.bgra8888,
      );
      await ctrl.initialize();
      if (!mounted) return;
      setState(() {
        _cam = ctrl;
        _status =
            '1:N MongoDB · N=$_gallerySize · API duynguyen.io.vn';
      });
      _timer =
          Timer.periodic(const Duration(milliseconds: 900), (_) => _tick());
    } catch (e) {
      setState(() => _status = 'Lỗi: $e');
    }
  }

  Future<void> _tick() async {
    if (_processing || _cam == null || !_cam!.value.isInitialized) return;
    _processing = true;
    try {
      final shot = await _cam!.takePicture();
      final bytes = await shot.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final img = frame.image;
      final bd = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (bd == null) return;
      final r = FaceNcnn.instance
          .infer(bd.buffer.asUint8List(), img.width, img.height);
      if (r.emb == null) {
        setState(() {
          _status = 'Không thấy mặt';
          _lastName = null;
          _topHits = [];
        });
        return;
      }

      final id = await _api.identify(
        embedding: r.emb!,
        threshold: AppConfig.matchThreshold,
        topK: 3,
      );
      final accepted = id['accepted'] as Map<String, dynamic>?;
      final hits = (id['hits'] as List?) ?? [];
      _gallerySize = (id['gallerySize'] as num?)?.toInt() ?? _gallerySize;

      setState(() {
        _topHits = hits;
        if (accepted != null) {
          _lastName = '${accepted['name']}';
          _lastScore = (accepted['score'] as num).toDouble();
          _status =
              'OK Mongo 1:N → $_lastName (${_lastScore.toStringAsFixed(2)})';
        } else if (hits.isNotEmpty) {
          final best = hits.first as Map<String, dynamic>;
          _lastName = null;
          _lastScore = (best['score'] as num).toDouble();
          _status =
              'Unknown · gần: ${best['name']} (${_lastScore.toStringAsFixed(2)})';
        } else {
          _status = 'Gallery trống trên MongoDB';
        }
      });

      if (accepted != null) {
        final now = DateTime.now();
        if (now.difference(_lastOpen).inMilliseconds >=
            AppConfig.doorCooldownMs) {
          _lastOpen = now;
          final name = '${accepted['name']}';
          await _mqtt.openDoor(name: name);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Mongo 1:N → mở cửa: $name')),
          );
        }
      }
    } catch (e) {
      setState(() => _status = 'Lỗi: $e');
    } finally {
      _processing = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cam?.dispose();
    _mqtt.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mở cửa 1:N (MongoDB)')),
      body: Column(
        children: [
          Expanded(
            child: _cam == null || !_cam!.value.isInitialized
                ? Center(child: Text(_status, textAlign: TextAlign.center))
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      CameraPreview(_cam!),
                      Positioned(
                        left: 16,
                        right: 16,
                        bottom: 16,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _status,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 15),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
          if (_topHits.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Top-K (server MongoDB)',
                      style: Theme.of(context).textTheme.titleSmall),
                  ..._topHits.map((h) {
                    final m = h as Map<String, dynamic>;
                    return Text(
                      '#${m['rank']} ${m['name']}  ${(m['score'] as num).toStringAsFixed(3)}',
                    );
                  }),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'N=$_gallerySize · thr ${AppConfig.matchThreshold} · host API public',
            ),
          ),
        ],
      ),
    );
  }
}
