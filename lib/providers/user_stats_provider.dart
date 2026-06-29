import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserStats {
  final int level;
  final int exp;
  final int nextLevelExp;

  UserStats({
    required this.level,
    required this.exp,
    required this.nextLevelExp,
  });

  UserStats copyWith({
    int? level,
    int? exp,
    int? nextLevelExp,
  }) {
    return UserStats(
      level: level ?? this.level,
      exp: exp ?? this.exp,
      nextLevelExp: nextLevelExp ?? this.nextLevelExp,
    );
  }
}

final userStatsProvider = StateNotifierProvider<UserStatsNotifier, UserStats>((ref) {
  return UserStatsNotifier();
});

class UserStatsNotifier extends StateNotifier<UserStats> {
  UserStatsNotifier() : super(UserStats(level: 1, exp: 0, nextLevelExp: 100)) {
    _loadStats();
  }

  static const _levelKey = 'user_level';
  static const _expKey = 'user_exp';

  Future<void> _loadStats() async {
    final prefs = await SharedPreferences.getInstance();
    final level = prefs.getInt(_levelKey) ?? 1;
    final exp = prefs.getInt(_expKey) ?? 0;
    
    state = UserStats(
      level: level,
      exp: exp,
      nextLevelExp: _calculateNextLevelExp(level),
    );
  }

  int _calculateNextLevelExp(int currentLevel) {
    // Formula: level * 100 (e.g. Level 1 needs 100 EXP, Level 2 needs 200 EXP, etc.)
    return currentLevel * 100;
  }

  Future<bool> addExp(int amount) async {
    final prefs = await SharedPreferences.getInstance();
    int newExp = state.exp + amount;
    int newLevel = state.level;
    bool leveledUp = false;

    // Check for level ups (looping in case they gain massive EXP)
    while (newExp >= _calculateNextLevelExp(newLevel)) {
      newExp -= _calculateNextLevelExp(newLevel);
      newLevel++;
      leveledUp = true;
    }

    state = UserStats(
      level: newLevel,
      exp: newExp,
      nextLevelExp: _calculateNextLevelExp(newLevel),
    );

    await prefs.setInt(_levelKey, newLevel);
    await prefs.setInt(_expKey, newExp);

    return leveledUp; // Return true if they leveled up, so the UI can show a celebration/popup!
  }
}
