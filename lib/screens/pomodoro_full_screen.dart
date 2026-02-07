import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/pomodoro_provider.dart';
import '../providers/theme_provider.dart';
import 'pomodoro_settings_screen.dart';

/// Full-screen Pomodoro Timer - Immersive focus experience
class PomodoroFullScreen extends ConsumerStatefulWidget {
  const PomodoroFullScreen({super.key});

  @override
  ConsumerState<PomodoroFullScreen> createState() => _PomodoroFullScreenState();
}

class _PomodoroFullScreenState extends ConsumerState<PomodoroFullScreen> 
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = ref.watch(themeColorProvider);
    final pomodoroState = ref.watch(pomodoroProvider);
    final pomodoroNotifier = ref.read(pomodoroProvider.notifier);

    // Session color
    final sessionColor = pomodoroState.isWorkSession
        ? Colors.red.withValues(alpha: 0.8)
        : Colors.green.withValues(alpha: 0.8);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Background gradient
            if (pomodoroState.isRunning)
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.center,
                        radius: 1.0 + (_pulseController.value * 0.2),
                        colors: [
                          sessionColor.withValues(alpha: 0.1 * _pulseController.value),
                          Colors.black,
                        ],
                      ),
                    ),
                  );
                },
              ),

            // Main content
            Column(
              children: [
                // Header
                _buildHeader(context),

                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Session type
                        Text(
                          pomodoroState.isWorkSession ? 'FOCUS TIME' : 'BREAK TIME',
                          style: TextStyle(
                            fontSize: 16,
                            letterSpacing: 4,
                            fontWeight: FontWeight.w300,
                            color: sessionColor,
                          ),
                        ),

                        const SizedBox(height: 60),

                        // Circular timer
                        _buildCircularTimer(pomodoroState, sessionColor, themeColor.color),

                        const SizedBox(height: 80),

                        // Controls
                        _buildControls(pomodoroState, pomodoroNotifier, sessionColor),
                      ],
                    ),
                  ),
                ),

                // Bottom tips
                _buildBottomTips(pomodoroState),
              ],
            ),

            // Completion celebration
            if (pomodoroState.justCompleted)
              _buildCompletionOverlay(pomodoroState, sessionColor),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.close,
                color: Colors.white.withValues(alpha: 0.7),
                size: 20,
              ),
            ),
          ),
          const Spacer(),
          // Settings button
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PomodoroSettingsScreen(),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.settings_outlined,
                color: Colors.white.withValues(alpha: 0.7),
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircularTimer(PomodoroState state, Color sessionColor, Color themeColor) {
    final size = 280.0;
    
    return Stack(
      alignment: Alignment.center,
      children: [
        // Background circle
        SizedBox(
          width: size,
          height: size,
          child: CircularProgressIndicator(
            value: 1.0,
            strokeWidth: 8,
            backgroundColor: Colors.transparent,
            valueColor: AlwaysStoppedAnimation(
              Colors.white.withValues(alpha: 0.05),
            ),
          ),
        ),

        // Progress circle
        SizedBox(
          width: size,
          height: size,
          child: TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 300),
            tween: Tween(begin: 0, end: state.progress),
            builder: (context, value, child) {
              return Transform.rotate(
                angle: -math.pi / 2,
                child: CircularProgressIndicator(
                  value: value,
                  strokeWidth: 8,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation(sessionColor),
                  strokeCap: StrokeCap.round,
                ),
              );
            },
          ),
        ),

        // Time display
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _formatTime(state.remainingSeconds),
              style: TextStyle(
                fontSize: 72,
                fontWeight: FontWeight.w200,
                color: themeColor.withValues(alpha: 0.95),
                letterSpacing: 2,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              state.isRunning ? 'IN PROGRESS' : 'PAUSED',
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 2,
                color: Colors.white.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildControls(PomodoroState state, PomodoroNotifier notifier, Color sessionColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Reset
        _buildControlButton(
          icon: Icons.refresh,
          onTap: notifier.resetTimer,
          color: Colors.white.withValues(alpha: 0.1),
          iconColor: Colors.white.withValues(alpha: 0.5),
        ),

        const SizedBox(width: 30),

        // Play/Pause (larger)
        _buildControlButton(
          icon: state.isRunning ? Icons.pause : Icons.play_arrow,
          onTap: state.isRunning ? notifier.pauseTimer : notifier.startTimer,
          color: sessionColor.withValues(alpha: 0.3),
          iconColor: sessionColor,
          size: 80,
          iconSize: 40,
        ),

        const SizedBox(width: 30),

        // Skip
        _buildControlButton(
          icon: Icons.skip_next,
          onTap: notifier.skipToNext,
          color: Colors.white.withValues(alpha: 0.1),
          iconColor: Colors.white.withValues(alpha: 0.5),
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onTap,
    required Color color,
    required Color iconColor,
    double size = 60,
    double iconSize = 28,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: iconColor.withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        child: Icon(
          icon,
          color: iconColor,
          size: iconSize,
        ),
      ),
    );
  }

  Widget _buildBottomTips(PomodoroState state) {
    final tip = state.isWorkSession
        ? 'Stay focused. Eliminate distractions.'
        : 'Take a break. Relax your mind.';

    return Padding(
      padding: const EdgeInsets.only(bottom: 40),
      child: Text(
        tip,
        style: TextStyle(
          fontSize: 13,
          color: Colors.white.withValues(alpha: 0.3),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildCompletionOverlay(PomodoroState state, Color sessionColor) {
    final message = state.isWorkSession
        ? '🎉 Break Complete!\nTime to focus again'
        : '✨ Work Complete!\nYou earned a break';

    return AnimatedOpacity(
      opacity: state.justCompleted ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 500),
      child: Container(
        color: Colors.black.withValues(alpha: 0.9),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 800),
                tween: Tween(begin: 0.0, end: 1.0),
                curve: Curves.elasticOut,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: child,
                  );
                },
                child: Icon(
                  state.isWorkSession ? Icons.self_improvement : Icons.emoji_events,
                  size: 120,
                  color: sessionColor,
                ),
              ),
              const SizedBox(height: 30),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w300,
                  color: Colors.white.withValues(alpha: 0.9),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
