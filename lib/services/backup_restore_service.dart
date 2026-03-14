import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/hive_box_manager.dart';
import '../models/note.dart';
import '../models/prayer_record.dart';
import '../models/productivity_models.dart';
import '../features/prayer_alarm/models/prayer_alarm_config.dart';

/// Comprehensive backup & restore service for ALL user data.
///
/// Exports:
///  • All Hive boxes (user data, settings, preferences)
///  • SharedPreferences keys (saved verses, Ramadan, charity, display)
///
/// Format: Single JSON file (.sukoon_backup) containing every data category.
/// Import merges or overwrites data, then signals providers to reload.
class BackupRestoreService {
  // ───────────────────────────────────────────────────────────────
  // Backup version — increment when schema changes
  // ───────────────────────────────────────────────────────────────
  static const int _backupVersion = 1;

  // ───────────────────────────────────────────────────────────────
  // Hive box names that contain USER DATA (not caches)
  // ───────────────────────────────────────────────────────────────
  static const List<String> _hiveBoxNames = [
    'tasbih_data',
    'prayer_records',
    'notes',
    'productivity_todos',
    'productivity_events',
    'academic_doubts',
    'pomodoro_settings',
    'pomodoro_daily_stats',
    'app_block_rules',
    'focus_streak',
    'focus_categories',
    'settingsBox',
    'wallpaperBox',
    'zen_mode_box',
    'prayer_alarm_config',
    'prayer_alarm_times',
    'prayer_reminder_settings',
    'notification_filter_config',
    'settings',
    'adhkar_data',
    'addiction_interrupt',
    'notification_dhikr',
    'clock_style_box',
    'screen_time_config',
    'keyboard_auto_open',
  ];

  // SharedPreferences keys that store user data
  static const List<String> _sharedPrefKeys = [
    'saved_verses',
    'ramadan_data_2026',
    'charity_log_entries',
    'display_prayer_widget',
    'display_hijri_date',
    'display_fasting_widget',
    'display_dua_widget',
    'display_ramadan_day_offset',
    'display_use_24hour_format',
    'fasting_cache_date',
    'fasting_cache_data',
    'onboarding_completed',
  ];

  // ═══════════════════════════════════════════════════════════════
  // 📤 EXPORT — collect all data → JSON → file → share
  // ═══════════════════════════════════════════════════════════════

  /// Export all user data and save directly to device Downloads folder.
  /// Returns the saved file path on success, or empty string on failure.
  static Future<String> exportData() async {
    try {
      final backup = <String, dynamic>{
        'meta': {
          'version': _backupVersion,
          'app': 'Sukoon Launcher',
          'exportedAt': DateTime.now().toIso8601String(),
          'platform': Platform.operatingSystem,
        },
      };

      // ── 1. Export all Hive boxes ──
      final hiveData = <String, dynamic>{};
      for (final boxName in _hiveBoxNames) {
        try {
          final boxData = await _exportHiveBox(boxName);
          if (boxData.isNotEmpty) {
            hiveData[boxName] = boxData;
          }
        } catch (e) {
          debugPrint('Backup: Skipping box "$boxName": $e');
        }
      }
      backup['hive'] = hiveData;

      // ── 2. Export SharedPreferences ──
      final prefs = await SharedPreferences.getInstance();
      final prefsData = <String, dynamic>{};
      for (final key in _sharedPrefKeys) {
        try {
          // Use containsKey first, then read the actual value safely
          if (!prefs.containsKey(key)) continue;

          // Get the raw value — shared_preferences stores as Object?
          final raw = prefs.get(key);
          if (raw == null) continue;

          if (raw is String) {
            prefsData[key] = {'type': 'string', 'value': raw};
          } else if (raw is bool) {
            prefsData[key] = {'type': 'bool', 'value': raw};
          } else if (raw is int) {
            prefsData[key] = {'type': 'int', 'value': raw};
          } else if (raw is double) {
            prefsData[key] = {'type': 'double', 'value': raw};
          } else if (raw is List<String>) {
            prefsData[key] = {'type': 'stringList', 'value': raw};
          }
        } catch (e) {
          debugPrint('Backup: Skipping pref "$key": $e');
        }
      }
      backup['sharedPreferences'] = prefsData;

      // ── 3. Write directly to Downloads folder ──
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
      final fileName = 'sukoon_backup_$timestamp.json';
      final jsonString = const JsonEncoder.withIndent('  ').convert(backup);

      File? savedFile;

      // Try Downloads folder first (Android 10+: no permission needed)
      try {
        const downloadsPath = '/storage/emulated/0/Download';
        final downloadsDir = Directory(downloadsPath);
        if (await downloadsDir.exists()) {
          savedFile = File('$downloadsPath/$fileName');
          await savedFile.writeAsString(jsonString);
        }
      } catch (_) {
        savedFile = null;
      }

      // Fallback: app documents directory
      if (savedFile == null) {
        final dir = await getApplicationDocumentsDirectory();
        savedFile = File('${dir.path}/$fileName');
        await savedFile.writeAsString(jsonString);
      }

      return savedFile.path;
    } catch (e) {
      debugPrint('Backup export error: $e');
      return '';
    }
  }

