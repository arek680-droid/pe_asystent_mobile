import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'user_stats_provider.dart';

class AvatarInfo {
  final String id; // e.g. "dog", "cat"
  final String name; // e.g. "Pies", "Kot"
  final String pngPath; // assets/avatars/png/animal-[id].png
  final String glbPath; // assets/avatars/3d/animal-[id].glb
  final int requiredLevel;

  AvatarInfo({
    required this.id,
    required this.name,
    required this.pngPath,
    required this.glbPath,
    required this.requiredLevel,
  });
}

final avatarProvider = StateNotifierProvider<AvatarNotifier, String>((ref) {
  return AvatarNotifier(ref);
});

class AvatarNotifier extends StateNotifier<String> {
  final Ref _ref;
  AvatarNotifier(this._ref) : super('animal-dog') {
    _loadAvatar();
  }

  static const _avatarKey = 'selected_avatar_id';

  // List of all 24 Cube Pet Avatars with level requirements and Polish names
  static final List<AvatarInfo> allAvatars = [
    // Level 1 (Starter)
    AvatarInfo(id: 'dog', name: 'Pies', pngPath: 'assets/avatars/png/animal-dog.png', glbPath: 'assets/avatars/3d/animal-dog.glb', requiredLevel: 1),
    AvatarInfo(id: 'cat', name: 'Kot', pngPath: 'assets/avatars/png/animal-cat.png', glbPath: 'assets/avatars/3d/animal-cat.glb', requiredLevel: 1),
    AvatarInfo(id: 'pig', name: 'Świnka', pngPath: 'assets/avatars/png/animal-pig.png', glbPath: 'assets/avatars/3d/animal-pig.glb', requiredLevel: 1),
    AvatarInfo(id: 'cow', name: 'Krówka', pngPath: 'assets/avatars/png/animal-cow.png', glbPath: 'assets/avatars/3d/animal-cow.glb', requiredLevel: 1),
    AvatarInfo(id: 'chick', name: 'Kurczaczek', pngPath: 'assets/avatars/png/animal-chick.png', glbPath: 'assets/avatars/3d/animal-chick.glb', requiredLevel: 1),
    
    // Level 2
    AvatarInfo(id: 'bunny', name: 'Królik', pngPath: 'assets/avatars/png/animal-bunny.png', glbPath: 'assets/avatars/3d/animal-bunny.glb', requiredLevel: 2),
    AvatarInfo(id: 'beaver', name: 'Bóbr', pngPath: 'assets/avatars/png/animal-beaver.png', glbPath: 'assets/avatars/3d/animal-beaver.glb', requiredLevel: 2),
    AvatarInfo(id: 'crab', name: 'Krab', pngPath: 'assets/avatars/png/animal-crab.png', glbPath: 'assets/avatars/3d/animal-crab.glb', requiredLevel: 2),
    AvatarInfo(id: 'fish', name: 'Rybka', pngPath: 'assets/avatars/png/animal-fish.png', glbPath: 'assets/avatars/3d/animal-fish.glb', requiredLevel: 2),
    AvatarInfo(id: 'caterpillar', name: 'Gąsienica', pngPath: 'assets/avatars/png/animal-caterpillar.png', glbPath: 'assets/avatars/3d/animal-caterpillar.glb', requiredLevel: 2),

    // Level 3
    AvatarInfo(id: 'panda', name: 'Panda', pngPath: 'assets/avatars/png/animal-panda.png', glbPath: 'assets/avatars/3d/animal-panda.glb', requiredLevel: 3),
    AvatarInfo(id: 'koala', name: 'Koala', pngPath: 'assets/avatars/png/animal-koala.png', glbPath: 'assets/avatars/3d/animal-koala.glb', requiredLevel: 3),
    AvatarInfo(id: 'monkey', name: 'Małpka', pngPath: 'assets/avatars/png/animal-monkey.png', glbPath: 'assets/avatars/3d/animal-monkey.glb', requiredLevel: 3),
    AvatarInfo(id: 'penguin', name: 'Pingwin', pngPath: 'assets/avatars/png/animal-penguin.png', glbPath: 'assets/avatars/3d/animal-penguin.glb', requiredLevel: 3),
    AvatarInfo(id: 'parrot', name: 'Papuga', pngPath: 'assets/avatars/png/animal-parrot.png', glbPath: 'assets/avatars/3d/animal-parrot.glb', requiredLevel: 3),

    // Level 4
    AvatarInfo(id: 'fox', name: 'Lisek', pngPath: 'assets/avatars/png/animal-fox.png', glbPath: 'assets/avatars/3d/animal-fox.glb', requiredLevel: 4),
    AvatarInfo(id: 'giraffe', name: 'Żyrafa', pngPath: 'assets/avatars/png/animal-giraffe.png', glbPath: 'assets/avatars/3d/animal-giraffe.glb', requiredLevel: 4),
    AvatarInfo(id: 'elephant', name: 'Słoń', pngPath: 'assets/avatars/png/animal-elephant.png', glbPath: 'assets/avatars/3d/animal-elephant.glb', requiredLevel: 4),
    AvatarInfo(id: 'deer', name: 'Jeleń', pngPath: 'assets/avatars/png/animal-deer.png', glbPath: 'assets/avatars/3d/animal-deer.glb', requiredLevel: 4),
    AvatarInfo(id: 'hog', name: 'Dzik', pngPath: 'assets/avatars/png/animal-hog.png', glbPath: 'assets/avatars/3d/animal-hog.glb', requiredLevel: 4),

    // Level 5 (Legendary)
    AvatarInfo(id: 'lion', name: 'Lew', pngPath: 'assets/avatars/png/animal-lion.png', glbPath: 'assets/avatars/3d/animal-lion.glb', requiredLevel: 5),
    AvatarInfo(id: 'tiger', name: 'Tygrys', pngPath: 'assets/avatars/png/animal-tiger.png', glbPath: 'assets/avatars/3d/animal-tiger.glb', requiredLevel: 5),
    AvatarInfo(id: 'polar', name: 'Niedźwiedź Polarny', pngPath: 'assets/avatars/png/animal-polar.png', glbPath: 'assets/avatars/3d/animal-polar.glb', requiredLevel: 5),
  ];

  Future<void> _loadAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getString(_avatarKey);
    if (savedId != null && allAvatars.any((a) => 'animal-${a.id}' == savedId)) {
      state = savedId;
    }
  }

  Future<void> selectAvatar(String avatarFullId) async {
    final avatarId = avatarFullId.replaceFirst('animal-', '');
    final avatar = allAvatars.firstWhere((a) => a.id == avatarId);
    final currentLevel = _ref.read(userStatsProvider).level;

    if (currentLevel >= avatar.requiredLevel) {
      state = avatarFullId;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_avatarKey, avatarFullId);
    }
  }

  AvatarInfo get currentAvatarInfo {
    final currentId = state.replaceFirst('animal-', '');
    return allAvatars.firstWhere((a) => a.id == currentId);
  }

  bool isUnlocked(AvatarInfo avatar) {
    final currentLevel = _ref.watch(userStatsProvider).level;
    return currentLevel >= avatar.requiredLevel;
  }
}
