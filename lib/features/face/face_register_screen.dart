import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../face_ncnn/face_ncnn_ffi.dart';
import 'face_gallery.dart';

class FaceRegisterScreen extends StatefulWidget {
  const FaceRegisterScreen({super.key});

  @override
  State<FaceRegisterScreen> createState() => _FaceRegisterScreenState();
}

class _FaceRegisterScreenState extends State<FaceRegisterScreen> {
  CameraController? _cam;
  final _gallery = FaceGallery();
  final _nameCtrl = TextEditingController();
  String _status = 'Đang khởi tạo NCNN...';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  Future<void> _setup() async {
    try {
      await FaceNcnn.instance.ensureLoaded();
      await _gallery.load();
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
        _status = 'Căn mặt vào khung rồi bấm Đăng ký';
        _nameCtrl.text = context.read<AuthProvider>().user?.name ?? '';
      });
    } catch (e) {
      setState(() => _status = 'Lỗi: $e');
    }
  }

  Future<void> _register() async {
    if (_busy || _cam == null || !_cam!.value.isInitialized) return;
    setState(() {
      _busy = true;
      _status = 'Đang chụp & trích xuất embedding...';
    });
    try {
      final shot = await _cam!.takePicture();
      final bytes = await shot.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final decoded = frame.image;
      final w = decoded.width;
      final h = decoded.height;
      final bd = await decoded.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (bd == null) throw Exception('Không đọc được ảnh');
      final rgba = bd.buffer.asUint8List();
      final r = FaceNcnn.instance.infer(rgba, w, h);
      if (r.emb == null || r.box == null) {
        throw Exception('Không thấy khuôn mặt — thử lại');
      }
      if (!mounted) return;
      final user = context.read<AuthProvider>().user;
      final name = _nameCtrl.text.trim().isEmpty
          ? (user?.name ?? 'User')
          : _nameCtrl.text.trim();
      await _gallery.upsert(FaceProfile(
        id: user?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        embedding: r.emb!,
      ));
      if (!mounted) return;
      setState(() =>
          _status = 'Đã đăng ký: $name (det ${r.box!.score.toStringAsFixed(2)})');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đăng ký mặt thành công: $name')),
      );
    } catch (e) {
      setState(() => _status = 'Lỗi: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _cam?.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Đăng ký khuôn mặt')),
      body: Column(
        children: [
          Expanded(
            child: _cam == null || !_cam!.value.isInitialized
                ? Center(child: Text(_status, textAlign: TextAlign.center))
                : CameraPreview(_cam!),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(_status, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Tên hiển thị',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: _busy ? null : _register,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                    child: Text('Đăng ký mặt'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