  /// Export a single Hive box to a serializable map.
  /// Handles typed boxes (HiveObjects) and plain key-value boxes.
  static Future<Map<String, dynamic>> _exportHiveBox(String boxName) async {
    final result = <String, dynamic>{};

    // Open the box (reuse if already open)
    Box box;
    try {
      box = await _openBoxDynamic(boxName);
    } catch (e) {
      debugPrint('Backup: Cannot open box "$boxName": $e');
      return result;
    }

    for (final key in box.keys) {
      final value = box.get(key);
      if (value == null) continue;

      final strKey = key.toString();
      result[strKey] = _serializeValue(value);
    }

    return result;
  }

  /// Serialize any Hive value to a JSON-compatible structure.
  static dynamic _serializeValue(dynamic value) {
    if (value == null) return null;

    // Primitives
    if (value is String || value is int || value is double || value is bool) {
      return value;
    }

    // DateTime
    if (value is DateTime) {
      return {'__type': 'DateTime', 'value': value.toIso8601String()};
    }

    // List
    if (value is List) {
      return value.map((e) => _serializeValue(e)).toList();
    }

    // Map
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), _serializeValue(v)));
    }

    // ── Hive Model Objects ──
    if (value is Note) {
      return {
        '__type': 'Note',
        'id': value.id,
        'content': value.content,
        'createdAt': value.createdAt.toIso8601String(),
        'updatedAt': value.updatedAt.toIso8601String(),
      };
    }

    if (value is PrayerRecord) {
      return {
        '__type': 'PrayerRecord',
        'id': value.id,
        'date': value.date.toIso8601String(),
        'fajr': value.fajr,
        'dhuhr': value.dhuhr,
        'asr': value.asr,
        'maghrib': value.maghrib,
        'isha': value.isha,
        'createdAt': value.createdAt.toIso8601String(),
      };
    }

    if (value is TodoItem) {
      return {
        '__type': 'TodoItem',
        'id': value.id,
        'title': value.title,
        'isCompleted': value.isCompleted,
        'createdAt': value.createdAt.toIso8601String(),
        'dueDate': value.dueDate?.toIso8601String(),
        'priority': value.priority,
        'linkedEventId': value.linkedEventId,
        'linkedDoubtId': value.linkedDoubtId,
        'category': value.category,
      };
    }

    if (value is PomodoroSettings) {
      return {
        '__type': 'PomodoroSettings',
        'focusMinutes': value.focusMinutes,
        'shortBreakMinutes': value.shortBreakMinutes,
        'longBreakMinutes': value.longBreakMinutes,
        'sessionsBeforeLongBreak': value.sessionsBeforeLongBreak,
        'autoStartBreaks': value.autoStartBreaks,
        'autoStartFocus': value.autoStartFocus,
        'soundEnabled': value.soundEnabled,
        'autoBlockRuleId': value.autoBlockRuleId,
      };
    }

    if (value is AcademicDoubt) {
      return {
        '__type': 'AcademicDoubt',
        'id': value.id,
        'subject': value.subject,
        'question': value.question,
        'answer': value.answer,
        'isResolved': value.isResolved,
        'createdAt': value.createdAt.toIso8601String(),
        'resolvedAt': value.resolvedAt?.toIso8601String(),
        'urgency': value.urgency,
        'linkedTodoId': value.linkedTodoId,
        'tags': value.tags,
      };
    }

    if (value is ProductivityEvent) {
      return {
        '__type': 'ProductivityEvent',
        'id': value.id,
        'title': value.title,
        'description': value.description,
        'startTime': value.startTime.toIso8601String(),
        'endTime': value.endTime?.toIso8601String(),
        'color': value.color,
        'isAllDay': value.isAllDay,
        'linkedTodoId': value.linkedTodoId,
        'linkedBlockRuleId': value.linkedBlockRuleId,
        'hasReminder': value.hasReminder,
        'reminderMinutesBefore': value.reminderMinutesBefore,
        'repeatType': value.repeatType,
      };
    }

    if (value is AppBlockRule) {
      return {
        '__type': 'AppBlockRule',
        'id': value.id,
        'name': value.name,
        'blockedPackages': value.blockedPackages,
        'isEnabled': value.isEnabled,
        'isTimeBased': value.isTimeBased,
        'startHour': value.startHour,
        'startMinute': value.startMinute,
        'endHour': value.endHour,
        'endMinute': value.endMinute,
        'activeDays': value.activeDays,
        'linkedEventId': value.linkedEventId,
        'blockMessage': value.blockMessage,
        'allowBreaks': value.allowBreaks,
        'breaksTaken': value.breaksTaken,
        'maxBreaksPerSession': value.maxBreaksPerSession,
        'isHardBlock': value.isHardBlock,
        'expiresAt': value.expiresAt?.toIso8601String(),
      };
    }

    if (value is PrayerAlarmConfig) {
      return {
        '__type': 'PrayerAlarmConfig',
        'calculationMethod': value.calculationMethod,
        'latitude': value.latitude,
        'longitude': value.longitude,
        'timezone': value.timezone,
        'locationLabel': value.locationLabel,
        'lastFetchDate': value.lastFetchDate,
        'asrCalculationSchool': value.asrCalculationSchool,
      };
    }

    if (value is DailyPrayerTimes) {
      return {
        '__type': 'DailyPrayerTimes',
        'dateKey': value.dateKey,
        'fajr': value.fajr,
        'dhuhr': value.dhuhr,
        'asr': value.asr,
        'maghrib': value.maghrib,
        'isha': value.isha,
        'sunrise': value.sunrise,
      };
    }

    if (value is PrayerReminderSettings) {
      return {
        '__type': 'PrayerReminderSettings',
        'fajrEnabled': value.fajrEnabled,
        'dhuhrEnabled': value.dhuhrEnabled,
        'asrEnabled': value.asrEnabled,
        'maghribEnabled': value.maghribEnabled,
        'ishaEnabled': value.ishaEnabled,
        'fajrOverride': value.fajrOverride,
        'dhuhrOverride': value.dhuhrOverride,
        'asrOverride': value.asrOverride,
        'maghribOverride': value.maghribOverride,
        'ishaOverride': value.ishaOverride,
        'soundType': value.soundType,
        'volume': value.volume,
        'vibrationEnabled': value.vibrationEnabled,
        'snoozeDurationMinutes': value.snoozeDurationMinutes,
        'customSoundPath': value.customSoundPath,
      };
    }

    // Fallback: try toString
    return value.toString();
  }

  // ═══════════════════════════════════════════════════════════════
  // 📥 IMPORT — pick file → parse JSON → restore all data
  // ═══════════════════════════════════════════════════════════════

  /// Import data from a backup file.
  /// Returns a result message string.
  static Future<String> importData() async {
    try {
      // ── 1. Pick the backup file ──
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        return 'cancelled';
      }

      final filePath = result.files.single.path;
      if (filePath == null) return 'Error: Could not access file';

      final file = File(filePath);
      if (!await file.exists()) return 'Error: File not found';

      // ── 2. Parse JSON ──
      final jsonString = await file.readAsString();
      Map<String, dynamic> backup;
      try {
        backup = jsonDecode(jsonString) as Map<String, dynamic>;
      } catch (e) {
        return 'Error: Invalid backup file format';
      }

      // ── 3. Validate ──
      final meta = backup['meta'] as Map<String, dynamic>?;
      if (meta == null || meta['app'] != 'Sukoon Launcher') {
        return 'Error: Not a valid Sukoon Launcher backup';
      }

      final version = meta['version'] as int? ?? 0;
      if (version > _backupVersion) {
        return 'Error: Backup from newer app version. Please update the app.';
      }

      int restoredBoxes = 0;
      int restoredPrefs = 0;

      // ── 4. Restore Hive boxes ──
      final hiveData = backup['hive'] as Map<String, dynamic>?;
      if (hiveData != null) {
        for (final entry in hiveData.entries) {
          final boxName = entry.key;
          final boxData = entry.value as Map<String, dynamic>?;
          if (boxData == null || boxData.isEmpty) continue;

          try {
            await _importHiveBox(boxName, boxData);
            restoredBoxes++;
          } catch (e) {
            debugPrint('Import: Failed to restore box "$boxName": $e');
          }
        }
      }

      // ── 5. Restore SharedPreferences ──
      final prefsData = backup['sharedPreferences'] as Map<String, dynamic>?;
      if (prefsData != null) {
        final prefs = await SharedPreferences.getInstance();
        for (final entry in prefsData.entries) {
          try {
            final key = entry.key;
            final wrapper = entry.value as Map<String, dynamic>;
            final type = wrapper['type'] as String;
            final value = wrapper['value'];

            switch (type) {
              case 'string':
                await prefs.setString(key, value as String);
                break;
              case 'bool':
                await prefs.setBool(key, value as bool);
                break;
              case 'int':
                await prefs.setInt(key, value as int);
                break;
              case 'double':
                await prefs.setDouble(key, (value as num).toDouble());
                break;
              case 'stringList':
                await prefs.setStringList(key, (value as List).cast<String>());
                break;
            }
            restoredPrefs++;
          } catch (e) {
            debugPrint('Import: Failed to restore pref "${entry.key}": $e');
          }
        }
      }

      final exportedAt = meta['exportedAt'] as String? ?? 'unknown';
      return 'ok:Restored $restoredBoxes data categories and $restoredPrefs settings.\n'
             'Backup from: ${_formatDate(exportedAt)}';
    } catch (e) {
      debugPrint('Import error: $e');
      return 'Error: $e';
    }
  }

  /// Import a single Hive box from backup data.
  static Future<void> _importHiveBox(String boxName, Map<String, dynamic> data) async {
    Box box;
    try {
      box = await _openBoxDynamic(boxName);
    } catch (e) {
      debugPrint('Import: Cannot open box "$boxName": $e');
      return;
    }

    // Clear existing data first — full overwrite
    await box.clear();

    for (final entry in data.entries) {
      final key = entry.key;
      final value = _deserializeValue(entry.value);
      if (value != null) {
        await box.put(key, value);
      }
    }
  }

  /// Deserialize a JSON value back to its original Dart type.
  static dynamic _deserializeValue(dynamic value) {
    if (value == null) return null;

    // Primitives
    if (value is String || value is int || value is double || value is bool) {
      return value;
    }

    // List
    if (value is List) {
      return value.map((e) => _deserializeValue(e)).toList();
    }

    // Map — check for typed objects
    if (value is Map<String, dynamic>) {
      final type = value['__type'] as String?;

      if (type == 'DateTime') {
        return DateTime.parse(value['value'] as String);
      }

      if (type == 'Note') {
        return Note(
          id: value['id'] as String,
          content: value['content'] as String,
          createdAt: DateTime.parse(value['createdAt'] as String),
          updatedAt: DateTime.parse(value['updatedAt'] as String),
        );
      }

      if (type == 'PrayerRecord') {
        return PrayerRecord(
          id: value['id'] as String,
          date: DateTime.parse(value['date'] as String),
          fajr: value['fajr'] as bool? ?? false,
          dhuhr: value['dhuhr'] as bool? ?? false,
          asr: value['asr'] as bool? ?? false,
          maghrib: value['maghrib'] as bool? ?? false,
          isha: value['isha'] as bool? ?? false,
          createdAt: DateTime.parse(value['createdAt'] as String),
        );
      }

      if (type == 'TodoItem') {
        return TodoItem(
          id: value['id'] as String,
          title: value['title'] as String,
          isCompleted: value['isCompleted'] as bool? ?? false,
          createdAt: DateTime.parse(value['createdAt'] as String),
          dueDate: value['dueDate'] != null
              ? DateTime.parse(value['dueDate'] as String)
              : null,
          priority: value['priority'] as int? ?? 1,
          linkedEventId: value['linkedEventId'] as String?,
          linkedDoubtId: value['linkedDoubtId'] as String?,
          category: value['category'] as String? ?? 'general',
        );
      }

      if (type == 'PomodoroSettings') {
        return PomodoroSettings(
          focusMinutes: value['focusMinutes'] as int? ?? 25,
          shortBreakMinutes: value['shortBreakMinutes'] as int? ?? 5,
          longBreakMinutes: value['longBreakMinutes'] as int? ?? 15,
          sessionsBeforeLongBreak: value['sessionsBeforeLongBreak'] as int? ?? 4,
          autoStartBreaks: value['autoStartBreaks'] as bool? ?? false,
          autoStartFocus: value['autoStartFocus'] as bool? ?? false,
          soundEnabled: value['soundEnabled'] as bool? ?? true,
          autoBlockRuleId: value['autoBlockRuleId'] as String?,
        );
      }

      if (type == 'AcademicDoubt') {
        return AcademicDoubt(
          id: value['id'] as String,
          subject: value['subject'] as String,
          question: value['question'] as String,
          answer: value['answer'] as String?,
          isResolved: value['isResolved'] as bool? ?? false,
          createdAt: DateTime.parse(value['createdAt'] as String),
          resolvedAt: value['resolvedAt'] != null
              ? DateTime.parse(value['resolvedAt'] as String)
              : null,
          urgency: value['urgency'] as int? ?? 1,
          linkedTodoId: value['linkedTodoId'] as String?,
          tags: (value['tags'] as List?)?.cast<String>() ?? [],
        );
      }

      if (type == 'ProductivityEvent') {
        return ProductivityEvent(
          id: value['id'] as String,
          title: value['title'] as String,
          description: value['description'] as String?,
          startTime: DateTime.parse(value['startTime'] as String),
          endTime: value['endTime'] != null
              ? DateTime.parse(value['endTime'] as String)
              : null,
          color: value['color'] as String? ?? 'C2A366',
          isAllDay: value['isAllDay'] as bool? ?? false,
          linkedTodoId: value['linkedTodoId'] as String?,
          linkedBlockRuleId: value['linkedBlockRuleId'] as String?,
          hasReminder: value['hasReminder'] as bool? ?? false,
          reminderMinutesBefore: value['reminderMinutesBefore'] as int? ?? 15,
          repeatType: value['repeatType'] as String? ?? 'none',
        );
      }

      if (type == 'AppBlockRule') {
        return AppBlockRule(
          id: value['id'] as String,
          name: value['name'] as String,
          blockedPackages: (value['blockedPackages'] as List?)?.cast<String>() ?? [],
          isEnabled: value['isEnabled'] as bool? ?? true,
          isTimeBased: value['isTimeBased'] as bool? ?? false,
          startHour: value['startHour'] as int?,
          startMinute: value['startMinute'] as int?,
          endHour: value['endHour'] as int?,
          endMinute: value['endMinute'] as int?,
          activeDays: (value['activeDays'] as List?)?.cast<int>() ?? [1, 2, 3, 4, 5, 6, 7],
          linkedEventId: value['linkedEventId'] as String?,
          blockMessage: value['blockMessage'] as String? ?? 'Stay focused!',
          allowBreaks: value['allowBreaks'] as bool? ?? true,
          breaksTaken: value['breaksTaken'] as int? ?? 0,
          maxBreaksPerSession: value['maxBreaksPerSession'] as int? ?? 3,
          isHardBlock: value['isHardBlock'] as bool? ?? false,
          expiresAt: value['expiresAt'] != null
              ? DateTime.parse(value['expiresAt'] as String)
              : null,
        );
      }

      if (type == 'PrayerAlarmConfig') {
        return PrayerAlarmConfig(
          calculationMethod: value['calculationMethod'] as int? ?? 2,
          latitude: (value['latitude'] as num?)?.toDouble() ?? 0.0,
          longitude: (value['longitude'] as num?)?.toDouble() ?? 0.0,
          timezone: value['timezone'] as String? ?? 'UTC',
          locationLabel: value['locationLabel'] as String? ?? '',
          lastFetchDate: value['lastFetchDate'] as String?,
          asrCalculationSchool: value['asrCalculationSchool'] as int? ?? 0,
        );
      }

      if (type == 'DailyPrayerTimes') {
        return DailyPrayerTimes(
          dateKey: value['dateKey'] as String,
          fajr: value['fajr'] as String,
          dhuhr: value['dhuhr'] as String,
          asr: value['asr'] as String,
          maghrib: value['maghrib'] as String,
          isha: value['isha'] as String,
          sunrise: value['sunrise'] as String? ?? '',
        );
      }

      if (type == 'PrayerReminderSettings') {
        return PrayerReminderSettings(
          fajrEnabled: value['fajrEnabled'] as bool? ?? true,
          dhuhrEnabled: value['dhuhrEnabled'] as bool? ?? true,
          asrEnabled: value['asrEnabled'] as bool? ?? true,
          maghribEnabled: value['maghribEnabled'] as bool? ?? true,
          ishaEnabled: value['ishaEnabled'] as bool? ?? true,
          fajrOverride: value['fajrOverride'] as String? ?? '',
          dhuhrOverride: value['dhuhrOverride'] as String? ?? '',
          asrOverride: value['asrOverride'] as String? ?? '',
          maghribOverride: value['maghribOverride'] as String? ?? '',
          ishaOverride: value['ishaOverride'] as String? ?? '',
          soundType: value['soundType'] as String? ?? 'namaz_reminder',
          volume: (value['volume'] as num?)?.toDouble() ?? 0.8,
          vibrationEnabled: value['vibrationEnabled'] as bool? ?? true,
          snoozeDurationMinutes: value['snoozeDurationMinutes'] as int? ?? 10,
          customSoundPath: value['customSoundPath'] as String? ?? '',
        );
      }

      // Plain map — deserialize values recursively
      return value.map((k, v) => MapEntry(k, _deserializeValue(v)));
    }

    return value;
  }

  // ═══════════════════════════════════════════════════════════════
  // Helpers
  // ═══════════════════════════════════════════════════════════════

  /// Open a Hive box dynamically based on box name.
  /// Uses the correct type for typed boxes, falls back to dynamic.
  static Future<Box> _openBoxDynamic(String boxName) async {
    switch (boxName) {
      case 'notes':
        return await HiveBoxManager.get<Note>(boxName);
      case 'prayer_records':
        return await HiveBoxManager.get<PrayerRecord>(boxName);
      case 'productivity_todos':
        return await HiveBoxManager.get<TodoItem>(boxName);
      case 'productivity_events':
        return await HiveBoxManager.get<ProductivityEvent>(boxName);
      case 'academic_doubts':
        return await HiveBoxManager.get<AcademicDoubt>(boxName);
      case 'pomodoro_settings':
        return await HiveBoxManager.get<PomodoroSettings>(boxName);
      case 'app_block_rules':
        return await HiveBoxManager.get<AppBlockRule>(boxName);
      case 'prayer_alarm_config':
        return await HiveBoxManager.get(boxName);
      case 'prayer_alarm_times':
        return await HiveBoxManager.get<DailyPrayerTimes>(boxName);
      case 'prayer_reminder_settings':
        return await HiveBoxManager.get(boxName);
      case 'focus_categories':
        return await HiveBoxManager.get<List>(boxName);
      default:
        return await HiveBoxManager.get(boxName);
    }
  }

  /// Format an ISO date string for display
  static String _formatDate(String isoString) {
    try {
      final dt = DateTime.parse(isoString);
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}, '
             '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoString;
    }
  }

  /// Get a summary of what data exists (for display before export).
  static Future<Map<String, int>> getDataSummary() async {
    final summary = <String, int>{};

    try {
      final prayerBox = await HiveBoxManager.get<PrayerRecord>('prayer_records');
      summary['Prayer Records'] = prayerBox.length;
    } catch (_) {}

    try {
      final tasbihBox = await HiveBoxManager.get('tasbih_data');
      final totalCount = tasbihBox.get('totalAllTime', defaultValue: 0) as int;
      summary['Total Dhikr Count'] = totalCount;
    } catch (_) {}

    try {
      final noteBox = await HiveBoxManager.get<Note>('notes');
      summary['Notes'] = noteBox.length;
    } catch (_) {}

    try {
      final todoBox = await HiveBoxManager.get<TodoItem>('productivity_todos');
      summary['Todos'] = todoBox.length;
    } catch (_) {}

    try {
      final eventBox = await HiveBoxManager.get<ProductivityEvent>('productivity_events');
      summary['Events'] = eventBox.length;
    } catch (_) {}

    try {
      final doubtBox = await HiveBoxManager.get<AcademicDoubt>('academic_doubts');
      summary['Academic Doubts'] = doubtBox.length;
    } catch (_) {}

    try {
      final blockBox = await HiveBoxManager.get<AppBlockRule>('app_block_rules');
      summary['Block Rules'] = blockBox.length;
    } catch (_) {}

    try {
      final prefs = await SharedPreferences.getInstance();
      final versesJson = prefs.getString('saved_verses');
      if (versesJson != null) {
        final list = jsonDecode(versesJson) as List;
        summary['Saved Verses'] = list.length;
      }
    } catch (_) {}

    try {
      final prefs = await SharedPreferences.getInstance();
      final charityJson = prefs.getString('charity_log_entries');
      if (charityJson != null) {
        final list = jsonDecode(charityJson) as List;
        summary['Charity Entries'] = list.length;
      }
    } catch (_) {}

    return summary;
  }
}
