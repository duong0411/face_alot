import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config.dart';

/// Một người trong gallery 1:N (có thể nhiều embedding / mẫu).
class FaceProfile {
  FaceProfile({
    required this.id,
    required this.name,
    required this.embeddings,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final String name;
  /// Nhiều mẫu cùng người → match lấy max cosine (ổn định hơn 1 ảnh).
  final List<Float32List> embeddings;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'embeddings': embeddings.map((e) => e.toList()).toList(),
        // tương thích bản cũ: 1 embedding
        'embedding': embeddings.isEmpty ? <double>[] : embeddings.first.toList(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory FaceProfile.fromJson(Map<String, dynamic> j) {
    final List<Float32List> embs = [];
    if (j['embeddings'] is List) {
      for (final e in (j['embeddings'] as List)) {
        embs.add(Float32List.fromList(
          (e as List).map((x) => (x as num).toDouble()).toList(),
        ));
      }
    } else if (j['embedding'] is List) {
      embs.add(Float32List.fromList(
        (j['embedding'] as List).map((x) => (x as num).toDouble()).toList(),
      ));
    }
    return FaceProfile(
      id: '${j['id']}',
      name: '${j['name']}',
      embeddings: embs,
      createdAt: DateTime.tryParse('${j['createdAt'] ?? ''}') ?? DateTime.now(),
    );
  }
}

class FaceMatchHit {
  FaceMatchHit({
    required this.profile,
    required this.score,
    required this.rank,
  });
  final FaceProfile profile;
  final double score;
  final int rank;
}

/// Kết quả identify 1:N.
class FaceIdentifyResult {
  FaceIdentifyResult({
    required this.hits,
    required this.accepted,
    required this.threshold,
  });

  /// Top-K theo cosine giảm dần (toàn gallery).
  final List<FaceMatchHit> hits;
  /// Người được chấp nhận nếu score ≥ threshold; null = unknown.
  final FaceProfile? accepted;
  final double threshold;

  FaceMatchHit? get best => hits.isEmpty ? null : hits.first;
  double get bestScore => best?.score ?? -1;
}

/// Gallery nhận diện khuôn mặt **1:N** (probe vs toàn bộ người đã đăng ký).
class FaceGallery {
  static const _key = 'face_gallery_v2';
  static const _keyLegacy = 'face_gallery_v1';

  final List<FaceProfile> profiles = [];

  int get count => profiles.length;
  int get sampleCount =>
      profiles.fold<int>(0, (a, p) => a + p.embeddings.length);

  Future<void> load() async {
    profiles.clear();
    final p = await SharedPreferences.getInstance();
    var raw = p.getString(_key);
    if (raw == null || raw.isEmpty) {
      raw = p.getString(_keyLegacy);
    }
    if (raw == null || raw.isEmpty) return;
    final list = jsonDecode(raw) as List;
    for (final e in list) {
      final profile =
          FaceProfile.fromJson(Map<String, dynamic>.from(e as Map));
      if (profile.embeddings.isNotEmpty) profiles.add(profile);
    }
    // migrate legacy → v2
    if (p.getString(_key) == null && profiles.isNotEmpty) {
      await save();
    }
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
      _key,
      jsonEncode(profiles.map((e) => e.toJson()).toList()),
    );
  }

  /// Thêm người mới (1:N — mỗi người một id riêng, không gắn user login).
  Future<FaceProfile> registerPerson({
    required String name,
    required Float32List embedding,
    String? id,
  }) async {
    final emb = _l2(embedding);
    final pid = id ??
        'face_${DateTime.now().millisecondsSinceEpoch}_${math.Random().nextInt(9999)}';
    final profile = FaceProfile(
      id: pid,
      name: name.trim().isEmpty ? 'Unknown' : name.trim(),
      embeddings: [emb],
    );
    profiles.add(profile);
    await save();
    return profile;
  }

  /// Thêm mẫu embedding cho người đã có (cải thiện 1:N).
  Future<void> addSample(String personId, Float32List embedding) async {
    final i = profiles.indexWhere((e) => e.id == personId);
    if (i < 0) return;
    final list = List<Float32List>.from(profiles[i].embeddings)..add(_l2(embedding));
    // giữ tối đa 5 mẫu / người
    while (list.length > 5) {
      list.removeAt(0);
    }
    profiles[i] = FaceProfile(
      id: profiles[i].id,
      name: profiles[i].name,
      embeddings: list,
      createdAt: profiles[i].createdAt,
    );
    await save();
  }

  /// Cập nhật tên / ghi đè nếu trùng id.
  Future<void> upsert(FaceProfile profile) async {
    final i = profiles.indexWhere((e) => e.id == profile.id);
    if (i >= 0) {
      profiles[i] = profile;
    } else {
      profiles.add(profile);
    }
    await save();
  }

  Future<void> remove(String id) async {
    profiles.removeWhere((e) => e.id == id);
    await save();
  }

  Future<void> clear() async {
    profiles.clear();
    await save();
  }

  /// Cosine similarity hai vector đã L2 (hoặc chưa — sẽ chuẩn hoá).
  static double cosine(Float32List a, Float32List b) {
    final n = math.min(a.length, b.length);
    if (n == 0) return 0;
    var na = 0.0, nb = 0.0, dot = 0.0;
    for (var i = 0; i < n; i++) {
      dot += a[i] * b[i];
      na += a[i] * a[i];
      nb += b[i] * b[i];
    }
    na = math.sqrt(na);
    nb = math.sqrt(nb);
    if (na < 1e-9 || nb < 1e-9) return 0;
    return dot / (na * nb);
  }

  /// Điểm người = **max** cosine trên mọi mẫu của người đó.
  double scoreAgainst(Float32List probe, FaceProfile person) {
    var best = -1.0;
    final p = _l2(probe);
    for (final e in person.embeddings) {
      final s = cosine(p, e);
      if (s > best) best = s;
    }
    return best;
  }

  /// **1:N identify**: so probe với toàn gallery, trả top-K + người được chấp nhận theo ngưỡng.
  FaceIdentifyResult identify(
    Float32List probe, {
    double? threshold,
    int topK = 5,
    double Function(Float32List, Float32List)? cosineFn,
  }) {
    final thr = threshold ?? AppConfig.matchThreshold;
    final hits = <FaceMatchHit>[];

    for (final person in profiles) {
      double score;
      if (cosineFn != null) {
        // tương thích FFI cosine: lấy max trên samples
        var best = -1.0;
        for (final e in person.embeddings) {
          final s = cosineFn(probe, e);
          if (s > best) best = s;
        }
        score = best;
      } else {
        score = scoreAgainst(probe, person);
      }
      hits.add(FaceMatchHit(profile: person, score: score, rank: 0));
    }

    hits.sort((a, b) => b.score.compareTo(a.score));
    final ranked = <FaceMatchHit>[];
    for (var i = 0; i < hits.length && i < topK; i++) {
      ranked.add(FaceMatchHit(
        profile: hits[i].profile,
        score: hits[i].score,
        rank: i + 1,
      ));
    }

    FaceProfile? accepted;
    if (ranked.isNotEmpty && ranked.first.score >= thr) {
      // margin: best phải hơn hạng 2 một chút để tránh nhầm 1:N
      final marginOk = ranked.length < 2 ||
          (ranked.first.score - ranked[1].score) >= 0.03 ||
          ranked[1].score < thr;
      if (marginOk) accepted = ranked.first.profile;
    }

    return FaceIdentifyResult(
      hits: ranked,
      accepted: accepted,
      threshold: thr,
    );
  }

  /// Alias cũ — luôn trả best + score (kể cả dưới ngưỡng). Prefer [identify].
  ({FaceProfile? match, double score}) bestMatch(
    Float32List emb,
    double Function(Float32List, Float32List) cosineFn,
  ) {
    final r = identify(emb, cosineFn: cosineFn, threshold: -1);
    return (match: r.best?.profile, score: r.bestScore);
  }

  static Float32List _l2(Float32List v) {
    var s = 0.0;
    for (var i = 0; i < v.length; i++) {
      s += v[i] * v[i];
    }
    s = math.sqrt(s);
    if (s < 1e-9) return Float32List.fromList(v);
    final out = Float32List(v.length);
    for (var i = 0; i < v.length; i++) {
      out[i] = v[i] / s;
    }
    return out;
  }
}
