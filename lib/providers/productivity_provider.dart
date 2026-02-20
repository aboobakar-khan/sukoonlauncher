import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/productivity_models.dart';
import '../services/native_app_blocker_service.dart';

const _uuid = Uuid();

// ═══════════════════════════════════════════════════════════════════════════════
// 📋 TODO PROVIDER
// ═══════════════════════════════════════════════════════════════════════════════

class TodoNotifier extends StateNotifier<List<TodoItem>> {
  Box<TodoItem>? _box;

  TodoNotifier() : super([]) {
    _init();
  }

  Future<void> _init() async {
    _box = await Hive.openBox<TodoItem>('productivity_todos');
    state = _box!.values.toList()..sort(_sortTodos);
  }

  int _sortTodos(TodoItem a, TodoItem b) {
    // Incomplete first, then by priority (high→low), then by due date
    if (a.isCompleted != b.isCompleted) {
      return a.isCompleted ? 1 : -1;
    }
    if (a.priority != b.priority) return b.priority.compareTo(a.priority);
    if (a.dueDate != null && b.dueDate != null) {
      return a.dueDate!.compareTo(b.dueDate!);
    }
    if (a.dueDate != null) return -1;
    if (b.dueDate != null) return 1;
    return b.createdAt.compareTo(a.createdAt);
  }

  Future<TodoItem> addTodo({
    required String title,
    DateTime? dueDate,
    int priority = 1,
    String category = 'general',
    String? linkedEventId,
    String? linkedDoubtId,
  }) async {
    final todo = TodoItem(
      id: _uuid.v4(),
      title: title,
      createdAt: DateTime.now(),
      dueDate: dueDate,
      priority: priority,
      category: category,
      linkedEventId: linkedEventId,
      linkedDoubtId: linkedDoubtId,
    );
    await _box?.put(todo.id, todo);
    state = [...state.where((t) => t.id != todo.id), todo]..sort(_sortTodos);
    return todo;
  }

  Future<void> toggleTodo(String id) async {
    final todo = _box?.get(id);
    if (todo != null) {
      todo.isCompleted = !todo.isCompleted;
      await todo.save();
      state = _box!.values.toList()..sort(_sortTodos);
    }
  }

  Future<void> updateTodo(String id, {String? title, DateTime? dueDate, int? priority, String? category}) async {
    final todo = _box?.get(id);
    if (todo != null) {
      if (title != null) todo.title = title;
      if (dueDate != null) todo.dueDate = dueDate;
      if (priority != null) todo.priority = priority;
      if (category != null) todo.category = category;
      await todo.save();
      state = _box!.values.toList()..sort(_sortTodos);
    }
  }

  Future<void> deleteTodo(String id) async {
    await _box?.delete(id);
    state = state.where((t) => t.id != id).toList();
  }

  List<TodoItem> getByCategory(String category) {
    if (category == 'all') return state;
    return state.where((t) => t.category == category).toList();
  }

  List<TodoItem> getTodosForDate(DateTime date) {
    return state.where((t) {
      if (t.dueDate == null) return false;
      return t.dueDate!.year == date.year &&
          t.dueDate!.month == date.month &&
          t.dueDate!.day == date.day;
    }).toList();
  }

  int get completedToday {
    final now = DateTime.now();
    return state.where((t) =>
        t.isCompleted &&
        t.createdAt.year == now.year &&
        t.createdAt.month == now.month &&
        t.createdAt.day == now.day).length;
  }

  int get pendingCount => state.where((t) => !t.isCompleted).length;
}

final todoProvider = StateNotifierProvider<TodoNotifier, List<TodoItem>>(
  (ref) => TodoNotifier(),
);

// ═══════════════════════════════════════════════════════════════════════════════
// 🍅 POMODORO PROVIDER
// ═══════════════════════════════════════════════════════════════════════════════

enum PomodoroState { idle, focusing, shortBreak, longBreak, paused }

