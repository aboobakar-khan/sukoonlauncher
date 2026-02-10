import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/productivity_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/installed_apps_provider.dart';
import '../models/installed_app.dart';
import '../providers/premium_provider.dart';
import '../providers/sukoon_coin_provider.dart';
import '../models/productivity_models.dart';
import '../providers/ambient_sound_provider.dart';
import '../services/native_app_blocker_service.dart';
import '../widgets/zen_mode_widget.dart';
import 'premium_paywall_screen.dart';

// ─── Sukoon Design Tokens ────────────────────────────────────────────────────
const Color _sandGold = Color(0xFFC2A366);
const Color _warmBrown = Color(0xFFA67B5B);
const Color _oasisGreen = Color(0xFF7BAE6E);
const Color _desertWarm = Color(0xFFD4A96A);
const Color _desertSunset = Color(0xFFE8915A);

/// 🌙 Productivity Hub — Distraction-free tools
/// Features: Todo · Pomodoro · Academic Doubts · Events · App Blocker
class ProductivityHubScreen extends ConsumerStatefulWidget {
  const ProductivityHubScreen({super.key});

  @override
  ConsumerState<ProductivityHubScreen> createState() =>
      _ProductivityHubScreenState();
}

class _ProductivityHubScreenState extends ConsumerState<ProductivityHubScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Timer? _pomodoroTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _startPomodoroTicker();
  }

  void _startPomodoroTicker() {
    _pomodoroTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final pomo = ref.read(pomodoroProvider);
      if (pomo.state != PomodoroState.idle && pomo.state != PomodoroState.paused) {
        ref.read(pomodoroProvider.notifier).tick();
      }
      // Issue 7: Auto-manage ambient sound based on timer state
      _syncAmbientSound(pomo.state);
    });
  }

  PomodoroState? _lastPomodoroState;

  /// Sync ambient sound with pomodoro timer state
  void _syncAmbientSound(PomodoroState currentState) {
    if (_lastPomodoroState == currentState) return;
    final prev = _lastPomodoroState;
    _lastPomodoroState = currentState;

    final ambient = ref.read(ambientSoundProvider);
    final ambientNotifier = ref.read(ambientSoundProvider.notifier);

    // Timer started running → auto-play sound (even first time with default)
    if ((currentState == PomodoroState.focusing ||
         currentState == PomodoroState.shortBreak ||
         currentState == PomodoroState.longBreak) &&
        (prev == PomodoroState.paused || prev == PomodoroState.idle)) {
      if (!ambient.isPlaying) {
        // If user has a sound selected, play it; otherwise auto-pick 'rain' as default
        final soundId = ambient.currentSoundId ?? 'rain';
        ambientNotifier.selectAndPlay(soundId);
      }
    }
    // Timer paused → pause sound
    else if (currentState == PomodoroState.paused && ambient.isPlaying) {
      ambientNotifier.togglePlayPause();
    }
    // Timer stopped/reset → stop sound completely
    else if (currentState == PomodoroState.idle && prev != null && prev != PomodoroState.idle) {
      ambientNotifier.stop();
    }
  }

  @override
  void dispose() {
    _pomodoroTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = ref.watch(themeColorProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: TabBarView(
            controller: _tabController,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _PomodoroTab(),
              _TodoTab(),
              _DoubtsTab(),
              _BlockerTab(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomTabBar(themeColor.color),
    );
  }

  Widget _buildBottomTabBar(Color accent) {
    final icons = [
      Icons.timer_outlined,
      Icons.check_circle_outline,
      Icons.help_outline,
      Icons.shield_outlined,
    ];
    final labels = ['Focus', 'Tasks', 'Doubts', 'Block'];

    return AnimatedBuilder(
      animation: _tabController,
      builder: (ctx, _) {
        return Container(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.9),
            border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: List.generate(4, (i) {
                final selected = _tabController.index == i;
                return Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      _tabController.animateTo(i);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              icons[i],
                              size: selected ? 26 : 22,
                              color: selected
                                  ? _sandGold
                                  : Colors.white.withValues(alpha: 0.30),
                            ),
                          ),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 200),
                            child: selected
                                ? Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      labels[i],
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: _sandGold,
                                      ),
                                    ),
                                  )
                                : const SizedBox(height: 4),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 📋 TODO TAB
// ═══════════════════════════════════════════════════════════════════════════════

class _TodoTab extends ConsumerStatefulWidget {
  @override
  ConsumerState<_TodoTab> createState() => _TodoTabState();
}

class _TodoTabState extends ConsumerState<_TodoTab> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final todos = ref.watch(todoProvider);
    final events = ref.watch(productivityEventProvider);
    final filtered = _filter == 'all'
        ? todos
        : _filter == 'active'
            ? todos.where((t) => !t.isCompleted).toList()
            : todos.where((t) => t.isCompleted).toList();
    final pending = todos.where((t) => !t.isCompleted).length;

    // Events: show today's + upcoming (only in 'all' or 'active' filter)
    final now = DateTime.now();
    final todayEvents = (_filter != 'done')
        ? events.where((e) {
            final d = e.startTime;
            return d.year == now.year && d.month == now.month && d.day == now.day;
          }).toList()
        : <ProductivityEvent>[];
    final upcomingEvents = (_filter != 'done')
        ? events
            .where((e) => e.startTime.isAfter(now) &&
                !(e.startTime.year == now.year &&
                    e.startTime.month == now.month &&
                    e.startTime.day == now.day))
            .take(3)
            .toList()
        : <ProductivityEvent>[];

    // Build a unified list: today events → todos → upcoming events
    final hasEvents = todayEvents.isNotEmpty || upcomingEvents.isNotEmpty;
    final isEmpty = filtered.isEmpty && !hasEvents;

    return Column(
      children: [
        // Stats bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              Text(
                '$pending tasks pending',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              _filterChip('all'),
              const SizedBox(width: 6),
              _filterChip('active'),
              const SizedBox(width: 6),
              _filterChip('done'),
            ],
          ),
        ),
        // Unified list
        Expanded(
          child: isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_outline,
                          size: 48,
                          color: Colors.white.withValues(alpha: 0.15)),
                      const SizedBox(height: 12),
                      Text(
                        _filter == 'done'
                            ? 'No completed tasks'
                            : 'No tasks yet',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.3)),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  children: [
                    // Today's events
                    if (todayEvents.isNotEmpty) ...[
                      _sectionLabel('Today\'s Events'),
                      ...todayEvents.map((e) => _inlineEventTile(e)),
                      const SizedBox(height: 8),
                    ],
                    // Todos
                    ...filtered.map((t) => _todoTile(t)),
                    // Upcoming events
                    if (upcomingEvents.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _sectionLabel('Upcoming'),
                      ...upcomingEvents.map((e) => _inlineEventTile(e)),
                    ],
                  ],
                ),
        ),
        // Add buttons row — task + event
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: _AddButton(
                  label: 'Add Task',
                  icon: Icons.add,
                  onTap: () => _showAddTodo(context),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _showAddEvent(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: _sandGold.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _sandGold.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.event_outlined,
                          size: 16, color: _sandGold.withValues(alpha: 0.7)),
                      const SizedBox(width: 6),
                      Text('Event',
                          style: TextStyle(
                            color: _sandGold.withValues(alpha: 0.7),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          )),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 2),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.35),
          fontSize: 11,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _inlineEventTile(ProductivityEvent event) {
    final color = Color(int.parse('FF${event.color}', radix: 16));
    String timeText;
    if (event.isAllDay) {
      timeText = 'All day';
    } else if (event.endTime != null) {
      timeText = '${DateFormat('h:mm a').format(event.startTime)} — ${DateFormat('h:mm a').format(event.endTime!)}';
    } else if (event.startTime.hour == 9 && event.startTime.minute == 0) {
      timeText = DateFormat('MMM d').format(event.startTime);
    } else {
      timeText = DateFormat('h:mm a').format(event.startTime);
    }

    return GestureDetector(
      onLongPress: () => _showEventOptions(event),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.12)),
        ),
        child: Row(
          children: [
            Container(
              width: 3, height: 28,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event.title,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 13, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(timeText,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.35),
                          fontSize: 11)),
                ],
              ),
            ),
            Icon(Icons.event_outlined, size: 14,
                color: color.withValues(alpha: 0.4)),
          ],
        ),
      ),
    );
  }

  void _showEventOptions(ProductivityEvent event) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add_task, color: _sandGold),
              title: const Text('Create Todo from Event',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                ref.read(todoProvider.notifier).addTodo(
                      title: event.title,
                      dueDate: event.startTime,
                      linkedEventId: event.id,
                    );
                Navigator.pop(ctx);
                HapticFeedback.lightImpact();
              },
            ),
            ListTile(
              leading: const Icon(Icons.shield_outlined,
                  color: _desertSunset),
              title: const Text('Block apps during event',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _createBlockRuleForEvent(event);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline,
                  color: Colors.red.withValues(alpha: 0.6)),
              title: Text('Delete',
                  style: TextStyle(
                      color: Colors.red.withValues(alpha: 0.7))),
              onTap: () {
                ref
                    .read(productivityEventProvider.notifier)
                    .deleteEvent(event.id);
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _createBlockRuleForEvent(ProductivityEvent event) {
    final endHour = event.endTime?.hour ?? (event.startTime.hour + 1);
    final endMinute = event.endTime?.minute ?? event.startTime.minute;
    ref.read(appBlockRuleProvider.notifier).addRule(
          name: '${event.title} block',
          isTimeBased: true,
          startHour: event.startTime.hour,
          startMinute: event.startTime.minute,
          endHour: endHour,
          endMinute: endMinute,
          activeDays: [event.startTime.weekday],
          linkedEventId: event.id,
        );
  }

  Widget _filterChip(String label) {
    final selected = _filter == label;
    return GestureDetector(
      onTap: () => setState(() => _filter = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected
              ? _sandGold.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? _sandGold.withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Text(
          label[0].toUpperCase() + label.substring(1),
          style: TextStyle(
            fontSize: 11,
            color: selected ? _sandGold : Colors.white.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }

  Widget _todoTile(TodoItem todo) {
    final priorityColors = [
      Colors.white.withValues(alpha: 0.4),
      _oasisGreen,
      _desertWarm,
      _desertSunset,
    ];
    final color = priorityColors[todo.priority.clamp(0, 3)];

    return Dismissible(
      key: Key(todo.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.delete_outline,
            color: Colors.red.withValues(alpha: 0.6)),
      ),
      onDismissed: (_) => ref.read(todoProvider.notifier).deleteTodo(todo.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: ListTile(
          dense: true,
          leading: GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              ref.read(todoProvider.notifier).toggleTodo(todo.id);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: todo.isCompleted
                    ? _oasisGreen.withValues(alpha: 0.3)
                    : Colors.transparent,
                border: Border.all(
                  color: todo.isCompleted
                      ? _oasisGreen
                      : color.withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              child: todo.isCompleted
                  ? const Icon(Icons.check, size: 14, color: _oasisGreen)
                  : null,
            ),
          ),
          title: Text(
            todo.title,
            style: TextStyle(
              color: todo.isCompleted
                  ? Colors.white.withValues(alpha: 0.3)
                  : Colors.white.withValues(alpha: 0.85),
              fontSize: 14,
              decoration:
                  todo.isCompleted ? TextDecoration.lineThrough : null,
            ),
          ),
          subtitle: todo.dueDate != null
              ? Text(
                  DateFormat('MMM d, h:mm a').format(todo.dueDate!),
                  style: TextStyle(
                    fontSize: 11,
                    color: _isDueToday(todo.dueDate!)
                        ? _desertSunset.withValues(alpha: 0.7)
                        : Colors.white.withValues(alpha: 0.3),
                  ),
                )
              : null,
          trailing: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
          ),
        ),
      ),
    );
  }

  bool _isDueToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  void _showAddTodo(BuildContext context) {
    final controller = TextEditingController();
    int priority = 1;
    DateTime? dueDate;
    String? linkedDoubtId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setBS) => Container(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A1A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Text('New Task',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 18,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              // Text field
              TextField(
                controller: controller,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'What needs to be done?',
                  hintStyle:
                      TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.06),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Priority row
              Row(
                children: [
                  Text('Priority:',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 12)),
                  const SizedBox(width: 8),
                  for (int p = 1; p <= 3; p++)
                    GestureDetector(
                      onTap: () => setBS(() => priority = p),
                      child: Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: priority == p
                              ? [
                                  Colors.transparent,
                                  _oasisGreen,
                                  _desertWarm,
                                  _desertSunset
                                ][p]
                                  .withValues(alpha: 0.2)
                              : Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          ['', 'Low', 'Med', 'High'][p],
                          style: TextStyle(
                            fontSize: 11,
                            color: priority == p
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                    ),
                  const Spacer(),
                  // Due date
                  GestureDetector(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: ctx,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate:
                            DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date != null) {
                        final time = await showTimePicker(
                          context: ctx,
                          initialTime: TimeOfDay.now(),
                        );
                        setBS(() {
                          dueDate = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            time?.hour ?? 23,
                            time?.minute ?? 59,
                          );
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: dueDate != null
                            ? _sandGold.withValues(alpha: 0.15)
                            : Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.calendar_today,
                              size: 12,
                              color: dueDate != null
                                  ? _sandGold
                                  : Colors.white.withValues(alpha: 0.4)),
                          if (dueDate != null) ...[
                            const SizedBox(width: 4),
                            Text(
                              DateFormat('MMM d').format(dueDate!),
                              style: const TextStyle(
                                  fontSize: 11, color: _sandGold),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              // Link to doubt
              Consumer(builder: (ctx, cRef, _) {
                final doubts = cRef.watch(academicDoubtProvider)
                    .where((d) => !d.isResolved)
                    .toList();
                if (doubts.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: GestureDetector(
                    onTap: () {
                      _showLinkDoubtPicker(ctx, doubts, (id) {
                        setBS(() => linkedDoubtId = id);
                      });
                    },
                    child: Row(
                      children: [
                        Icon(Icons.link,
                            size: 14,
                            color: linkedDoubtId != null
                                ? _sandGold
                                : Colors.white.withValues(alpha: 0.3)),
                        const SizedBox(width: 6),
                        Text(
                          linkedDoubtId != null
                              ? 'Linked to doubt ✓'
                              : 'Link to academic doubt',
                          style: TextStyle(
                            fontSize: 12,
                            color: linkedDoubtId != null
                                ? _sandGold
                                : Colors.white.withValues(alpha: 0.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 16),
              // Submit
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (controller.text.trim().isEmpty) return;
                    ref.read(todoProvider.notifier).addTodo(
                          title: controller.text.trim(),
                          priority: priority,
                          dueDate: dueDate,
                          linkedDoubtId: linkedDoubtId,
                        );
                    Navigator.pop(ctx);
                    HapticFeedback.lightImpact();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _sandGold.withValues(alpha: 0.2),
                    foregroundColor: _sandGold,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Add Task'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLinkDoubtPicker(BuildContext context, List<AcademicDoubt> doubts,
      void Function(String) onSelect) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SizedBox(
        height: 300,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: doubts.length,
          itemBuilder: (ctx, i) => ListTile(
            dense: true,
            title: Text(doubts[i].question,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 13)),
            subtitle: Text(doubts[i].subject,
                style: TextStyle(
                    color: _sandGold.withValues(alpha: 0.6), fontSize: 11)),
            onTap: () {
              onSelect(doubts[i].id);
              Navigator.pop(ctx);
            },
          ),
        ),
      ),
    );
  }

  void _showAddEvent(BuildContext context) {
    final titleCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(hours: 1));
    TimeOfDay? selectedStartTime;
    TimeOfDay? selectedEndTime;
    bool isAllDay = false;
    bool hasSpecificTime = false;
    String selectedColor = 'C2A366';

    final colorOptions = {
      'C2A366': _sandGold,
      'A67B5B': _warmBrown,
      '7BAE6E': _oasisGreen,
      'E8915A': _desertSunset,
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setBS) => Container(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A1A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('New Event',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 18,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                TextField(
                  controller: titleCtrl,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Event title',
                    hintStyle:
                        TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.06),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                // Date picker
                GestureDetector(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: ctx,
                      initialDate: selectedDate,
                      firstDate: DateTime.now().subtract(const Duration(days: 1)),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) setBS(() => selectedDate = date);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today, size: 16, color: _sandGold.withValues(alpha: 0.7)),
                        const SizedBox(width: 10),
                        Text(DateFormat('EEE, MMM d').format(selectedDate),
                            style: const TextStyle(color: Colors.white, fontSize: 13)),
                        const Spacer(),
                        Icon(Icons.chevron_right, size: 16, color: Colors.white.withValues(alpha: 0.3)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // All day
                Row(
                  children: [
                    Text('All day', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13)),
                    const Spacer(),
                    Switch(value: isAllDay, onChanged: (v) => setBS(() { isAllDay = v; if (v) hasSpecificTime = false; }), activeColor: _sandGold),
                  ],
                ),
                if (!isAllDay) ...[
                  Row(
                    children: [
                      Text('Set time', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13)),
                      const Spacer(),
                      Switch(value: hasSpecificTime, onChanged: (v) => setBS(() { hasSpecificTime = v; if (v && selectedStartTime == null) selectedStartTime = TimeOfDay.fromDateTime(DateTime.now().add(const Duration(hours: 1))); }), activeColor: _sandGold),
                    ],
                  ),
                  if (hasSpecificTime) ...[
                    GestureDetector(
                      onTap: () async {
                        final time = await showTimePicker(context: ctx, initialTime: selectedStartTime ?? TimeOfDay.now());
                        if (time != null) setBS(() => selectedStartTime = time);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(10)),
                        child: Row(children: [
                          Text('Start', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
                          const Spacer(),
                          Text(selectedStartTime?.format(ctx) ?? 'Set', style: const TextStyle(color: Colors.white, fontSize: 13)),
                        ]),
                      ),
                    ),
                    GestureDetector(
                      onTap: () async {
                        final time = await showTimePicker(context: ctx, initialTime: selectedEndTime ?? TimeOfDay(hour: (selectedStartTime?.hour ?? TimeOfDay.now().hour) + 1, minute: selectedStartTime?.minute ?? 0));
                        if (time != null) setBS(() => selectedEndTime = time);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.04), borderRadius: BorderRadius.circular(10)),
                        child: Row(children: [
                          Text('End (optional)', style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 12)),
                          const Spacer(),
                          Text(selectedEndTime?.format(ctx) ?? '—', style: TextStyle(color: selectedEndTime != null ? Colors.white : Colors.white.withValues(alpha: 0.3), fontSize: 13)),
                        ]),
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 8),
                // Color
                Row(
                  children: [
                    Text('Color', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
                    const SizedBox(width: 12),
                    ...colorOptions.entries.map((e) => GestureDetector(
                          onTap: () => setBS(() => selectedColor = e.key),
                          child: Container(
                            margin: const EdgeInsets.only(right: 8), width: 24, height: 24,
                            decoration: BoxDecoration(color: e.value, shape: BoxShape.circle,
                              border: selectedColor == e.key ? Border.all(color: Colors.white, width: 2) : null),
                          ),
                        )),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (titleCtrl.text.trim().isEmpty) return;
                      DateTime finalStart;
                      DateTime? finalEnd;
                      if (isAllDay) {
                        finalStart = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
                      } else if (hasSpecificTime && selectedStartTime != null) {
                        finalStart = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, selectedStartTime!.hour, selectedStartTime!.minute);
                        if (selectedEndTime != null) {
                          finalEnd = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, selectedEndTime!.hour, selectedEndTime!.minute);
                        }
                      } else {
                        finalStart = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, 9, 0);
                      }
                      ref.read(productivityEventProvider.notifier).addEvent(
                            title: titleCtrl.text.trim(),
                            startTime: finalStart,
                            endTime: finalEnd,
                            color: selectedColor,
                            isAllDay: isAllDay,
                          );
                      Navigator.pop(ctx);
                      HapticFeedback.lightImpact();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _sandGold.withValues(alpha: 0.2),
                      foregroundColor: _sandGold,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Create Event'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 🍅 POMODORO TAB
// ═══════════════════════════════════════════════════════════════════════════════

class _PomodoroTab extends ConsumerStatefulWidget {
  @override
  ConsumerState<_PomodoroTab> createState() => _PomodoroTabState();
}

class _PomodoroTabState extends ConsumerState<_PomodoroTab> {
  int _prevSessionCount = 0;

  @override
  Widget build(BuildContext context) {
    final pomo = ref.watch(pomodoroProvider);
    final todos = ref.watch(todoProvider).where((t) => !t.isCompleted).toList();

    // 🪙 Award Sukoon Coins when a focus session completes (session count increases)
    if (pomo.completedSessions > _prevSessionCount) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(sukoonCoinProvider.notifier).awardPomodoroComplete();
        setState(() => _prevSessionCount = pomo.completedSessions);
      });
    }

    final stateColors = {
      PomodoroState.idle: Colors.white.withValues(alpha: 0.5),
      PomodoroState.focusing: _desertSunset,
      PomodoroState.shortBreak: _oasisGreen,
      PomodoroState.longBreak: _sandGold,
      PomodoroState.paused: Colors.white.withValues(alpha: 0.4),
    };

    final stateLabels = {
      PomodoroState.idle: 'Ready to Focus',
      PomodoroState.focusing: 'Stay Focused 🌙',
      PomodoroState.shortBreak: 'Short Break',
      PomodoroState.longBreak: 'Long Break',
      PomodoroState.paused: 'Paused',
    };

    final accent = stateColors[pomo.state]!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const Spacer(flex: 1),

          // ── Preset chips (only when idle) ──
          if (pomo.state == PomodoroState.idle) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _PresetChip(
                  label: '25 / 5',
                  subtitle: 'Classic',
                  isSelected: pomo.settings.focusMinutes == 25 && pomo.settings.shortBreakMinutes == 5,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    ref.read(pomodoroProvider.notifier).updateSettings(
                      PomodoroSettings(focusMinutes: 25, shortBreakMinutes: 5, longBreakMinutes: 15, sessionsBeforeLongBreak: pomo.settings.sessionsBeforeLongBreak),
                    );
                  },
                ),
                const SizedBox(width: 8),
                _PresetChip(
                  label: '50 / 10',
                  subtitle: 'Extended',
                  isSelected: pomo.settings.focusMinutes == 50 && pomo.settings.shortBreakMinutes == 10,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    ref.read(pomodoroProvider.notifier).updateSettings(
                      PomodoroSettings(focusMinutes: 50, shortBreakMinutes: 10, longBreakMinutes: 20, sessionsBeforeLongBreak: pomo.settings.sessionsBeforeLongBreak),
                    );
                  },
                ),
                const SizedBox(width: 8),
                _PresetChip(
                  label: '90',
                  subtitle: 'Deep',
                  isSelected: pomo.settings.focusMinutes == 90,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    ref.read(pomodoroProvider.notifier).updateSettings(
                      PomodoroSettings(focusMinutes: 90, shortBreakMinutes: 15, longBreakMinutes: 30, sessionsBeforeLongBreak: 2),
                    );
                  },
                ),
                const SizedBox(width: 8),
                // Custom — opens settings
                GestureDetector(
                  onTap: () => _showPomodoroSettings(context, ref, pomo.settings),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                    ),
                    child: Icon(Icons.tune_rounded, size: 16, color: Colors.white.withValues(alpha: 0.35)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],

          // ── Timer Ring ──
          SizedBox(
            width: 220,
            height: 220,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Background ring
                SizedBox(
                  width: 200,
                  height: 200,
                  child: CircularProgressIndicator(
                    value: 1.0,
                    strokeWidth: 4,
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
                // Progress ring
                SizedBox(
                  width: 200,
                  height: 200,
                  child: CircularProgressIndicator(
                    value: pomo.progress,
                    strokeWidth: 4,
                    color: accent,
                    strokeCap: StrokeCap.round,
                  ),
                ),
                // Time display
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      pomo.timeDisplay,
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w200,
                        color: Colors.white.withValues(alpha: 0.9),
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      stateLabels[pomo.state]!,
                      style: TextStyle(
                        fontSize: 12,
                        color: accent,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Session dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              pomo.settings.sessionsBeforeLongBreak,
              (i) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < pomo.completedSessions
                      ? _oasisGreen
                      : Colors.white.withValues(alpha: 0.12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${pomo.totalFocusMinutesToday} min focused today',
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.3),
            ),
          ),
          const Spacer(),
          // Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // When paused: show Resume + Break
              if (pomo.state == PomodoroState.paused) ...[
                _CircleButton(
                  icon: Icons.play_arrow_rounded,
                  color: _desertSunset.withValues(alpha: 0.2),
                  size: 64,
                  iconSize: 32,
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    ref.read(pomodoroProvider.notifier).resume();
                  },
                ),
                const SizedBox(width: 24),
                _CircleButton(
                  icon: Icons.coffee_rounded,
                  color: _oasisGreen.withValues(alpha: 0.2),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    ref.read(pomodoroProvider.notifier).startBreak();
                  },
                ),
              ]
              // When running: show Stop + Pause
              else if (pomo.state != PomodoroState.idle) ...[
                _CircleButton(
                  icon: Icons.stop_rounded,
                  color: Colors.white.withValues(alpha: 0.2),
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    ref.read(pomodoroProvider.notifier).reset();
                  },
                ),
                const SizedBox(width: 24),
                _CircleButton(
                  icon: Icons.pause_rounded,
                  color: accent.withValues(alpha: 0.2),
                  size: 64,
                  iconSize: 32,
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    ref.read(pomodoroProvider.notifier).pause();
                  },
                ),
              ]
              // When idle: show Play (+ Break if sessions > 0)
              else ...[
                _CircleButton(
                  icon: Icons.play_arrow_rounded,
                  color: accent.withValues(alpha: 0.2),
                  size: 64,
                  iconSize: 32,
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    ref.read(pomodoroProvider.notifier)
                        .startFocus(todoId: pomo.activeTodoId);
                  },
                ),
                if (pomo.completedSessions > 0) ...[
                  const SizedBox(width: 24),
                  _CircleButton(
                    icon: Icons.coffee_rounded,
                    color: _oasisGreen.withValues(alpha: 0.2),
                    onTap: () {
                      HapticFeedback.lightImpact();
                      ref.read(pomodoroProvider.notifier).startBreak();
                    },
                  ),
                ],
              ],
            ],
          ),
          const Spacer(),
          // Link to todo
          if (todos.isNotEmpty)
            _LinkTodoRow(
              activeTodoId: pomo.activeTodoId,
              todos: todos,
              onSelect: (id) {
                ref.read(pomodoroProvider.notifier).startFocus(todoId: id);
              },
            ),
          // Sound quick-toggle (only when idle or focusing)
          if (pomo.state == PomodoroState.idle || pomo.state == PomodoroState.focusing || pomo.state == PomodoroState.paused)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Consumer(
                builder: (ctx, sRef, _) {
                  final sound = sRef.watch(ambientSoundProvider);
                  final currentSound = sound.currentSoundId != null
                      ? ambientSounds.firstWhere((s) => s.id == sound.currentSoundId, orElse: () => ambientSounds.first)
                      : null;
                  return GestureDetector(
                    onTap: () => _showPomodoroSettings(context, ref, pomo.settings),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          sound.isPlaying ? '${currentSound?.emoji ?? '🎵'} ${currentSound?.name ?? 'Sound'}' : '🔇 No sound',
                          style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.3)),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.chevron_right_rounded, size: 14, color: Colors.white.withValues(alpha: 0.2)),
                      ],
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showPomodoroSettings(
      BuildContext context, WidgetRef ref, PomodoroSettings current) {
    int focus = current.focusMinutes;
    int shortBreak = current.shortBreakMinutes;
    int longBreak = current.longBreakMinutes;
    int sessions = current.sessionsBeforeLongBreak;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D0D0D),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setBS) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 28,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──
              Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: _sandGold.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.tune_rounded, color: _sandGold.withValues(alpha: 0.6), size: 18),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Focus Settings',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 17, fontWeight: FontWeight.w600)),
                      Text('Customize your session',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 11)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Timer Settings — Clean card ──
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: Column(
                  children: [
                    _SettingRow(
                      label: 'Focus',
                      value: focus,
                      suffix: 'min',
                      color: _desertSunset,
                      onMinus: () { if (focus > 5) setBS(() => focus -= 5); },
                      onPlus: () { if (focus < 90) setBS(() => focus += 5); },
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Container(height: 1, color: Colors.white.withValues(alpha: 0.04)),
                    ),
                    _SettingRow(
                      label: 'Short Break',
                      value: shortBreak,
                      suffix: 'min',
                      color: _oasisGreen,
                      onMinus: () { if (shortBreak > 1) setBS(() => shortBreak--); },
                      onPlus: () { if (shortBreak < 15) setBS(() => shortBreak++); },
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Container(height: 1, color: Colors.white.withValues(alpha: 0.04)),
                    ),
                    _SettingRow(
                      label: 'Long Break',
                      value: longBreak,
                      suffix: 'min',
                      color: _sandGold,
                      onMinus: () { if (longBreak > 5) setBS(() => longBreak -= 5); },
                      onPlus: () { if (longBreak < 30) setBS(() => longBreak += 5); },
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Container(height: 1, color: Colors.white.withValues(alpha: 0.04)),
                    ),
                    _SettingRow(
                      label: 'Sessions',
                      value: sessions,
                      suffix: '',
                      color: _warmBrown,
                      onMinus: () { if (sessions > 2) setBS(() => sessions--); },
                      onPlus: () { if (sessions < 8) setBS(() => sessions++); },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // ── Soothing Sounds ──
              Row(
                children: [
                  Icon(Icons.spa_rounded, color: _sandGold.withValues(alpha: 0.5), size: 16),
                  const SizedBox(width: 8),
                  Text('Soothing Sounds',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text('Auto-plays on focus',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.25), fontSize: 10)),
                ],
              ),
              const SizedBox(height: 12),
              Consumer(
                builder: (ctx, sRef, _) {
                  final soundState = sRef.watch(ambientSoundProvider);
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                    ),
                    child: Column(
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildSoundChip(
                              emoji: '🔇',
                              label: 'None',
                              isSelected: soundState.currentSoundId == null && !soundState.isPlaying,
                              onTap: () {
                                HapticFeedback.selectionClick();
                                sRef.read(ambientSoundProvider.notifier).stop();
                              },
                            ),
                            ...ambientSounds.map((sound) {
                              final isSelected = soundState.currentSoundId == sound.id;
                              return _buildSoundChip(
                                emoji: sound.emoji,
                                label: sound.name,
                                isSelected: isSelected && soundState.isPlaying,
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  if (isSelected && soundState.isPlaying) {
                                    sRef.read(ambientSoundProvider.notifier).stop();
                                  } else {
                                    sRef.read(ambientSoundProvider.notifier).selectAndPlay(sound.id);
                                  }
                                },
                              );
                            }),
                          ],
                        ),
                        // Volume slider — only if playing
                        if (soundState.isPlaying) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(Icons.volume_down_rounded,
                                  size: 15, color: Colors.white.withValues(alpha: 0.3)),
                              Expanded(
                                child: SliderTheme(
                                  data: SliderThemeData(
                                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                                    trackHeight: 2.5,
                                    activeTrackColor: _sandGold.withValues(alpha: 0.6),
                                    inactiveTrackColor: Colors.white.withValues(alpha: 0.06),
                                    thumbColor: _sandGold,
                                  ),
                                  child: Slider(
                                    value: soundState.volume,
                                    min: 0.0,
                                    max: 1.0,
                                    onChanged: (v) {
                                      sRef.read(ambientSoundProvider.notifier).setVolume(v);
                                    },
                                  ),
                                ),
                              ),
                              Icon(Icons.volume_up_rounded,
                                  size: 15, color: Colors.white.withValues(alpha: 0.3)),
                            ],
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 22),

              // ── Save Button ──
              GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  final s = PomodoroSettings(
                    focusMinutes: focus,
                    shortBreakMinutes: shortBreak,
                    longBreakMinutes: longBreak,
                    sessionsBeforeLongBreak: sessions,
                  );
                  ref.read(pomodoroProvider.notifier).updateSettings(s);
                  Navigator.pop(ctx);
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                    color: _sandGold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _sandGold.withValues(alpha: 0.2)),
                  ),
                  child: Center(
                    child: Text('Save',
                      style: TextStyle(color: _sandGold, fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }

  Widget _buildSoundChip({
    required String emoji,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? _sandGold.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected 
                ? _sandGold.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? _sandGold : Colors.white.withValues(alpha: 0.5),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 📝 ACADEMIC DOUBTS TAB
// ═══════════════════════════════════════════════════════════════════════════════

class _DoubtsTab extends ConsumerStatefulWidget {
  @override
  ConsumerState<_DoubtsTab> createState() => _DoubtsTabState();
}

class _DoubtsTabState extends ConsumerState<_DoubtsTab> {
  String _subjectFilter = 'All';

  @override
  Widget build(BuildContext context) {
    final doubts = ref.watch(academicDoubtProvider);
    final subjects = ['All', ...ref.read(academicDoubtProvider.notifier).allSubjects];
    final filtered = _subjectFilter == 'All'
        ? doubts
        : doubts.where((d) => d.subject == _subjectFilter).toList();
    final unresolved = doubts.where((d) => !d.isResolved).length;

    return Column(
      children: [
        // Subject filter chips
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: SizedBox(
            height: 32,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: subjects.map((s) {
                final selected = _subjectFilter == s;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () => setState(() => _subjectFilter = s),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: selected
                            ? _sandGold.withValues(alpha: 0.15)
                            : Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: selected
                              ? _sandGold.withValues(alpha: 0.3)
                              : Colors.white.withValues(alpha: 0.06),
                        ),
                      ),
                      child: Text(
                        s,
                        style: TextStyle(
                          fontSize: 11,
                          color: selected
                              ? _sandGold
                              : Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        // Stats
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Text(
                '$unresolved unresolved',
                style: TextStyle(
                    color: _desertSunset.withValues(alpha: 0.6),
                    fontSize: 11),
              ),
              const Spacer(),
              Text(
                '${doubts.length} total',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.3), fontSize: 11),
              ),
            ],
          ),
        ),
        // Doubts list
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lightbulb_outline,
                          size: 48,
                          color: Colors.white.withValues(alpha: 0.15)),
                      const SizedBox(height: 12),
                      Text('No doubts yet',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.3))),
                      const SizedBox(height: 4),
                      Text('Note down academic questions',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.2),
                              fontSize: 12)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) => _doubtCard(filtered[i]),
                ),
        ),
        // Add
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: _AddButton(
            label: 'Add Doubt',
            icon: Icons.add,
            onTap: () => _showAddDoubt(context),
          ),
        ),
      ],
    );
  }

  Widget _doubtCard(AcademicDoubt doubt) {
    return GestureDetector(
      onTap: () => _showDoubtDetail(doubt),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: doubt.isResolved
                ? _oasisGreen.withValues(alpha: 0.15)
                : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _sandGold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(doubt.subject,
                      style:
                          const TextStyle(fontSize: 10, color: _sandGold)),
                ),
                const Spacer(),
                if (doubt.isResolved)
                  Icon(Icons.check_circle,
                      size: 16,
                      color: _oasisGreen.withValues(alpha: 0.6)),
                if (!doubt.isResolved)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(
                      doubt.urgency.clamp(1, 3),
                      (_) => Icon(Icons.priority_high,
                          size: 10,
                          color: _desertSunset.withValues(alpha: 0.5)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              doubt.question,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 13,
                height: 1.4,
              ),
            ),
            if (doubt.answer != null && doubt.answer!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                doubt.answer!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _oasisGreen.withValues(alpha: 0.6),
                  fontSize: 11,
                ),
              ),
            ],
            if (doubt.tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                children: doubt.tags
                    .map((t) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(t,
                              style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.white.withValues(alpha: 0.3))),
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showDoubtDetail(AcademicDoubt doubt) {
    final answerController = TextEditingController(text: doubt.answer ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _sandGold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(doubt.subject,
                      style:
                          const TextStyle(fontSize: 11, color: _sandGold)),
                ),
                const Spacer(),
                // Delete
                IconButton(
                  icon: Icon(Icons.delete_outline,
                      size: 18,
                      color: Colors.red.withValues(alpha: 0.5)),
                  onPressed: () {
                    ref
                        .read(academicDoubtProvider.notifier)
                        .deleteDoubt(doubt.id);
                    Navigator.pop(ctx);
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              doubt.question,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 15,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Text('Answer / Resolution',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 12)),
            const SizedBox(height: 8),
            TextField(
              controller: answerController,
              maxLines: 4,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Type your answer or resolution...',
                hintStyle:
                    TextStyle(color: Colors.white.withValues(alpha: 0.2)),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.06),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      if (answerController.text.trim().isNotEmpty) {
                        ref
                            .read(academicDoubtProvider.notifier)
                            .resolveDoubt(
                                doubt.id, answerController.text.trim());
                      }
                      Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _oasisGreen.withValues(alpha: 0.2),
                      foregroundColor: _oasisGreen,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(doubt.isResolved
                        ? 'Update'
                        : 'Mark Resolved'),
                  ),
                ),
                // Create todo from doubt
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    ref.read(todoProvider.notifier).addTodo(
                          title: 'Resolve: ${doubt.question}',
                          priority: doubt.urgency,
                          linkedDoubtId: doubt.id,
                        );
                    Navigator.pop(ctx);
                    HapticFeedback.lightImpact();
                    // Brief non-blocking overlay instead of sticky snackbar
                    if (context.mounted) {
                      final overlay = Overlay.of(context);
                      final entry = OverlayEntry(
                        builder: (context) => Positioned(
                          top: MediaQuery.of(context).padding.top + 60,
                          left: 40,
                          right: 40,
                          child: Material(
                            color: Colors.transparent,
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0.0, end: 1.0),
                              duration: const Duration(milliseconds: 300),
                              builder: (context, value, child) => Opacity(
                                opacity: value,
                                child: Transform.translate(
                                  offset: Offset(0, -10 * (1 - value)),
                                  child: child,
                                ),
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1A2332),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: _sandGold.withValues(alpha: 0.2)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.3),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.check_circle_outline,
                                        color: _oasisGreen, size: 18),
                                    const SizedBox(width: 8),
                                    const Text('Todo created ✓',
                                        style: TextStyle(color: Colors.white,
                                            fontSize: 13, fontWeight: FontWeight.w500)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                      overlay.insert(entry);
                      Future.delayed(const Duration(milliseconds: 1500), () {
                        entry.remove();
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _sandGold.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.add_task,
                        size: 20, color: _sandGold),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAddDoubt(BuildContext context) {
    final questionCtrl = TextEditingController();
    final subjectCtrl = TextEditingController();
    final tagsCtrl = TextEditingController();
    int urgency = 1;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setBS) => Container(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A1A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('New Doubt',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 18,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              // Subject
              TextField(
                controller: subjectCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Subject (e.g. Math, Physics)',
                  hintStyle:
                      TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.06),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 10),
              // Question
              TextField(
                controller: questionCtrl,
                autofocus: true,
                maxLines: 3,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Describe your doubt...',
                  hintStyle:
                      TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.06),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 10),
              // Tags
              TextField(
                controller: tagsCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 12),
                decoration: InputDecoration(
                  hintText: 'Tags (comma separated)',
                  hintStyle:
                      TextStyle(color: Colors.white.withValues(alpha: 0.2)),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.04),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 10),
              // Urgency
              Row(
                children: [
                  Text('Urgency:',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 12)),
                  const SizedBox(width: 8),
                  for (int u = 1; u <= 3; u++)
                    GestureDetector(
                      onTap: () => setBS(() => urgency = u),
                      child: Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: urgency == u
                              ? [
                                  Colors.transparent,
                                  _oasisGreen,
                                  _desertWarm,
                                  _desertSunset
                                ][u]
                                  .withValues(alpha: 0.2)
                              : Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          ['', 'Low', 'Medium', 'Urgent'][u],
                          style: TextStyle(
                            fontSize: 11,
                            color: urgency == u
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (questionCtrl.text.trim().isEmpty) return;
                    final tags = tagsCtrl.text
                        .split(',')
                        .map((t) => t.trim())
                        .where((t) => t.isNotEmpty)
                        .toList();
                    ref.read(academicDoubtProvider.notifier).addDoubt(
                          subject: subjectCtrl.text.trim().isEmpty
                              ? 'General'
                              : subjectCtrl.text.trim(),
                          question: questionCtrl.text.trim(),
                          urgency: urgency,
                          tags: tags.isEmpty ? null : tags,
                        );
                    Navigator.pop(ctx);
                    HapticFeedback.lightImpact();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _sandGold.withValues(alpha: 0.2),
                    foregroundColor: _sandGold,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Add Doubt'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 📅 EVENTS TAB
// ═══════════════════════════════════════════════════════════════════════════════

class _EventsTab extends ConsumerStatefulWidget {
  @override
  ConsumerState<_EventsTab> createState() => _EventsTabState();
}

class _EventsTabState extends ConsumerState<_EventsTab> {
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final events = ref.watch(productivityEventProvider);
    final dateEvents = ref.watch(eventsForDateProvider(_selectedDate));
    final upcoming = events
        .where((e) => e.startTime.isAfter(DateTime.now()))
        .take(5)
        .toList();

    return Column(
      children: [
        // Date selector
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: _WeekStrip(
            selected: _selectedDate,
            eventDates: ref.watch(productivityEventDatesProvider),
            onSelect: (d) => setState(() => _selectedDate = d),
          ),
        ),
        // Events for date
        Expanded(
          child: dateEvents.isEmpty && upcoming.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.event_outlined,
                          size: 48,
                          color: Colors.white.withValues(alpha: 0.15)),
                      const SizedBox(height: 12),
                      Text('No events',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.3))),
                    ],
                  ),
                )
              : ListView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  children: [
                    if (dateEvents.isNotEmpty) ...[
                      Text(
                        DateFormat('EEEE, MMMM d').format(_selectedDate),
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 12,
                            fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      ...dateEvents.map(_eventCard),
                    ],
                    if (dateEvents.isEmpty && upcoming.isNotEmpty) ...[
                      Text('Upcoming',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 12,
                              fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      ...upcoming.map(_eventCard),
                    ],
                  ],
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: _AddButton(
            label: 'Add Event',
            icon: Icons.add,
            onTap: () => _showAddEvent(context),
          ),
        ),
      ],
    );
  }

  Widget _eventCard(ProductivityEvent event) {
    final color = Color(int.parse('FF${event.color}', radix: 16));
    final now = DateTime.now();
    final isActive = event.startTime.isBefore(now) && 
        (event.endTime?.isAfter(now) ?? event.startTime.day == now.day);

    String timeText;
    if (event.isAllDay) {
      timeText = 'All day';
    } else if (event.endTime != null) {
      timeText = '${DateFormat('h:mm a').format(event.startTime)} — ${DateFormat('h:mm a').format(event.endTime!)}';
    } else if (event.startTime.hour == 9 && event.startTime.minute == 0) {
      // Date-only event (no specific time set)
      timeText = DateFormat('MMM d').format(event.startTime);
    } else {
      timeText = DateFormat('h:mm a').format(event.startTime);
    }

    return GestureDetector(
      onLongPress: () => _showEventOptions(event),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isActive
              ? color.withValues(alpha: 0.1)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive
                ? color.withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 40,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    timeText,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (event.linkedBlockRuleId != null)
              Icon(Icons.shield_outlined,
                  size: 16,
                  color: _desertSunset.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }

  void _showEventOptions(ProductivityEvent event) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add_task, color: _sandGold),
              title: const Text('Create Todo from Event',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                ref.read(todoProvider.notifier).addTodo(
                      title: event.title,
                      dueDate: event.startTime,
                      linkedEventId: event.id,
                    );
                Navigator.pop(ctx);
                HapticFeedback.lightImpact();
              },
            ),
            ListTile(
              leading: const Icon(Icons.shield_outlined,
                  color: _desertSunset),
              title: const Text('Block apps during event',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _createBlockRuleForEvent(event);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline,
                  color: Colors.red.withValues(alpha: 0.6)),
              title: Text('Delete',
                  style: TextStyle(
                      color: Colors.red.withValues(alpha: 0.7))),
              onTap: () {
                ref
                    .read(productivityEventProvider.notifier)
                    .deleteEvent(event.id);
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _createBlockRuleForEvent(ProductivityEvent event) {
    // Auto-create a time-based block rule matching event time
    final endHour = event.endTime?.hour ?? (event.startTime.hour + 1);
    final endMinute = event.endTime?.minute ?? event.startTime.minute;
    ref.read(appBlockRuleProvider.notifier).addRule(
          name: '${event.title} block',
          isTimeBased: true,
          startHour: event.startTime.hour,
          startMinute: event.startTime.minute,
          endHour: endHour,
          endMinute: endMinute,
          activeDays: [event.startTime.weekday],
          linkedEventId: event.id,
        ).then((rule) {
      // Auto-open app selector for the new rule
      if (mounted) {
        _showEditAppsForRule(context, ref, rule);
      }
    });
  }

  void _showEditAppsForRule(BuildContext context, WidgetRef ref, AppBlockRule rule) {
    final allApps = ref.read(installedAppsProvider);
    final selected = Set<String>.from(rule.blockedPackages);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setBS) => SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Select Apps to Block',
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text('Block rule: ${rule.name}',
                              style: TextStyle(
                                  color: _sandGold.withValues(alpha: 0.5),
                                  fontSize: 12)),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        ref
                            .read(appBlockRuleProvider.notifier)
                            .updateRule(rule.id,
                                blockedPackages: selected.toList());
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${selected.length} apps will be blocked during event'),
                            backgroundColor: const Color(0xFF7BAE6E),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: _sandGold.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('Done',
                            style: TextStyle(
                                color: _sandGold, fontSize: 13)),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: allApps.length,
                  itemBuilder: (ctx, i) {
                    final app = allApps[i];
                    final isSelected =
                        selected.contains(app.packageName);
                    return ListTile(
                      dense: true,
                      title: Text(app.appName,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 13)),
                      subtitle: Text(app.packageName,
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.3),
                              fontSize: 10)),
                      trailing: Icon(
                        isSelected
                            ? Icons.check_circle
                            : Icons.circle_outlined,
                        color: isSelected
                            ? _desertSunset
                            : Colors.white.withValues(alpha: 0.2),
                        size: 20,
                      ),
                      onTap: () {
                        setBS(() {
                          if (isSelected) {
                            selected.remove(app.packageName);
                          } else {
                            selected.add(app.packageName);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddEvent(BuildContext context) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(hours: 1));
    TimeOfDay? selectedStartTime;
    TimeOfDay? selectedEndTime;
    bool isAllDay = false;
    bool hasSpecificTime = false;
    String selectedColor = 'C2A366';

    final colorOptions = {
      'C2A366': _sandGold,
      'A67B5B': _warmBrown,
      '7BAE6E': _oasisGreen,
      'E8915A': _desertSunset,
      'D4A96A': _desertWarm,
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setBS) => Container(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A1A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('New Event',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 18,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                TextField(
                  controller: titleCtrl,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Event title',
                    hintStyle:
                        TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.06),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descCtrl,
                  style:
                      const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Description (optional)',
                    hintStyle:
                        TextStyle(color: Colors.white.withValues(alpha: 0.2)),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.04),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                // Date picker (always shown)
                GestureDetector(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: ctx,
                      initialDate: selectedDate,
                      firstDate: DateTime.now().subtract(const Duration(days: 1)),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) {
                      setBS(() => selectedDate = date);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today, size: 16, color: _sandGold.withValues(alpha: 0.7)),
                        const SizedBox(width: 10),
                        Text('Date',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 12)),
                        const Spacer(),
                        Text(
                          DateFormat('EEE, MMM d, yyyy').format(selectedDate),
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.chevron_right,
                            size: 16,
                            color: Colors.white.withValues(alpha: 0.3)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // All day toggle
                Row(
                  children: [
                    Text('All day',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 13)),
                    const Spacer(),
                    Switch(
                      value: isAllDay,
                      onChanged: (v) => setBS(() {
                        isAllDay = v;
                        if (v) hasSpecificTime = false;
                      }),
                      activeColor: _sandGold,
                    ),
                  ],
                ),
                if (!isAllDay) ...[
                  // Add specific time toggle
                  Row(
                    children: [
                      Text('Add specific time',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 13)),
                      const Spacer(),
                      Switch(
                        value: hasSpecificTime,
                        onChanged: (v) => setBS(() {
                          hasSpecificTime = v;
                          if (v && selectedStartTime == null) {
                            selectedStartTime = TimeOfDay.fromDateTime(
                                DateTime.now().add(const Duration(hours: 1)));
                          }
                        }),
                        activeColor: _sandGold,
                      ),
                    ],
                  ),
                  if (hasSpecificTime) ...[
                    // Start time
                    GestureDetector(
                      onTap: () async {
                        final time = await showTimePicker(
                          context: ctx,
                          initialTime: selectedStartTime ?? TimeOfDay.now(),
                        );
                        if (time != null) {
                          setBS(() => selectedStartTime = time);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Text('Start',
                                style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.5),
                                    fontSize: 12)),
                            const Spacer(),
                            Text(
                              selectedStartTime?.format(ctx) ?? 'Set time',
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.chevron_right,
                                size: 16,
                                color: Colors.white.withValues(alpha: 0.3)),
                          ],
                        ),
                      ),
                    ),
                    // End time (optional)
                    GestureDetector(
                      onTap: () async {
                        final time = await showTimePicker(
                          context: ctx,
                          initialTime: selectedEndTime ??
                              TimeOfDay(
                                  hour: (selectedStartTime?.hour ?? TimeOfDay.now().hour) + 1,
                                  minute: selectedStartTime?.minute ?? 0),
                        );
                        if (time != null) {
                          setBS(() => selectedEndTime = time);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.04),
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: Row(
                          children: [
                            Text('End',
                                style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.35),
                                    fontSize: 12)),
                            const SizedBox(width: 4),
                            Text('(optional)',
                                style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    fontSize: 10,
                                    fontStyle: FontStyle.italic)),
                            const Spacer(),
                            Text(
                              selectedEndTime?.format(ctx) ?? '—',
                              style: TextStyle(
                                  color: selectedEndTime != null
                                      ? Colors.white
                                      : Colors.white.withValues(alpha: 0.3),
                                  fontSize: 13),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.chevron_right,
                                size: 16,
                                color: Colors.white.withValues(alpha: 0.3)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 12),
                // Color picker
                Row(
                  children: [
                    Text('Color',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 12)),
                    const SizedBox(width: 12),
                    ...colorOptions.entries.map((e) => GestureDetector(
                          onTap: () => setBS(() => selectedColor = e.key),
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: e.value,
                              shape: BoxShape.circle,
                              border: selectedColor == e.key
                                  ? Border.all(color: Colors.white, width: 2)
                                  : null,
                            ),
                          ),
                        )),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (titleCtrl.text.trim().isEmpty) return;
                      // Build startTime from date + optional time
                      DateTime finalStart;
                      DateTime? finalEnd;
                      if (isAllDay) {
                        finalStart = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
                        finalEnd = null;
                      } else if (hasSpecificTime && selectedStartTime != null) {
                        finalStart = DateTime(selectedDate.year, selectedDate.month,
                            selectedDate.day, selectedStartTime!.hour, selectedStartTime!.minute);
                        if (selectedEndTime != null) {
                          finalEnd = DateTime(selectedDate.year, selectedDate.month,
                              selectedDate.day, selectedEndTime!.hour, selectedEndTime!.minute);
                        }
                      } else {
                        // Date only, no specific time
                        finalStart = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, 9, 0);
                        finalEnd = null;
                      }
                      ref
                          .read(productivityEventProvider.notifier)
                          .addEvent(
                            title: titleCtrl.text.trim(),
                            description: descCtrl.text.trim().isEmpty
                                ? null
                                : descCtrl.text.trim(),
                            startTime: finalStart,
                            endTime: finalEnd,
                            color: selectedColor,
                            isAllDay: isAllDay,
                          );
                      Navigator.pop(ctx);
                      HapticFeedback.lightImpact();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _sandGold.withValues(alpha: 0.2),
                      foregroundColor: _sandGold,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Create Event'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 🛡️ APP BLOCKER TAB
// ═══════════════════════════════════════════════════════════════════════════════

class _BlockerTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rules = ref.watch(appBlockRuleProvider);

    return Column(
      children: [
        // ─── Zen Mode Card ────────────────────────────
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: ZenModeWidget(),
        ),

        // Active rules count
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              Icon(Icons.shield,
                  size: 14,
                  color: rules.any((r) => r.isEnabled)
                      ? _oasisGreen
                      : Colors.white.withValues(alpha: 0.3)),
              const SizedBox(width: 6),
              Text(
                '${rules.where((r) => r.isEnabled).length} active rules',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12),
              ),
            ],
          ),
        ),
        // Rules list
        Expanded(
          child: rules.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shield_outlined,
                          size: 48,
                          color: Colors.white.withValues(alpha: 0.15)),
                      const SizedBox(height: 12),
                      Text('No block rules',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.3))),
                      const SizedBox(height: 4),
                      Text('Block distracting apps 🌙',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.2),
                              fontSize: 12)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: rules.length,
                  itemBuilder: (ctx, i) => _ruleCard(ctx, ref, rules[i]),
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: _AddButton(
            label: 'New Block Rule',
            icon: Icons.add,
            onTap: () => _showAddRule(context, ref),
          ),
        ),
      ],
    );
  }

  Widget _ruleCard(BuildContext context, WidgetRef ref, AppBlockRule rule) {
    return GestureDetector(
      onTap: () => _showRuleInfoSheet(context, ref, rule),
      child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: rule.isHardBlock
            ? _desertSunset.withValues(alpha: 0.08)
            : rule.isEnabled
                ? _desertSunset.withValues(alpha: 0.06)
                : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: rule.isHardBlock
              ? _desertSunset.withValues(alpha: 0.35)
              : rule.isEnabled
                  ? _desertSunset.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (rule.isHardBlock) ...[
                Icon(Icons.lock, size: 14, color: _desertSunset.withValues(alpha: 0.7)),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  rule.name,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (rule.isHardBlock)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _desertSunset.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'HARD BLOCK',
                    style: TextStyle(
                      color: _desertSunset.withValues(alpha: 0.8),
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                )
              else
                // Toggle
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    if (rule.isEnabled) {
                      // Show confirmation before deactivating
                      _showDeactivateConfirmation(context, ref, rule);
                    } else {
                      ref.read(appBlockRuleProvider.notifier).toggleRule(rule.id);
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 44,
                    height: 24,
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: rule.isEnabled
                          ? _desertSunset.withValues(alpha: 0.3)
                          : Colors.white.withValues(alpha: 0.1),
                    ),
                    child: AnimatedAlign(
                      duration: const Duration(milliseconds: 200),
                      alignment: rule.isEnabled
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color:
                              rule.isEnabled ? _desertSunset : Colors.white38,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // Time / type info
          Row(
            children: [
              Icon(
                rule.isTimeBased ? Icons.schedule : Icons.block,
                size: 12,
                color: Colors.white.withValues(alpha: 0.3),
              ),
              const SizedBox(width: 4),
              Text(
                rule.isTimeBased
                    ? '${_formatHour(rule.startHour, rule.startMinute)} — ${_formatHour(rule.endHour, rule.endMinute)}'
                    : 'Manual toggle',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 11),
              ),
              const Spacer(),
              Text(
                '${rule.blockedPackages.length} apps',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.3),
                    fontSize: 11),
              ),
            ],
          ),
          if (rule.allowBreaks) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.free_breakfast_outlined, size: 11,
                    color: Colors.white.withValues(alpha: 0.25)),
                const SizedBox(width: 4),
                Text(
                  'Breaks allowed',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.25), fontSize: 10),
                ),
              ],
            ),
          ],
          // Locked info for all rules
          if (rule.isHardBlock)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 11, color: Colors.white.withValues(alpha: 0.2)),
                  const SizedBox(width: 4),
                  Text(
                    'Locked — cannot be modified or deleted',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.2),
                      fontSize: 10,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
    );
  }

  String _formatHour(int? h, int? m) {
    if (h == null) return '--:--';
    final hour = h % 12 == 0 ? 12 : h % 12;
    final ampm = h < 12 ? 'AM' : 'PM';
    return '$hour:${(m ?? 0).toString().padLeft(2, '0')} $ampm';
  }

  // ── Deactivation confirmation for easy-mode blockers ──
  void _showDeactivateConfirmation(BuildContext context, WidgetRef ref, AppBlockRule rule) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
        decoration: const BoxDecoration(
          color: Color(0xFF141414),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 28),
            // Shield icon
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: _desertSunset.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.shield_outlined, size: 30,
                  color: _desertSunset.withValues(alpha: 0.8)),
            ),
            const SizedBox(height: 20),
            Text(
              'Stay Focused',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.95),
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'You set this blocker for a reason.\nDisabling it now means giving in to distraction.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: _sandGold.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _sandGold.withValues(alpha: 0.15)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.format_quote, size: 14,
                      color: _sandGold.withValues(alpha: 0.6)),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      '"Discipline is choosing between what you\nwant now and what you want most."',
                      style: TextStyle(
                        color: _sandGold.withValues(alpha: 0.8),
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Keep it ON button (primary)
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.pop(ctx);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: _desertSunset.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _desertSunset.withValues(alpha: 0.4)),
                  ),
                  child: Center(
                    child: Text(
                      'Keep Blocker Active',
                      style: TextStyle(
                        color: _desertSunset,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Confirm deactivate button → 100-tap confirmation
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => _DeactivateRuleConfirmScreen(
                        ruleId: rule.id,
                        ruleName: rule.name,
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      'Confirm Deactivate',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.35),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditApps(BuildContext context, WidgetRef ref, AppBlockRule rule) {
    final allApps = ref.read(installedAppsProvider);
    final selected = Set<String>.from(rule.blockedPackages);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setBS) => SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Text('Select Apps to Block',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 16,
                            fontWeight: FontWeight.w600)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        ref
                            .read(appBlockRuleProvider.notifier)
                            .updateRule(rule.id,
                                blockedPackages: selected.toList());
                        Navigator.pop(ctx);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: _sandGold.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('Done',
                            style: TextStyle(
                                color: _sandGold, fontSize: 13)),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: allApps.length,
                  itemBuilder: (ctx, i) {
                    final app = allApps[i];
                    final isSelected =
                        selected.contains(app.packageName);
                    return ListTile(
                      dense: true,
                      title: Text(app.appName,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 13)),
                      subtitle: Text(app.packageName,
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.3),
                              fontSize: 10)),
                      trailing: Icon(
                        isSelected
                            ? Icons.check_circle
                            : Icons.circle_outlined,
                        color: isSelected
                            ? _desertSunset
                            : Colors.white.withValues(alpha: 0.2),
                        size: 20,
                      ),
                      onTap: () {
                        setBS(() {
                          if (isSelected) {
                            selected.remove(app.packageName);
                          } else {
                            selected.add(app.packageName);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Rule Info Sheet (shown after creation) ──
  void _showRuleInfoSheet(BuildContext context, WidgetRef ref, AppBlockRule rule) {
    final allApps = ref.read(installedAppsProvider);
    final dayLabels = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.75),
        decoration: const BoxDecoration(
          color: Color(0xFF141414),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Success indicator
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _oasisGreen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.check_circle_rounded,
                        color: _oasisGreen.withValues(alpha: 0.8), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Rule Created',
                            style: TextStyle(
                                color: _oasisGreen.withValues(alpha: 0.9),
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(rule.name,
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 17,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  if (rule.isHardBlock)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _desertSunset.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock, size: 10, color: _desertSunset.withValues(alpha: 0.8)),
                          const SizedBox(width: 4),
                          Text('HARD',
                              style: TextStyle(
                                  color: _desertSunset.withValues(alpha: 0.8),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Schedule / Timer info ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.schedule_rounded, size: 14,
                            color: _sandGold.withValues(alpha: 0.7)),
                        const SizedBox(width: 6),
                        Text('Schedule',
                            style: TextStyle(
                                color: _sandGold.withValues(alpha: 0.8),
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _infoChip(
                            Icons.play_arrow_rounded,
                            'Start',
                            _formatHour(rule.startHour, rule.startMinute),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.arrow_forward, size: 12,
                            color: Colors.white.withValues(alpha: 0.15)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _infoChip(
                            Icons.stop_rounded,
                            'End',
                            _formatHour(rule.endHour, rule.endMinute),
                          ),
                        ),
                      ],
                    ),
                    if (rule.activeDays.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        children: rule.activeDays.map((d) {
                          final label = d >= 1 && d <= 7 ? dayLabels[d] : '?';
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _sandGold.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(label,
                                style: TextStyle(
                                    color: _sandGold.withValues(alpha: 0.7),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500)),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ── Blocked Apps ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.block_rounded, size: 14,
                            color: _desertSunset.withValues(alpha: 0.7)),
                        const SizedBox(width: 6),
                        Text('Blocked Apps',
                            style: TextStyle(
                                color: _desertSunset.withValues(alpha: 0.8),
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                        const Spacer(),
                        Text('${rule.blockedPackages.length}',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.3),
                                fontSize: 11)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: rule.blockedPackages.map((pkg) {
                        final appName = allApps
                            .where((a) => a.packageName == pkg)
                            .map((a) => a.appName)
                            .firstOrNull ?? pkg.split('.').last;
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: _desertSunset.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _desertSunset.withValues(alpha: 0.15)),
                          ),
                          child: Text(appName,
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 11)),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ── Settings info ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                ),
                child: Row(
                  children: [
                    _settingPill(Icons.shield, rule.isHardBlock ? 'Hard Block' : 'Easy Block',
                        rule.isHardBlock ? _desertSunset : _oasisGreen),
                    const SizedBox(width: 8),
                    if (rule.allowBreaks)
                      _settingPill(Icons.free_breakfast_outlined, 'Breaks On', _sandGold),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Delete button ──
              if (!rule.isHardBlock)
                SizedBox(
                  width: double.infinity,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => _DeleteRuleConfirmScreen(
                            ruleId: rule.id,
                            ruleName: rule.name,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.withValues(alpha: 0.15)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.delete_outline, size: 16,
                              color: Colors.red.withValues(alpha: 0.6)),
                          const SizedBox(width: 8),
                          Text('Delete Rule',
                              style: TextStyle(
                                  color: Colors.red.withValues(alpha: 0.6),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ),
                ),

              // ── Done button ──
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: _sandGold.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text('Done',
                          style: TextStyle(
                              color: _sandGold,
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
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

  Widget _infoChip(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 11, color: Colors.white.withValues(alpha: 0.3)),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.35), fontSize: 10)),
            ],
          ),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8), fontSize: 13,
              fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _settingPill(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color.withValues(alpha: 0.7)),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(
              color: color.withValues(alpha: 0.8), fontSize: 11,
              fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  // ── Task 6: Show block type chooser — checks permissions first ──
  void _showAddRule(BuildContext context, WidgetRef ref) async {
    // Check if all required permissions are granted
    final hasUsage = await NativeAppBlockerService.hasUsageStatsPermission();
    final hasNotif = await NativeAppBlockerService.hasNotificationPermission();

    if (!hasUsage || !hasNotif) {
      // Show permission setup flow
      if (context.mounted) {
        final granted = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => _BlockerPermissionScreen(
              hasUsageStats: hasUsage,
              hasNotification: hasNotif,
            ),
          ),
        );
        if (granted != true) return; // User cancelled
      } else {
        return;
      }
    }

    if (!context.mounted) return;
    _showAddRuleChooser(context, ref);
  }

  void _showAddRuleChooser(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('New Block Rule',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 18,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text('Choose how to set up your blocker',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                    fontSize: 13)),
            const SizedBox(height: 20),
            // Option A: Custom Block (unified)
            _BlockTypeOption(
              icon: Icons.tune_rounded,
              color: _desertSunset,
              title: 'Custom Block',
              subtitle: 'Pick apps and choose your schedule',
              onTap: () {
                Navigator.pop(ctx);
                _showUnifiedBlockSheet(context, ref);
              },
            ),
            const SizedBox(height: 10),
            // Option B: Smart Packs
            _BlockTypeOption(
              icon: Icons.inventory_2_rounded,
              color: _oasisGreen,
              title: 'Smart Packs',
              subtitle: 'Pre-built packs — social media, games & more',
              onTap: () {
                Navigator.pop(ctx);
                _showSmartPackSheet(context, ref);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Unified Block Sheet (replaces Block Now + Scheduled Block) ──
  void _showUnifiedBlockSheet(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    Set<String> selectedApps = {};
    int scheduleMode = 0; // 0=Always, 1=Duration, 2=Time Window
    int durationMinutes = 30;
    int startH = 9, startM = 0, endH = 17, endM = 0;
    Set<int> activeDays = {1, 2, 3, 4, 5};
    int breakDifficulty = 0;
    final durations = [15, 30, 45, 60, 90, 120];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setBS) => Container(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.88),
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A1A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.tune_rounded,
                      color: _desertSunset.withValues(alpha: 0.7), size: 20),
                  const SizedBox(width: 8),
                  Text('Custom Block',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 18,
                          fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: 16),
                // Rule name
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Rule name (e.g. Study Focus)',
                    hintStyle:
                        TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.06),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),
                // Add Apps
                _buildAddAppsButton(ctx, ref, selectedApps, setBS),
                const SizedBox(height: 16),

                // Schedule mode selector
                Text('Schedule',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 13)),
                const SizedBox(height: 8),
                Row(children: [
                  _buildScheduleChip("Always On", 0, scheduleMode, _desertSunset, (v) => setBS(() => scheduleMode = v)),
                  const SizedBox(width: 8),
                  _buildScheduleChip("Duration", 1, scheduleMode, _desertSunset, (v) => setBS(() => scheduleMode = v)),
                  const SizedBox(width: 8),
                  _buildScheduleChip("Time Window", 2, scheduleMode, _desertSunset, (v) => setBS(() => scheduleMode = v)),
                ]),

                // Duration picker (mode 1)
                if (scheduleMode == 1) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: durations.map((d) {
                      final isSelected = durationMinutes == d;
                      final label = d >= 60 ? '${d ~/ 60}h${d % 60 > 0 ? " ${d % 60}m" : ""}' : '${d}m';
                      return GestureDetector(
                        onTap: () => setBS(() => durationMinutes = d),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? _desertSunset.withValues(alpha: 0.15)
                                : Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: isSelected
                                    ? _desertSunset.withValues(alpha: 0.4)
                                    : Colors.white.withValues(alpha: 0.06)),
                          ),
                          child: Text(label,
                              style: TextStyle(
                                  color: isSelected
                                      ? _desertSunset
                                      : Colors.white.withValues(alpha: 0.5),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500)),
                        ),
                      );
                    }).toList(),
                  ),
                ],

                // Time window picker (mode 2)
                if (scheduleMode == 2) ...[
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final time = await showTimePicker(
                              context: ctx, initialTime: TimeOfDay(hour: startH, minute: startM));
                          if (time != null) setBS(() { startH = time.hour; startM = time.minute; });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text('Start: ${_formatHour(startH, startM)}',
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              textAlign: TextAlign.center),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final time = await showTimePicker(
                              context: ctx, initialTime: TimeOfDay(hour: endH, minute: endM));
                          if (time != null) setBS(() { endH = time.hour; endM = time.minute; });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text('End: ${_formatHour(endH, endM)}',
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              textAlign: TextAlign.center),
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(7, (i) {
                      final day = i + 1;
                      final labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                      final active = activeDays.contains(day);
                      return GestureDetector(
                        onTap: () => setBS(() {
                          if (active) activeDays.remove(day); else activeDays.add(day);
                        }),
                        child: Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: active
                                ? _desertSunset.withValues(alpha: 0.2)
                                : Colors.white.withValues(alpha: 0.04),
                          ),
                          child: Center(
                            child: Text(labels[i],
                                style: TextStyle(
                                    fontSize: 12,
                                    color: active ? _desertSunset : Colors.white.withValues(alpha: 0.3))),
                          ),
                        ),
                      );
                    }),
                  ),
                ],

                const SizedBox(height: 16),
                // Break difficulty
                _buildBreakDifficultySelector(ref, breakDifficulty, (v) => setBS(() => breakDifficulty = v), ctx),
                const SizedBox(height: 20),
                // Create button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (nameCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                          content: const Text('Please enter a rule name'),
                          backgroundColor: Colors.red.withValues(alpha: 0.8),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ));
                        return;
                      }
                      if (selectedApps.isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                          content: const Text('Please add at least one app to block'),
                          backgroundColor: Colors.red.withValues(alpha: 0.8),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ));
                        return;
                      }

                      int sH = 0, sM = 0, eH = 23, eM = 59;
                      List<int> days = List.generate(7, (i) => i + 1);
                      bool isTimeBased = true;

                      if (scheduleMode == 1) {
                        final now = DateTime.now();
                        final end = now.add(Duration(minutes: durationMinutes));
                        sH = now.hour; sM = now.minute;
                        eH = end.hour; eM = end.minute;
                        days = [now.weekday];
                      } else if (scheduleMode == 2) {
                        sH = startH; sM = startM;
                        eH = endH; eM = endM;
                        days = activeDays.toList();
                      } else {
                        isTimeBased = false;
                      }

                      final newRule = await ref.read(appBlockRuleProvider.notifier).addRule(
                        name: nameCtrl.text.trim(),
                        blockedPackages: selectedApps.toList(),
                        isTimeBased: isTimeBased,
                        startHour: sH,
                        startMinute: sM,
                        endHour: eH,
                        endMinute: eM,
                        activeDays: days,
                        isHardBlock: breakDifficulty == 1,
                        allowBreaks: breakDifficulty == 0,
                      );
                      Navigator.pop(ctx);
                      HapticFeedback.lightImpact();
                      if (context.mounted) {
                        _showRuleInfoSheet(context, ref, newRule);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _desertSunset.withValues(alpha: 0.2),
                      foregroundColor: _desertSunset,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(scheduleMode == 1
                        ? 'Start Blocking \u00b7 ${durationMinutes}min'
                        : 'Create Rule'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Smart Packs (pre-built app packs) ──
  static const _smartPacks = <Map<String, dynamic>>[
    {
      'id': 'social_media',
      'name': 'Social Media',
      'icon': Icons.people_alt_rounded,
      'color': Color(0xFFE8915A), // desertSunset
      'desc': 'Instagram, TikTok, Facebook, Twitter & more',
      'apps': <Map<String, String>>[
        {'pkg': 'com.instagram.android', 'name': 'Instagram'},
        {'pkg': 'com.facebook.katana', 'name': 'Facebook'},
        {'pkg': 'com.twitter.android', 'name': 'X (Twitter)'},
        {'pkg': 'com.snapchat.android', 'name': 'Snapchat'},
        {'pkg': 'com.tiktok.android', 'name': 'TikTok'},
        {'pkg': 'com.zhiliaoapp.musically', 'name': 'TikTok Lite'},
        {'pkg': 'com.pinterest', 'name': 'Pinterest'},
        {'pkg': 'com.reddit.frontpage', 'name': 'Reddit'},
        {'pkg': 'com.linkedin.android', 'name': 'LinkedIn'},
        {'pkg': 'org.telegram.messenger', 'name': 'Telegram'},
        {'pkg': 'com.whatsapp', 'name': 'WhatsApp'},
        {'pkg': 'com.discord', 'name': 'Discord'},
        {'pkg': 'com.Slack', 'name': 'Slack'},
      ],
    },
    {
      'id': 'entertainment',
      'name': 'Entertainment',
      'icon': Icons.movie_rounded,
      'color': Color(0xFFC2A366), // sandGold
      'desc': 'YouTube, Netflix, Spotify, Twitch & more',
      'apps': <Map<String, String>>[
        {'pkg': 'com.google.android.youtube', 'name': 'YouTube'},
        {'pkg': 'com.netflix.mediaclient', 'name': 'Netflix'},
        {'pkg': 'com.spotify.music', 'name': 'Spotify'},
        {'pkg': 'tv.twitch.android.app', 'name': 'Twitch'},
        {'pkg': 'com.amazon.avod.thirdpartyclient', 'name': 'Prime Video'},
        {'pkg': 'com.disney.disneyplus', 'name': 'Disney+'},
        {'pkg': 'com.hulu.livingroomplus', 'name': 'Hulu'},
      ],
    },
    {
      'id': 'gaming',
      'name': 'Gaming',
      'icon': Icons.sports_esports_rounded,
      'color': Color(0xFF7BAE6E), // oasisGreen
      'desc': 'Popular games & game stores',
      'apps': <Map<String, String>>[
        {'pkg': 'com.supercell.clashofclans', 'name': 'Clash of Clans'},
        {'pkg': 'com.supercell.clashroyale', 'name': 'Clash Royale'},
        {'pkg': 'com.supercell.brawlstars', 'name': 'Brawl Stars'},
        {'pkg': 'com.kiloo.subwaysurf', 'name': 'Subway Surfers'},
        {'pkg': 'com.epicgames.fortnite', 'name': 'Fortnite'},
        {'pkg': 'com.mojang.minecraftpe', 'name': 'Minecraft'},
        {'pkg': 'com.activision.callofduty.shooter', 'name': 'COD Mobile'},
        {'pkg': 'com.tencent.ig', 'name': 'PUBG Mobile'},
        {'pkg': 'com.riotgames.league.wildrift', 'name': 'Wild Rift'},
        {'pkg': 'com.mobile.legends', 'name': 'Mobile Legends'},
      ],
    },
  ];

  // Check if a smart pack is already active (has a matching rule)
  Map<String, dynamic>? _getActivePackRule(WidgetRef ref, Map<String, dynamic> pack) {
    final rules = ref.read(appBlockRuleProvider);
    final packName = pack['name'] as String;
    final packApps = (pack['apps'] as List<Map<String, String>>).map((a) => a['pkg']!).toSet();

    for (final rule in rules) {
      // Match by name containing pack name, OR by significant overlap in blocked apps
      final rulePackages = rule.blockedPackages.toSet();
      final overlap = rulePackages.intersection(packApps);
      if (rule.name.toLowerCase().contains(packName.toLowerCase()) ||
          (overlap.length >= 3 && overlap.length >= rulePackages.length * 0.5)) {
        return {'rule': rule, 'isEnabled': rule.isEnabled};
      }
    }
    return null;
  }

  void _showSmartPackSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.inventory_2_rounded, color: _oasisGreen.withValues(alpha: 0.7), size: 20),
              const SizedBox(width: 8),
              Text("Smart Packs",
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 18,
                      fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 4),
            Text("One-tap block packs — review & customize apps",
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35), fontSize: 13)),
            const SizedBox(height: 20),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _smartPacks.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final pack = _smartPacks[i];
                  final packColor = pack['color'] as Color;
                  final apps = pack['apps'] as List<Map<String, String>>;
                  final activeInfo = _getActivePackRule(ref, pack);
                  final isActive = activeInfo != null && activeInfo['isEnabled'] == true;
                  final isInactive = activeInfo != null && activeInfo['isEnabled'] == false;

                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(ctx);
                      if (isActive || isInactive) {
                        // Edit existing rule — pass the active rule
                        final existingRule = activeInfo!['rule'] as AppBlockRule;
                        _showPackEditSheet(context, ref, pack, existingRule);
                      } else {
                        _showPackCustomizeSheet(context, ref, pack);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isActive
                            ? packColor.withValues(alpha: 0.1)
                            : packColor.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isActive
                              ? packColor.withValues(alpha: 0.4)
                              : packColor.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: packColor.withValues(alpha: isActive ? 0.18 : 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(pack['icon'] as IconData, color: packColor.withValues(alpha: 0.8), size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(pack['name'] as String,
                                          style: TextStyle(
                                              color: Colors.white.withValues(alpha: 0.9),
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600)),
                                    ),
                                    if (isActive) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: _oasisGreen.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.shield_rounded, size: 10, color: _oasisGreen.withValues(alpha: 0.9)),
                                            const SizedBox(width: 3),
                                            Text("ACTIVE",
                                                style: TextStyle(
                                                    color: _oasisGreen.withValues(alpha: 0.9),
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w700,
                                                    letterSpacing: 0.5)),
                                          ],
                                        ),
                                      ),
                                    ] else if (isInactive) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.06),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text("PAUSED",
                                            style: TextStyle(
                                                color: Colors.white.withValues(alpha: 0.3),
                                                fontSize: 9,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 0.5)),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(pack['desc'] as String,
                                    style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.35),
                                        fontSize: 12)),
                                const SizedBox(height: 6),
                                Text(isActive
                                    ? "${apps.length} apps \u00b7 Blocking"
                                    : "${apps.length} apps included",
                                    style: TextStyle(
                                        color: isActive
                                            ? _oasisGreen.withValues(alpha: 0.6)
                                            : packColor.withValues(alpha: 0.6),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                          Icon(isActive ? Icons.edit_rounded : Icons.arrow_forward_ios,
                              size: 14, color: Colors.white.withValues(alpha: isActive ? 0.3 : 0.15)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Pack customizer: review apps, pick schedule, create rule ──
  void _showPackCustomizeSheet(BuildContext context, WidgetRef ref, Map<String, dynamic> pack) {
    final packApps = (pack['apps'] as List<Map<String, String>>);
    final packColor = pack['color'] as Color;
    final packName = pack['name'] as String;
    final allInstalledApps = ref.read(installedAppsProvider);
    final installedPkgs = allInstalledApps.map((a) => a.packageName).toSet();

    // Pre-select only apps that are installed on the device
    Set<String> selectedApps = {};
    Map<String, String> appLabels = {};
    for (final app in packApps) {
      final pkg = app['pkg']!;
      appLabels[pkg] = app['name']!;
      if (installedPkgs.contains(pkg)) {
        selectedApps.add(pkg);
      }
    }

    int scheduleMode = 0; // 0=Always, 1=Block Now (duration), 2=Scheduled
    int durationMinutes = 60;
    int startH = 9, startM = 0, endH = 17, endM = 0;
    Set<int> activeDays = {1, 2, 3, 4, 5};
    int breakDifficulty = 1; // Default Hard for packs
    final durations = [15, 30, 45, 60, 90, 120];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setBS) => Container(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.88),
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A1A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(children: [
                  Icon(pack['icon'] as IconData, color: packColor.withValues(alpha: 0.7), size: 20),
                  const SizedBox(width: 8),
                  Text("$packName Pack",
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 18,
                          fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: packColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text("${selectedApps.length} apps",
                        style: TextStyle(color: packColor, fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                ]),
                const SizedBox(height: 16),

                // Apps list with toggles
                Text("Apps to Block",
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13)),
                const SizedBox(height: 4),
                Text("Remove any apps you want to keep accessible",
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.25), fontSize: 11)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: packApps.map((app) {
                    final pkg = app['pkg']!;
                    final name = app['name']!;
                    final isSelected = selectedApps.contains(pkg);
                    final isInstalled = installedPkgs.contains(pkg);
                    return GestureDetector(
                      onTap: isInstalled ? () {
                        HapticFeedback.selectionClick();
                        setBS(() {
                          if (isSelected) {
                            selectedApps.remove(pkg);
                          } else {
                            selectedApps.add(pkg);
                          }
                        });
                      } : null,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: !isInstalled
                              ? Colors.white.withValues(alpha: 0.02)
                              : isSelected
                                  ? packColor.withValues(alpha: 0.12)
                                  : Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: !isInstalled
                                ? Colors.white.withValues(alpha: 0.04)
                                : isSelected
                                    ? packColor.withValues(alpha: 0.3)
                                    : Colors.white.withValues(alpha: 0.06),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isSelected && isInstalled)
                              Icon(Icons.check_circle_rounded, size: 15, color: packColor.withValues(alpha: 0.8))
                            else if (!isInstalled)
                              Icon(Icons.block_rounded, size: 15, color: Colors.white.withValues(alpha: 0.15))
                            else
                              Icon(Icons.circle_outlined, size: 15, color: Colors.white.withValues(alpha: 0.2)),
                            const SizedBox(width: 6),
                            Text(name,
                                style: TextStyle(
                                    color: !isInstalled
                                        ? Colors.white.withValues(alpha: 0.2)
                                        : isSelected
                                            ? Colors.white.withValues(alpha: 0.8)
                                            : Colors.white.withValues(alpha: 0.4),
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400)),
                            if (!isInstalled) ...[
                              const SizedBox(width: 4),
                              Text("not installed",
                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.15), fontSize: 9)),
                            ],
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 20),

                // Schedule mode selector
                Text("Schedule",
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13)),
                const SizedBox(height: 8),
                Row(children: [
                  _buildScheduleChip("Always On", 0, scheduleMode, packColor, (v) => setBS(() => scheduleMode = v)),
                  const SizedBox(width: 8),
                  _buildScheduleChip("Duration", 1, scheduleMode, packColor, (v) => setBS(() => scheduleMode = v)),
                  const SizedBox(width: 8),
                  _buildScheduleChip("Time Window", 2, scheduleMode, packColor, (v) => setBS(() => scheduleMode = v)),
                ]),

                // Duration picker (mode 1)
                if (scheduleMode == 1) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: durations.map((d) {
                      final isSelected = durationMinutes == d;
                      final label = d >= 60 ? '${d ~/ 60}h${d % 60 > 0 ? " ${d % 60}m" : ""}' : '${d}m';
                      return GestureDetector(
                        onTap: () => setBS(() => durationMinutes = d),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? packColor.withValues(alpha: 0.15)
                                : Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: isSelected
                                    ? packColor.withValues(alpha: 0.4)
                                    : Colors.white.withValues(alpha: 0.06)),
                          ),
                          child: Text(label,
                              style: TextStyle(
                                  color: isSelected
                                      ? packColor
                                      : Colors.white.withValues(alpha: 0.5),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500)),
                        ),
                      );
                    }).toList(),
                  ),
                ],

                // Time window picker (mode 2)
                if (scheduleMode == 2) ...[
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final time = await showTimePicker(
                              context: ctx, initialTime: TimeOfDay(hour: startH, minute: startM));
                          if (time != null) setBS(() { startH = time.hour; startM = time.minute; });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text("Start: ${_formatHour(startH, startM)}",
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              textAlign: TextAlign.center),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final time = await showTimePicker(
                              context: ctx, initialTime: TimeOfDay(hour: endH, minute: endM));
                          if (time != null) setBS(() { endH = time.hour; endM = time.minute; });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text("End: ${_formatHour(endH, endM)}",
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              textAlign: TextAlign.center),
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(7, (i) {
                      final day = i + 1;
                      final labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                      final active = activeDays.contains(day);
                      return GestureDetector(
                        onTap: () => setBS(() {
                          if (active) activeDays.remove(day); else activeDays.add(day);
                        }),
                        child: Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: active
                                ? packColor.withValues(alpha: 0.2)
                                : Colors.white.withValues(alpha: 0.04),
                          ),
                          child: Center(
                            child: Text(labels[i],
                                style: TextStyle(
                                    fontSize: 12,
                                    color: active ? packColor : Colors.white.withValues(alpha: 0.3))),
                          ),
                        ),
                      );
                    }),
                  ),
                ],

                const SizedBox(height: 16),
                // Break difficulty
                _buildBreakDifficultySelector(ref, breakDifficulty, (v) => setBS(() => breakDifficulty = v), ctx),

                const SizedBox(height: 20),
                // Create button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (selectedApps.isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                          content: const Text("Select at least one app to block"),
                          backgroundColor: Colors.red.withValues(alpha: 0.8),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ));
                        return;
                      }

                      int sH = 0, sM = 0, eH = 23, eM = 59;
                      List<int> days = List.generate(7, (i) => i + 1);
                      bool isTimeBased = true;

                      if (scheduleMode == 1) {
                        // Duration-based: start now, end after X minutes
                        final now = DateTime.now();
                        final end = now.add(Duration(minutes: durationMinutes));
                        sH = now.hour; sM = now.minute;
                        eH = end.hour; eM = end.minute;
                        days = [now.weekday];
                      } else if (scheduleMode == 2) {
                        // Scheduled time window
                        sH = startH; sM = startM;
                        eH = endH; eM = endM;
                        days = activeDays.toList();
                      } else {
                        // Always on = not time-based
                        isTimeBased = false;
                      }

                      final newRule = await ref.read(appBlockRuleProvider.notifier).addRule(
                        name: "$packName Block",
                        blockedPackages: selectedApps.toList(),
                        isTimeBased: isTimeBased,
                        startHour: sH,
                        startMinute: sM,
                        endHour: eH,
                        endMinute: eM,
                        activeDays: days,
                        isHardBlock: breakDifficulty == 1,
                        allowBreaks: breakDifficulty == 0,
                      );
                      Navigator.pop(ctx);
                      HapticFeedback.lightImpact();
                      if (context.mounted) {
                        _showRuleInfoSheet(context, ref, newRule);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: packColor.withValues(alpha: 0.2),
                      foregroundColor: packColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text("Activate $packName Block"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Pack EDIT sheet: edit apps on an existing active smart pack rule ──
  void _showPackEditSheet(BuildContext context, WidgetRef ref, Map<String, dynamic> pack, AppBlockRule existingRule) {
    final packApps = (pack['apps'] as List<Map<String, String>>);
    final packColor = pack['color'] as Color;
    final packName = pack['name'] as String;
    final allInstalledApps = ref.read(installedAppsProvider);
    final installedPkgs = allInstalledApps.map((a) => a.packageName).toSet();

    // These are LOCKED — already blocked, cannot be removed
    final lockedApps = Set<String>.from(existingRule.blockedPackages);

    // Selected starts with locked apps; user can only ADD more
    Set<String> selectedApps = Set<String>.from(lockedApps);
    Map<String, String> appLabels = {};
    for (final app in packApps) {
      appLabels[app['pkg']!] = app['name']!;
    }
    // Also add labels for any apps in rule that aren't in pack definition
    for (final pkg in existingRule.blockedPackages) {
      if (!appLabels.containsKey(pkg)) {
        final appName = allInstalledApps
            .where((a) => a.packageName == pkg)
            .map((a) => a.appName)
            .firstOrNull ?? pkg.split('.').last;
        appLabels[pkg] = appName;
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setBS) => Container(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.75),
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A1A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(children: [
                  Icon(pack['icon'] as IconData, color: packColor.withValues(alpha: 0.7), size: 20),
                  const SizedBox(width: 8),
                  Text("Edit $packName",
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 18,
                          fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _oasisGreen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shield_rounded, size: 10, color: _oasisGreen.withValues(alpha: 0.9)),
                        const SizedBox(width: 4),
                        Text("${selectedApps.length} blocked",
                            style: TextStyle(color: _oasisGreen, fontSize: 11, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ]),
                const SizedBox(height: 16),

                Text("🔒 Existing apps are locked · Tap to add new apps",
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 12)),
                const SizedBox(height: 12),

                // Pack apps with toggle
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: packApps.map((app) {
                    final pkg = app['pkg']!;
                    final name = app['name']!;
                    final isSelected = selectedApps.contains(pkg);
                    final isInstalled = installedPkgs.contains(pkg);
                    final isLocked = lockedApps.contains(pkg);
                    return GestureDetector(
                      onTap: (isInstalled && !isLocked) ? () {
                        HapticFeedback.selectionClick();
                        setBS(() {
                          if (isSelected) {
                            selectedApps.remove(pkg);
                          } else {
                            selectedApps.add(pkg);
                          }
                        });
                      } : isLocked ? () {
                        HapticFeedback.heavyImpact();
                        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                          content: const Text("🔒 Active blocked apps can't be removed"),
                          backgroundColor: Colors.white.withValues(alpha: 0.1),
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ));
                      } : null,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: !isInstalled
                              ? Colors.white.withValues(alpha: 0.02)
                              : isLocked
                                  ? packColor.withValues(alpha: 0.18)
                                  : isSelected
                                      ? packColor.withValues(alpha: 0.12)
                                      : Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: !isInstalled
                                ? Colors.white.withValues(alpha: 0.04)
                                : isLocked
                                    ? packColor.withValues(alpha: 0.5)
                                    : isSelected
                                        ? packColor.withValues(alpha: 0.3)
                                        : Colors.white.withValues(alpha: 0.06),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isLocked)
                              Icon(Icons.lock_rounded, size: 15, color: packColor.withValues(alpha: 0.9))
                            else if (isSelected && isInstalled)
                              Icon(Icons.check_circle_rounded, size: 15, color: packColor.withValues(alpha: 0.8))
                            else if (!isInstalled)
                              Icon(Icons.block_rounded, size: 15, color: Colors.white.withValues(alpha: 0.15))
                            else
                              Icon(Icons.circle_outlined, size: 15, color: Colors.white.withValues(alpha: 0.2)),
                            const SizedBox(width: 6),
                            Text(name,
                                style: TextStyle(
                                    color: !isInstalled
                                        ? Colors.white.withValues(alpha: 0.2)
                                        : isLocked
                                            ? Colors.white.withValues(alpha: 0.9)
                                            : isSelected
                                                ? Colors.white.withValues(alpha: 0.8)
                                                : Colors.white.withValues(alpha: 0.4),
                                    fontSize: 12,
                                    fontWeight: isLocked ? FontWeight.w600 : isSelected ? FontWeight.w500 : FontWeight.w400)),
                            if (isLocked) ...[
                              const SizedBox(width: 4),
                              Text("locked",
                                  style: TextStyle(color: packColor.withValues(alpha: 0.6), fontSize: 9, fontWeight: FontWeight.w600)),
                            ],
                            if (!isInstalled) ...[
                              const SizedBox(width: 4),
                              Text("not installed",
                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.15), fontSize: 9)),
                            ],
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 24),

                // Save button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (selectedApps.isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                          content: const Text("At least 1 app must be blocked"),
                          backgroundColor: Colors.red.withValues(alpha: 0.8),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ));
                        return;
                      }
                      ref.read(appBlockRuleProvider.notifier).updateRule(
                        existingRule.id,
                        blockedPackages: selectedApps.toList(),
                      );
                      Navigator.pop(ctx);
                      HapticFeedback.lightImpact();
                      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                        content: Text('$packName updated · ${selectedApps.length} apps blocked'),
                        backgroundColor: _oasisGreen,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: packColor.withValues(alpha: 0.2),
                      foregroundColor: packColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text("Save Changes"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScheduleChip(String label, int value, int selected, Color color, ValueChanged<int> onTap) {
    final isActive = selected == value;
    return GestureDetector(
      onTap: () { HapticFeedback.selectionClick(); onTap(value); },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: isActive ? color.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive ? color.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Text(label,
            style: TextStyle(
                color: isActive ? color : Colors.white.withValues(alpha: 0.4),
                fontSize: 12,
                fontWeight: FontWeight.w500)),
      ),
    );
  }

  // ── Shared: "Add Apps" button + selected chips ──
  Widget _buildAddAppsButton(
      BuildContext ctx, WidgetRef ref, Set<String> selectedApps, StateSetter setBS) {
    final allApps = ref.read(installedAppsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text('Apps to Block',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6), fontSize: 13)),
          const Spacer(),
          if (selectedApps.isNotEmpty)
            Text('${selectedApps.length} selected',
                style: TextStyle(
                    color: _desertSunset.withValues(alpha: 0.6), fontSize: 11)),
        ]),
        const SizedBox(height: 8),
        // Selected app chips
        if (selectedApps.isNotEmpty) ...[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: selectedApps.map((pkg) {
              final appName = allApps
                  .where((a) => a.packageName == pkg)
                  .map((a) => a.appName)
                  .firstOrNull ?? pkg.split('.').last;
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _desertSunset.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: _desertSunset.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(appName,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 12)),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => setBS(() => selectedApps.remove(pkg)),
                      child: Icon(Icons.close,
                          size: 14,
                          color: Colors.white.withValues(alpha: 0.3)),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
        ],
        // "Add Apps" button
        GestureDetector(
          onTap: () async {
            final result = await Navigator.of(ctx, rootNavigator: true).push<Set<String>>(
              PageRouteBuilder(
                fullscreenDialog: true,
                transitionDuration: const Duration(milliseconds: 300),
                reverseTransitionDuration: const Duration(milliseconds: 200),
                pageBuilder: (c, anim, _) => _AppSelectionScreen(
                  allApps: allApps,
                  preSelected: selectedApps,
                ),
                transitionsBuilder: (c, anim, _, child) =>
                    SlideTransition(
                      position: Tween<Offset>(
                              begin: const Offset(0, 0.3), end: Offset.zero)
                          .animate(CurvedAnimation(
                              parent: anim, curve: Curves.easeOutCubic)),
                      child: child,
                    ),
              ),
            );
            if (result != null) {
              setBS(() {
                selectedApps.clear();
                selectedApps.addAll(result);
              });
            }
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_rounded,
                    color: _desertSunset.withValues(alpha: 0.6), size: 18),
                const SizedBox(width: 8),
                Text(
                  selectedApps.isEmpty ? 'Add Apps' : 'Change Apps',
                  style: TextStyle(
                      color: _desertSunset.withValues(alpha: 0.7),
                      fontSize: 13,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Hard Mode Info Page ──
  void _showHardModeInfo(BuildContext ctx, VoidCallback onConfirm) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (bsCtx) => Padding(
        padding: EdgeInsets.only(
          left: 24, right: 24, top: 28,
          bottom: MediaQuery.of(bsCtx).viewInsets.bottom + 28,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Red lock icon
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFD93025).withValues(alpha: 0.08),
                border: Border.all(color: const Color(0xFFD93025).withValues(alpha: 0.2)),
              ),
              child: Icon(Icons.lock_rounded, color: const Color(0xFFD93025).withValues(alpha: 0.7), size: 26),
            ),
            const SizedBox(height: 18),
            const Text('Hard Mode',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text('This cannot be undone easily',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 13)),
            const SizedBox(height: 24),
            // Rules
            _hardModeRule(Icons.block_rounded, "Can't disable or delete this rule"),
            const SizedBox(height: 12),
            _hardModeRule(Icons.pause_circle_outline_rounded, "Can't pause or take breaks"),
            const SizedBox(height: 12),
            _hardModeRule(Icons.delete_forever_rounded, "Can't uninstall blocked apps"),
            const SizedBox(height: 12),
            _hardModeRule(Icons.timer_off_rounded, "Only expires when the timer ends"),
            const SizedBox(height: 28),
            // Confirm
            GestureDetector(
              onTap: () {
                HapticFeedback.heavyImpact();
                Navigator.pop(bsCtx);
                onConfirm();
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(
                  color: const Color(0xFFD93025).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFD93025).withValues(alpha: 0.25)),
                ),
                child: const Center(
                  child: Text('I understand, enable Hard Mode',
                    style: TextStyle(color: Color(0xFFD93025), fontSize: 14, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => Navigator.pop(bsCtx),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Center(
                  child: Text('Cancel',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hardModeRule(IconData icon, String text) {
    return Row(
      children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white.withValues(alpha: 0.35), size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 14)),
        ),
      ],
    );
  }

  // ── Shared: Break Difficulty Selector ──
  Widget _buildBreakDifficultySelector(
      WidgetRef ref, int difficulty, ValueChanged<int> onChanged, BuildContext ctx) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Break Difficulty',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6), fontSize: 13)),
        const SizedBox(height: 8),
        Row(children: [
          // Easy
          Expanded(
            child: GestureDetector(
              onTap: () { HapticFeedback.selectionClick(); onChanged(0); },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: difficulty == 0
                      ? _oasisGreen.withValues(alpha: 0.08)
                      : Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: difficulty == 0
                        ? _oasisGreen.withValues(alpha: 0.3)
                        : Colors.white.withValues(alpha: 0.06),
                  ),
                ),
                child: Column(children: [
                  Icon(Icons.lock_open_rounded,
                      size: 22,
                      color: difficulty == 0
                          ? _oasisGreen
                          : Colors.white.withValues(alpha: 0.3)),
                  const SizedBox(height: 6),
                  Text('Easy',
                      style: TextStyle(
                          color: difficulty == 0
                              ? _oasisGreen
                              : Colors.white.withValues(alpha: 0.5),
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('Can take breaks\n& pause anytime',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.25),
                          fontSize: 10)),
                ]),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Hard
          Expanded(
            child: GestureDetector(
              onTap: () {
                final isPremium = ref.read(premiumProvider).isPremium;
                if (!isPremium) {
                  Navigator.pop(ctx);
                  showPremiumPaywall(ctx, triggerFeature: 'Hard Block');
                  return;
                }
                HapticFeedback.selectionClick();
                // Show Hard Mode info page first
                _showHardModeInfo(ctx, () => onChanged(1));
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: difficulty == 1
                      ? _desertSunset.withValues(alpha: 0.08)
                      : Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: difficulty == 1
                        ? _desertSunset.withValues(alpha: 0.3)
                        : Colors.white.withValues(alpha: 0.06),
                  ),
                ),
                child: Column(children: [
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.lock_rounded,
                        size: 22,
                        color: difficulty == 1
                            ? _desertSunset
                            : Colors.white.withValues(alpha: 0.3)),
                    if (!ref.read(premiumProvider).isPremium) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: _sandGold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('PRO',
                            style: TextStyle(
                                color: _sandGold.withValues(alpha: 0.8),
                                fontSize: 8,
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 6),
                  Text('Hard',
                      style: TextStyle(
                          color: difficulty == 1
                              ? _desertSunset
                              : Colors.white.withValues(alpha: 0.5),
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text("Can't break, leave\nor uninstall app",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.25),
                          fontSize: 10)),
                ]),
              ),
            ),
          ),
        ]),
      ],
    );
  }
}

