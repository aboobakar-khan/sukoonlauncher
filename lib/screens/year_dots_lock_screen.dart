import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../widgets/year_dots_wallpaper.dart';

/// Lock screen widget showing current time + 365-dot year progress grid.
///
/// Design:
/// - Pure black background (0xFF000000)
/// - Clock at top (white text): "Sat 17 Jan 2:14"
/// - Year dots grid below: completed = pure white, today = orange
/// - Updates time every minute
/// - Shows when app opens while device is locked
class YearDotsLockScreen extends StatefulWidget {
  const YearDotsLockScreen({super.key});

  @override
  State<YearDotsLockScreen> createState() => _YearDotsLockScreenState();
}

class _YearDotsLockScreenState extends State<YearDotsLockScreen> {
  late Timer _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Hide system UI for immersive lock screen experience
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    
    // Update time every minute
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    // Restore system UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Format time: "Sat 17 Jan 2:14"
    final dayOfWeek = DateFormat('EEE').format(_now); // Sat
    final day = _now.day; // 17
    final month = DateFormat('MMM').format(_now); // Jan
    final time = DateFormat('H:mm').format(_now); // 2:14 (24h) or 2:14 (12h based on system)

    final screenHeight = MediaQuery.of(context).size.height;
    final clockTopPadding = screenHeight * 0.12; // Clock at ~12% from top
    final dotsTopPadding = screenHeight * 0.25; // Dots start at ~25% from top

    return PopScope(
      // Swipe down or back button exits lock screen
      canPop: true,
      child: Scaffold(
        backgroundColor: Colors.black, // Pure black background
        body: SafeArea(
          child: Stack(
            children: [
              // Clock at top
              Positioned(
                top: clockTopPadding,
                left: 0,
                right: 0,
                child: Column(
                  children: [
                    // Date line: "Sat 17 Jan"
                    Text(
                      '$dayOfWeek $day $month',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w300,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Time: "2:14"
                    Text(
                      time,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 72,
                        fontWeight: FontWeight.w200,
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
              ),

              // Year dots grid below clock
              Positioned(
                top: dotsTopPadding,
                left: 0,
                right: 0,
                bottom: 0,
                child: const _YearDotsLockScreenGrid(),
              ),

              // Subtle hint at bottom: swipe down to unlock
              Positioned(
                bottom: 32,
                left: 0,
                right: 0,
                child: Center(
                  child: Text(
                    'Swipe down to exit',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.3),
                      fontSize: 12,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Year dots grid for lock screen — hardcoded colors for lock screen design.
class _YearDotsLockScreenGrid extends StatelessWidget {
  const _YearDotsLockScreenGrid();

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final progress = YearProgress.snapshot();

    const columns = 15; // 15 dots per row
    const spacing = 6.0;
    final dotSize = ((screenWidth - 32 - (spacing * (columns - 1))) / columns)
        .clamp(8.0, 14.0);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: spacing,
            crossAxisSpacing: spacing,
            childAspectRatio: 1,
          ),
          itemCount: progress.totalDays,
          itemBuilder: (context, index) {
            final dayNumber = index + 1;
            final isPast = dayNumber < progress.today;
            final isToday = dayNumber == progress.today;

            Color dotColor;
            if (isToday) {
              dotColor = Colors.orange; // Today = orange
            } else if (isPast) {
              dotColor = Colors.white; // Completed = pure white
            } else {
              dotColor = Colors.white.withValues(alpha: 0.08); // Future = faint
            }

            return Container(
              width: dotSize,
              height: dotSize,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            );
          },
        ),
      ),
    );
  }
}
