import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/note.dart';
import 'models/deen_mode.dart';
import 'models/favorite_app.dart';
import 'models/installed_app.dart';
import 'models/prayer_record.dart';
import 'models/productivity_models.dart';
import 'screens/launcher_shell.dart';
import 'screens/onboarding_screen.dart';
import 'providers/font_provider.dart';
import 'providers/font_size_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive
  await Hive.initFlutter();

  Hive.registerAdapter(NoteAdapter());
  Hive.registerAdapter(DeenModeSettingsAdapter()); // Deen Mode
  Hive.registerAdapter(FavoriteAppAdapter());
  Hive.registerAdapter(InstalledAppAdapter());
  Hive.registerAdapter(PrayerRecordAdapter()); // Prayer tracking

  // Productivity Hub adapters
  Hive.registerAdapter(TodoItemAdapter());
  Hive.registerAdapter(PomodoroSessionAdapter());
  Hive.registerAdapter(AcademicDoubtAdapter());
  Hive.registerAdapter(ProductivityEventAdapter());
  Hive.registerAdapter(AppBlockRuleAdapter());
  Hive.registerAdapter(PomodoroSettingsAdapter());

  // Set system UI overlay style for immersive experience
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  
  // Enable edge-to-edge mode - this helps reduce system gesture interference
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.edgeToEdge,
    overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
  );
  await Hive.openBox('wallpaperBox');

  runApp(const ProviderScope(child: MinimalistLauncherApp()));
}

class MinimalistLauncherApp extends ConsumerWidget {
  const MinimalistLauncherApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appFont = ref.watch(fontProvider);
    final fontSize = ref.watch(fontSizeProvider);

    return MaterialApp(
      title: 'Camel Launcher',
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(fontSize)),
          child: child!,
        );
      },
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black.withValues(alpha: 0.5),
        primarySwatch: Colors.grey,
        useMaterial3: true,
        fontFamily: appFont.fontFamily,
        // Prevent any default underlines
        textTheme: const TextTheme().apply(
          decoration: TextDecoration.none,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
        dividerTheme: const DividerThemeData(
          color: Colors.transparent,
        ),
      ),
      home: const _LauncherEntryPoint(),
    );
  }
}

/// Entry point that checks if onboarding is completed
class _LauncherEntryPoint extends StatelessWidget {
  const _LauncherEntryPoint();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _checkOnboardingStatus(),
      builder: (context, snapshot) {
        // Show loading while checking
        if (!snapshot.hasData) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: CircularProgressIndicator(
                color: Color(0xFFC2A366), // CamelColors.sandGold
              ),
            ),
          );
        }

        // Show onboarding if not completed, otherwise show launcher
        final onboardingCompleted = snapshot.data ?? false;
        return onboardingCompleted 
            ? const LauncherShell() 
            : const OnboardingScreen();
      },
    );
  }

  Future<bool> _checkOnboardingStatus() async {
    final box = await Hive.openBox('settingsBox');
    return box.get('onboarding_completed', defaultValue: false);
  }
}