class PomodoroTimerState {
  final PomodoroState state;
  final PomodoroState? previousState; // Track what was running before pause
  final int remainingSeconds;
  final int completedSessions;
  final int totalFocusMinutesToday;
  final String? activeTodoId;
  final PomodoroSettings settings;

  PomodoroTimerState({
    this.state = PomodoroState.idle,
    this.previousState,
    this.remainingSeconds = 1500, // 25 min
    this.completedSessions = 0,
    this.totalFocusMinutesToday = 0,
    this.activeTodoId,
    PomodoroSettings? settings,
  }) : settings = settings ?? PomodoroSettings();

  PomodoroTimerState copyWith({
    PomodoroState? state,
    PomodoroState? previousState,
    int? remainingSeconds,
    int? completedSessions,
    int? totalFocusMinutesToday,
    String? activeTodoId,
    PomodoroSettings? settings,
    bool clearTodoId = false,
    bool clearPreviousState = false,
  }) {
    return PomodoroTimerState(
      state: state ?? this.state,
      previousState: clearPreviousState ? null : (previousState ?? this.previousState),
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      completedSessions: completedSessions ?? this.completedSessions,
      totalFocusMinutesToday: totalFocusMinutesToday ?? this.totalFocusMinutesToday,
      activeTodoId: clearTodoId ? null : (activeTodoId ?? this.activeTodoId),
      settings: settings ?? this.settings,
    );
  }

  String get timeDisplay {
    final min = remainingSeconds ~/ 60;
    final sec = remainingSeconds % 60;
    return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  double get progress {
    // Use previousState for paused to show accurate progress
    final effectiveState = state == PomodoroState.paused ? previousState ?? PomodoroState.focusing : state;
    final total = effectiveState == PomodoroState.focusing
        ? settings.focusMinutes * 60
        : effectiveState == PomodoroState.longBreak
            ? settings.longBreakMinutes * 60
            : settings.shortBreakMinutes * 60;
    if (total == 0) return 0;
    return 1.0 - (remainingSeconds / total);
  }
}

class PomodoroNotifier extends StateNotifier<PomodoroTimerState> {
  PomodoroNotifier() : super(PomodoroTimerState()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final box = await Hive.openBox<PomodoroSettings>('pomodoro_settings');
    if (box.isNotEmpty) {
      final settings = box.getAt(0)!;
      state = state.copyWith(
        settings: settings,
        remainingSeconds: settings.focusMinutes * 60,
      );
    }
  }

  void startFocus({String? todoId}) {
    state = state.copyWith(
      state: PomodoroState.focusing,
      remainingSeconds: state.settings.focusMinutes * 60,
      activeTodoId: todoId,
    );
  }

  void startBreak() {
    final isLong = (state.completedSessions + 1) %
            state.settings.sessionsBeforeLongBreak ==
        0;
    state = state.copyWith(
      state: isLong ? PomodoroState.longBreak : PomodoroState.shortBreak,
      remainingSeconds: isLong
          ? state.settings.longBreakMinutes * 60
          : state.settings.shortBreakMinutes * 60,
    );
  }

  void tick() {
    if (state.state == PomodoroState.idle || state.state == PomodoroState.paused) return;
    if (state.remainingSeconds <= 0) {
      _onTimerComplete();
      return;
    }
    state = state.copyWith(remainingSeconds: state.remainingSeconds - 1);
  }

  void _onTimerComplete() {
    if (state.state == PomodoroState.focusing) {
      // Focus complete → increment session
      state = state.copyWith(
        completedSessions: state.completedSessions + 1,
        totalFocusMinutesToday:
            state.totalFocusMinutesToday + state.settings.focusMinutes,
        state: PomodoroState.idle,
      );
      if (state.settings.autoStartBreaks) {
        startBreak();
      }
    } else {
      // Break complete → go idle or auto-start focus
      state = state.copyWith(state: PomodoroState.idle);
      if (state.settings.autoStartFocus) {
        startFocus(todoId: state.activeTodoId);
      }
    }
  }

