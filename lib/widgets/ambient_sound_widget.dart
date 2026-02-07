import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/ambient_sound_provider.dart';

/// Compact ambient sound widget for the dashboard
class AmbientSoundWidget extends ConsumerWidget {
  const AmbientSoundWidget({super.key});

  static const _sandGold = Color(0xFFC2A366);
  static const _desertSunset = Color(0xFFE8915A);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final soundState = ref.watch(ambientSoundProvider);
    final currentSound = soundState.currentSoundId != null
        ? ambientSounds.firstWhere(
            (s) => s.id == soundState.currentSoundId,
            orElse: () => ambientSounds.first,
          )
        : null;

    return GestureDetector(
      onTap: () => _showSoundPicker(context, ref),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: soundState.isPlaying
                ? _sandGold.withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Row(
          children: [
            // Sound icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: soundState.isPlaying
                    ? _sandGold.withValues(alpha: 0.12)
                    : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  currentSound?.emoji ?? '🎵',
                  style: const TextStyle(fontSize: 20),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    soundState.isPlaying
                        ? currentSound?.name ?? 'Ambient Sound'
                        : 'Ambient Sound',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    soundState.isPlaying
                        ? 'Playing · Tap to change'
                        : 'Tap to select a sound',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.35),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            // Mute / Play-pause controls
            if (soundState.currentSoundId != null) ...[
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  ref.read(ambientSoundProvider.notifier).toggleMute();
                },
                child: Icon(
                  soundState.isMuted
                      ? Icons.volume_off_rounded
                      : Icons.volume_up_rounded,
                  color: _sandGold.withValues(alpha: 0.5),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  ref.read(ambientSoundProvider.notifier).togglePlayPause();
                },
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _sandGold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    soundState.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: _sandGold,
                    size: 18,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showSoundPicker(BuildContext context, WidgetRef ref) {
    final soundState = ref.read(ambientSoundProvider);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Ambient Sounds',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Play soothing background sounds',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 20),
            // Sound grid
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: ambientSounds.map((sound) {
                final isActive = soundState.currentSoundId == sound.id;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    ref
                        .read(ambientSoundProvider.notifier)
                        .selectAndPlay(sound.id);
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    width: (MediaQuery.of(ctx).size.width - 82) / 3,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 14),
                    decoration: BoxDecoration(
                      color: isActive
                          ? _sandGold.withValues(alpha: 0.12)
                          : Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isActive
                            ? _sandGold.withValues(alpha: 0.3)
                            : Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(sound.emoji,
                            style: const TextStyle(fontSize: 26)),
                        const SizedBox(height: 6),
                        Text(
                          sound.name,
                          style: TextStyle(
                            color: isActive
                                ? _sandGold
                                : Colors.white.withValues(alpha: 0.6),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            // Stop button
            if (soundState.currentSoundId != null) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {
                    ref.read(ambientSoundProvider.notifier).stop();
                    Navigator.pop(ctx);
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: _desertSunset.withValues(alpha: 0.7),
                  ),
                  child: const Text('Stop Sound'),
                ),
              ),
            ],
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
