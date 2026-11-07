import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../face_ncnn/face_ncnn_ffi.dart';
import 'face_gallery.dart';

/// Đăng ký khuôn mặt vào gallery **1:N** (nhiều người, mỗi người nhiều mẫu).
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
  String? _lastPersonId;

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
        _status =
            'Gallery 1:N: ${_gallery.count} người / ${_gallery.sampleCount} mẫu\nNhập tên → Đăng ký người mới (hoặc Thêm mẫu)';
        _nameCtrl.text = context.read<AuthProvider>().user?.name ?? '';
      });
    } catch (e) {
      setState(() => _status = 'Lỗi: $e');
    }
  }

  Future<Float32List?> _captureEmbedding() async {
    final shot = await _cam!.takePicture();
    final bytes = await shot.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final decoded = frame.image;
    final bd = await decoded.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (bd == null) throw Exception('Không đọc được ảnh');
    final r = FaceNcnn.instance
        .infer(bd.buffer.asUint8List(), decoded.width, decoded.height);
    if (r.emb == null || r.box == null) {
      throw Exception('Không thấy khuôn mặt — thử lại');
    }
    return r.emb;
  }

  Future<void> _registerNew() async {
    if (_busy || _cam == null || !_cam!.value.isInitialized) return;
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nhập tên người cần đăng ký')),
      );
      return;
    }
    setState(() {
      _busy = true;
      _status = 'Đang đăng ký người mới vào gallery 1:N...';
    });
    try {
      final emb = await _captureEmbedding();
      if (emb == null) throw Exception('Embedding rỗng');
      final profile = await _gallery.registerPerson(name: name, embedding: emb);
      _lastPersonId = profile.id;
      if (!mounted) return;
      setState(() => _status =
          'Đã thêm "${profile.name}" (id ${profile.id})\nGallery: ${_gallery.count} người / ${_gallery.sampleCount} mẫu');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('1:N — đã đăng ký: ${profile.name}')),
      );
    } catch (e) {
      setState(() => _status = 'Lỗi: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _addSample() async {
    if (_busy || _cam == null) return;
    final id = _lastPersonId;
    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Đăng ký người mới trước, rồi thêm mẫu')),
      );
      return;
    }
    setState(() {
      _busy = true;
      _status = 'Thêm mẫu embedding cho người vừa đăng ký...';
    });
    try {
      final emb = await _captureEmbedding();
      if (emb == null) throw Exception('Embedding rỗng');
      await _gallery.addSample(id, emb);
      if (!mounted) return;
      setState(() => _status =
          'Đã thêm mẫu. Gallery: ${_gallery.count} người / ${_gallery.sampleCount} mẫu');
    } catch (e) {
      setState(() => _status = 'Lỗi: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _deletePerson(FaceProfile p) async {
    await _gallery.remove(p.id);
    if (_lastPersonId == p.id) _lastPersonId = null;
    setState(() => _status =
        'Đã xoá ${p.name}. Còn ${_gallery.count} người trong gallery 1:N');
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
      appBar: AppBar(title: const Text('Đăng ký mặt (1:N)')),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: _cam == null || !_cam!.value.isInitialized
                ? Center(child: Text(_status, textAlign: TextAlign.center))
                : CameraPreview(_cam!),
          ),
          Expanded(
            flex: 2,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(_status, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Tên người (mỗi người = 1 mục trong 1:N)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: _busy ? null : _registerNew,
                        child: const Text('Đăng ký người mới'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _busy ? null : _addSample,
                        child: const Text('Thêm mẫu'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text('Danh sách gallery (${_gallery.count})',
                    style: Theme.of(context).textTheme.titleSmall),
                ..._gallery.profiles.map(
                  (p) => ListTile(
                    dense: true,
                    title: Text(p.name),
                    subtitle: Text('${p.embeddings.length} mẫu · ${p.id}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _deletePerson(p),
                    ),
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
