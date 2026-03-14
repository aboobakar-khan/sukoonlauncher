import 'package:hive/hive.dart';

part 'installed_app.g.dart';

/// Minimalist app data stored in Hive
/// Text-only, no icons - instant performance
@HiveType(typeId: 9)
class InstalledApp {
  @HiveField(0)
  final String packageName;

  @HiveField(1)
  final String appName;

  @HiveField(2)
  final DateTime lastUpdated;

  @HiveField(3)
  String? customName; // User's custom rename (if set)

  InstalledApp({
    required this.packageName,
    required this.appName,
    DateTime? lastUpdated,
    this.customName,
  }) : lastUpdated = lastUpdated ?? DateTime.now();

  /// Get the display name (custom name if set, otherwise original app name)
  String get displayName => customName ?? appName;

  InstalledApp copyWith({
    String? packageName,
    String? appName,
    DateTime? lastUpdated,
    String? customName,
  }) {
    return InstalledApp(
      packageName: packageName ?? this.packageName,
      appName: appName ?? this.appName,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      customName: customName ?? this.customName,
    );
  }
}
