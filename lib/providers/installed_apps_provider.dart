import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../models/installed_app.dart';
import '../utils/app_filter_utils.dart';

/// Provider for installed apps stored permanently in Hive
/// Loaded into memory, no cache, instant filtering
/// True minimalist architecture
class InstalledAppsNotifier extends StateNotifier<List<InstalledApp>> {
  InstalledAppsNotifier() : super([]) {
    _loadApps();
  }

  Box<InstalledApp>? _box;
  bool _isRefreshing = false;

  /// Load apps from Hive into memory
  Future<void> _loadApps() async {
    _box ??= await Hive.openBox<InstalledApp>('installed_apps');

    // If box is empty, fetch from system
    if (_box!.isEmpty) {
      await refreshApps();
    } else {
      // Load from Hive instantly
      state = _box!.values.toList()
        ..sort(
          (a, b) => a.appName.toLowerCase().compareTo(b.appName.toLowerCase()),
        );
    }
  }

  /// Refresh apps from system (call manually when needed)
  Future<void> refreshApps() async {
    if (_isRefreshing) return;
    _isRefreshing = true;

    try {
      _box ??= await Hive.openBox<InstalledApp>('installed_apps');

      // Get filtered apps from system
      final systemApps = await AppFilterUtils.getFilteredAppsAlternative();

      // Clear old data
      await _box!.clear();

      // Store in Hive
      final installedApps = systemApps
          .map(
            (app) =>
                InstalledApp(packageName: app.packageName, appName: app.name),
          )
          .toList();

      for (final app in installedApps) {
        await _box!.add(app);
      }

      // Update memory
      state = installedApps
        ..sort(
          (a, b) => a.appName.toLowerCase().compareTo(b.appName.toLowerCase()),
        );
    } finally {
      _isRefreshing = false;
    }
  }

  /// Filter apps in memory - instant performance
  List<InstalledApp> filterApps(String query) {
    if (query.isEmpty) return state;

    final lowerQuery = query.toLowerCase();
    return state.where((app) {
      return app.appName.toLowerCase().contains(lowerQuery) ||
          app.packageName.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  /// Remove an app from the installed apps list (for hide/uninstall)
  void removeApp(String packageName) {
    final updatedApps = state
        .where((app) => app.packageName != packageName)
        .toList();
    state = updatedApps;
  }

  /// Check if refresh is in progress
  bool get isRefreshing => _isRefreshing;
}

final installedAppsProvider =
    StateNotifierProvider<InstalledAppsNotifier, List<InstalledApp>>(
      (ref) => InstalledAppsNotifier(),
    );
