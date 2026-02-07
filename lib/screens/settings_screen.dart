import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
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
import 'theme_color_picker_screen.dart';
import 'font_picker_screen.dart';
import 'clock_style_picker_screen.dart';
import 'wallpaper_picker_screen.dart';
import 'debug_apps_screen.dart';
import 'premium_paywall_screen.dart';
import 'favorite_picker_screen.dart';
import 'privacy_policy_screen.dart';
import 'credits_screen.dart';
import '../services/offline_content_manager.dart';
import '../widgets/offline_download_indicator.dart';

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

    // Find current font size preset name
    final fontSizePreset = fontSizePresets.firstWhere(
      (preset) => preset.scale == currentFontSize,
      orElse: () => fontSizePresets[1], // Default to Normal
    );

    return Scaffold(
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
                        subtitle: currentFont.name,
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
                      _buildSettingsItem(
                        icon: Icons.dashboard,
                        title: 'Widget Layout',
                        subtitle: 'Coming soon',
                        onTap: () {
                          // TODO: Implement widget customization
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
                      // Main premium tile - opens paywall
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
                      
                      // Testing controls (remove in production)
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            // Buy Premium Button
                            Expanded(
                              child: GestureDetector(
                                onTap: () async {
                                  await ref.read(premiumProvider.notifier).activatePremium(
                                    type: 'lifetime',
                                  );
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('✓ Premium Activated (Test)'),
                                        backgroundColor: Color(0xFFC2A366),
                                        duration: Duration(seconds: 1),
                                      ),
                                    );
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFC2A366).withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: const Color(0xFFC2A366).withValues(alpha: 0.5),
                                    ),
                                  ),
                                  child: const Center(
                                    child: Text(
                                      '🧪 Buy (Test)',
                                      style: TextStyle(
                                        color: Color(0xFFC2A366),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Cancel Premium Button
                            Expanded(
                              child: GestureDetector(
                                onTap: () async {
                                  // Reset premium status
                                  final box = await Hive.openBox('premiumBox');
                                  await box.put('isPremium', false);
                                  await box.put('subscriptionType', null);
                                  await box.put('expiryDate', null);
                                  
                                  // Force refresh by re-reading
                                  ref.invalidate(premiumProvider);
                                  
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Text('✗ Premium Cancelled (Test)'),
                                        backgroundColor: Colors.red.shade700,
                                        duration: const Duration(seconds: 1),
                                      ),
                                    );
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.red.withValues(alpha: 0.4),
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '🧪 Cancel (Test)',
                                      style: TextStyle(
                                        color: Colors.red.shade300,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          'Testing controls - Remove before release',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.3),
                            fontSize: 10,
                          ),
                        ),
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
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Icon(
              Icons.arrow_back,
              color: Colors.white.withValues(alpha: 0.7),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Text(
            'SETTINGS',
            style: TextStyle(
              fontSize: 20,
              letterSpacing: 4,
              fontWeight: FontWeight.w300,
              color: Colors.white.withValues(alpha: 0.9),
            ),
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
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 2,
              fontWeight: FontWeight.w400,
              color: Colors.white.withValues(alpha: 0.4),
            ),
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
        backgroundColor: const Color(0xFF1a1a1a),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        title: Text(
          'FONT SIZE',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 16,
            letterSpacing: 2,
            fontWeight: FontWeight.w300,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: fontSizePresets.map((preset) {
            return ListTile(
              title: Text(
                preset.name,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 14 * preset.scale,
                ),
              ),
              trailing: ref.watch(fontSizeProvider) == preset.scale
                  ? Icon(
                      Icons.check,
                      color: Colors.white.withValues(alpha: 0.7),
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
        backgroundColor: const Color(0xFF1a1a1a),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        title: Text(
          'ARABIC FONT',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 16,
            letterSpacing: 2,
            fontWeight: FontWeight.w300,
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
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 16,
                    fontFamily: font.fontFamily,
                  ),
                ),
                trailing: isSelected
                    ? Icon(
                        Icons.check,
                        color: Colors.white.withValues(alpha: 0.7),
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
            backgroundColor: const Color(0xFF1a1a1a),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
            title: Text(
              'TAFSEER EDITION',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 16,
                letterSpacing: 2,
                fontWeight: FontWeight.w300,
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
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white.withValues(alpha: 0.5), size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 15,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 12,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
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
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
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
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Offline Content',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 15,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 12,
                      letterSpacing: 0.5,
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
          backgroundColor: const Color(0xFF1a1a1a),
          title: const Text(
            'Select Time Format',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w500,
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
    return InkWell(
      onTap: () {
        ref.read(timeFormatProvider.notifier).setTimeFormat(format);
        Navigator.of(context).pop();
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? Colors.white.withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.4),
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.7),
                fontSize: 15,
                letterSpacing: 0.5,
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
          backgroundColor: const Color(0xFF1a1a1a),
          title: const Text(
            'Select Clock Opacity',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w500,
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
    return InkWell(
      onTap: () {
        ref.read(clockOpacityProvider.notifier).setOpacity(opacity);
        Navigator.of(context).pop();
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? Colors.white.withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.4),
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              opacity.name,
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.7),
                fontSize: 15,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumBanner(BuildContext context, AppThemeColor currentTheme) {
    const greenAccent = Color(0xFFC2A366);
    
    return InkWell(
      onTap: () {
        // Use new psychology-optimized paywall
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
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              greenAccent.withValues(alpha: 0.15),
              greenAccent.withValues(alpha: 0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: greenAccent.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFC2A366), Color(0xFFA67B5B)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: greenAccent.withValues(alpha: 0.3),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: const Icon(Icons.workspace_premium, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Go Premium',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.95),
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          '75% OFF',
                          style: TextStyle(
                            color: Colors.amber,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Unlock all themes, Deen Mode & more',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '10K+ Muslims already upgraded ⭐',
                    style: TextStyle(
                      color: greenAccent.withValues(alpha: 0.7),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: greenAccent, size: 24),
          ],
        ),
      ),
    );
  }
}
