import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/pomodoro_provider.dart';
import '../providers/ambient_sound_provider.dart';

/// Pomodoro Settings Screen - Customize work and break durations
class PomodoroSettingsScreen extends ConsumerWidget {
  const PomodoroSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pomodoroState = ref.watch(pomodoroProvider);
    
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.pop(context);
          },
        ),
        title: Text(
          'Pomodoro Settings',
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 18,
            fontWeight: FontWeight.w300,
            letterSpacing: 1.2,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Work Duration Setting
            _buildDurationCard(
              context: context,
              ref: ref,
              title: 'Work Duration',
              subtitle: 'Focus session length',
              currentMinutes: pomodoroState.workDuration,
              color: Colors.red,
              icon: Icons.work_outline,
              onChanged: (minutes) {
                HapticFeedback.selectionClick();
                ref.read(pomodoroProvider.notifier).setWorkDuration(minutes);
              },
            ),

            const SizedBox(height: 20),

            // Break Duration Setting
            _buildDurationCard(
              context: context,
              ref: ref,
              title: 'Break Duration',
              subtitle: 'Rest session length',
              currentMinutes: pomodoroState.breakDuration,
              color: Colors.green,
              icon: Icons.coffee_outlined,
              onChanged: (minutes) {
                HapticFeedback.selectionClick();
                ref.read(pomodoroProvider.notifier).setBreakDuration(minutes);
              },
            ),

            const SizedBox(height: 20),

            // Ambient Sound Setting
            _buildAmbientSoundCard(context, ref, pomodoroState),

            const SizedBox(height: 30),

            // Presets Section
            _buildPresetsSection(context, ref),

            const SizedBox(height: 30),

            // Info Card
            _buildInfoCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildDurationCard({
    required BuildContext context,
    required WidgetRef ref,
    required String title,
    required String subtitle,
    required int currentMinutes,
    required Color color,
    required IconData icon,
    required Function(int) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.95),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Current Value Display
          Center(
            child: Text(
              '$currentMinutes',
              style: TextStyle(
                color: color,
                fontSize: 64,
                fontWeight: FontWeight.w200,
                letterSpacing: -2,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Center(
            child: Text(
              'MINUTES',
              style: TextStyle(
                color: Colors.white.withOpacity(0.3),
                fontSize: 11,
                fontWeight: FontWeight.w300,
                letterSpacing: 2,
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Slider
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: color,
              inactiveTrackColor: color.withOpacity(0.2),
              thumbColor: color,
              overlayColor: color.withOpacity(0.2),
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            ),
            child: Slider(
              value: currentMinutes.toDouble(),
              min: 1,
              max: 120,
              divisions: 119,
              onChanged: (value) {
                onChanged(value.toInt());
              },
            ),
          ),

          const SizedBox(height: 8),

          // Quick adjustment buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildAdjustButton(
                label: '-5',
                onTap: () {
                  if (currentMinutes > 5) {
                    onChanged(currentMinutes - 5);
                  }
                },
                color: color,
              ),
              const SizedBox(width: 8),
              _buildAdjustButton(
                label: '-1',
                onTap: () {
                  if (currentMinutes > 1) {
                    onChanged(currentMinutes - 1);
                  }
                },
                color: color,
              ),
              const SizedBox(width: 20),
              _buildAdjustButton(
                label: '+1',
                onTap: () {
                  if (currentMinutes < 120) {
                    onChanged(currentMinutes + 1);
                  }
                },
                color: color,
              ),
              const SizedBox(width: 8),
              _buildAdjustButton(
                label: '+5',
                onTap: () {
                  if (currentMinutes < 115) {
                    onChanged(currentMinutes + 5);
                  }
                },
                color: color,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAdjustButton({
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }

  Widget _buildAmbientSoundCard(BuildContext context, WidgetRef ref, PomodoroState pomodoroState) {
    final soundState = ref.watch(ambientSoundProvider);
    final currentSound = pomodoroState.ambientSoundId != null
        ? ambientSounds.firstWhere(
            (s) => s.id == pomodoroState.ambientSoundId,
            orElse: () => ambientSounds.first,
          )
        : null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFC2A366).withOpacity(0.2),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFC2A366).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.music_note, color: Color(0xFFC2A366), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Focus Sound',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.95),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      'Play soothing sounds during sessions',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Current sound display
          if (currentSound != null) ...[
            Center(
              child: Column(
                children: [
                  Text(
                    currentSound.emoji,
                    style: const TextStyle(fontSize: 48),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    currentSound.name,
                    style: TextStyle(
                      color: const Color(0xFFC2A366),
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    soundState.isPlaying ? 'PLAYING' : 'SELECTED',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                      fontSize: 10,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Play/Pause button
            Center(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  if (soundState.isPlaying) {
                    ref.read(ambientSoundProvider.notifier).togglePlayPause();
                  } else {
                    ref.read(ambientSoundProvider.notifier).selectAndPlay(pomodoroState.ambientSoundId!);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC2A366).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFC2A366).withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        soundState.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                        color: const Color(0xFFC2A366),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        soundState.isPlaying ? 'Pause' : 'Play',
                        style: const TextStyle(
                          color: Color(0xFFC2A366),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ] else ...[
            Center(
              child: Column(
                children: [
                  Icon(
                    Icons.music_off,
                    size: 48,
                    color: Colors.white.withOpacity(0.2),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No sound selected',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Select/Change sound button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showAmbientSoundPicker(context, ref, pomodoroState),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC2A366).withOpacity(0.1),
                foregroundColor: const Color(0xFFC2A366),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: const Color(0xFFC2A366).withOpacity(0.2),
                  ),
                ),
              ),
              icon: const Icon(Icons.library_music, size: 18),
              label: Text(
                currentSound != null ? 'Change Sound' : 'Select Sound',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),

          // Remove sound button (if sound is selected)
          if (currentSound != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  ref.read(pomodoroProvider.notifier).setAmbientSound(null);
                  ref.read(ambientSoundProvider.notifier).stop();
                },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white.withOpacity(0.4),
                ),
                child: const Text('Remove Sound'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showAmbientSoundPicker(BuildContext context, WidgetRef ref, PomodoroState pomodoroState) {
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
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Focus Sounds',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Select a soothing sound for your Pomodoro sessions',
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 20),
            // Sound grid
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: ambientSounds.map((sound) {
                final isActive = pomodoroState.ambientSoundId == sound.id;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    ref.read(pomodoroProvider.notifier).setAmbientSound(sound.id);
                    ref.read(ambientSoundProvider.notifier).selectAndPlay(sound.id);
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    width: (MediaQuery.of(ctx).size.width - 82) / 3,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    decoration: BoxDecoration(
                      color: isActive
                          ? const Color(0xFFC2A366).withOpacity(0.12)
                          : Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isActive
                            ? const Color(0xFFC2A366).withOpacity(0.3)
                            : Colors.white.withOpacity(0.06),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(sound.emoji, style: const TextStyle(fontSize: 26)),
                        const SizedBox(height: 6),
                        Text(
                          sound.name,
                          style: TextStyle(
                            color: isActive
                                ? const Color(0xFFC2A366)
                                : Colors.white.withOpacity(0.6),
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
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetsSection(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PRESETS',
          style: TextStyle(
            color: Colors.white.withOpacity(0.4),
            fontSize: 11,
            fontWeight: FontWeight.w500,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        
        // Preset buttons
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildPresetButton(
              context: context,
              ref: ref,
              label: 'Classic',
              workMinutes: 25,
              breakMinutes: 5,
              description: '25 min work / 5 min break',
            ),
            _buildPresetButton(
              context: context,
              ref: ref,
              label: 'Extended',
              workMinutes: 50,
              breakMinutes: 10,
              description: '50 min work / 10 min break',
            ),
            _buildPresetButton(
              context: context,
              ref: ref,
              label: 'Short',
              workMinutes: 15,
              breakMinutes: 3,
              description: '15 min work / 3 min break',
            ),
            _buildPresetButton(
              context: context,
              ref: ref,
              label: 'Deep Work',
              workMinutes: 90,
              breakMinutes: 20,
              description: '90 min work / 20 min break',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPresetButton({
    required BuildContext context,
    required WidgetRef ref,
    required String label,
    required int workMinutes,
    required int breakMinutes,
    required String description,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        ref.read(pomodoroProvider.notifier).setWorkDuration(workMinutes);
        ref.read(pomodoroProvider.notifier).setBreakDuration(breakMinutes);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Applied $label preset'),
            duration: const Duration(seconds: 1),
            backgroundColor: Colors.white.withOpacity(0.1),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              description,
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.blue.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            color: Colors.blue.withOpacity(0.6),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pomodoro Technique',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Work in focused intervals, then take short breaks. After 4 work sessions, take a longer break. Adjust durations to match your workflow.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