// ─── Block Type Chooser Option ──────────────────────────────────────────────

class _BlockTypeOption extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _BlockTypeOption({
    required this.icon, required this.color, required this.title,
    required this.subtitle, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () { HapticFeedback.lightImpact(); onTap(); },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color.withValues(alpha: 0.8), size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.35),
                          fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios,
                size: 14, color: Colors.white.withValues(alpha: 0.15)),
          ],
        ),
      ),
    );
  }
}

// ─── 100-Tap Deactivate Confirmation ────────────────────────────────────────

class _DeactivateRuleConfirmScreen extends ConsumerStatefulWidget {
  final String ruleId;
  final String ruleName;
  const _DeactivateRuleConfirmScreen({required this.ruleId, required this.ruleName});

  @override
  ConsumerState<_DeactivateRuleConfirmScreen> createState() => _DeactivateRuleConfirmScreenState();
}

class _DeactivateRuleConfirmScreenState extends ConsumerState<_DeactivateRuleConfirmScreen> {
  int _tapCount = 0;
  static const int _requiredTaps = 100;

  void _handleTap() {
    HapticFeedback.selectionClick();
    setState(() => _tapCount++);
    if (_tapCount >= _requiredTaps) {
      HapticFeedback.heavyImpact();
      ref.read(appBlockRuleProvider.notifier).toggleRule(widget.ruleId);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Rule "${widget.ruleName}" deactivated'),
          backgroundColor: _desertSunset.withValues(alpha: 0.8),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _tapCount / _requiredTaps;
    final remaining = _requiredTaps - _tapCount;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.arrow_back_ios_new,
                          color: Colors.white.withValues(alpha: 0.4), size: 16),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Deactivate Blocker',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 18,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Warning icon
                      Container(
                        width: 80, height: 80,
                        decoration: BoxDecoration(
                          color: _desertSunset.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.shield_outlined, size: 40,
                            color: _desertSunset.withValues(alpha: 0.6)),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Stay focused?',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Deactivating "${widget.ruleName}" removes\nyour focus protection.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Progress bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 8,
                          backgroundColor: Colors.white.withValues(alpha: 0.06),
                          color: Color.lerp(
                            _desertSunset.withValues(alpha: 0.3),
                            _desertSunset.withValues(alpha: 0.8),
                            progress,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '$remaining taps remaining',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.35),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Tap target
                      GestureDetector(
                        onTap: _handleTap,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 100),
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color.lerp(
                              _desertSunset.withValues(alpha: 0.06),
                              _desertSunset.withValues(alpha: 0.25),
                              progress,
                            ),
                            border: Border.all(
                              color: Color.lerp(
                                _desertSunset.withValues(alpha: 0.15),
                                _desertSunset.withValues(alpha: 0.5),
                                progress,
                              )!,
                              width: 2,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '$_tapCount',
                                style: TextStyle(
                                  color: _desertSunset.withValues(alpha: 0.5 + progress * 0.4),
                                  fontSize: 32,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Tap to\ndeactivate',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: _desertSunset.withValues(alpha: 0.35),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Tap the button $_requiredTaps times to deactivate',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.2),
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 100-Tap Delete Confirmation ────────────────────────────────────────────

class _DeleteRuleConfirmScreen extends ConsumerStatefulWidget {
  final String ruleId;
  final String ruleName;
  const _DeleteRuleConfirmScreen({required this.ruleId, required this.ruleName});

  @override
  ConsumerState<_DeleteRuleConfirmScreen> createState() => _DeleteRuleConfirmScreenState();
}

class _DeleteRuleConfirmScreenState extends ConsumerState<_DeleteRuleConfirmScreen> {
  int _tapCount = 0;
  static const int _requiredTaps = 100;

  void _handleTap() {
    HapticFeedback.selectionClick();
    setState(() => _tapCount++);
    if (_tapCount >= _requiredTaps) {
      HapticFeedback.heavyImpact();
      ref.read(appBlockRuleProvider.notifier).deleteRule(widget.ruleId);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Rule "${widget.ruleName}" deleted'),
          backgroundColor: Colors.red.withValues(alpha: 0.8),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _tapCount / _requiredTaps;
    final remaining = _requiredTaps - _tapCount;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.arrow_back_ios_new,
                          color: Colors.white.withValues(alpha: 0.4), size: 16),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Delete Rule',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 18,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Warning icon
                      Container(
                        width: 80, height: 80,
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.warning_amber_rounded, size: 40,
                            color: Colors.red.withValues(alpha: 0.6)),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Are you absolutely sure?',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Deleting "${widget.ruleName}" means removing\nyour focus protection.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Progress bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 8,
                          backgroundColor: Colors.white.withValues(alpha: 0.06),
                          color: Color.lerp(
                            Colors.red.withValues(alpha: 0.3),
                            Colors.red.withValues(alpha: 0.8),
                            progress,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '$remaining taps remaining',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.35),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Tap target
                      GestureDetector(
                        onTap: _handleTap,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 100),
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color.lerp(
                              Colors.red.withValues(alpha: 0.06),
                              Colors.red.withValues(alpha: 0.25),
                              progress,
                            ),
                            border: Border.all(
                              color: Color.lerp(
                                Colors.red.withValues(alpha: 0.15),
                                Colors.red.withValues(alpha: 0.5),
                                progress,
                              )!,
                              width: 2,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '$_tapCount',
                                style: TextStyle(
                                  color: Colors.red.withValues(alpha: 0.5 + progress * 0.4),
                                  fontSize: 32,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Tap to\nconfirm',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.red.withValues(alpha: 0.35),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Tap the button $_requiredTaps times to delete',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.2),
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Full-Screen App Selection ──────────────────────────────────────────────

class _AppSelectionScreen extends StatefulWidget {
  final List<InstalledApp> allApps;
  final Set<String> preSelected;
  const _AppSelectionScreen({required this.allApps, required this.preSelected});

  @override
  State<_AppSelectionScreen> createState() => _AppSelectionScreenState();
}

class _AppSelectionScreenState extends State<_AppSelectionScreen> {
  late Set<String> _selected;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selected = Set.from(widget.preSelected);
  }

  List<InstalledApp> get _filteredApps {
    if (_searchQuery.isEmpty) return widget.allApps;
    final q = _searchQuery.toLowerCase();
    return widget.allApps
        .where((a) =>
            a.appName.toLowerCase().contains(q) ||
            a.packageName.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.arrow_back_ios_new,
                        color: Colors.white.withValues(alpha: 0.4), size: 16),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Select Apps',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 18,
                              fontWeight: FontWeight.w600)),
                      Text('${_selected.length} app${_selected.length == 1 ? '' : 's'} selected',
                          style: TextStyle(
                              color: _desertSunset.withValues(alpha: 0.6),
                              fontSize: 12)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context, _selected);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: _sandGold.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('Done',
                        style: TextStyle(
                            color: _sandGold,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ]),
            ),
            // Search
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                onChanged: (v) => setState(() => _searchQuery = v),
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search apps...',
                  hintStyle:
                      TextStyle(color: Colors.white.withValues(alpha: 0.25)),
                  prefixIcon: Icon(Icons.search,
                      color: Colors.white.withValues(alpha: 0.2)),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                ),
              ),
            ),
            // Quick actions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                GestureDetector(
                  onTap: () => setState(() {
                    _selected = widget.allApps
                        .map((a) => a.packageName)
                        .toSet();
                  }),
                  child: Text('Select All',
                      style: TextStyle(
                          color: _sandGold.withValues(alpha: 0.5),
                          fontSize: 12)),
                ),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: () => setState(() => _selected.clear()),
                  child: Text('Clear',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3),
                          fontSize: 12)),
                ),
              ]),
            ),
            const SizedBox(height: 8),
            // App list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: _filteredApps.length,
                itemBuilder: (ctx, i) {
                  final app = _filteredApps[i];
                  final isSelected = _selected.contains(app.packageName);
                  return ListTile(
                    dense: true,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        if (isSelected) {
                          _selected.remove(app.packageName);
                        } else {
                          _selected.add(app.packageName);
                        }
                      });
                    },
                    title: Text(app.appName,
                        style: TextStyle(
                            color: isSelected
                                ? Colors.white.withValues(alpha: 0.9)
                                : Colors.white.withValues(alpha: 0.6),
                            fontSize: 14)),
                    subtitle: Text(app.packageName,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.2),
                            fontSize: 10)),
                    trailing: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(7),
                        color: isSelected
                            ? _desertSunset.withValues(alpha: 0.2)
                            : Colors.white.withValues(alpha: 0.04),
                        border: Border.all(
                            color: isSelected
                                ? _desertSunset.withValues(alpha: 0.5)
                                : Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: isSelected
                          ? const Icon(Icons.check_rounded,
                              color: _desertSunset, size: 16)
                          : null,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 🔧 SHARED WIDGETS
// ═══════════════════════════════════════════════════════════════════════════════

class _AddButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _AddButton({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: _sandGold.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _sandGold.withValues(alpha: 0.15)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: _sandGold.withValues(alpha: 0.6)),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: _sandGold.withValues(alpha: 0.7),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _PresetChip({
    required this.label,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? _sandGold.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? _sandGold.withValues(alpha: 0.35)
                : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? _sandGold : Colors.white.withValues(alpha: 0.5),
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 9,
                color: isSelected
                    ? _sandGold.withValues(alpha: 0.6)
                    : Colors.white.withValues(alpha: 0.25),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final double iconSize;
  final VoidCallback onTap;

  const _CircleButton({
    required this.icon,
    required this.color,
    this.size = 48,
    this.iconSize = 24,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Icon(icon, size: iconSize, color: Colors.white.withValues(alpha: 0.8)),
      ),
    );
  }
}

class _LinkTodoRow extends StatelessWidget {
  final String? activeTodoId;
  final List<TodoItem> todos;
  final void Function(String) onSelect;

  const _LinkTodoRow({
    this.activeTodoId,
    required this.todos,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: const Color(0xFF1A1A1A),
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
          builder: (ctx) => SizedBox(
            height: 300,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: todos.length,
              itemBuilder: (ctx, i) => ListTile(
                dense: true,
                leading: Icon(Icons.check_circle_outline,
                    size: 16, color: _sandGold.withValues(alpha: 0.4)),
                title: Text(todos[i].title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 13)),
                onTap: () {
                  onSelect(todos[i].id);
                  Navigator.pop(ctx);
                },
              ),
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.link, size: 14,
                color: activeTodoId != null
                    ? _sandGold
                    : Colors.white.withValues(alpha: 0.3)),
            const SizedBox(width: 6),
            Text(
              activeTodoId != null ? 'Linked to task ✓' : 'Focus on a task',
              style: TextStyle(
                fontSize: 12,
                color: activeTodoId != null
                    ? _sandGold
                    : Colors.white.withValues(alpha: 0.3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Minimalist +/- setting row for focus settings
class _SettingRow extends StatelessWidget {
  final String label;
  final int value;
  final String suffix;
  final Color color;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  const _SettingRow({
    required this.label,
    required this.value,
    required this.suffix,
    required this.color,
    required this.onMinus,
    required this.onPlus,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 14)),
          ),
          GestureDetector(
            onTap: () { HapticFeedback.selectionClick(); onMinus(); },
            child: Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.remove_rounded, color: Colors.white.withValues(alpha: 0.4), size: 16),
            ),
          ),
          SizedBox(
            width: 52,
            child: Center(
              child: Text(
                suffix.isNotEmpty ? '$value$suffix' : '$value',
                style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          GestureDetector(
            onTap: () { HapticFeedback.selectionClick(); onPlus(); },
            child: Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.add_rounded, color: Colors.white.withValues(alpha: 0.4), size: 16),
            ),
          ),
        ],
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final String suffix;
  final Color color;
  final void Function(int) onChanged;

  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.suffix,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6), fontSize: 12)),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: color.withValues(alpha: 0.5),
                inactiveTrackColor: Colors.white.withValues(alpha: 0.08),
                thumbColor: color,
                overlayColor: color.withValues(alpha: 0.1),
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              ),
              child: Slider(
                value: value.toDouble(),
                min: min.toDouble(),
                max: max.toDouble(),
                divisions: max - min,
                onChanged: (v) => onChanged(v.round()),
              ),
            ),
          ),
          SizedBox(
            width: 40,
            child: Text(
              '$value$suffix',
              textAlign: TextAlign.right,
              style: TextStyle(color: color, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekStrip extends StatefulWidget {
  final DateTime selected;
  final Set<DateTime> eventDates;
  final void Function(DateTime) onSelect;

  const _WeekStrip({
    required this.selected,
    required this.eventDates,
    required this.onSelect,
  });

  @override
  State<_WeekStrip> createState() => _WeekStripState();
}

class _WeekStripState extends State<_WeekStrip> {
  late ScrollController _scrollController;
  static const int _totalDays = 21; // 10 past + today + 10 future
  static const int _pastDays = 10;
  static const double _itemWidth = 44;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelected();
    });
  }

  @override
  void didUpdateWidget(_WeekStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) {
      _scrollToSelected();
    }
  }

  void _scrollToSelected() {
    final today = DateTime.now();
    final todayNorm = DateTime(today.year, today.month, today.day);
    final selectedNorm = DateTime(widget.selected.year, widget.selected.month, widget.selected.day);
    final diffDays = selectedNorm.difference(todayNorm).inDays;
    final index = _pastDays + diffDays;
    final offset = (index * _itemWidth) - (MediaQuery.of(context).size.width / 2) + (_itemWidth / 2);
    _scrollController.animateTo(
      offset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final startDate = DateTime(today.year, today.month, today.day)
        .subtract(Duration(days: _pastDays));
    final dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return SizedBox(
      height: 60,
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        itemCount: _totalDays,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemBuilder: (context, i) {
          final day = startDate.add(Duration(days: i));
          final isSelected = day.year == widget.selected.year &&
              day.month == widget.selected.month &&
              day.day == widget.selected.day;
          final isToday = day.year == today.year &&
              day.month == today.month &&
              day.day == today.day;
          final hasEvent = widget.eventDates.contains(
              DateTime(day.year, day.month, day.day));

          return GestureDetector(
            onTap: () => widget.onSelect(day),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: _itemWidth,
              padding: const EdgeInsets.symmetric(vertical: 8),
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: isSelected
                    ? _sandGold.withValues(alpha: 0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: isToday && !isSelected
                    ? Border.all(
                        color: _sandGold.withValues(alpha: 0.2))
                    : null,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    dayLabels[day.weekday - 1],
                    style: TextStyle(
                      fontSize: 10,
                      color: isSelected
                          ? _sandGold
                          : Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${day.day}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: isSelected
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (hasEvent)
                    Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: _sandGold,
                      ),
                    )
                  else
                    const SizedBox(height: 4),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TimePickerRow extends StatelessWidget {
  final String label;
  final DateTime time;
  final VoidCallback onPick;

  const _TimePickerRow({
    required this.label,
    required this.time,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: onPick,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Text(label,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12)),
              const Spacer(),
              Text(
                DateFormat('EEE, MMM d · h:mm a').format(time),
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right,
                  size: 16,
                  color: Colors.white.withValues(alpha: 0.3)),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 🛡️ BLOCKER PERMISSION SETUP SCREEN
// ═══════════════════════════════════════════════════════════════════════════════

class _BlockerPermissionScreen extends StatefulWidget {
  final bool hasUsageStats;
  final bool hasNotification;

  const _BlockerPermissionScreen({
    required this.hasUsageStats,
    required this.hasNotification,
  });

  @override
  State<_BlockerPermissionScreen> createState() => _BlockerPermissionScreenState();
}

class _BlockerPermissionScreenState extends State<_BlockerPermissionScreen>
    with WidgetsBindingObserver {
  late bool _usageGranted;
  late bool _notifGranted;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _usageGranted = widget.hasUsageStats;
    _notifGranted = widget.hasNotification;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Re-check permissions when user comes back from system settings
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _recheckPermissions();
    }
  }

  Future<void> _recheckPermissions() async {
    if (_checking) return;
    _checking = true;
    final u = await NativeAppBlockerService.hasUsageStatsPermission();
    final n = await NativeAppBlockerService.hasNotificationPermission();
    if (mounted) {
      setState(() {
        _usageGranted = u;
        _notifGranted = n;
      });

      // All permissions granted → auto-proceed
      if (_usageGranted && _notifGranted) {
        await Future.delayed(const Duration(milliseconds: 400));
        if (mounted) Navigator.pop(context, true);
      }
    }
    _checking = false;
  }

  bool get _allGranted => _usageGranted && _notifGranted;

  @override
  Widget build(BuildContext context) {
    final grantedCount = (_usageGranted ? 1 : 0) + (_notifGranted ? 1 : 0);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              // ── Back button ──
              GestureDetector(
                onTap: () => Navigator.pop(context, false),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.arrow_back_rounded,
                      color: Colors.white.withValues(alpha: 0.6), size: 20),
                ),
              ),

              const SizedBox(height: 32),

              // ── Shield icon ──
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: _desertSunset.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.shield_rounded,
                      color: _desertSunset.withValues(alpha: 0.8), size: 40),
                ),
              ),

              const SizedBox(height: 24),

              // ── Title ──
              Center(
                child: Text(
                  'Setup App Blocker',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.95),
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),

              const SizedBox(height: 8),

              Center(
                child: Text(
                  'To block apps from all entry points —\nnotifications, recent apps & more',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ── Progress ──
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: _oasisGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$grantedCount / 2 permissions granted',
                    style: TextStyle(
                      color: _oasisGreen.withValues(alpha: 0.8),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // ── Permission 1: Usage Stats ──
              _PermissionCard(
                step: 1,
                icon: Icons.bar_chart_rounded,
                title: 'Usage Access',
                description:
                    'Required to detect which app is in the foreground.\nThis is how the blocker knows when a blocked app opens.',
                isGranted: _usageGranted,
                onGrant: () async {
                  HapticFeedback.mediumImpact();
                  await NativeAppBlockerService.requestUsageStatsPermission();
                },
              ),

              const SizedBox(height: 14),

              // ── Permission 2: Notifications ──
              _PermissionCard(
                step: 2,
                icon: Icons.notifications_active_rounded,
                title: 'Notifications',
                description:
                    'Required to keep the blocker running in the background.\nShows a small "Focus Mode Active" notification.',
                isGranted: _notifGranted,
                onGrant: () async {
                  HapticFeedback.mediumImpact();
                  await NativeAppBlockerService.requestNotificationPermission();
                  // Small delay then re-check (Android dialog is quick)
                  await Future.delayed(const Duration(milliseconds: 800));
                  _recheckPermissions();
                },
              ),

              const Spacer(),

              // ── Continue button ──
              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: () {
                    if (_allGranted) {
                      HapticFeedback.lightImpact();
                      Navigator.pop(context, true);
                    } else {
                      HapticFeedback.heavyImpact();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Please grant all permissions to continue'),
                          backgroundColor: _desertSunset.withValues(alpha: 0.9),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      );
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: _allGranted
                          ? _oasisGreen.withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _allGranted
                            ? _oasisGreen.withValues(alpha: 0.4)
                            : Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _allGranted
                              ? Icons.check_circle_rounded
                              : Icons.lock_rounded,
                          color: _allGranted
                              ? _oasisGreen
                              : Colors.white.withValues(alpha: 0.3),
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _allGranted
                              ? 'Continue to Create Rule'
                              : 'Grant All Permissions to Continue',
                          style: TextStyle(
                            color: _allGranted
                                ? _oasisGreen
                                : Colors.white.withValues(alpha: 0.3),
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Individual Permission Card ──
class _PermissionCard extends StatelessWidget {
  final int step;
  final IconData icon;
  final String title;
  final String description;
  final bool isGranted;
  final VoidCallback onGrant;

  const _PermissionCard({
    required this.step,
    required this.icon,
    required this.title,
    required this.description,
    required this.isGranted,
    required this.onGrant,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isGranted ? null : onGrant,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isGranted
              ? _oasisGreen.withValues(alpha: 0.06)
              : _desertSunset.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isGranted
                ? _oasisGreen.withValues(alpha: 0.25)
                : _desertSunset.withValues(alpha: 0.15),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Step number / check icon
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isGranted
                    ? _oasisGreen.withValues(alpha: 0.15)
                    : _desertSunset.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: isGranted
                    ? Icon(Icons.check_rounded,
                        color: _oasisGreen, size: 20)
                    : Text(
                        '$step',
                        style: TextStyle(
                          color: _desertSunset.withValues(alpha: 0.8),
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 14),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon,
                          size: 16,
                          color: isGranted
                              ? _oasisGreen.withValues(alpha: 0.7)
                              : _desertSunset.withValues(alpha: 0.7)),
                      const SizedBox(width: 6),
                      Text(
                        title,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      if (isGranted)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _oasisGreen.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('GRANTED',
                              style: TextStyle(
                                  color: _oasisGreen,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5)),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: _desertSunset.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('GRANT',
                              style: TextStyle(
                                  color: _desertSunset,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.35),
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
