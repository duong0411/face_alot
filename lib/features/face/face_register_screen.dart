import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/api/face_api.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/home_atmosphere.dart';
import '../../face_ncnn/face_image.dart';
import '../../face_ncnn/face_ncnn_ffi.dart' show FaceNcnn;

class FaceRegisterScreen extends StatefulWidget {
  const FaceRegisterScreen({super.key});

  @override
  State<FaceRegisterScreen> createState() => _FaceRegisterScreenState();
}

class _FaceRegisterScreenState extends State<FaceRegisterScreen> {
  final _api = FaceApi();
  final _picker = ImagePicker();
  final _nameCtrl = TextEditingController();
  final List<Map<String, dynamic>> _people = [];

  Uint8List? _preview;
  double? _faceScore;
  String _status = 'Chụp hoặc tải ảnh mặt nhìn thẳng';
  bool _busy = false;
  bool _ready = false;
  bool _detecting = false;
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
      if (!mounted) return;
      setState(() {
        _ready = true;
        _nameCtrl.text = context.read<AuthProvider>().user?.name ?? '';
        _status = 'Chụp hoặc tải ảnh → hệ thống tự kiểm tra mặt';
      });
    } catch (e) {
      setState(() => _status = 'Không khởi tạo nhận diện: $e');
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

  Future<void> _pick(ImageSource source) async {
    if (_busy || !_ready || _detecting) return;
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 90,
        preferredCameraDevice: CameraDevice.front,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _preview = bytes;
        _faceScore = null;
        _status = 'Đang kiểm tra khuôn mặt...';
        _detecting = true;
      });
      await _runDetect(bytes);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _detecting = false;
        _status = 'Không lấy được ảnh: $e';
      });
    }
  }

  Future<void> _runDetect(Uint8List bytes) async {
    try {
      final r = await detectEmbedFromPhotoBytes(bytes);
      if (!mounted) return;
      setState(() {
        _faceScore = r.score;
        _status =
            'Đã thấy mặt · độ tin cậy ${r.score.toStringAsFixed(2)} — có thể Đăng ký';
        _detecting = false;
      });
    } catch (e) {
      final msg =
          '$e'.replaceFirst('Bad state: ', '').replaceFirst('Exception: ', '');
      if (!mounted) return;
      setState(() {
        _faceScore = null;
        _status = msg;
        _detecting = false;
      });
    }
  }

  Future<Float32List> _embeddingFromPreview() async {
    final bytes = _preview;
    if (bytes == null || bytes.isEmpty) {
      throw StateError('Chưa có ảnh. Hãy chụp hoặc chọn ảnh trước.');
    }
    if (_faceScore == null) {
      final r = await detectEmbedFromPhotoBytes(bytes);
      return r.emb;
    }
    return embeddingFromPhotoBytes(bytes);
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
    );
  }

  Future<void> _registerNew() async {
    if (_busy || !_ready || _detecting) return;
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _toast('Nhập tên thành viên');
      return;
    }
    if (_preview == null) {
      _toast('Chụp hoặc chọn ảnh khuôn mặt trước');
      return;
    }
    if (_faceScore == null) {
      _toast('Chưa thấy khuôn mặt trong ảnh — chọn ảnh khác');
      return;
    }

    setState(() {
      _busy = true;
      _status = 'Đang lưu thành viên...';
    });
    try {
      final emb = await _embeddingFromPreview();
      final data = await _api.register(name: name, embedding: emb);
      _lastPersonId = '${data['personId']}';
      await _reloadList();
      if (!mounted) return;
      setState(() => _status =
          'Đã thêm ${data['name']} · ${data['sampleCount']} ảnh mẫu');
      _toast('Đã đăng ký ${data['name']}');
    } catch (e) {
      final msg =
          '$e'.replaceFirst('Bad state: ', '').replaceFirst('Exception: ', '');
      setState(() => _status = msg);
      if (mounted) _toast(msg.split('\n').first);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addSample() async {
    if (_busy || !_ready || _detecting) return;
    if (_lastPersonId == null) {
      _toast('Đăng ký thành viên mới trước, rồi thêm ảnh mẫu');
      return;
    }
    if (_preview == null || _faceScore == null) {
      _toast('Cần ảnh có khuôn mặt hợp lệ');
      return;
    }

    setState(() {
      _busy = true;
      _status = 'Đang thêm ảnh mẫu...';
    });
    try {
      final emb = await _embeddingFromPreview();
      final data =
          await _api.addSample(personId: _lastPersonId!, embedding: emb);
      await _reloadList();
      if (!mounted) return;
      setState(() => _status = 'Đã thêm mẫu · tổng ${data['sampleCount']} ảnh');
      _toast('Đã thêm ảnh mẫu');
    } catch (e) {
      final msg =
          '$e'.replaceFirst('Bad state: ', '').replaceFirst('Exception: ', '');
      setState(() => _status = msg);
      if (mounted) _toast(msg.split('\n').first);
    } finally {
      if (mounted) setState(() => _busy = false);
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
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final faceOk = _faceScore != null;

    return Scaffold(
      body: HomeAtmosphere(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            children: [
              Row(
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
                  if (_ready)
                    Text(
                      '${_people.length} TV',
                      style: TextStyle(
                        color: AppColors.inkSoft,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              SoftPanel(
                padding: EdgeInsets.zero,
                child: AspectRatio(
                  aspectRatio: 3 / 4,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (_preview != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: ColoredBox(
                            color: Colors.black12,
                            child: Image.memory(
                              _preview!,
                              fit: BoxFit.contain,
                            ),
                          ),
                        )
                      else
                        Container(
                          alignment: Alignment.center,
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.face_retouching_natural,
                                size: 56,
                                color: AppColors.sage.withValues(alpha: 0.55),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Chưa có ảnh\nĐể cả khuôn mặt trong khung',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.inkSoft,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (_detecting)
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black38,
                            borderRadius: BorderRadius.circular(22),
                          ),
                          alignment: Alignment.center,
                          child: const CircularProgressIndicator(
                            color: Colors.white,
                          ),
                        ),
                      if (_preview != null && !_detecting)
                        Positioned(
                          left: 12,
                          right: 12,
                          bottom: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: faceOk
                                  ? AppColors.ok.withValues(alpha: 0.92)
                                  : Colors.black.withValues(alpha: 0.65),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  faceOk
                                      ? Icons.check_circle_rounded
                                      : Icons.error_outline_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    faceOk
                                        ? 'Detect OK · ${_faceScore!.toStringAsFixed(2)}'
                                        : 'Không detect được mặt',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: (_busy || !_ready || _detecting)
                          ? null
                          : () => _pick(ImageSource.camera),
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('Chụp ảnh'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: (_busy || !_ready || _detecting)
                          ? null
                          : () => _pick(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('Tải ảnh lên'),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                _status,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: faceOk ? AppColors.sage : AppColors.inkSoft,
                      height: 1.35,
                      fontWeight: faceOk ? FontWeight.w600 : FontWeight.w400,
                    ),
              ),
              const SizedBox(height: 12),
              SoftPanel(
                child: Column(
                  children: [
                    TextField(
                      controller: _nameCtrl,
                      textCapitalization: TextCapitalization.words,
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
                            onPressed: (_busy || !_ready || !faceOk)
                                ? null
                                : _registerNew,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: _busy
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Đăng ký'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: (_busy || !_ready || !faceOk)
                                ? null
                                : _addSample,
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Text('Thêm ảnh mẫu'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
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
                      onTap: () {
                        setState(() {
                          _lastPersonId = '${p['personId']}';
                          _nameCtrl.text = '${p['name']}';
                          _status =
                              'Đã chọn ${p['name']} — có thể thêm ảnh mẫu';
                        });
                      },
                      selected: _lastPersonId == '${p['personId']}',
                      leading: CircleAvatar(
                        backgroundColor: AppColors.sage.withValues(alpha: 0.15),
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
      ),
    );
  }
}
