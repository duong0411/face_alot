import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/face_api.dart';
import '../../core/providers/auth_provider.dart';
import '../../face_ncnn/face_ncnn_ffi.dart';

/// Đăng ký mặt → MongoDB Docker (public qua https://duynguyen.io.vn/api/faces).
class FaceRegisterScreen extends StatefulWidget {
  const FaceRegisterScreen({super.key});

  @override
  State<FaceRegisterScreen> createState() => _FaceRegisterScreenState();
}

class _FaceRegisterScreenState extends State<FaceRegisterScreen> {
  CameraController? _cam;
  final _api = FaceApi();
  final _nameCtrl = TextEditingController();
  final List<Map<String, dynamic>> _people = [];
  String _status = 'Đang khởi tạo...';
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
      await _reloadList();
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
        _nameCtrl.text = context.read<AuthProvider>().user?.name ?? '';
        _status =
            'Gallery MongoDB: ${_people.length} người\nAPI: duynguyen.io.vn/api/faces';
      });
    } catch (e) {
      setState(() => _status = 'Lỗi: $e');
    }
  }

  Future<void> _reloadList() async {
    final list = await _api.list();
    if (!mounted) return;
    setState(() {
      _people
        ..clear()
        ..addAll(list);
    });
  }

  Future<Float32List> _captureEmbedding() async {
    final shot = await _cam!.takePicture();
    final bytes = await shot.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final decoded = frame.image;
    final bd = await decoded.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (bd == null) throw Exception('Không đọc được ảnh');
    final r = FaceNcnn.instance
        .infer(bd.buffer.asUint8List(), decoded.width, decoded.height);
    if (r.emb == null) throw Exception('Không thấy khuôn mặt');
    return r.emb!;
  }

  Future<void> _registerNew() async {
    if (_busy || _cam == null) return;
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nhập tên người')),
      );
      return;
    }
    setState(() {
      _busy = true;
      _status = 'Upload embedding → MongoDB...';
    });
    try {
      final emb = await _captureEmbedding();
      final data = await _api.register(name: name, embedding: emb);
      _lastPersonId = '${data['personId']}';
      await _reloadList();
      if (!mounted) return;
      setState(() => _status =
          'Đã lưu MongoDB: ${data['name']} (${data['sampleCount']} mẫu)');
    } catch (e) {
      setState(() => _status = 'Lỗi: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _addSample() async {
    if (_busy || _lastPersonId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đăng ký người mới trước')),
      );
      return;
    }
    setState(() {
      _busy = true;
      _status = 'Thêm mẫu → MongoDB...';
    });
    try {
      final emb = await _captureEmbedding();
      final data =
          await _api.addSample(personId: _lastPersonId!, embedding: emb);
      await _reloadList();
      setState(() => _status = 'Sample OK · ${data['sampleCount']} mẫu');
    } catch (e) {
      setState(() => _status = 'Lỗi: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _delete(String personId) async {
    await _api.remove(personId);
    if (_lastPersonId == personId) _lastPersonId = null;
    await _reloadList();
    setState(() => _status = 'Đã xoá $personId trên MongoDB');
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
      appBar: AppBar(title: const Text('Đăng ký mặt → MongoDB')),
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
                    labelText: 'Tên (1:N trên server)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: _busy ? null : _registerNew,
                        child: const Text('Đăng ký → Mongo'),
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
                Text('Gallery server (${_people.length})',
                    style: Theme.of(context).textTheme.titleSmall),
                ..._people.map(
                  (p) => ListTile(
                    dense: true,
                    title: Text('${p['name']}'),
                    subtitle: Text(
                        '${p['sampleCount']} mẫu · ${p['personId']}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _delete('${p['personId']}'),
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
