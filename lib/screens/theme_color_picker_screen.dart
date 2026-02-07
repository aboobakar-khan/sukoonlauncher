import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/theme_provider.dart';
import '../providers/premium_provider.dart';
import '../screens/premium_paywall_screen.dart';

/// Theme Color Picker Screen with Premium Gating
/// Free: 3 colors | Premium: All 12 colors
class ThemeColorPickerScreen extends ConsumerWidget {
  const ThemeColorPickerScreen({super.key});

  // First 3 themes are free
  static const int freeThemeCount = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTheme = ref.watch(themeColorProvider);
    final isPremium = ref.watch(premiumProvider).isPremium;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(context, isPremium),

            // Color grid
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(20),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.5,
                ),
                itemCount: ThemeColors.all.length,
                itemBuilder: (context, index) {
                  final theme = ThemeColors.all[index];
                  final isSelected = theme.name == currentTheme.name;
                  final isLocked = !isPremium && index >= freeThemeCount;

                  return _buildColorOption(
                    context, 
                    ref, 
                    theme, 
                    isSelected, 
                    isLocked,
                    index,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isPremium) {
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
          Expanded(
            child: Text(
              'THEME COLOR',
              style: TextStyle(
                fontSize: 20,
                letterSpacing: 4,
                fontWeight: FontWeight.w300,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ),
          // Premium indicator
          if (!isPremium)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFC2A366).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFC2A366).withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.lock_open,
                    color: const Color(0xFFC2A366),
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${ThemeColors.all.length - freeThemeCount} PRO',
                    style: const TextStyle(
                      color: Color(0xFFC2A366),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildColorOption(
    BuildContext context,
    WidgetRef ref,
    AppThemeColor theme,
    bool isSelected,
    bool isLocked,
    int index,
  ) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        
        if (isLocked) {
          // Show premium paywall
          showPremiumPaywall(
            context, 
            triggerFeature: 'Theme: ${theme.name}',
          );
          return;
        }
        
        ref.read(themeColorProvider.notifier).setThemeColor(theme);
        Navigator.of(context).pop();
      },
      child: Stack(
        children: [
          // Main card
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected 
                    ? theme.color 
                    : isLocked 
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.white.withValues(alpha: 0.1),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Stack(
              children: [
                // Color preview
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    gradient: LinearGradient(
                      colors: [
                        theme.color.withValues(alpha: isLocked ? 0.15 : 0.3),
                        theme.accentColor.withValues(alpha: isLocked ? 0.05 : 0.1),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),

                // Color name and circle
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: theme.color.withValues(alpha: isLocked ? 0.5 : 1.0),
                          shape: BoxShape.circle,
                          boxShadow: isLocked ? null : [
                            BoxShadow(
                              color: theme.color.withValues(alpha: 0.3),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: isLocked 
                            ? Icon(
                                Icons.lock,
                                color: Colors.white.withValues(alpha: 0.7),
                                size: 18,
                              )
                            : null,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        theme.name,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: isLocked ? 0.4 : 0.8),
                          fontSize: 14,
                          letterSpacing: 1,
                          fontWeight: isSelected
                              ? FontWeight.w500
                              : FontWeight.w300,
                        ),
                      ),
                    ],
                  ),
                ),

                // Selected indicator
                if (isSelected)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: theme.color,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check, color: Colors.black, size: 16),
                    ),
                  ),
              ],
            ),
          ),
          
          // Premium badge for locked themes
          if (isLocked)
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFC2A366).withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'PRO',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