  void pause() {
    // Save the current state so we can resume from it
    state = state.copyWith(
      previousState: state.state,
      state: PomodoroState.paused,
    );
  }

  /// Resume from paused — continues the timer from where it left off
  void resume() {
    if (state.state != PomodoroState.paused || state.previousState == null) return;
    state = state.copyWith(
      state: state.previousState,
      clearPreviousState: true,
    );
  }

  void reset() {
    state = state.copyWith(
      state: PomodoroState.idle,
      remainingSeconds: state.settings.focusMinutes * 60,
      clearTodoId: true,
      clearPreviousState: true,
    );
  }

  Future<void> updateSettings(PomodoroSettings settings) async {
    final box = await Hive.openBox<PomodoroSettings>('pomodoro_settings');
    if (box.isEmpty) {
      await box.add(settings);
    } else {
      await box.putAt(0, settings);
    }
    state = state.copyWith(settings: settings);
    if (state.state == PomodoroState.idle) {
      state = state.copyWith(remainingSeconds: settings.focusMinutes * 60);
    }
  }
}

final pomodoroProvider =
    StateNotifierProvider<PomodoroNotifier, PomodoroTimerState>(
  (ref) => PomodoroNotifier(),
);

// ═══════════════════════════════════════════════════════════════════════════════
// 📝 ACADEMIC DOUBTS PROVIDER
// ═══════════════════════════════════════════════════════════════════════════════

class AcademicDoubtNotifier extends StateNotifier<List<AcademicDoubt>> {
  Box<AcademicDoubt>? _box;

  AcademicDoubtNotifier() : super([]) {
    _init();
  }

  Future<void> _init() async {
    _box = await Hive.openBox<AcademicDoubt>('academic_doubts');
    state = _box!.values.toList()
      ..sort((a, b) {
        if (a.isResolved != b.isResolved) return a.isResolved ? 1 : -1;
        return b.createdAt.compareTo(a.createdAt);
      });
  }

  Future<AcademicDoubt> addDoubt({
    required String subject,
    required String question,
    int urgency = 1,
    List<String>? tags,
  }) async {
    final doubt = AcademicDoubt(
      id: _uuid.v4(),
      subject: subject,
      question: question,
      createdAt: DateTime.now(),
      urgency: urgency,
      tags: tags,
    );
    await _box?.put(doubt.id, doubt);
    state = [...state, doubt]..sort((a, b) {
        if (a.isResolved != b.isResolved) return a.isResolved ? 1 : -1;
        return b.createdAt.compareTo(a.createdAt);
      });
    return doubt;
  }

  Future<void> resolveDoubt(String id, String answer) async {
    final doubt = _box?.get(id);
    if (doubt != null) {
      doubt.answer = answer;
      doubt.isResolved = true;
      doubt.resolvedAt = DateTime.now();
      await doubt.save();
      state = _box!.values.toList()..sort((a, b) {
          if (a.isResolved != b.isResolved) return a.isResolved ? 1 : -1;
          return b.createdAt.compareTo(a.createdAt);
        });
    }
  }

  Future<void> updateDoubt(String id, {String? question, String? subject, int? urgency, List<String>? tags}) async {
    final doubt = _box?.get(id);
    if (doubt != null) {
      if (question != null) doubt.question = question;
      if (subject != null) doubt.subject = subject;
      if (urgency != null) doubt.urgency = urgency;
      if (tags != null) doubt.tags = tags;
      await doubt.save();
      state = _box!.values.toList()..sort((a, b) {
          if (a.isResolved != b.isResolved) return a.isResolved ? 1 : -1;
          return b.createdAt.compareTo(a.createdAt);
        });
    }
  }

  Future<void> deleteDoubt(String id) async {
    await _box?.delete(id);
    state = state.where((d) => d.id != id).toList();
  }

  List<AcademicDoubt> getBySubject(String subject) {
    return state.where((d) => d.subject == subject).toList();
  }

