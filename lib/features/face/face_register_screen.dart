import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/face_api.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/home_atmosphere.dart';
import '../../face_ncnn/face_ncnn_ffi.dart';

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
  String _status = 'Đang mở camera...';
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
        _status = 'Nhìn thẳng camera, rồi nhấn Đăng ký';
      });
    } catch (e) {
      setState(() => _status = 'Không mở được camera: $e');
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
        const SnackBar(content: Text('Nhập tên thành viên')),
      );
      return;
    }
    setState(() {
      _busy = true;
      _status = 'Đang lưu khuôn mặt...';
    });
    try {
      final emb = await _captureEmbedding();
      final data = await _api.register(name: name, embedding: emb);
      _lastPersonId = '${data['personId']}';
      await _reloadList();
      if (!mounted) return;
      setState(() => _status =
          'Đã thêm ${data['name']} · ${data['sampleCount']} ảnh mẫu');
    } catch (e) {
      setState(() => _status = 'Lỗi: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _addSample() async {
    if (_busy || _lastPersonId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đăng ký thành viên mới trước')),
      );
      return;
    }
    setState(() {
      _busy = true;
      _status = 'Đang thêm ảnh mẫu...';
    });
    try {
      final emb = await _captureEmbedding();
      final data =
          await _api.addSample(personId: _lastPersonId!, embedding: emb);
      await _reloadList();
      setState(() => _status = 'Đã thêm mẫu · tổng ${data['sampleCount']} ảnh');
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
    setState(() => _status = 'Đã xoá thành viên');
  }

  @override
  void dispose() {
    _cam?.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ready = _cam != null && _cam!.value.isInitialized;
    return Scaffold(
      body: HomeAtmosphere(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 16, 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    Expanded(
                      child: Text(
                        'Thêm thành viên',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 5,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: ready
                        ? CameraPreview(_cam!)
                        : Container(
                            color: AppColors.ink.withValues(alpha: 0.08),
                            alignment: Alignment.center,
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              _status,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.inkSoft),
                            ),
                          ),
                  ),
                ),
              ),
              Expanded(
                flex: 4,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  children: [
                    Text(
                      _status,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.inkSoft,
                          ),
                    ),
                    const SizedBox(height: 12),
                    SoftPanel(
                      child: Column(
                        children: [
                          TextField(
                            controller: _nameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Tên thành viên',
                              prefixIcon: Icon(Icons.person_outline_rounded),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton(
                                  onPressed: _busy ? null : _registerNew,
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                    child: Text('Đăng ký'),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _busy ? null : _addSample,
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                    child: Text('Thêm ảnh'),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Trong nhà (${_people.length})',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (_people.isEmpty)
                      Text(
                        'Chưa có ai — đăng ký người đầu tiên.',
                        style: TextStyle(color: AppColors.inkSoft),
                      ),
                    ..._people.map(
                      (p) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: SoftPanel(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundColor:
                                  AppColors.sage.withValues(alpha: 0.15),
                              foregroundColor: AppColors.sage,
                              child: Text(
                                () {
                                  final n = '${p['name']}';
                                  return n.isNotEmpty
                                      ? n.substring(0, 1).toUpperCase()
                                      : '?';
                                }(),
                              ),
                            ),
                            title: Text('${p['name']}'),
                            subtitle: Text('${p['sampleCount']} ảnh mẫu'),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline_rounded),
                              onPressed: () => _delete('${p['personId']}'),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
