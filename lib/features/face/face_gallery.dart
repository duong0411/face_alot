import 'dart:convert';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';

class FaceProfile {
  FaceProfile({required this.id, required this.name, required this.embedding});
  final String id;
  final String name;
  final Float32List embedding;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'embedding': embedding.toList(),
      };

  factory FaceProfile.fromJson(Map<String, dynamic> j) => FaceProfile(
        id: '${j['id']}',
        name: '${j['name']}',
        embedding: Float32List.fromList(
          (j['embedding'] as List).map((e) => (e as num).toDouble()).toList(),
        ),
      );
}

class FaceGallery {
  static const _key = 'face_gallery_v1';
  final List<FaceProfile> profiles = [];

  Future<void> load() async {
    profiles.clear();
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_key);
    if (raw == null || raw.isEmpty) return;
    final list = jsonDecode(raw) as List;
    for (final e in list) {
      profiles.add(FaceProfile.fromJson(Map<String, dynamic>.from(e as Map)));
    }
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, jsonEncode(profiles.map((e) => e.toJson()).toList()));
  }

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

  ({FaceProfile? match, double score}) bestMatch(
    Float32List emb,
    double Function(Float32List, Float32List) cosine,
  ) {
    FaceProfile? best;
    double bestScore = -1;
    for (final p in profiles) {
      final s = cosine(emb, p.embedding);
      if (s > bestScore) {
        bestScore = s;
        best = p;
      }
    }
    return (match: best, score: bestScore);
  }
}