  List<String> get allSubjects {
    return state.map((d) => d.subject).toSet().toList()..sort();
  }

  int get unresolvedCount => state.where((d) => !d.isResolved).length;
}

final academicDoubtProvider =
    StateNotifierProvider<AcademicDoubtNotifier, List<AcademicDoubt>>(
  (ref) => AcademicDoubtNotifier(),
);

// ═══════════════════════════════════════════════════════════════════════════════
// 📅 EVENTS PROVIDER (Calendar-integrated)
// ═══════════════════════════════════════════════════════════════════════════════

class ProductivityEventNotifier extends StateNotifier<List<ProductivityEvent>> {
  Box<ProductivityEvent>? _box;

  ProductivityEventNotifier() : super([]) {
    _init();
  }

  Future<void> _init() async {
    _box = await Hive.openBox<ProductivityEvent>('productivity_events');
    state = _box!.values.toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  Future<ProductivityEvent> addEvent({
    required String title,
    String? description,
    required DateTime startTime,
    DateTime? endTime,
    String color = 'C2A366',
    bool isAllDay = false,
    String? linkedTodoId,
    String? linkedBlockRuleId,
    bool hasReminder = false,
    int reminderMinutesBefore = 15,
    String repeatType = 'none',
  }) async {
    final event = ProductivityEvent(
      id: _uuid.v4(),
      title: title,
      description: description,
      startTime: startTime,
      endTime: endTime,
      color: color,
      isAllDay: isAllDay,
      linkedTodoId: linkedTodoId,
      linkedBlockRuleId: linkedBlockRuleId,
      hasReminder: hasReminder,
      reminderMinutesBefore: reminderMinutesBefore,
      repeatType: repeatType,
    );
    await _box?.put(event.id, event);
    state = [...state, event]
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    return event;
  }

  Future<void> updateEvent(String id, {
    String? title,
    String? description,
    DateTime? startTime,
    DateTime? endTime,
    String? color,
    String? linkedBlockRuleId,
  }) async {
    final event = _box?.get(id);
    if (event != null) {
      if (title != null) event.title = title;
      if (description != null) event.description = description;
      if (startTime != null) event.startTime = startTime;
      if (endTime != null) event.endTime = endTime;
      if (color != null) event.color = color;
      if (linkedBlockRuleId != null) event.linkedBlockRuleId = linkedBlockRuleId;
      await event.save();
      state = _box!.values.toList()
        ..sort((a, b) => a.startTime.compareTo(b.startTime));
    }
  }

  Future<void> deleteEvent(String id) async {
    await _box?.delete(id);
    state = state.where((e) => e.id != id).toList();
  }

  List<ProductivityEvent> getEventsForDate(DateTime date) {
    return state.where((e) {
      final eventDate = DateTime(e.startTime.year, e.startTime.month, e.startTime.day);
      final targetDate = DateTime(date.year, date.month, date.day);
      return eventDate == targetDate;
    }).toList();
  }

  Set<DateTime> get eventDates {
    return state.map((e) => DateTime(
      e.startTime.year, e.startTime.month, e.startTime.day,
    )).toSet();
  }

  ProductivityEvent? getActiveEvent() {
    final now = DateTime.now();
    try {
      return state.firstWhere(
        (e) => e.startTime.isBefore(now) && (e.endTime?.isAfter(now) ?? e.startTime.day == now.day),
      );
    } catch (_) {
      return null;
    }
  }

  List<ProductivityEvent> getUpcoming({int limit = 5}) {
    final now = DateTime.now();
    return state.where((e) => e.startTime.isAfter(now)).take(limit).toList();
  }
}

final productivityEventProvider =
    StateNotifierProvider<ProductivityEventNotifier, List<ProductivityEvent>>(
  (ref) => ProductivityEventNotifier(),
);

/// Convenience provider: event dates for calendar dots
final productivityEventDatesProvider = Provider<Set<DateTime>>((ref) {
  final events = ref.watch(productivityEventProvider);
  return events.map((e) => DateTime(
    e.startTime.year, e.startTime.month, e.startTime.day,
  )).toSet();
});

/// Convenience provider: events for a specific date
final eventsForDateProvider = Provider.family<List<ProductivityEvent>, DateTime>((ref, date) {
  final events = ref.watch(productivityEventProvider);
  return events.where((e) {
    final d = DateTime(e.startTime.year, e.startTime.month, e.startTime.day);
    final t = DateTime(date.year, date.month, date.day);
    return d == t;
  }).toList();
});

// ═══════════════════════════════════════════════════════════════════════════════
// 🛡️ APP BLOCK RULES PROVIDER
// ═══════════════════════════════════════════════════════════════════════════════

class AppBlockRuleNotifier extends StateNotifier<List<AppBlockRule>> {
  Box<AppBlockRule>? _box;

