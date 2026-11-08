import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../core/api/face_api.dart';
import '../../core/config.dart';
import '../../core/mqtt/door_mqtt.dart';
import '../../core/theme/app_theme.dart';
import '../../face_ncnn/camera_rgba.dart';
import '../../face_ncnn/face_ncnn_ffi.dart';
import 'face_register_screen.dart';

class FaceUnlockScreen extends StatefulWidget {
  const FaceUnlockScreen({super.key});

  @override
  State<FaceUnlockScreen> createState() => _FaceUnlockScreenState();
}

class _FaceUnlockScreenState extends State<FaceUnlockScreen> {
  static const _minInferGap = Duration(milliseconds: 280);

  CameraController? _cam;
  final _api = FaceApi();
  final _mqtt = DoorMqtt();
  String _status = 'Đang chuẩn bị...';
  String? _lastName;
  double _lastScore = 0;
  bool _matched = false;
  int _gallerySize = 0;
  bool _emptyGallery = false;
  bool _camFailed = false;
  DateTime _lastOpen = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastInfer = DateTime.fromMillisecondsSinceEpoch(0);
  bool _processing = false;
  bool _streaming = false;

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
        if (!mounted) return;
        setState(() {
          _emptyGallery = true;
          _status = 'Chưa có thành viên';
        });
        return;
      }
      final cams = await availableCameras();
      if (cams.isEmpty) {
        setState(() {
          _camFailed = true;
          _status = 'Không tìm thấy camera trên máy';
        });
        return;
      }
      final front = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cams.first,
      );

      CameraController? ctrl;
      Object? lastErr;
      for (final fmt in [
        ImageFormatGroup.bgra8888,
        ImageFormatGroup.yuv420,
      ]) {
        final c = CameraController(
          front,
          ResolutionPreset.medium,
          enableAudio: false,
          imageFormatGroup: fmt,
        );
        try {
          await c.initialize();
          ctrl = c;
          break;
        } catch (e) {
          lastErr = e;
          await c.dispose();
        }
      }
      if (ctrl == null) {
        throw lastErr ?? StateError('Không khởi tạo camera');
      }

      if (!mounted) {
        await ctrl.dispose();
        return;
      }
      setState(() {
        _cam = ctrl;
        _status = 'Đang nhận diện...';
      });
      await _startStream();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _camFailed = true;
        _status = 'Không mở được nhận diện: $e';
      });
    }
  }

  Future<void> _startStream() async {
    final cam = _cam;
    if (cam == null || !cam.value.isInitialized || _streaming) return;
    await cam.startImageStream(_onFrame);
    _streaming = true;
  }

  Future<void> _stopStream() async {
    final cam = _cam;
    if (cam == null || !_streaming) {
      _streaming = false;
      return;
    }
    try {
      if (cam.value.isStreamingImages) {
        await cam.stopImageStream();
      }
    } catch (_) {}
    _streaming = false;
  }

  void _onFrame(CameraImage image) {
    if (!mounted || _processing) return;
    final now = DateTime.now();
    if (now.difference(_lastInfer) < _minInferGap) return;
    _lastInfer = now;
    _processing = true;
    // ignore: discarded_futures
    _processFrame(image).whenComplete(() => _processing = false);
  }

  Future<void> _processFrame(CameraImage image) async {
    try {
      final frame = cameraImageToRgba(image, maxSide: 640);
      if (frame == null) return;

      final r = FaceNcnn.instance.infer(frame.bytes, frame.width, frame.height);
      if (r.emb == null) {
        if (!mounted) return;
        setState(() {
          _status = 'Chưa thấy khuôn mặt';
          _lastName = null;
          _matched = false;
        });
        return;
      }

      final id = await _api.identify(
        embedding: r.emb!,
        threshold: AppConfig.matchThreshold,
        topK: 3,
      );
      if (!mounted) return;

      final accepted = id['accepted'] as Map<String, dynamic>?;
      _gallerySize = (id['gallerySize'] as num?)?.toInt() ?? _gallerySize;

      setState(() {
        if (accepted != null) {
          _matched = true;
          _lastName = '${accepted['name']}';
          _lastScore = (accepted['score'] as num).toDouble();
          _status = 'Xin chào $_lastName';
        } else {
          _matched = false;
          _lastName = null;
          final hits = (id['hits'] as List?) ?? [];
          if (hits.isNotEmpty) {
            final best = hits.first as Map<String, dynamic>;
            _lastScore = (best['score'] as num).toDouble();
            _status =
                'Chưa khớp · gần nhất ${_lastScore.toStringAsFixed(2)}';
          } else {
            _status = 'Đang nhận diện...';
          }
        }
      });

      if (accepted != null) {
        final t = DateTime.now();
        if (t.difference(_lastOpen).inMilliseconds >= AppConfig.doorCooldownMs) {
          _lastOpen = t;
          final name = '${accepted['name']}';
          await _mqtt.openDoor(name: name);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Đã mở cửa cho $name')),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'Lỗi: $e');
    }
  }

  Future<void> _goRegister() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FaceRegisterScreen()),
    );
    if (!mounted) return;
    await _stopStream();
    await _cam?.dispose();
    _cam = null;
    setState(() {
      _emptyGallery = false;
      _camFailed = false;
      _status = 'Đang chuẩn bị...';
      _matched = false;
      _lastName = null;
    });
    await _setup();
  }

  @override
  void dispose() {
    // stopImageStream must finish before dispose; fire-and-forget is ok here
    final cam = _cam;
    _cam = null;
    _streaming = false;
    if (cam != null) {
      () async {
        try {
          if (cam.value.isStreamingImages) await cam.stopImageStream();
        } catch (_) {}
        await cam.dispose();
      }();
    }
    _mqtt.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ready = _cam != null && _cam!.value.isInitialized;

    if (_emptyGallery || _camFailed) {
      return Scaffold(
        backgroundColor: AppColors.ink,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_rounded,
                          color: Colors.white),
                    ),
                    Expanded(
                      child: Text(
                        'Mở cửa',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Icon(
                  _emptyGallery
                      ? Icons.person_off_outlined
                      : Icons.videocam_off_outlined,
                  size: 64,
                  color: Colors.white54,
                ),
                const SizedBox(height: 20),
                Text(
                  _emptyGallery
                      ? 'Chưa có thành viên'
                      : 'Không mở được camera',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _emptyGallery
                      ? 'Thêm khuôn mặt trước, rồi quay lại để mở cửa.'
                      : _status,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    height: 1.4,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 28),
                if (_emptyGallery)
                  FilledButton.icon(
                    onPressed: _goRegister,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.sage,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    label: const Text('Thêm thành viên'),
                  ),
                const Spacer(flex: 2),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.ink,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (ready)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _cam!.value.previewSize?.height ?? 720,
                height: _cam!.value.previewSize?.width ?? 1280,
                child: CameraPreview(_cam!),
              ),
            )
          else
            const Center(
              child: CircularProgressIndicator(color: Colors.white54),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: Colors.white),
                  ),
                  Expanded(
                    child: Text(
                      'Mở cửa',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                          ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$_gallerySize TV',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (ready)
            IgnorePointer(
              child: CustomPaint(
                painter: _FaceFramePainter(matched: _matched),
                child: const SizedBox.expand(),
              ),
            ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 28,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              decoration: BoxDecoration(
                color: _matched
                    ? AppColors.ok.withValues(alpha: 0.92)
                    : Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _status,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (_matched) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Độ khớp ${_lastScore.toStringAsFixed(2)} · cửa đang mở',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FaceFramePainter extends CustomPainter {
  _FaceFramePainter({required this.matched});
  final bool matched;

  @override
  void paint(Canvas canvas, Size size) {
    final color = matched ? AppColors.ok : Colors.white.withValues(alpha: 0.7);
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final w = size.width * 0.62;
    final h = size.height * 0.38;
    final left = (size.width - w) / 2;
    final top = size.height * 0.22;
    final len = 28.0;

    void corner(double x, double y, double dx, double dy) {
      canvas.drawLine(Offset(x, y), Offset(x + dx, y), paint);
      canvas.drawLine(Offset(x, y), Offset(x, y + dy), paint);
    }

    corner(left, top, len, len);
    corner(left + w, top, -len, len);
    corner(left, top + h, len, -len);
    corner(left + w, top + h, -len, -len);
  }

  @override
  bool shouldRepaint(covariant _FaceFramePainter oldDelegate) =>
      oldDelegate.matched != matched;
}
