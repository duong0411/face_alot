import 'dart:async';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../../core/config.dart';
import '../../core/mqtt/door_mqtt.dart';
import '../../face_ncnn/face_ncnn_ffi.dart';
import 'face_gallery.dart';

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
        setState(() => _status = 'Chưa đăng ký mặt — hãy đăng ký trước');
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
        _status = 'Realtime: đưa mặt vào khung';
      });
      _timer = Timer.periodic(const Duration(milliseconds: 700), (_) => _tick());
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
      final r = FaceNcnn.instance.infer(bd.buffer.asUint8List(), img.width, img.height);
      if (r.emb == null) {
        setState(() {
          _status = 'Không thấy mặt';
          _lastName = null;
        });
        return;
      }
      final match = _gallery.bestMatch(r.emb!, FaceNcnn.instance.cosine);
      setState(() {
        _lastScore = match.score;
        _lastName = match.match?.name;
        _status = match.match == null
            ? 'Unknown (${match.score.toStringAsFixed(2)})'
            : '${match.match!.name} · ${match.score.toStringAsFixed(2)}';
      });

      if (match.match != null && match.score >= AppConfig.matchThreshold) {
        final now = DateTime.now();
        if (now.difference(_lastOpen).inMilliseconds >= AppConfig.doorCooldownMs) {
          _lastOpen = now;
          await _mqtt.openDoor(name: match.match!.name);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Đã mở cửa: ${match.match!.name}')),
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
      appBar: AppBar(title: const Text('Mở cửa bằng mặt')),
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
                            style: const TextStyle(color: Colors.white, fontSize: 16),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              _lastName == null
                  ? 'Ngưỡng: ${AppConfig.matchThreshold}'
                  : 'Match: $_lastName (${_lastScore.toStringAsFixed(2)})',
            ),
          ),
        ],
      ),
    );
  }
}