  AppBlockRuleNotifier() : super([]) {
    _init();
  }

  Future<void> _init() async {
    _box = await Hive.openBox<AppBlockRule>('app_block_rules');
    state = _box!.values.toList();
    // Sync to native blocker on startup
    _syncToNativeBlocker();
  }

  /// Sync all currently-blocked packages to the native foreground service.
  /// This is the key integration point — the native service will monitor
  /// the foreground app and block any that are in this list.
  void _syncToNativeBlocker() {
    final now = DateTime.now();
    final allBlockedPackages = <String>{};

    for (final rule in state) {
      if (!rule.isEnabled) continue;

      if (rule.isTimeBased) {
        if (rule.startHour == null || rule.endHour == null) continue;
        if (!rule.activeDays.contains(now.weekday)) continue;

        final startMin = rule.startHour! * 60 + (rule.startMinute ?? 0);
        final endMin = rule.endHour! * 60 + (rule.endMinute ?? 0);
        final nowMin = now.hour * 60 + now.minute;

        bool inWindow;
        if (startMin <= endMin) {
          inWindow = nowMin >= startMin && nowMin <= endMin;
        } else {
          inWindow = nowMin >= startMin || nowMin <= endMin;
        }
        if (inWindow) {
          allBlockedPackages.addAll(rule.blockedPackages);
        }
      } else {
        // Manual toggle — always active when enabled
        allBlockedPackages.addAll(rule.blockedPackages);
      }
    }

    NativeAppBlockerService.updateBlockedPackages(allBlockedPackages.toList());
  }

  Future<AppBlockRule> addRule({
    required String name,
    List<String>? blockedPackages,
    bool isTimeBased = false,
    int? startHour,
    int? startMinute,
    int? endHour,
    int? endMinute,
    List<int>? activeDays,
    String? linkedEventId,
    String blockMessage = 'Stay focused! 🌙',
    bool allowBreaks = true,
    bool isHardBlock = false,
  }) async {
    final rule = AppBlockRule(
      id: _uuid.v4(),
      name: name,
      blockedPackages: blockedPackages,
      isTimeBased: isTimeBased,
      startHour: startHour,
      startMinute: startMinute,
      endHour: endHour,
      endMinute: endMinute,
      activeDays: activeDays,
      linkedEventId: linkedEventId,
      blockMessage: blockMessage,
      allowBreaks: allowBreaks,
      isHardBlock: isHardBlock,
    );
    await _box?.put(rule.id, rule);
    state = [...state, rule];
    _syncToNativeBlocker();
    return rule;
  }

  Future<void> toggleRule(String id) async {
    final rule = _box?.get(id);
    if (rule != null) {
      // Hard-blocked rules cannot be toggled
      if (rule.isHardBlock) return;
      rule.isEnabled = !rule.isEnabled;
      if (rule.isEnabled) rule.breaksTaken = 0; // Reset breaks on re-enable
      await rule.save();
      state = _box!.values.toList();
      _syncToNativeBlocker();
    }
  }

