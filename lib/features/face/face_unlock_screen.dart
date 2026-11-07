import 'dart:async';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../../core/config.dart';
import '../../core/mqtt/door_mqtt.dart';
import '../../face_ncnn/face_ncnn_ffi.dart';
import 'face_gallery.dart';

/// Nhận diện realtime **1:N**: embedding probe so với toàn gallery.
class FaceUnlockScreen extends StatefulWidget {
  const FaceUnlockScreen({super.key});

  @override
  State<FaceUnlockScreen> createState() => _FaceUnlockScreenState();
}

class _FaceUnlockScreenState extends State<FaceUnlockScreen> {
  CameraController? _cam;
  final _gallery = FaceGallery();
  final _mqtt = DoorMqtt();
  Timer? _timer;
  String _status = 'Khởi tạo...';
  String? _lastName;
  double _lastScore = 0;
  List<FaceMatchHit> _topHits = [];
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
      await _gallery.load();
      if (_gallery.profiles.isEmpty) {
        setState(() => _status = 'Gallery trống — đăng ký ít nhất 1 người (1:N)');
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
            '1:N · ${_gallery.count} người · ngưỡng ${AppConfig.matchThreshold}';
      });
      _timer = Timer.periodic(const Duration(milliseconds: 800), (_) => _tick());
    } catch (e) {
      setState(() => _status = 'Lỗi: $e');
    }
  }

  Future<void> _tick() async {
    if (_processing || _cam == null || !_cam!.value.isInitialized) return;
    if (!mounted) return;
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

      // 1:N identify trên toàn gallery
      final id = _gallery.identify(
        r.emb!,
        threshold: AppConfig.matchThreshold,
        topK: 3,
        cosineFn: FaceNcnn.instance.cosine,
      );

      setState(() {
        _topHits = id.hits;
        _lastScore = id.bestScore;
        if (id.accepted != null) {
          _lastName = id.accepted!.name;
          _status =
              'OK 1:N → ${id.accepted!.name} (${id.bestScore.toStringAsFixed(2)})';
        } else if (id.best != null) {
          _lastName = null;
          _status =
              'Unknown · gần nhất: ${id.best!.profile.name} (${id.bestScore.toStringAsFixed(2)}) < ${id.threshold}';
        } else {
          _lastName = null;
          _status = 'Gallery trống';
        }
      });

      if (id.accepted != null) {
        final now = DateTime.now();
        if (now.difference(_lastOpen).inMilliseconds >= AppConfig.doorCooldownMs) {
          _lastOpen = now;
          await _mqtt.openDoor(name: id.accepted!.name);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '1:N match → mở cửa: ${id.accepted!.name} (${id.bestScore.toStringAsFixed(2)})'),
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _status = 'Infer lỗi: $e');
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
      appBar: AppBar(title: const Text('Mở cửa 1:N')),
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
                  Text('Top-K 1:N',
                      style: Theme.of(context).textTheme.titleSmall),
                  ..._topHits.map(
                    (h) => Text(
                      '#${h.rank} ${h.profile.name}  ${h.score.toStringAsFixed(3)}'
                      '${_lastName == h.profile.name ? "  ✓" : ""}',
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              _lastName == null
                  ? 'Ngưỡng accept: ${AppConfig.matchThreshold} · N=${_gallery.count}'
                  : 'Accepted: $_lastName (${_lastScore.toStringAsFixed(2)})',
            ),
          ),
        ],
      ),
    );
  }
}
