import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Stub usage stats — placeholder for future native UsageStatsManager integration
class UsageSummary {
  final int socialMinutes;
  final int entertainmentMinutes;
  final int islamicMinutes;
  const UsageSummary({
    this.socialMinutes = 0,
    this.entertainmentMinutes = 0,
    this.islamicMinutes = 0,
  });
}

class UsageStatsState {
  final UsageSummary? todaySummary;
  const UsageStatsState({this.todaySummary});
}

class UsageStatsNotifier extends StateNotifier<UsageStatsState> {
  UsageStatsNotifier() : super(const UsageStatsState());
}

final usageStatsProvider =
    StateNotifierProvider<UsageStatsNotifier, UsageStatsState>(
  (ref) => UsageStatsNotifier(),
);