  Future<void> updateRule(String id, {
    String? name,
    List<String>? blockedPackages,
    bool? isTimeBased,
    int? startHour,
    int? startMinute,
    int? endHour,
    int? endMinute,
    List<int>? activeDays,
    String? linkedEventId,
    String? blockMessage,
  }) async {
    final rule = _box?.get(id);
    if (rule != null) {
      if (name != null) rule.name = name;
      if (blockedPackages != null) rule.blockedPackages = blockedPackages;
      if (isTimeBased != null) rule.isTimeBased = isTimeBased;
      if (startHour != null) rule.startHour = startHour;
      if (startMinute != null) rule.startMinute = startMinute;
      if (endHour != null) rule.endHour = endHour;
      if (endMinute != null) rule.endMinute = endMinute;
      if (activeDays != null) rule.activeDays = activeDays;
      if (linkedEventId != null) rule.linkedEventId = linkedEventId;
      if (blockMessage != null) rule.blockMessage = blockMessage;
      await rule.save();
      state = _box!.values.toList();
      _syncToNativeBlocker();
    }
  }

  Future<void> deleteRule(String id) async {
    final rule = _box?.get(id);
    // Hard-blocked rules cannot be deleted
    if (rule != null && rule.isHardBlock) return;
    await _box?.delete(id);
    state = state.where((r) => r.id != id).toList();
    _syncToNativeBlocker();
  }

  Future<void> takeBreak(String id) async {
    final rule = _box?.get(id);
    if (rule != null && rule.allowBreaks && rule.breaksTaken < rule.maxBreaksPerSession) {
      rule.breaksTaken++;
      await rule.save();
      state = _box!.values.toList();
    }
  }

  /// Check if a package is currently blocked by ANY active rule
  bool isAppBlocked(String packageName) {
    final now = DateTime.now();
    for (final rule in state) {
      if (!rule.isEnabled) continue;
      if (!rule.blockedPackages.contains(packageName)) continue;

      if (rule.isTimeBased) {
        // Check time window
        if (rule.startHour == null || rule.endHour == null) continue;
        if (!rule.activeDays.contains(now.weekday)) continue;

        final startMin = rule.startHour! * 60 + (rule.startMinute ?? 0);
        final endMin = rule.endHour! * 60 + (rule.endMinute ?? 0);
        final nowMin = now.hour * 60 + now.minute;

        if (startMin <= endMin) {
          if (nowMin >= startMin && nowMin <= endMin) return true;
        } else {
          // Overnight rule (e.g. 22:00 → 06:00)
          if (nowMin >= startMin || nowMin <= endMin) return true;
        }
      } else {
        // Manual toggle — always active when enabled
        return true;
      }
    }
    return false;
  }

  /// Get the block message for a blocked app
  String? getBlockMessage(String packageName) {
    for (final rule in state) {
      if (!rule.isEnabled) continue;
      if (rule.blockedPackages.contains(packageName)) {
        return rule.blockMessage;
      }
    }
    return null;
  }

  /// Get all active rules right now
  List<AppBlockRule> get activeRules {
    final now = DateTime.now();
    return state.where((rule) {
      if (!rule.isEnabled) return false;
      if (!rule.isTimeBased) return true;
      if (rule.startHour == null || rule.endHour == null) return false;
      if (!rule.activeDays.contains(now.weekday)) return false;
      final startMin = rule.startHour! * 60 + (rule.startMinute ?? 0);
      final endMin = rule.endHour! * 60 + (rule.endMinute ?? 0);
      final nowMin = now.hour * 60 + now.minute;
      if (startMin <= endMin) {
        return nowMin >= startMin && nowMin <= endMin;
      } else {
        return nowMin >= startMin || nowMin <= endMin;
      }
    }).toList();
  }
}

final appBlockRuleProvider =
    StateNotifierProvider<AppBlockRuleNotifier, List<AppBlockRule>>(
  (ref) => AppBlockRuleNotifier(),
);

// ═══════════════════════════════════════════════════════════════════════════════
// 🏷️ FOCUS CATEGORY PROVIDER
// ═══════════════════════════════════════════════════════════════════════════════

class FocusCategoryState {
  final List<String> categories;
  final String? activeCategory;

