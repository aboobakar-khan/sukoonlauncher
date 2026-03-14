import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Sound presets — these use bundled asset files in assets/sounds/
class AmbientSound {
  final String id;
  final String name;
  final String emoji;
  final String assetPath;

  const AmbientSound({
    required this.id,
    required this.name,
    required this.emoji,
    required this.assetPath,
  });
}

const ambientSounds = [
  AmbientSound(id: 'rain', name: 'Rain', emoji: '🌧️', assetPath: 'sounds/rain.mp3'),
  AmbientSound(id: 'waterfall', name: 'Waterfall', emoji: '💦', assetPath: 'sounds/waterfall.mp3'),
  AmbientSound(id: 'stream', name: 'Stream', emoji: '💧', assetPath: 'sounds/streamfall.mp3'),
  AmbientSound(id: 'gentle', name: 'Gentle Water', emoji: '🫧', assetPath: 'sounds/gentle_water.mp3'),
];

class AmbientSoundState {
  final String? currentSoundId;
  final bool isPlaying;
  final bool isMuted;
  final double volume;

  const AmbientSoundState({
    this.currentSoundId,
    this.isPlaying = false,
    this.isMuted = false,
    this.volume = 0.5,
  });

  AmbientSoundState copyWith({
    String? currentSoundId,
    bool? isPlaying,
    bool? isMuted,
    double? volume,
  }) {
    return AmbientSoundState(
      currentSoundId: currentSoundId ?? this.currentSoundId,
      isPlaying: isPlaying ?? this.isPlaying,
      isMuted: isMuted ?? this.isMuted,
      volume: volume ?? this.volume,
    );
  }
}

class AmbientSoundNotifier extends StateNotifier<AmbientSoundState> {
  final AudioPlayer _player = AudioPlayer();

  AmbientSoundNotifier() : super(const AmbientSoundState()) {
    _player.setReleaseMode(ReleaseMode.loop);
  }

  Future<void> selectAndPlay(String soundId) async {
    final sound = ambientSounds.firstWhere(
      (s) => s.id == soundId,
      orElse: () => ambientSounds.first,
    );

    try {
      await _player.stop();
      await _player.setSource(AssetSource(sound.assetPath));
      await _player.setVolume(state.isMuted ? 0.0 : state.volume);
      await _player.resume();
      state = state.copyWith(currentSoundId: soundId, isPlaying: true);
    } catch (_) {
      // Asset not found — silently fail
      state = state.copyWith(currentSoundId: soundId, isPlaying: false);
    }
  }

  Future<void> togglePlayPause() async {
    if (state.isPlaying) {
      await _player.pause();
      state = state.copyWith(isPlaying: false);
    } else if (state.currentSoundId != null) {
      await _player.resume();
      state = state.copyWith(isPlaying: true);
    }
  }

  Future<void> toggleMute() async {
    final muted = !state.isMuted;
    await _player.setVolume(muted ? 0.0 : state.volume);
    state = state.copyWith(isMuted: muted);
  }

  Future<void> setVolume(double vol) async {
    await _player.setVolume(state.isMuted ? 0.0 : vol);
    state = state.copyWith(volume: vol);
  }

  Future<void> stop() async {
    await _player.stop();
    state = const AmbientSoundState();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}

final ambientSoundProvider =
    StateNotifierProvider<AmbientSoundNotifier, AmbientSoundState>(
  (ref) => AmbientSoundNotifier(),
);
