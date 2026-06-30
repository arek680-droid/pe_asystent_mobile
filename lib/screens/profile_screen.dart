import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_3d_controller/flutter_3d_controller.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/user_stats_provider.dart';
import '../providers/avatar_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/update_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  void _showAvatarSelectorSheet(BuildContext context, WidgetRef ref) {
    final currentLevel = ref.read(userStatsProvider).level;
    final selectedAvatar = ref.read(avatarProvider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        final theme = Theme.of(context);
        final allAvatars = AvatarNotifier.allAvatars;

        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          maxChildSize: 0.9,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  // Drag handle
                  Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Wybierz swojego chowańca',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Odblokowuj nowe zwierzątka awansując na kolejne poziomy!',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.secondary.withValues(alpha: 0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: GridView.builder(
                      controller: scrollController,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.85,
                      ),
                      itemCount: allAvatars.length,
                      itemBuilder: (context, index) {
                        final avatar = allAvatars[index];
                        final isUnlocked = currentLevel >= avatar.requiredLevel;
                        final isCurrentlySelected = selectedAvatar == 'animal-${avatar.id}';

                        return InkWell(
                          onTap: isUnlocked
                              ? () {
                                  ref.read(avatarProvider.notifier).selectAvatar('animal-${avatar.id}');
                                  Navigator.of(context).pop();
                                }
                              : null,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isCurrentlySelected
                                  ? theme.colorScheme.primary.withValues(alpha: 0.08)
                                  : theme.cardColor,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isCurrentlySelected
                                    ? theme.colorScheme.primary
                                    : isUnlocked
                                        ? theme.colorScheme.secondary.withValues(alpha: 0.1)
                                        : theme.colorScheme.secondary.withValues(alpha: 0.05),
                                width: isCurrentlySelected ? 2 : 1,
                              ),
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      height: 64,
                                      width: 64,
                                      decoration: BoxDecoration(
                                        color: isUnlocked
                                            ? theme.colorScheme.primary.withValues(alpha: 0.05)
                                            : theme.colorScheme.secondary.withValues(alpha: 0.03),
                                        shape: BoxShape.circle,
                                      ),
                                      child: isUnlocked
                                          ? Center(
                                              child: Image.asset(
                                                avatar.pngPath,
                                                height: 44,
                                                width: 44,
                                              ),
                                            )
                                          : Icon(
                                              Icons.lock_rounded,
                                              color: theme.colorScheme.secondary.withValues(alpha: 0.4),
                                              size: 24,
                                            ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      avatar.name,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                                if (!isUnlocked)
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.secondary.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'Lvl ${avatar.requiredLevel}',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.secondary,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    final userStats = ref.watch(userStatsProvider);
    final avatarNotifier = ref.watch(avatarProvider.notifier);
    final profileState = ref.watch(profileProvider);
    final activeAvatar = avatarNotifier.currentAvatarInfo;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final email = user?.email ?? 'uzytkownik@example.com';
    final name = profileState.value ?? email.split('@')[0];

    final isAdmin = ref.watch(isAdminProvider).value ?? false;
    final showGamificationSetting = ref.watch(gamificationSettingsProvider).value ?? true;
    final showGamification = showGamificationSetting || isAdmin;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Mój Profil',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 20),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Avatar & Name Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    // 3D Model Viewer Container
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          height: 220,
                          width: 220,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(alpha: 0.03),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: theme.colorScheme.primary.withValues(alpha: 0.1),
                              width: 2,
                            ),
                          ),
                          child: ClipOval(
                            child: Flutter3DViewer(
                              key: ValueKey(activeAvatar.glbPath), // Forces rebuild on change
                              src: activeAvatar.glbPath,
                            ),
                          ),
                        ),
                        // Edit button positioned at the bottom right of the 3D circle
                        Positioned(
                          bottom: 0,
                          right: 10,
                          child: FloatingActionButton.small(
                            onPressed: () => _showAvatarSelectorSheet(context, ref),
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: theme.scaffoldBackgroundColor,
                            shape: const CircleBorder(),
                            child: const Icon(Icons.edit_rounded, size: 18),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Twój chowaniec: ${activeAvatar.name}',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.secondary.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Gamification stats card
            if (showGamification) ...[
              Text(
                'Statystyki',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          const Text(
                            'POZIOM',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${userStats.level}',
                            style: GoogleFonts.outfit(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        width: 1,
                        height: 50,
                        color: theme.dividerTheme.color ?? Colors.grey.shade200,
                      ),
                      Column(
                        children: [
                          const Text(
                            'EXP DO AWANSU',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${userStats.nextLevelExp - userStats.exp}',
                            style: GoogleFonts.outfit(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF4F46E5),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Settings Section
            Text(
              'Ustawienia',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  // Theme switch tile
                  ListTile(
                    leading: Icon(
                      isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                      color: theme.colorScheme.primary,
                    ),
                    title: const Text('Tryb ciemny'),
                    trailing: Switch(
                      value: isDark,
                      onChanged: (_) {
                        ref.read(themeProvider.notifier).toggleTheme();
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  // About tile (optional, but looks professional)
                  ListTile(
                    leading: Icon(Icons.info_outline, color: theme.colorScheme.primary),
                    title: const Text('O aplikacji'),
                    subtitle: Text(
                      ref.watch(updateProvider).currentVersion.isNotEmpty
                          ? ref.watch(updateProvider).currentVersion
                          : 'Wersja 1.0.0',
                    ),
                    onTap: () {},
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Admin Settings Section
            if (isAdmin) ...[
              Text(
                'Panel administratora',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(
                        Icons.insights_rounded,
                        color: theme.colorScheme.primary,
                      ),
                      title: const Text('Pokazuj paski EXP i grywalizację'),
                      subtitle: const Text('Globalne włączenie poziomu/EXP dla wszystkich użytkowników'),
                      trailing: Switch(
                        value: showGamificationSetting,
                        onChanged: (val) {
                          ref.read(gamificationSettingsProvider.notifier).updateSetting(val);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Logout Button
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: theme.colorScheme.error.withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () async {
                await ref.read(authProvider.notifier).signOut();
              },
              icon: Icon(Icons.logout_rounded, color: theme.colorScheme.error, size: 20),
              label: Text(
                'Wyloguj się',
                style: GoogleFonts.inter(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
