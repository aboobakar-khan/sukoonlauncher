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
import '../models/productivity_models.dart';
import 'premium_paywall_screen.dart';

// ─── Camel Design Tokens ────────────────────────────────────────────────────
const Color _sandGold = Color(0xFFC2A366);
const Color _camelBrown = Color(0xFFA67B5B);
const Color _oasisGreen = Color(0xFF7BAE6E);
const Color _desertWarm = Color(0xFFD4A96A);
const Color _desertSunset = Color(0xFFE8915A);

/// 🐪 Productivity Hub — Distraction-free tools
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
    _tabController = TabController(length: 5, vsync: this);
    _startPomodoroTicker();
  }

  void _startPomodoroTicker() {
    _pomodoroTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final pomo = ref.read(pomodoroProvider);
      if (pomo.state != PomodoroState.idle) {
        ref.read(pomodoroProvider.notifier).tick();
      }
    });
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
        child: Column(
          children: [
            // ── Tab Bar ──
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: _buildTabBar(themeColor.color),
            ),
            // ── Tab Content ──
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _TodoTab(),
                  _PomodoroTab(),
                  _DoubtsTab(),
                  _EventsTab(),
                  _BlockerTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar(Color accent) {
    final icons = [
      Icons.check_circle_outline,
      Icons.timer_outlined,
      Icons.help_outline,
      Icons.event_outlined,
      Icons.shield_outlined,
    ];
    final labels = ['Todo', 'Focus', 'Doubts', 'Events', 'Block'];

    return AnimatedBuilder(
      animation: _tabController,
      builder: (ctx, _) {
        return Row(
          children: List.generate(5, (i) {
            final selected = _tabController.index == i;
            return Expanded(
              child: GestureDetector(
                onTap: () => _tabController.animateTo(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: selected
                        ? accent.withValues(alpha: 0.12)
                        : Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected
                          ? accent.withValues(alpha: 0.3)
                          : Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icons[i],
                        size: 18,
                        color: selected
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        labels[i],
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.w400,
                          color: selected
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
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
    final filtered = _filter == 'all'
        ? todos
        : _filter == 'active'
            ? todos.where((t) => !t.isCompleted).toList()
            : todos.where((t) => t.isCompleted).toList();
    final pending = todos.where((t) => !t.isCompleted).length;

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
        // Todo list
        Expanded(
          child: filtered.isEmpty
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
              : ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) => _todoTile(filtered[i]),
                ),
        ),
        // Add button
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: _AddButton(
            label: 'Add Task',
            icon: Icons.add,
            onTap: () => _showAddTodo(context),
          ),
        ),
      ],
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
}

// ═══════════════════════════════════════════════════════════════════════════════
// 🍅 POMODORO TAB
// ═══════════════════════════════════════════════════════════════════════════════

class _PomodoroTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pomo = ref.watch(pomodoroProvider);
    final todos = ref.watch(todoProvider).where((t) => !t.isCompleted).toList();

    final stateColors = {
      PomodoroState.idle: Colors.white.withValues(alpha: 0.5),
      PomodoroState.focusing: _desertSunset,
      PomodoroState.shortBreak: _oasisGreen,
      PomodoroState.longBreak: _sandGold,
    };

    final stateLabels = {
      PomodoroState.idle: 'Ready to Focus',
      PomodoroState.focusing: 'Stay Focused 🐪',
      PomodoroState.shortBreak: 'Short Break',
      PomodoroState.longBreak: 'Long Break',
    };

    final accent = stateColors[pomo.state]!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const Spacer(flex: 2),
          // Timer Ring
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
              if (pomo.state != PomodoroState.idle) ...[
                _CircleButton(
                  icon: Icons.stop_rounded,
                  color: Colors.white.withValues(alpha: 0.2),
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    ref.read(pomodoroProvider.notifier).reset();
                  },
                ),
                const SizedBox(width: 24),
              ],
              _CircleButton(
                icon: pomo.state == PomodoroState.idle
                    ? Icons.play_arrow_rounded
                    : Icons.pause_rounded,
                color: accent.withValues(alpha: 0.2),
                size: 64,
                iconSize: 32,
                onTap: () {
                  HapticFeedback.mediumImpact();
                  if (pomo.state == PomodoroState.idle) {
                    ref
                        .read(pomodoroProvider.notifier)
                        .startFocus(todoId: pomo.activeTodoId);
                  } else {
                    ref.read(pomodoroProvider.notifier).pause();
                  }
                },
              ),
              if (pomo.state == PomodoroState.idle &&
                  pomo.completedSessions > 0) ...[
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
          const SizedBox(height: 8),
          // Settings
          GestureDetector(
            onTap: () => _showPomodoroSettings(context, ref, pomo.settings),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.tune, size: 14,
                    color: Colors.white.withValues(alpha: 0.3)),
                const SizedBox(width: 4),
                Text('Settings',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.3))),
              ],
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
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setBS) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Focus Settings',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 18,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 20),
              _SliderRow(
                label: 'Focus',
                value: focus,
                min: 5,
                max: 90,
                suffix: 'min',
                color: _desertSunset,
                onChanged: (v) => setBS(() => focus = v),
              ),
              _SliderRow(
                label: 'Short Break',
                value: shortBreak,
                min: 1,
                max: 15,
                suffix: 'min',
                color: _oasisGreen,
                onChanged: (v) => setBS(() => shortBreak = v),
              ),
              _SliderRow(
                label: 'Long Break',
                value: longBreak,
                min: 5,
                max: 30,
                suffix: 'min',
                color: _sandGold,
                onChanged: (v) => setBS(() => longBreak = v),
              ),
              _SliderRow(
                label: 'Sessions',
                value: sessions,
                min: 2,
                max: 8,
                suffix: '',
                color: _camelBrown,
                onChanged: (v) => setBS(() => sessions = v),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final s = PomodoroSettings(
                      focusMinutes: focus,
                      shortBreakMinutes: shortBreak,
                      longBreakMinutes: longBreak,
                      sessionsBeforeLongBreak: sessions,
                    );
                    ref.read(pomodoroProvider.notifier).updateSettings(s);
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _sandGold.withValues(alpha: 0.2),
                    foregroundColor: _sandGold,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Save'),
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
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Todo created from doubt')),
                    );
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
      'A67B5B': _camelBrown,
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
                      Text('Block distracting apps 🐪',
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
    return Container(
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
            // Confirm deactivate button (subtle)
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  ref.read(appBlockRuleProvider.notifier).toggleRule(rule.id);
                  Navigator.pop(ctx);
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

  // ── Task 6: Show block type chooser first ──
  void _showAddRule(BuildContext context, WidgetRef ref) {
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
            Text('Choose block type',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                    fontSize: 13)),
            const SizedBox(height: 20),
            // Option A: Block Now
            _BlockTypeOption(
              icon: Icons.flash_on_rounded,
              color: _desertSunset,
              title: 'Block Now',
              subtitle: 'Instantly block apps for a set duration',
              onTap: () {
                Navigator.pop(ctx);
                _showQuickBlockSheet(context, ref);
              },
            ),
            const SizedBox(height: 10),
            // Option B: Scheduled Block
            _BlockTypeOption(
              icon: Icons.schedule_rounded,
              color: _sandGold,
              title: 'Scheduled Block',
              subtitle: 'Block apps during specific time windows',
              onTap: () {
                Navigator.pop(ctx);
                _showScheduledBlockSheet(context, ref);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Quick Block (Block Now for X minutes) ──
  void _showQuickBlockSheet(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController(text: 'Quick Focus');
    int durationMinutes = 30;
    int breakDifficulty = 0; // 0 = Easy, 1 = Hard
    Set<String> selectedApps = {};
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
              maxHeight: MediaQuery.of(ctx).size.height * 0.85),
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
                  Icon(Icons.flash_on_rounded,
                      color: _desertSunset.withValues(alpha: 0.7), size: 20),
                  const SizedBox(width: 8),
                  Text('Block Now',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 18,
                          fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Rule name',
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
                // Duration selector
                Text('Duration',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: durations.map((d) {
                    final isSelected = durationMinutes == d;
                    final label =
                        d >= 60 ? '${d ~/ 60}h${d % 60 > 0 ? " ${d % 60}m" : ""}' : '${d}m';
                    return GestureDetector(
                      onTap: () => setBS(() => durationMinutes = d),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
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
                const SizedBox(height: 16),
                // Add Apps button
                _buildAddAppsButton(ctx, ref, selectedApps, setBS),
                const SizedBox(height: 16),
                // Break difficulty
                _buildBreakDifficultySelector(ref, breakDifficulty, (v) => setBS(() => breakDifficulty = v), ctx),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (selectedApps.isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                          content: const Text('Please add at least one app to block'),
                          backgroundColor: Colors.red.withValues(alpha: 0.8),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ));
                        return;
                      }
                      final now = DateTime.now();
                      final endTime = now.add(Duration(minutes: durationMinutes));
                      ref.read(appBlockRuleProvider.notifier).addRule(
                            name: nameCtrl.text.trim().isEmpty
                                ? 'Quick Focus'
                                : nameCtrl.text.trim(),
                            blockedPackages: selectedApps.toList(),
                            isTimeBased: true,
                            startHour: now.hour,
                            startMinute: now.minute,
                            endHour: endTime.hour,
                            endMinute: endTime.minute,
                            activeDays: [now.weekday],
                            isHardBlock: breakDifficulty == 1,
                            allowBreaks: breakDifficulty == 0,
                          );
                      Navigator.pop(ctx);
                      HapticFeedback.lightImpact();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _desertSunset.withValues(alpha: 0.2),
                      foregroundColor: _desertSunset,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text('Start Blocking · ${durationMinutes}min'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Scheduled Block (time-duration based) ──
  void _showScheduledBlockSheet(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    int startH = 9, startM = 0, endH = 17, endM = 0;
    Set<int> activeDays = {1, 2, 3, 4, 5}; // Mon-Fri
    Set<String> selectedApps = {};
    int breakDifficulty = 0; // 0 = Easy, 1 = Hard

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setBS) => Container(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.85),
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
                  Icon(Icons.schedule_rounded,
                      color: _sandGold.withValues(alpha: 0.7), size: 20),
                  const SizedBox(width: 8),
                  Text('Scheduled Block',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 18,
                          fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
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
                // Time picker row
                Text('Schedule',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 13)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final time = await showTimePicker(
                            context: ctx,
                            initialTime:
                                TimeOfDay(hour: startH, minute: startM),
                          );
                          if (time != null) {
                            setBS(() {
                              startH = time.hour;
                              startM = time.minute;
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Start: ${_formatHour(startH, startM)}',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final time = await showTimePicker(
                            context: ctx,
                            initialTime:
                                TimeOfDay(hour: endH, minute: endM),
                          );
                          if (time != null) {
                            setBS(() {
                              endH = time.hour;
                              endM = time.minute;
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'End: ${_formatHour(endH, endM)}',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Day selector
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(7, (i) {
                    final day = i + 1;
                    final labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                    final active = activeDays.contains(day);
                    return GestureDetector(
                      onTap: () => setBS(() {
                        if (active) {
                          activeDays.remove(day);
                        } else {
                          activeDays.add(day);
                        }
                      }),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: active
                              ? _sandGold.withValues(alpha: 0.2)
                              : Colors.white.withValues(alpha: 0.04),
                        ),
                        child: Center(
                          child: Text(
                            labels[i],
                            style: TextStyle(
                              fontSize: 12,
                              color: active
                                  ? _sandGold
                                  : Colors.white.withValues(alpha: 0.3),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 16),
                // Add Apps button
                _buildAddAppsButton(ctx, ref, selectedApps, setBS),
                const SizedBox(height: 16),
                // Break difficulty
                _buildBreakDifficultySelector(ref, breakDifficulty, (v) => setBS(() => breakDifficulty = v), ctx),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (nameCtrl.text.trim().isEmpty) return;
                      if (selectedApps.isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                          content: const Text('Please add at least one app to block'),
                          backgroundColor: Colors.red.withValues(alpha: 0.8),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ));
                        return;
                      }
                      ref.read(appBlockRuleProvider.notifier).addRule(
                            name: nameCtrl.text.trim(),
                            blockedPackages: selectedApps.toList(),
                            isTimeBased: true,
                            startHour: startH,
                            startMinute: startM,
                            endHour: endH,
                            endMinute: endM,
                            activeDays: activeDays.toList(),
                            isHardBlock: breakDifficulty == 1,
                            allowBreaks: breakDifficulty == 0,
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
                    child: const Text('Create Rule'),
                  ),
                ),
              ],
            ),
          ),
        ),
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
                onChanged(1);
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

class _WeekStrip extends StatelessWidget {
  final DateTime selected;
  final Set<DateTime> eventDates;
  final void Function(DateTime) onSelect;

  const _WeekStrip({
    required this.selected,
    required this.eventDates,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    // Show 7 days centered around selected
    final startOfWeek = selected.subtract(Duration(days: selected.weekday - 1));

    return SizedBox(
      height: 60,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(7, (i) {
          final day = startOfWeek.add(Duration(days: i));
          final isSelected = day.year == selected.year &&
              day.month == selected.month &&
              day.day == selected.day;
          final isToday = day.year == today.year &&
              day.month == today.month &&
              day.day == today.day;
          final hasEvent = eventDates.contains(
              DateTime(day.year, day.month, day.day));
          final dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

          return GestureDetector(
            onTap: () => onSelect(day),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 40,
              padding: const EdgeInsets.symmetric(vertical: 8),
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
                    dayLabels[i],
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
        }),
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
