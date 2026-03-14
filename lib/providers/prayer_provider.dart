import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/prayer_record.dart';
import '../utils/hive_box_manager.dart';

const _uuid = Uuid();

/// Provider for the list of prayer records
final prayerRecordListProvider =
    StateNotifierProvider<PrayerRecordListNotifier, List<PrayerRecord>>((ref) {
  return PrayerRecordListNotifier();
});

/// Provider to get today's prayer record
final todayPrayerRecordProvider = Provider<PrayerRecord?>((ref) {
  final records = ref.watch(prayerRecordListProvider);
  final today = PrayerRecord.dateOnly(DateTime.now());
  final todayKey =
      '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

  try {
    return records.firstWhere((r) => r.dateKey == todayKey);
  } catch (e) {
    return null;
  }
});

/// Provider to get prayer records for the past year (for the contribution grid)
final prayerRecordsMapProvider = Provider<Map<String, PrayerRecord>>((ref) {
  final records = ref.watch(prayerRecordListProvider);
  final map = <String, PrayerRecord>{};
  for (final record in records) {
    map[record.dateKey] = record;
  }
  return map;
});

class PrayerRecordListNotifier extends StateNotifier<List<PrayerRecord>> {
  Box<PrayerRecord>? _box;

  PrayerRecordListNotifier() : super([]) {
    _init();
  }

  Future<void> _init() async {
    try {
      _box = await HiveBoxManager.get<PrayerRecord>('prayer_records');
      state = _box!.values.toList();
    } catch (e) {
      state = [];
    }
  }

  /// Toggle a specific prayer for a given date
  Future<void> togglePrayer(DateTime date, String prayerName) async {
    _box ??= await HiveBoxManager.get<PrayerRecord>('prayer_records');

    final dateOnly = PrayerRecord.dateOnly(date);
    final dateKey =
        '${dateOnly.year}-${dateOnly.month.toString().padLeft(2, '0')}-${dateOnly.day.toString().padLeft(2, '0')}';

    // Find existing record for this date
    PrayerRecord? existing;
    try {
      existing = state.firstWhere((r) => r.dateKey == dateKey);
    } catch (e) {
      existing = null;
    }

    if (existing != null) {
      // Update existing record
      PrayerRecord updated;
      switch (prayerName.toLowerCase()) {
        case 'fajr':
          updated = existing.copyWith(fajr: !existing.fajr);
          break;
        case 'dhuhr':
          updated = existing.copyWith(dhuhr: !existing.dhuhr);
          break;
        case 'asr':
          updated = existing.copyWith(asr: !existing.asr);
          break;
        case 'maghrib':
          updated = existing.copyWith(maghrib: !existing.maghrib);
          break;
        case 'isha':
          updated = existing.copyWith(isha: !existing.isha);
          break;
        default:
          return;
      }
      await _box!.put(existing.id, updated);
      state = _box!.values.toList();
    } else {
      // Create new record for this date
      final newRecord = PrayerRecord(
        id: _uuid.v4(),
        date: dateOnly,
        createdAt: DateTime.now(),
      );

      // Set the toggled prayer
      PrayerRecord recordWithPrayer;
      switch (prayerName.toLowerCase()) {
        case 'fajr':
          recordWithPrayer = newRecord.copyWith(fajr: true);
          break;
        case 'dhuhr':
          recordWithPrayer = newRecord.copyWith(dhuhr: true);
          break;
        case 'asr':
          recordWithPrayer = newRecord.copyWith(asr: true);
          break;
        case 'maghrib':
          recordWithPrayer = newRecord.copyWith(maghrib: true);
          break;
        case 'isha':
          recordWithPrayer = newRecord.copyWith(isha: true);
          break;
        default:
          return;
      }

      await _box!.put(recordWithPrayer.id, recordWithPrayer);
      state = [...state, recordWithPrayer];
    }
  }

  /// Get prayer record for a specific date
  PrayerRecord? getRecordForDate(DateTime date) {
    final dateOnly = PrayerRecord.dateOnly(date);
    final dateKey =
        '${dateOnly.year}-${dateOnly.month.toString().padLeft(2, '0')}-${dateOnly.day.toString().padLeft(2, '0')}';
    try {
      return state.firstWhere((r) => r.dateKey == dateKey);
    } catch (e) {
      return null;
    }
  }
}
