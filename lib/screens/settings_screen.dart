import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import '../providers/theme_provider.dart';
import '../providers/font_provider.dart';
import '../providers/font_size_provider.dart';
import '../providers/clock_style_provider.dart';
import '../providers/time_format_provider.dart';
import '../providers/clock_opacity_provider.dart';
import '../providers/wallpaper_provider.dart';
import '../providers/arabic_font_provider.dart';
import '../providers/premium_provider.dart';
import '../providers/tafseer_edition_provider.dart';
import '../providers/amoled_provider.dart';
import 'theme_color_picker_screen.dart';
import 'font_picker_screen.dart';
import 'clock_style_picker_screen.dart';
import 'wallpaper_picker_screen.dart';
import 'premium_paywall_screen.dart';
import 'favorite_picker_screen.dart';
import 'privacy_policy_screen.dart';
import 'credits_screen.dart';
import '../services/offline_content_manager.dart';
import '../widgets/offline_download_indicator.dart';
import '../widgets/swipe_back_wrapper.dart';

/// Settings Screen - Customization options
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTheme = ref.watch(themeColorProvider);
    final currentFont = ref.watch(fontProvider);
    final currentFontSize = ref.watch(fontSizeProvider);
    final currentClockStyle = ref.watch(clockStyleProvider);
    final currentTimeFormat = ref.watch(timeFormatProvider);
    final currentClockOpacity = ref.watch(clockOpacityProvider);
    final currentWallpaper = ref.watch(wallpaperProvider);
    final currentArabicFont = ref.watch(arabicFontProvider);
    final isPremium = ref.watch(premiumProvider);
    final isAmoled = ref.watch(amoledProvider);

    // Find current font size preset name
    final fontSizePreset = fontSizePresets.firstWhere(
      (preset) => preset.scale == currentFontSize,
      orElse: () => fontSizePresets[1], // Default to Normal
    );

    return SwipeBackWrapper(
      child: Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(context),

            // Settings list
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Premium banner (only show if not premium)
                  if (!isPremium.isPremium) ...[
                    _buildPremiumBanner(
                      context,
                      AppThemeColor(
                        color: Colors.amber,
                        name: 'Amber',
                        accentColor: Colors.amberAccent,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  _buildSettingsSection(
                    title: 'APPEARANCE',
                    items: [
                      _buildSettingsItem(
                        icon: Icons.font_download,
                        title: 'Font Style',
                        subtitle: '${currentFont.name} · ${AppFonts.categoryName(currentFont.category)}',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const FontPickerScreen(),
                            ),
                          );
                        },
                      ),
                      _buildSettingsItem(
                        icon: Icons.format_size,
                        title: 'Font Size',
                        subtitle: fontSizePreset.name,
                        onTap: () {
                          _showFontSizeDialog(context, ref);
                        },
                      ),
                      _buildSettingsItem(
                        icon: Icons.wallpaper,
                        title: 'Wallpaper',
                        subtitle: currentWallpaper.name,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) =>
                                  const WallpaperPickerScreen(),
                            ),
                          );
                        },
                      ),
                      _buildSettingsItem(
                        icon: Icons.palette,
                        title: 'Theme Color',
                        subtitle: currentTheme.name,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) =>
                                  const ThemeColorPickerScreen(),
                            ),
                          );
                        },
                      ),
                      _buildSettingsItem(
                        icon: Icons.access_time,
                        title: 'Clock Style',
                        subtitle: currentClockStyle.name,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) =>
                                  const ClockStylePickerScreen(),
                            ),
                          );
                        },
                      ),
                      _buildSettingsItem(
                        icon: Icons.schedule,
                        title: 'Time Format',
                        subtitle: currentTimeFormat.name,
                        onTap: () {
                          _showTimeFormatDialog(
                            context,
                            ref,
                            currentTimeFormat,
                          );
                        },
                      ),
                      _buildSettingsItem(
                        icon: Icons.opacity,
                        title: 'Clock Opacity',
                        subtitle: currentClockOpacity.name,
                        onTap: () {
                          _showClockOpacityDialog(
                            context,
                            ref,
                            currentClockOpacity,
                          );
                        },
                      ),
                      _buildAmoledToggle(context, ref, isAmoled),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildSettingsSection(
                    title: 'QURAN',
                    items: [
                      _buildSettingsItem(
                        icon: Icons.text_fields,
                        title: 'Arabic Font',
                        subtitle: currentArabicFont.name,
                        onTap: () {
                          _showArabicFontDialog(context, ref);
                        },
                      ),
                      Consumer(
                        builder: (context, ref, _) {
                          final selectedEdition = ref.watch(selectedTafseerEditionProvider);
                          return _buildSettingsItem(
                            icon: Icons.menu_book,
                            title: 'Tafseer Edition',
                            subtitle: selectedEdition.name,
                            onTap: () {
                              _showTafseerEditionDialog(context, ref);
                            },
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildSettingsSection(
                    title: 'WIDGETS',
                    items: [
                      _buildSettingsItem(
                        icon: Icons.star_rounded,
                        title: 'Manage Favorites',
                        subtitle: 'Choose up to 7 favorite apps',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const FavoritePickerScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildSettingsSection(
                    title: 'SYSTEM',
                    items: [
                      _buildSettingsItem(
                        icon: Icons.home,
                        title: 'Change Default Launcher',
                        subtitle: 'Set as default home app',
                        onTap: () {
                          _openHomeLauncherSettings(context);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildSettingsSection(
                    title: 'CONTENT',
                    items: [
                      _buildOfflineContentItem(context, ref),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildSettingsSection(
                    title: 'PREMIUM',
                    items: [
                      _buildSettingsItem(
                        icon: isPremium.isPremium ? Icons.workspace_premium : Icons.stars,
                        title: isPremium.isPremium
                            ? 'Premium Active ✓'
                            : 'Unlock Pro Version',
                        subtitle: isPremium.isPremium
                            ? 'All features unlocked'
                            : 'Get access to all premium features',
                        onTap: () {
                          showPremiumPaywall(context);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildSettingsSection(
                    title: 'ABOUT',
                    items: [
                      _buildSettingsItem(
                        icon: Icons.info_outline,
                        title: 'Version',
                        subtitle: '1.0.0',
                        onTap: null,
                      ),
                      _buildSettingsItem(
                        icon: Icons.menu_book,
                        title: 'Credits & Licenses',
                        subtitle: 'Qur\'an sources and attributions',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const CreditsScreen(),
                            ),
                          );
                        },
                      ),
                      _buildSettingsItem(
                        icon: Icons.privacy_tip_outlined,
                        title: 'Privacy Policy',
                        subtitle: 'How we handle your data',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const PrivacyPolicyScreen(),
                            ),
                          );
                        },
                      ),
                    ],
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

  void _openHomeLauncherSettings(BuildContext context) async {
    try {
      // Open Android home screen settings using platform channel
      const platform = MethodChannel('com.example.minimalist_app/launcher');
      await platform.invokeMethod('openHomeLauncherSettings');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open launcher settings: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.arrow_back_ios_new,
                color: Colors.white.withValues(alpha: 0.5),
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Settings',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
              Text(
                'Customize your experience',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.35),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection({
    required String title,
    required List<Widget> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 14),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 14,
                decoration: BoxDecoration(
                  color: const Color(0xFFC2A366).withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFC2A366).withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
        ...items,
      ],
    );
  }

  void _showFontSizeDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF141414),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: const Color(0xFFC2A366).withValues(alpha: 0.15),
          ),
        ),
        title: const Text(
          'Font Size',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: fontSizePresets.map((preset) {
            final isSelected = ref.watch(fontSizeProvider) == preset.scale;
            return ListTile(
              title: Text(
                preset.name,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.6),
                  fontSize: 14 * preset.scale,
                ),
              ),
              trailing: isSelected
                  ? const Icon(
                      Icons.check_rounded,
                      color: Color(0xFFC2A366),
                    )
                  : null,
              onTap: () {
                ref.read(fontSizeProvider.notifier).setFontSize(preset.scale);
                Navigator.of(context).pop();
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showArabicFontDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF141414),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: const Color(0xFFC2A366).withValues(alpha: 0.15),
          ),
        ),
        title: const Text(
          'Arabic Font',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: ArabicFonts.all.length,
            itemBuilder: (context, index) {
              final font = ArabicFonts.all[index];
              final isSelected =
                  ref.watch(arabicFontProvider).name == font.name;

              return ListTile(
                title: Text(
                  font.name,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.6),
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 16,
                    fontFamily: font.fontFamily,
                  ),
                ),
                trailing: isSelected
                    ? const Icon(
                        Icons.check_rounded,
                        color: Color(0xFFC2A366),
                      )
                    : null,
                onTap: () {
                  ref.read(arabicFontProvider.notifier).setFont(font);
                  Navigator.of(context).pop();
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _showTafseerEditionDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final editionsAsync = ref.watch(tafseerEditionsProvider);
          final selectedEdition = ref.watch(selectedTafseerEditionProvider);

          return AlertDialog(
            backgroundColor: const Color(0xFF141414),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: const Color(0xFFC2A366).withValues(alpha: 0.15),
              ),
            ),
            title: const Text(
              'Tafseer Edition',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            content: SizedBox(
              width: double.maxFinite,
              height: 400,
              child: editionsAsync.when(
                data: (editions) {
                  // Filter to show English editions first, then others
                  final sortedEditions = [...editions];
                  sortedEditions.sort((a, b) {
                    if (a.language.toLowerCase() == 'english' && b.language.toLowerCase() != 'english') {
                      return -1;
                    } else if (a.language.toLowerCase() != 'english' && b.language.toLowerCase() == 'english') {
                      return 1;
                    }
                    return a.name.compareTo(b.name);
                  });

                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: sortedEditions.length,
                    itemBuilder: (context, index) {
                      final edition = sortedEditions[index];
                      final isSelected = selectedEdition.slug == edition.slug;

                      return ListTile(
                        title: Text(
                          edition.name,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          '${edition.authorName} • ${edition.language}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 12,
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(
                                Icons.check,
                                color: Color(0xFFC2A366),
                              )
                            : null,
                        onTap: () {
                          ref.read(selectedTafseerEditionProvider.notifier).setEdition(edition);
                          Navigator.of(context).pop();
                        },
                      );
                    },
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(color: Color(0xFFC2A366)),
                ),
                error: (_, __) => Center(
                  child: Text(
                    'Could not load editions',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFC2A366).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: const Color(0xFFC2A366).withValues(alpha: 0.6), size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.35),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(
                Icons.chevron_right,
                color: Colors.white.withValues(alpha: 0.2),
                size: 18,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmoledToggle(BuildContext context, WidgetRef ref, bool isEnabled) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFC2A366).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.brightness_1,
                color: const Color(0xFFC2A366).withValues(alpha: 0.6), size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AMOLED Mode',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  isEnabled ? 'Pure black · Saves battery' : 'Disabled',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              ref.read(amoledProvider.notifier).toggle();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              height: 24,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: isEnabled
                    ? const Color(0xFFC2A366).withValues(alpha: 0.3)
                    : Colors.white.withValues(alpha: 0.1),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 200),
                alignment: isEnabled ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isEnabled ? const Color(0xFFC2A366) : Colors.white38,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineContentItem(BuildContext context, WidgetRef ref) {
    final status = ref.watch(offlineContentProvider);
    
    IconData icon;
    Color iconColor;
    String subtitle;
    
    if (status.isComplete) {
      icon = Icons.cloud_done;
      iconColor = Colors.green;
      subtitle = status.detailText;
    } else if (status.isDownloading) {
      icon = Icons.cloud_download;
      iconColor = Colors.blue;
      subtitle = '${(status.progress * 100).toInt()}% - ${status.currentItem ?? "Downloading..."}';
    } else {
      icon = Icons.cloud_off;
      iconColor = Colors.orange;
      subtitle = 'Tap to manage offline content';
    }

    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: const Color(0xFF161B22),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (context) => const OfflineDownloadSheet(),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: status.isDownloading
                  ? Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            value: status.progress,
                            strokeWidth: 2.5,
                            color: iconColor,
                            backgroundColor: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        Text(
                          '${(status.progress * 100).toInt()}',
                          style: TextStyle(
                            color: iconColor,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    )
                  : Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Offline Content',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.35),
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.white.withValues(alpha: 0.3),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _showTimeFormatDialog(
    BuildContext context,
    WidgetRef ref,
    TimeFormat currentFormat,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF141414),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: const Color(0xFFC2A366).withValues(alpha: 0.15),
            ),
          ),
          title: const Text(
            'Time Format',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTimeFormatOption(
                context,
                ref,
                '12-Hour (AM/PM)',
                TimeFormat.hour12,
                currentFormat,
              ),
              const SizedBox(height: 8),
              _buildTimeFormatOption(
                context,
                ref,
                '24-Hour',
                TimeFormat.hour24,
                currentFormat,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTimeFormatOption(
    BuildContext context,
    WidgetRef ref,
    String label,
    TimeFormat format,
    TimeFormat currentFormat,
  ) {
    final isSelected = format == currentFormat;
    const gold = Color(0xFFC2A366);
    return InkWell(
      onTap: () {
        ref.read(timeFormatProvider.notifier).setTimeFormat(format);
        Navigator.of(context).pop();
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? gold.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? gold.withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.06),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected
                  ? gold
                  : Colors.white.withValues(alpha: 0.3),
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.6),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showClockOpacityDialog(
    BuildContext context,
    WidgetRef ref,
    ClockOpacity currentOpacity,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF141414),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: const Color(0xFFC2A366).withValues(alpha: 0.15),
            ),
          ),
          title: const Text(
            'Clock Opacity',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildClockOpacityOption(
                context,
                ref,
                ClockOpacity.low,
                currentOpacity,
              ),
              const SizedBox(height: 8),
              _buildClockOpacityOption(
                context,
                ref,
                ClockOpacity.medium,
                currentOpacity,
              ),
              const SizedBox(height: 8),
              _buildClockOpacityOption(
                context,
                ref,
                ClockOpacity.high,
                currentOpacity,
              ),
              const SizedBox(height: 8),
              _buildClockOpacityOption(
                context,
                ref,
                ClockOpacity.veryHigh,
                currentOpacity,
              ),
              const SizedBox(height: 8),
              _buildClockOpacityOption(
                context,
                ref,
                ClockOpacity.ultraHigh,
                currentOpacity,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildClockOpacityOption(
    BuildContext context,
    WidgetRef ref,
    ClockOpacity opacity,
    ClockOpacity currentOpacity,
  ) {
    final isSelected = opacity == currentOpacity;
    const gold = Color(0xFFC2A366);
    return InkWell(
      onTap: () {
        ref.read(clockOpacityProvider.notifier).setOpacity(opacity);
        Navigator.of(context).pop();
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? gold.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? gold.withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.06),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected
                  ? gold
                  : Colors.white.withValues(alpha: 0.3),
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              opacity.name,
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.6),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumBanner(BuildContext context, AppThemeColor currentTheme) {
    const gold = Color(0xFFC2A366);
    
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          PageRouteBuilder(
            opaque: false,
            pageBuilder: (context, _, __) => const PremiumPaywallScreen(),
            transitionsBuilder: (context, anim, _, child) {
              return FadeTransition(opacity: anim, child: child);
            },
          ),
        );
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: gold.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: gold.withValues(alpha: 0.18),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: gold.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.workspace_premium_rounded, color: gold, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Upgrade to Premium',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Unlock all themes, Deen Mode & more',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: gold.withValues(alpha: 0.5),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
