import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/note.dart';
import 'models/favorite_app.dart';
import 'models/installed_app.dart';
import 'models/prayer_record.dart';
import 'models/productivity_models.dart';
import 'screens/launcher_shell.dart';
import 'screens/onboarding_screen.dart';
import 'providers/font_provider.dart';
import 'providers/font_size_provider.dart';
import 'providers/amoled_provider.dart';
import 'utils/hive_box_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive
  await Hive.initFlutter();

  Hive.registerAdapter(NoteAdapter());
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

  // Pre-open frequently used Hive boxes (avoids repeated I/O)
  await Future.wait([
    HiveBoxManager.get('settingsBox'),
    HiveBoxManager.get('zen_mode_box'),
    HiveBoxManager.get('tasbih_data'),
  ]);

  runApp(const ProviderScope(child: SukoonLauncherApp()));
}

class SukoonLauncherApp extends ConsumerWidget {
  const SukoonLauncherApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appFont = ref.watch(fontProvider);
    final fontSize = ref.watch(fontSizeProvider);
    final isAmoled = ref.watch(amoledProvider);
    final bgColor = isAmoled ? Colors.black : Colors.black.withValues(alpha: 0.5);

    return MaterialApp(
      title: 'Sukoon Launcher',
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
        scaffoldBackgroundColor: bgColor,
        primarySwatch: Colors.grey,
        useMaterial3: true,
        fontFamily: appFont.fontFamily,
        // 2-font hierarchy: headings use heading font, body uses body font
        textTheme: TextTheme(
          // Display styles — large headings
          displayLarge: TextStyle(fontFamily: appFont.headingFamily, decoration: TextDecoration.none),
          displayMedium: TextStyle(fontFamily: appFont.headingFamily, decoration: TextDecoration.none),
          displaySmall: TextStyle(fontFamily: appFont.headingFamily, decoration: TextDecoration.none),
          // Headline styles — section headings
          headlineLarge: TextStyle(fontFamily: appFont.headingFamily, decoration: TextDecoration.none),
          headlineMedium: TextStyle(fontFamily: appFont.headingFamily, decoration: TextDecoration.none),
          headlineSmall: TextStyle(fontFamily: appFont.headingFamily, decoration: TextDecoration.none),
          // Title styles — card / appbar titles
          titleLarge: TextStyle(fontFamily: appFont.headingFamily, decoration: TextDecoration.none),
          titleMedium: TextStyle(fontFamily: appFont.fontFamily, decoration: TextDecoration.none),
          titleSmall: TextStyle(fontFamily: appFont.fontFamily, decoration: TextDecoration.none),
          // Body styles — paragraphs, content
          bodyLarge: TextStyle(fontFamily: appFont.fontFamily, decoration: TextDecoration.none),
          bodyMedium: TextStyle(fontFamily: appFont.fontFamily, decoration: TextDecoration.none),
          bodySmall: TextStyle(fontFamily: appFont.fontFamily, decoration: TextDecoration.none),
          // Label styles — buttons, chips
          labelLarge: TextStyle(fontFamily: appFont.fontFamily, decoration: TextDecoration.none),
          labelMedium: TextStyle(fontFamily: appFont.fontFamily, decoration: TextDecoration.none),
          labelSmall: TextStyle(fontFamily: appFont.fontFamily, decoration: TextDecoration.none),
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

/// Entry point that checks onboarding + manages app lifecycle
class _LauncherEntryPoint extends StatefulWidget {
  const _LauncherEntryPoint();

  @override
  State<_LauncherEntryPoint> createState() => _LauncherEntryPointState();
}

class _LauncherEntryPointState extends State<_LauncherEntryPoint>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        // Compact Hive boxes when app goes to background
        HiveBoxManager.compactAll();
        break;
      case AppLifecycleState.resumed:
        // Nothing special needed on resume
        break;
      default:
        break;
    }
  }

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
                color: Color(0xFFC2A366), // SukoonColors.sandGold
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
    final box = await HiveBoxManager.get('settingsBox');
    return box.get('onboarding_completed', defaultValue: false);
  }
}
