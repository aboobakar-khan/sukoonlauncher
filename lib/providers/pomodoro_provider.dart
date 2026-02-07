import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'ambient_sound_provider.dart';

/// Pomodoro timer state
class PomodoroState {
  final int remainingSeconds;
  final bool isRunning;
  final bool isWorkSession;
  final int workDuration; // in minutes
  final int breakDuration; // in minutes
  final bool justCompleted; // Flag for completion animation
  final int totalSeconds; // Total seconds for progress calculation
  final String? ambientSoundId; // Selected ambient sound

  const PomodoroState({
    this.remainingSeconds = 25 * 60,
    this.isRunning = false,
    this.isWorkSession = true,
    this.workDuration = 25,
    this.breakDuration = 10,
    this.justCompleted = false,
    this.totalSeconds = 25 * 60,
    this.ambientSoundId,
  });

  double get progress {
    if (totalSeconds == 0) return 0;
    return (totalSeconds - remainingSeconds) / totalSeconds;
  }

  PomodoroState copyWith({
    int? remainingSeconds,
    bool? isRunning,
    bool? isWorkSession,
    int? workDuration,
    int? breakDuration,
    bool? justCompleted,
    int? totalSeconds,
    String? ambientSoundId,
  }) {
    return PomodoroState(
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      isRunning: isRunning ?? this.isRunning,
      isWorkSession: isWorkSession ?? this.isWorkSession,
      workDuration: workDuration ?? this.workDuration,
      breakDuration: breakDuration ?? this.breakDuration,
      justCompleted: justCompleted ?? this.justCompleted,
      totalSeconds: totalSeconds ?? this.totalSeconds,
      ambientSoundId: ambientSoundId ?? this.ambientSoundId,
    );
  }
}

/// Pomodoro timer notifier - manages timer state globally
class PomodoroNotifier extends StateNotifier<PomodoroState> {
  Timer? _timer;
  final AudioPlayer _audioPlayer = AudioPlayer();
  final AmbientSoundNotifier? _ambientSound;

  PomodoroNotifier({AmbientSoundNotifier? ambientSound}) 
      : _ambientSound = ambientSound,
        super(const PomodoroState());

  @override
  void dispose() {
    _timer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  void startTimer() {
    if (state.isRunning) return;

    state = state.copyWith(
      isRunning: true,
      justCompleted: false,
      totalSeconds: state.remainingSeconds,
    );

    // Auto-play ambient sound if one is selected
    if (state.ambientSoundId != null && _ambientSound != null) {
      _ambientSound.selectAndPlay(state.ambientSoundId!);
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.remainingSeconds > 0) {
        state = state.copyWith(remainingSeconds: state.remainingSeconds - 1);
      } else {
        _onTimerComplete();
      }
    });
  }

  void pauseTimer() {
    _timer?.cancel();
    state = state.copyWith(isRunning: false);
    // Pause ambient sound when timer pauses
    if (_ambientSound != null && _ambientSound.state.isPlaying) {
      _ambientSound.togglePlayPause();
    }
  }

  void resetTimer() {
    _timer?.cancel();
    // Stop ambient sound on reset
    _ambientSound?.stop();
    final duration = state.workDuration * 60;
    state = state.copyWith(
      isRunning: false,
      remainingSeconds: duration,
      isWorkSession: true,
      justCompleted: false,
      totalSeconds: duration,
    );
  }

  void skipToNext() {
    _onTimerComplete();
  }

  void _onTimerComplete() async {
    _timer?.cancel();

    // Stop ambient sound when session completes
    _ambientSound?.stop();

    // Play completion sound and haptic feedback
    await _playCompletionSound();
    HapticFeedback.heavyImpact();

    if (state.isWorkSession) {
      // Work complete, start break
      final breakDuration = state.breakDuration * 60;
      state = state.copyWith(
        isRunning: false,
        remainingSeconds: breakDuration,
        isWorkSession: false,
        justCompleted: true,
        totalSeconds: breakDuration,
      );
    } else {
      // Break complete, start work
      final workDuration = state.workDuration * 60;
      state = state.copyWith(
        isRunning: false,
        remainingSeconds: workDuration,
        isWorkSession: true,
        justCompleted: true,
        totalSeconds: workDuration,
      );
    }

    // Reset completion flag after animation
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        state = state.copyWith(justCompleted: false);
      }
    });
  }

  Future<void> _playCompletionSound() async {
    try {
      // Play a soothing bell sound
      // You can use a custom asset or system sound
      await _audioPlayer.play(AssetSource('sounds/pomodoro_complete.mp3'));
    } catch (e) {
      // Fallback to system sound if asset not found
      HapticFeedback.mediumImpact();
      await Future.delayed(const Duration(milliseconds: 100));
      HapticFeedback.mediumImpact();
    }
  }

  void setWorkDuration(int minutes) {
    state = state.copyWith(workDuration: minutes);
    if (state.isWorkSession && !state.isRunning) {
      final duration = minutes * 60;
      state = state.copyWith(
        remainingSeconds: duration,
        totalSeconds: duration,
      );
    }
  }

  void setBreakDuration(int minutes) {
    state = state.copyWith(breakDuration: minutes);
    if (!state.isWorkSession && !state.isRunning) {
      final duration = minutes * 60;
      state = state.copyWith(
        remainingSeconds: duration,
        totalSeconds: duration,
      );
    }
  }

  void setAmbientSound(String? soundId) {
    state = state.copyWith(ambientSoundId: soundId);
  }
}

/// Global pomodoro provider - keeps timer running across screen changes
final pomodoroProvider = StateNotifierProvider<PomodoroNotifier, PomodoroState>(
  (ref) {
    final ambientNotifier = ref.read(ambientSoundProvider.notifier);
    return PomodoroNotifier(ambientSound: ambientNotifier);
  },
);
