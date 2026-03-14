import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Audio playback state
enum QuranAudioState {
  idle,
  loading,
  playing,
  paused,
  error,
}

/// Audio playback state model
class QuranAudioPlaybackState {
  final QuranAudioState state;
  final int? currentSurahId;
  final String? currentReciter;
  final String? currentUrl;
  final Duration position;
  final Duration duration;
  final String? errorMessage;

  const QuranAudioPlaybackState({
    this.state = QuranAudioState.idle,
    this.currentSurahId,
    this.currentReciter,
    this.currentUrl,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.errorMessage,
  });

  QuranAudioPlaybackState copyWith({
    QuranAudioState? state,
    int? currentSurahId,
    String? currentReciter,
    String? currentUrl,
    Duration? position,
    Duration? duration,
    String? errorMessage,
  }) {
    return QuranAudioPlaybackState(
      state: state ?? this.state,
      currentSurahId: currentSurahId ?? this.currentSurahId,
      currentReciter: currentReciter ?? this.currentReciter,
      currentUrl: currentUrl ?? this.currentUrl,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      errorMessage: errorMessage,
    );
  }

  bool get isPlaying => state == QuranAudioState.playing;
  bool get isPaused => state == QuranAudioState.paused;
  bool get isLoading => state == QuranAudioState.loading;
  bool get isIdle => state == QuranAudioState.idle;

  double get progress {
    if (duration.inMilliseconds == 0) return 0.0;
    return (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
  }
}

/// Provider for audio playback
final quranAudioProvider =
    StateNotifierProvider<QuranAudioNotifier, QuranAudioPlaybackState>((ref) {
  return QuranAudioNotifier();
});

class QuranAudioNotifier extends StateNotifier<QuranAudioPlaybackState> {
  final AudioPlayer _player = AudioPlayer();

  QuranAudioNotifier() : super(const QuranAudioPlaybackState()) {
    _player.onPlayerStateChanged.listen((playerState) {
      if (!mounted) return;
      switch (playerState) {
        case PlayerState.playing:
          state = state.copyWith(state: QuranAudioState.playing);
          break;
        case PlayerState.paused:
          state = state.copyWith(state: QuranAudioState.paused);
          break;
        case PlayerState.stopped:
          state = state.copyWith(state: QuranAudioState.idle);
          break;
        case PlayerState.completed:
          state = state.copyWith(
            state: QuranAudioState.idle,
            position: Duration.zero,
          );
          break;
        default:
          break;
      }
    });

    _player.onPositionChanged.listen((pos) {
      if (!mounted) return;
      state = state.copyWith(position: pos);
    });

    _player.onDurationChanged.listen((dur) {
      if (!mounted) return;
      state = state.copyWith(duration: dur);
    });
  }

  /// Play a surah recitation from URL
  Future<void> play({
    required int surahId,
    required String reciterName,
    required String audioUrl,
  }) async {
    if (audioUrl.isEmpty) return;

    try {
      state = state.copyWith(
        state: QuranAudioState.loading,
        currentSurahId: surahId,
        currentReciter: reciterName,
        currentUrl: audioUrl,
        errorMessage: null,
      );

      await _player.stop();
      await _player.play(UrlSource(audioUrl));
    } catch (e) {
      debugPrint('QuranAudio: Play error: $e');
      state = state.copyWith(
        state: QuranAudioState.error,
        errorMessage: 'Failed to play audio',
      );
    }
  }

  /// Pause playback
  Future<void> pause() async {
    try {
      await _player.pause();
    } catch (e) {
      debugPrint('QuranAudio: Pause error: $e');
    }
  }

  /// Resume playback
  Future<void> resume() async {
    try {
      await _player.resume();
    } catch (e) {
      debugPrint('QuranAudio: Resume error: $e');
    }
  }

  /// Stop playback
  Future<void> stop() async {
    try {
      await _player.stop();
      state = const QuranAudioPlaybackState();
    } catch (e) {
      debugPrint('QuranAudio: Stop error: $e');
    }
  }

  /// Seek to a position
  Future<void> seek(Duration position) async {
    try {
      await _player.seek(position);
    } catch (e) {
      debugPrint('QuranAudio: Seek error: $e');
    }
  }

  /// Toggle play/pause
  Future<void> togglePlayPause({
    required int surahId,
    required String reciterName,
    required String audioUrl,
  }) async {
    if (state.isPlaying && state.currentSurahId == surahId) {
      await pause();
    } else if (state.isPaused && state.currentSurahId == surahId) {
      await resume();
    } else {
      await play(
        surahId: surahId,
        reciterName: reciterName,
        audioUrl: audioUrl,
      );
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