  const FocusCategoryState({
    this.categories = const ['Studying', 'Prototyping', 'Homework', 'Reading', 'Work'],
    this.activeCategory,
  });

  FocusCategoryState copyWith({
    List<String>? categories,
    String? activeCategory,
    bool clearActive = false,
  }) {
    return FocusCategoryState(
      categories: categories ?? this.categories,
      activeCategory: clearActive ? null : (activeCategory ?? this.activeCategory),
    );
  }
}

class FocusCategoryNotifier extends StateNotifier<FocusCategoryState> {
  FocusCategoryNotifier() : super(const FocusCategoryState()) {
    _init();
  }

  Future<void> _init() async {
    final box = await Hive.openBox<List>('focus_categories');
    final saved = box.get('categories');
    if (saved != null && saved.isNotEmpty) {
      state = state.copyWith(categories: saved.cast<String>());
    }
    final active = box.get('activeCategory');
    if (active != null && active.isNotEmpty) {
      state = state.copyWith(activeCategory: active.first as String);
    }
  }

  Future<void> _save() async {
    final box = await Hive.openBox<List>('focus_categories');
    await box.put('categories', state.categories);
    await box.put('activeCategory',
        state.activeCategory != null ? [state.activeCategory] : []);
  }

  void select(String category) {
    state = state.copyWith(
      activeCategory: category,
      clearActive: state.activeCategory == category,
    );
    _save();
  }

  Future<void> add(String category) async {
    if (category.isEmpty || state.categories.contains(category)) return;
    state = state.copyWith(categories: [...state.categories, category]);
    await _save();
  }

  Future<void> remove(String category) async {
    state = state.copyWith(
      categories: state.categories.where((c) => c != category).toList(),
      clearActive: state.activeCategory == category,
    );
    await _save();
  }
}

final focusCategoryProvider =
    StateNotifierProvider<FocusCategoryNotifier, FocusCategoryState>(
  (ref) => FocusCategoryNotifier(),
);

// ═══════════════════════════════════════════════════════════════════════════════
// 🏆 FOCUS STREAK PROVIDER
// ═══════════════════════════════════════════════════════════════════════════════

class FocusStreakNotifier extends StateNotifier<int> {
  FocusStreakNotifier() : super(0) {
    _init();
  }

  Future<void> _init() async {
    final box = await Hive.openBox('focus_streak');
    final lastDate = box.get('lastFocusDate') as String?;
    final streak = box.get('streak') as int? ?? 0;
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month}-${today.day}';
    final yesterday = today.subtract(const Duration(days: 1));
    final yesterdayStr = '${yesterday.year}-${yesterday.month}-${yesterday.day}';

    if (lastDate == todayStr) {
      state = streak;
    } else if (lastDate == yesterdayStr) {
      state = streak; // hasn't focused today yet, but streak preserved
    } else {
      state = 0; // streak broken
      await box.put('streak', 0);
    }
  }

  Future<void> recordSession() async {
    final box = await Hive.openBox('focus_streak');
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month}-${today.day}';
    final lastDate = box.get('lastFocusDate') as String?;

    if (lastDate != todayStr) {
      // First session today — increment streak
      final yesterday = today.subtract(const Duration(days: 1));
      final yesterdayStr = '${yesterday.year}-${yesterday.month}-${yesterday.day}';
      final currentStreak = box.get('streak') as int? ?? 0;

      if (lastDate == yesterdayStr || lastDate == null) {
        state = currentStreak + 1;
      } else {
        state = 1; // streak was broken, start fresh
      }
      await box.put('streak', state);
      await box.put('lastFocusDate', todayStr);
    }
  }
}

final focusStreakProvider =
    StateNotifierProvider<FocusStreakNotifier, int>(
  (ref) => FocusStreakNotifier(),
);
