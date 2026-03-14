import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/theme_provider.dart';
import '../../../providers/fasting_provider.dart';
import '../../../providers/premium_provider.dart';
import '../../../screens/premium_paywall_screen.dart';
import '../providers/prayer_alarm_provider.dart';
import '../screens/prayer_alarm_settings_screen.dart';
import '../utils/prayer_time_utils.dart';

/// Compact dashboard card for the widget dashboard.
/// Shows next prayer time + quick access to settings.
class PrayerAlarmDashboardCard extends ConsumerWidget {
  const PrayerAlarmDashboardCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = ref.watch(themeColorProvider).color;
    final alarmState = ref.watch(prayerAlarmProvider);
    final fastingState = ref.watch(fastingProvider);
    final isSetup = alarmState.isSetupComplete;
    final isPremium = ref.watch(hasFeatureProvider(PremiumFeature.prayerAlarm));

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        if (!isPremium) {
          showPremiumPaywall(context, triggerFeature: 'Salah Wake');
          return;
        }
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (_, _, _) => const PrayerAlarmSettingsScreen(),
            transitionsBuilder: (_, anim, _, child) {
              return FadeTransition(
                opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
                child: child,
              );
            },
            transitionDuration: const Duration(milliseconds: 300),
          ),
        );
      },
      child: Stack(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accent.withValues(alpha: 0.08),
                  accent.withValues(alpha: 0.03),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: accent.withValues(alpha: 0.12)),
            ),
            child: isSetup
                ? _buildActiveCard(accent, alarmState, fastingState)
                : _buildSetupCard(accent),
          ),
          if (!isPremium)
            Positioned(
              top: 10,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFC2A366).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFC2A366).withValues(alpha: 0.30)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_rounded, size: 9, color: const Color(0xFFC2A366).withValues(alpha: 0.8)),
                    const SizedBox(width: 4),
                    Text(
                      'PRO',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFC2A366).withValues(alpha: 0.8),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Card when prayer alarm is NOT configured yet.
  Widget _buildSetupCard(Color accent) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.mosque_rounded,
            size: 20,
            color: accent.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Salah Wake',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Never miss a prayer — auto Adhan alarm',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.35),
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.arrow_forward_ios_rounded,
            color: accent.withValues(alpha: 0.5),
            size: 14,
          ),
        ),
      ],
    );
  }

  /// Card when prayer alarm IS configured — shows next prayer + fasting times.
  Widget _buildActiveCard(Color accent, PrayerAlarmState alarmState, FastingState fastingState) {
    final nextPrayer = findNextPrayer(alarmState);
    final enabledCount = alarmState.enabledMap.values.where((v) => v).length;
    final hasFasting = fastingState.isLoaded && fastingState.times != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Prayer row ─────────────────────────────────────────
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.mosque_rounded,
                size: 20,
                color: accent.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Salah Wake',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '$enabledCount/5',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: Colors.green.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  if (nextPrayer != null)
                    Text(
                      'Next: ${nextPrayer['name']} at ${nextPrayer['time']}',
                      style: TextStyle(
                        color: accent.withValues(alpha: 0.5),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    )
                  else
                    Text(
                      alarmState.config.locationLabel.isNotEmpty
                          ? alarmState.config.locationLabel
                          : 'All prayers done today',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3),
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.settings_rounded,
                color: accent.withValues(alpha: 0.5),
                size: 14,
              ),
            ),
          ],
        ),

        // ── Fasting row (if available) ─────────────────────────
        if (hasFasting) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Container(
              height: 0.4,
              color: Colors.white.withValues(alpha: 0.05),
            ),
          ),
          Row(
            children: [
              // Suhoor
              _FastingChip(
                icon: Icons.wb_twilight_rounded,
                label: 'SUHOOR',
                time: _fmt12h(fastingState.times!.sahur),
                accent: accent,
              ),
              const SizedBox(width: 10),
              // Iftar
              _FastingChip(
                icon: Icons.nightlight_round,
                label: 'IFTAR',
                time: _fmt12h(fastingState.times!.iftar),
                accent: accent,
              ),
            ],
          ),
        ],
      ],
    );
  }

  /// Convert "17:20" or "5:20 PM" → always "5:20 PM"
  /// Delegates to shared utility.
  String _fmt12h(String s) => fmt12h(s);

  // _getNextPrayer replaced by findNextPrayer() from prayer_time_utils.dart
}

/// Small inline chip showing a fasting time on the dashboard card.
class _FastingChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String time;
  final Color accent;

  const _FastingChip({
    required this.icon,
    required this.label,
    required this.time,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: accent.withValues(alpha: 0.05),
          border: Border.all(color: accent.withValues(alpha: 0.08)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: accent.withValues(alpha: 0.6)),
            const SizedBox(width: 5),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                ),
                Text(
                  time,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: accent.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
