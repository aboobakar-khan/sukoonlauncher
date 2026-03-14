import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../providers/theme_provider.dart';
import '../../../providers/display_settings_provider.dart';
import '../../../providers/fasting_provider.dart';
import '../../../widgets/swipe_back_wrapper.dart';
import '../providers/prayer_alarm_provider.dart';
import '../models/prayer_alarm_config.dart';
import '../services/aladhan_api_service.dart';
import '../services/prayer_alarm_service.dart';
import '../services/location_service.dart';
import '../utils/prayer_time_utils.dart';
import 'permission_setup_screen.dart';
// ─── Redesigned Salah Wake ───────────────────────────────────────
// Two independent concerns:
//   1. NAMAZ TIMES — hero, read-only, always visible
//   2. ALARM SETTINGS — separate, expandable, action layer
// Location is minimalist: one-tap GPS strip.
// Offline-first: shows cached times immediately.

class PrayerAlarmSettingsScreen extends ConsumerStatefulWidget {
  const PrayerAlarmSettingsScreen({super.key});

  @override
  ConsumerState<PrayerAlarmSettingsScreen> createState() =>
      _PrayerAlarmSettingsScreenState();
}

class _PrayerAlarmSettingsScreenState
    extends ConsumerState<PrayerAlarmSettingsScreen> {
  final _cityController = TextEditingController();
  AudioPlayer? _audioPreview;
  String? _previewingSound;
  bool _isLocating = false;
  bool _isSearching = false;
  bool _isSaving = false;
  List<Map<String, dynamic>> _searchResults = [];
  DateTime? _lastSearchTime;
  bool _showLocationSearch = false;
  bool _showCalcMethod = false;
  bool _showAsrSchool = false;
  // Holds the last auto-detected GPS city so it can be shown as a suggestion chip
  String? _autoDetectedCity;
  bool _showSoundSettings = false;
  String _activeTab = 'times'; // 'times' | 'alarms'
  bool? _hasNotifPermission;
  bool? _hasExactAlarmPermission;

  // ── Date navigation & timetable ──
  DateTime _viewDate = DateTime.now();
  DailyPrayerTimes? _viewTimes; // times for _viewDate (null = loading)
  bool _viewLoading = false;

  // ── Salah countdown timer ──
  Timer? _countdownTimer;
  Duration _timeUntilNext = Duration.zero;
  String _nextPrayerName = '';

  @override
  void initState() {
    super.initState();
    _audioPreview = AudioPlayer();
    _checkPermissions();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final config = ref.read(prayerAlarmProvider).config;
      if (config.locationLabel.isNotEmpty) {
        _cityController.text = config.locationLabel;
      }
      _loadViewDate(DateTime.now());
      _startCountdown();
    });
  }

  Future<void> _checkPermissions() async {
    final notif = await Permission.notification.isGranted;
    final exact = await PrayerAlarmService.canScheduleExactAlarms();
    if (mounted) {
      setState(() {
        _hasNotifPermission = notif;
        _hasExactAlarmPermission = exact;
      });
    }
  }

  // ── DATE NAVIGATION ──────────────────────────────────────────────────────

  Future<void> _loadViewDate(DateTime d) async {
    if (!mounted) return;
    setState(() {
      _viewDate = d;
      _viewLoading = true;
    });
    final stateNow = ref.read(prayerAlarmProvider);
    final key = dateKeyFor(d);
    final todayKey = todayDateKey();
    DailyPrayerTimes? times;
    if (key == todayKey && stateNow.todayTimes != null) {
      times = stateNow.todayTimes;
    } else {
      times = await ref
          .read(prayerAlarmProvider.notifier)
          .fetchTimesForDate(d);
    }
    if (mounted) setState(() { _viewTimes = times; _viewLoading = false; });
  }

  // ── COUNTDOWN TIMER ───────────────────────────────────────────────────────

  void _startCountdown() {
    _tickCountdown();
    _countdownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _tickCountdown(),
    );
  }

  void _tickCountdown() {
    if (!mounted) return;
    final now = DateTime.now();
    final todayPrayers = ref.read(prayerAlarmProvider).todayTimes;
    if (todayPrayers == null) return;
    const prayers = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
    for (final p in prayers) {
      final t = todayPrayers.timeFor(p);
      if (t.isEmpty) continue;
      final parts = t.split(':');
      if (parts.length != 2) continue;
      final prayerDt = DateTime(
        now.year, now.month, now.day,
        int.tryParse(parts[0]) ?? 0,
        int.tryParse(parts[1]) ?? 0,
      );
      if (prayerDt.isAfter(now)) {
        if (mounted) {
          setState(() {
            _nextPrayerName = p;
            _timeUntilNext = prayerDt.difference(now);
          });
        }
        return;
      }
    }
    if (mounted) {
      setState(() {
        _nextPrayerName = '';
        _timeUntilNext = Duration.zero;
      });
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _cityController.dispose();
    _audioPreview?.dispose();
    super.dispose();
  }

  Color get _a => ref.watch(themeColorProvider).color;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(prayerAlarmProvider);
    final s = state.reminderSettings;
    final hasLoc =
        state.config.latitude != 0.0 || state.config.longitude != 0.0;
    final enabledCount = state.enabledMap.values.where((v) => v).length;

    return SwipeBackWrapper(
      child: Scaffold(
        backgroundColor: const Color(0xFF050507),
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(enabledCount),
              // ── TAB SWITCHER ──
              _buildTabSwitcher(enabledCount),
              // ── SHARED SETTINGS BAR (location · calc method · asr school) ──
              _buildSettingsBar(state),
              Expanded(
                child: _activeTab == 'times'
                    ? _buildTimesTab(state, s, hasLoc)
                    : _buildAlarmsTab(state, s, hasLoc, enabledCount),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  //  HEADER
  // ══════════════════════════════════════════════════════

  Widget _buildHeader(int activeCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.arrow_back_ios_new_rounded,
                size: 17, color: Colors.white.withValues(alpha: 0.5)),
          ),
          const SizedBox(width: 2),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Salah Wake',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.9),
                  letterSpacing: -0.3,
                ),
              ),
              Text(
                'Prayer times & reminders',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.25),
                ),
              ),
            ],
          ),
          const Spacer(),
          if (activeCount > 0)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.green.withValues(alpha: 0.08),
                border: Border.all(
                    color: Colors.green.withValues(alpha: 0.15)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.alarm_on_rounded,
                      size: 11,
                      color: Colors.green.withValues(alpha: 0.7)),
                  const SizedBox(width: 4),
                  Text(
                    '$activeCount',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.green.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  //  TAB SWITCHER — Namaz Times | Alarm Settings
  // ══════════════════════════════════════════════════════

  Widget _buildTabSwitcher(int enabledCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white.withValues(alpha: 0.04),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: [
            _tabBtn(
              label: 'Namaz Times',
              icon: Icons.mosque_rounded,
              active: _activeTab == 'times',
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _activeTab = 'times');
              },
            ),
            _tabBtn(
              label: 'Alarm Settings',
              icon: Icons.alarm_rounded,
              active: _activeTab == 'alarms',
              badge: enabledCount > 0 ? '$enabledCount' : null,
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _activeTab = 'alarms');
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabBtn({
    required String label,
    required IconData icon,
    required bool active,
    required VoidCallback onTap,
    String? badge,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            color: active ? _a.withValues(alpha: 0.12) : Colors.transparent,
            border: active
                ? Border.all(color: _a.withValues(alpha: 0.22))
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 13,
                color: active
                    ? _a.withValues(alpha: 0.8)
                    : Colors.white.withValues(alpha: 0.25),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight:
                      active ? FontWeight.w700 : FontWeight.w500,
                  color: active
                      ? Colors.white.withValues(alpha: 0.85)
                      : Colors.white.withValues(alpha: 0.3),
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(5),
                    color: Colors.green.withValues(alpha: 0.15),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Colors.green.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  //  SHARED SETTINGS BAR — location · calc method · asr school
  //  Sits above both tabs, no duplication
  // ══════════════════════════════════════════════════════

  Widget _buildSettingsBar(PrayerAlarmState state) {
    final accent = _a;
    final hasLoc = state.config.locationLabel.isNotEmpty;
    final locLabel = hasLoc ? state.config.locationLabel : 'Set location';
    final calcName = _calcMethodName(state.config.calculationMethod);
    final asrName =
        state.config.asrCalculationSchool == 1 ? 'Hanafi' : 'Shafi\'i';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── single pill row ─────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.025),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Row(
              children: [
                // Location pill
                Expanded(
                  flex: 5,
                  child: _SettingsPill(
                    icon: hasLoc
                        ? Icons.location_on_rounded
                        : Icons.location_off_rounded,
                    label: locLabel,
                    accent: accent,
                    active: _showLocationSearch,
                    iconColor: hasLoc
                        ? Colors.green.withValues(alpha: 0.7)
                        : Colors.white.withValues(alpha: 0.25),
                    trailing: _isLocating
                        ? SizedBox(
                            width: 10,
                            height: 10,
                            child: CircularProgressIndicator(
                                strokeWidth: 1.2,
                                color: accent.withValues(alpha: 0.4)),
                          )
                        : GestureDetector(
                            onTap: _detectLocation,
                            child: Icon(Icons.my_location_rounded,
                                size: 12,
                                color: Colors.white.withValues(alpha: 0.2)),
                          ),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _showLocationSearch = !_showLocationSearch;
                        if (_showLocationSearch) {
                          _showCalcMethod = false;
                          _showAsrSchool = false;
                        }
                      });
                    },
                  ),
                ),
                // Divider
                _SettingsDivider(),
                // Calc method pill
                Expanded(
                  flex: 4,
                  child: _SettingsPill(
                    icon: Icons.calculate_outlined,
                    label: calcName,
                    accent: accent,
                    active: _showCalcMethod,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _showCalcMethod = !_showCalcMethod;
                        if (_showCalcMethod) {
                          _showLocationSearch = false;
                          _showAsrSchool = false;
                        }
                      });
                    },
                  ),
                ),
                // Divider
                _SettingsDivider(),
                // Asr school pill
                Expanded(
                  flex: 3,
                  child: _SettingsPill(
                    icon: Icons.wb_cloudy_outlined,
                    label: asrName,
                    accent: accent,
                    active: _showAsrSchool,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _showAsrSchool = !_showAsrSchool;
                        if (_showAsrSchool) {
                          _showLocationSearch = false;
                          _showCalcMethod = false;
                        }
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── expandable panels ────────────────────────────
        AnimatedCrossFade(
          firstChild: const SizedBox(height: 0),
          secondChild: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: _buildLocationExpanded(state),
          ),
          crossFadeState: _showLocationSearch
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 220),
          sizeCurve: Curves.easeOut,
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox(height: 0),
          secondChild: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: _buildCalcMethodPanel(state),
          ),
          crossFadeState: _showCalcMethod
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 220),
          sizeCurve: Curves.easeOut,
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox(height: 0),
          secondChild: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: _buildAsrSchoolPanel(state),
          ),
          crossFadeState: _showAsrSchool
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 220),
          sizeCurve: Curves.easeOut,
        ),
      ],
    );
  }

  /// Calc method panel — extracted from _buildLocationExpanded
  Widget _buildCalcMethodPanel(PrayerAlarmState state) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.015),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Calculation Method',
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
                color: Colors.white.withValues(alpha: 0.3)),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            initialValue: state.config.calculationMethod,
            items: AladhanApiService.calculationMethods
                .map((m) => DropdownMenuItem<int>(
                      value: m['id'] as int,
                      child: Text(m['name'] as String,
                          style: const TextStyle(fontSize: 11),
                          overflow: TextOverflow.ellipsis),
                    ))
                .toList(),
            onChanged: (val) {
              if (val != null) {
                ref
                    .read(prayerAlarmProvider.notifier)
                    .setCalculationMethod(val);
              }
            },
            isExpanded: true,
            dropdownColor: const Color(0xFF141418),
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.65),
                fontSize: 12),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.02),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }

  /// Asr school panel — compact two-option selector
  Widget _buildAsrSchoolPanel(PrayerAlarmState state) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.015),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Asr Calculation School',
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
                color: Colors.white.withValues(alpha: 0.3)),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _AsrOption(
                label: 'Shafi\'i',
                sublabel: 'Standard',
                selected: state.config.asrCalculationSchool == 0,
                accent: _a,
                onTap: () => ref
                    .read(prayerAlarmProvider.notifier)
                    .setAsrCalculationSchool(0),
              ),
              const SizedBox(width: 8),
              _AsrOption(
                label: 'Hanafi',
                sublabel: 'Indo-Pak',
                selected: state.config.asrCalculationSchool == 1,
                accent: _a,
                onTap: () => ref
                    .read(prayerAlarmProvider.notifier)
                    .setAsrCalculationSchool(1),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  //  TIMES TAB
  // ══════════════════════════════════════════════════════

  Widget _buildTimesTab(
      PrayerAlarmState state, PrayerReminderSettings s, bool hasLoc) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 40),
      physics: const ClampingScrollPhysics(),
      children: [
        _buildSalahTimetable(state, s),
        const SizedBox(height: 12),
        _buildFastingTimesCard(),
        const SizedBox(height: 16),
        _buildWidgetToggles(),
      ],
    );
  }

  // ══════════════════════════════════════════════════════
  //  ALARMS TAB
  // ══════════════════════════════════════════════════════

  Widget _buildAlarmsTab(PrayerAlarmState state, PrayerReminderSettings s,
      bool hasLoc, int enabledCount) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 40),
      physics: const ClampingScrollPhysics(),
      children: [
        _buildPermissionBanner(),
        _buildAlarmContent(state, s, hasLoc, enabledCount),
      ],
    );
  }

  // ══════════════════════════════════════════════════════
  //  PERMISSION STATUS BANNER
  // ══════════════════════════════════════════════════════

  Widget _buildPermissionBanner() {
    final notifOk = _hasNotifPermission ?? true;
    final exactOk = _hasExactAlarmPermission ?? true;
    if (notifOk && exactOk) return const SizedBox.shrink();

    final missing = <String>[];
    if (!notifOk) missing.add('Notifications');
    if (!exactOk) missing.add('Exact Alarms');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: _saveAndActivateAlarms,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.amber.withValues(alpha: 0.06),
            border: Border.all(color: Colors.amber.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.amber.withValues(alpha: 0.1),
                ),
                child: Icon(Icons.warning_amber_rounded,
                    size: 16, color: Colors.amber.withValues(alpha: 0.7)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Permissions Required',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.amber.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${missing.join(' & ')} not granted. Tap to fix.',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.amber.withValues(alpha: 0.45),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 12, color: Colors.amber.withValues(alpha: 0.4)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationExpanded(PrayerAlarmState state) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.015),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.03)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Auto-location chip (shown after GPS detect) ──
          if (_isLocating) ...[
            Row(
              children: [
                SizedBox(
                  width: 11,
                  height: 11,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.3,
                    color: _a.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Detecting your location…',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ] else if (_autoDetectedCity != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withValues(alpha: 0.15)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.my_location_rounded,
                      size: 12, color: Colors.green.withValues(alpha: 0.6)),
                  const SizedBox(width: 6),
                  Text(
                    'Auto-detected: $_autoDetectedCity',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.green.withValues(alpha: 0.75),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.check_circle_outline_rounded,
                      size: 12, color: Colors.green.withValues(alpha: 0.5)),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          TextField(
            controller: _cityController,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search city...',
              hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.15),
                  fontSize: 13),
              prefixIcon: Icon(Icons.search_rounded,
                  size: 15,
                  color: Colors.white.withValues(alpha: 0.15)),
              suffixIcon: _isLocating
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 1.5),
                      ),
                    )
                  : _isSearching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 14,
                        height: 14,
                        child:
                            CircularProgressIndicator(strokeWidth: 1.5),
                      ),
                    )
                  : _cityController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.close_rounded,
                              size: 14,
                              color: Colors.white
                                  .withValues(alpha: 0.25)),
                          onPressed: () {
                            _cityController.clear();
                            setState(() {
                              _searchResults = [];
                              _autoDetectedCity = null;
                            });
                          },
                        )
                      : IconButton(
                          icon: Icon(Icons.my_location_rounded,
                              size: 16,
                              color: Colors.white.withValues(alpha: 0.35)),
                          tooltip: 'Auto-detect location',
                          onPressed: _detectLocation,
                        ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.025),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              isDense: true,
            ),
            onChanged: (v) {
              // If user starts typing manually, clear the auto-detected chip
              if (_autoDetectedCity != null && v != _autoDetectedCity) {
                setState(() => _autoDetectedCity = null);
              }
              _onCitySearch(v);
            },
          ),
          if (_searchResults.isNotEmpty) ...[
            const SizedBox(height: 4),
            Container(
              constraints: const BoxConstraints(maxHeight: 130),
              decoration: BoxDecoration(
                color: const Color(0xFF0C0C10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: _searchResults.length,
                itemBuilder: (_, i) {
                  final r = _searchResults[i];
                  return InkWell(
                    onTap: () => _selectSearchResult(r),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      child: Text(
                        r['name'] as String,
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.white
                                .withValues(alpha: 0.65)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  String _calcMethodName(int id) {
    for (final m in AladhanApiService.calculationMethods) {
      if (m['id'] == id) {
        final name = m['name'] as String;
        return name.length > 25 ? '${name.substring(0, 25)}…' : name;
      }
    }
    return 'Default';
  }

  // ══════════════════════════════════════════════════════
  //  NAMAZ TIMES — Hero Section (read-only, prominent)
  // ══════════════════════════════════════════════════════

  // ══════════════════════════════════════════════════════
  //  SALAH TIMETABLE (date-navigable)
  // ══════════════════════════════════════════════════════

  Widget _buildSalahTimetable(PrayerAlarmState state, PrayerReminderSettings s) {
    final accent = _a;
    final isToday = dateKeyFor(_viewDate) == todayDateKey();

    // ── Countdown banner (today only) ─────────────────
    Widget countdownBanner = const SizedBox.shrink();
    if (isToday && _nextPrayerName.isNotEmpty) {
      final h = _timeUntilNext.inHours;
      final m = _timeUntilNext.inMinutes.remainder(60);
      final sec = _timeUntilNext.inSeconds.remainder(60);
      final label = h > 0
          ? '$_nextPrayerName in ${h}h ${m}m'
          : m > 0
              ? '$_nextPrayerName in ${m}m ${sec}s'
              : '$_nextPrayerName in ${sec}s';
      countdownBanner = Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: accent.withValues(alpha: 0.08),
          border: Border.all(color: accent.withValues(alpha: 0.18)),
        ),
        child: Row(
          children: [
            Icon(Icons.access_time_rounded,
                size: 14, color: accent.withValues(alpha: 0.6)),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: accent.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      );
    }

    // ── Date header string ─────────────────────────────
    final dateStr = DateFormat('EEEE d MMMM').format(_viewDate);

    // ── Prayer rows ────────────────────────────────────
    const prayers = ['Fajr', 'Sunrise', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
    const prayerIcons = {
      'Fajr': Icons.wb_twilight_rounded,
      'Sunrise': Icons.wb_sunny_outlined,
      'Dhuhr': Icons.wb_sunny_rounded,
      'Asr': Icons.wb_cloudy_rounded,
      'Maghrib': Icons.nights_stay_rounded,
      'Isha': Icons.dark_mode_rounded,
    };
    const arabicNames = {
      'Fajr': 'الفجر',
      'Sunrise': 'الشروق',
      'Dhuhr': 'الظهر',
      'Asr': 'العصر',
      'Maghrib': 'المغرب',
      'Isha': 'العشاء',
    };

    final String? nextPrayer = isToday ? _findNextPrayer(state) : null;

    Widget prayerRows;
    if (_viewLoading) {
      prayerRows = Column(
        children: List.generate(
          6,
          (i) => Container(
            margin: const EdgeInsets.symmetric(vertical: 3),
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: Colors.white.withValues(alpha: 0.03),
            ),
            child: Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: accent.withValues(alpha: 0.25)),
              ),
            ),
          ),
        ),
      );
    } else if (_viewTimes == null) {
      prayerRows = Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Column(
          children: [
            Icon(Icons.mosque_rounded,
                size: 32, color: accent.withValues(alpha: 0.12)),
            const SizedBox(height: 12),
            Text(
              state.config.locationLabel.isEmpty
                  ? 'Set your location to see prayer times'
                  : 'Unable to load times for this date',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.25),
                  height: 1.5),
            ),
          ],
        ),
      );
    } else {
      prayerRows = Column(
        children: prayers.map((prayer) {
          final rawTime = _viewTimes!.timeFor(prayer);
          // For the viewed date use raw times (adjustments only apply today)
          final displayTime = isToday
              ? _fmt12h(state.effectiveTimeFor(prayer) ?? rawTime)
              : _fmt12h(rawTime);

          final isNext = nextPrayer == prayer;
          final notifType = s.notifTypeFor(prayer);
          final alarmOn = notifType != 'silent';
          final isSunrise = prayer == 'Sunrise';

          return Container(
            margin: const EdgeInsets.symmetric(vertical: 3),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: isNext
                  ? accent.withValues(alpha: 0.10)
                  : Colors.white.withValues(alpha: 0.03),
              border: Border.all(
                color: isNext
                    ? accent.withValues(alpha: 0.30)
                    : Colors.white.withValues(alpha: 0.05),
                width: isNext ? 1.2 : 0.8,
              ),
            ),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isNext
                        ? accent.withValues(alpha: 0.15)
                        : Colors.white.withValues(alpha: 0.04),
                  ),
                  child: Icon(
                    prayerIcons[prayer]!,
                    size: 15,
                    color: isNext
                        ? accent.withValues(alpha: 0.9)
                        : Colors.white.withValues(alpha: 0.35),
                  ),
                ),
                const SizedBox(width: 10),
                // Name
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            prayer,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isNext
                                  ? Colors.white.withValues(alpha: 0.95)
                                  : Colors.white.withValues(alpha: 0.70),
                            ),
                          ),
                          if (isNext) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                                color: accent.withValues(alpha: 0.18),
                              ),
                              child: Text(
                                'NEXT',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                  color: accent,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        arabicNames[prayer]!,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white.withValues(alpha: 0.25),
                        ),
                      ),
                    ],
                  ),
                ),
                // Time
                Text(
                  rawTime.isEmpty ? '--:--' : displayTime,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isNext
                        ? accent.withValues(alpha: 0.95)
                        : Colors.white.withValues(alpha: 0.75),
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                // Bell / alarm status (not shown for Sunrise)
                if (!isSunrise) ...[
                  const SizedBox(width: 10),
                  Icon(
                    alarmOn ? Icons.notifications_rounded : Icons.notifications_off_outlined,
                    size: 15,
                    color: alarmOn
                        ? accent.withValues(alpha: 0.65)
                        : Colors.white.withValues(alpha: 0.18),
                  ),
                ],
              ],
            ),
          );
        }).toList(),
      );
    }

    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── date nav row + refresh ────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Prev
              _NavArrow(
                icon: Icons.chevron_left_rounded,
                accent: accent,
                onTap: () => _loadViewDate(
                    _viewDate.subtract(const Duration(days: 1))),
              ),
              // Date label
              Column(
                children: [
                  Text(
                    dateStr,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  if (isToday)
                    Text(
                      'TODAY',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                        color: accent.withValues(alpha: 0.5),
                      ),
                    ),
                ],
              ),
              // Next + refresh
              Row(
                children: [
                  if (state.isLoading || _viewLoading)
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: accent.withValues(alpha: 0.35)),
                    )
                  else
                    GestureDetector(
                      onTap: () {
                        // If no location set, prompt user to set it first
                        if (state.config.locationLabel.isEmpty) {
                          HapticFeedback.mediumImpact();
                          setState(() {
                            _showLocationSearch = true;
                            _showCalcMethod = false;
                            _showAsrSchool = false;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  Icon(Icons.location_off_rounded,
                                      size: 16,
                                      color: Colors.white
                                          .withValues(alpha: 0.8)),
                                  const SizedBox(width: 10),
                                  const Expanded(
                                    child: Text(
                                      'Set your location first to load prayer times',
                                      style: TextStyle(fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                              backgroundColor: const Color(0xFF1A1A1A),
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(seconds: 3),
                              action: SnackBarAction(
                                label: 'SET LOCATION',
                                textColor: accent,
                                onPressed: () {
                                  // Panel is already open (set above)
                                },
                              ),
                            ),
                          );
                          return;
                        }
                        if (isToday) {
                          ref
                              .read(prayerAlarmProvider.notifier)
                              .fetchTodayPrayerTimes();
                        }
                        _loadViewDate(_viewDate);
                      },
                      child: Icon(Icons.refresh_rounded,
                          size: 15,
                          color: Colors.white.withValues(alpha: 0.2)),
                    ),
                  const SizedBox(width: 8),
                  _NavArrow(
                    icon: Icons.chevron_right_rounded,
                    accent: accent,
                    onTap: () => _loadViewDate(
                        _viewDate.add(const Duration(days: 1))),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ── countdown banner (today only) ─────────────
          countdownBanner,

          // ── prayer rows ───────────────────────────────
          prayerRows,
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  //  SUHOOR & IFTAR
  // ══════════════════════════════════════════════════════

  Widget _buildFastingTimesCard() {
    final fastingState = ref.watch(fastingProvider);
    final isLoaded = fastingState.isLoaded;
    final times = fastingState.times;

    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.nightlight_round,
                  size: 13, color: _a.withValues(alpha: 0.4)),
              const SizedBox(width: 6),
              Text(
                'SUHOOR & IFTAR',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: _a.withValues(alpha: 0.4),
                ),
              ),
              const Spacer(),
              if (fastingState.status == FastingStatus.loading)
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                      strokeWidth: 1.5, color: _a),
                )
              else
                GestureDetector(
                  onTap: () =>
                      ref.read(fastingProvider.notifier).fetch(),
                  child: Icon(Icons.refresh_rounded,
                      size: 14, color: _a.withValues(alpha: 0.25)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (!isLoaded) ...[
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  fastingState.status == FastingStatus.loading
                      ? 'Loading times…'
                      : fastingState.errorMessage
                                  ?.contains('Location') ==
                              true
                          ? 'Set location to load fasting times'
                          : 'Could not load times',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.25),
                  ),
                ),
              ),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: _FastingTimeChip(
                    icon: Icons.wb_twilight_rounded,
                    label: 'SUHOOR',
                    time: _fmt12h(times!.sahur),
                    accent: _a,
                    onSetAlarm: () =>
                        _scheduleFastingAlarm('Suhoor', times.sahur),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _FastingTimeChip(
                    icon: Icons.nights_stay_rounded,
                    label: 'IFTAR',
                    time: _fmt12h(times.iftar),
                    accent: _a,
                    onSetAlarm: () =>
                        _scheduleFastingAlarm('Iftar', times.iftar),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Powered by IslamicAPI · ${times.date}',
              style: TextStyle(
                fontSize: 9,
                color: Colors.white.withValues(alpha: 0.12),
                letterSpacing: 0.3,
              ),
            ),
            // Show cached indicator if data is not from today
            if (fastingState.lastFetchDate != _todayKey()) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 11,
                      color: Colors.amber.withValues(alpha: 0.4)),
                  const SizedBox(width: 4),
                  Text(
                    'Showing cached times · tap ↻ to refresh',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.amber.withValues(alpha: 0.35),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  //  ALARM SETTINGS (independent, expandable section)
  // ══════════════════════════════════════════════════════

  Widget _buildAlarmContent(
    PrayerAlarmState state,
    PrayerReminderSettings s,
    bool hasLoc,
    int enabledCount,
  ) {
    const prayers = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
    const icons = {
      'Fajr': Icons.wb_twilight_rounded,
      'Dhuhr': Icons.light_mode_rounded,
      'Asr': Icons.wb_sunny_outlined,
      'Maghrib': Icons.nights_stay_outlined,
      'Isha': Icons.dark_mode_rounded,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),

        // ── Section label + All-toggle ──────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
          child: Row(
            children: [
              Text(
                'SET PRAYER ALARMS',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                  color: _a.withValues(alpha: 0.45),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () async {
                  HapticFeedback.lightImpact();
                  final allSilent = prayers
                      .every((p) => s.notifTypeFor(p) == 'silent');
                  final targetType =
                      allSilent ? 'notification' : 'silent';
                  for (final p in prayers) {
                    final ok = await ref
                        .read(prayerAlarmProvider.notifier)
                        .setPrayerNotifType(p, targetType);
                    if (!ok && mounted) {
                      _saveAndActivateAlarms();
                      return;
                    }
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.white.withValues(alpha: 0.04),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.07)),
                  ),
                  child: Text(
                    prayers.every((p) => s.notifTypeFor(p) == 'silent')
                        ? 'Enable all'
                        : 'Disable all',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── One card per prayer ─────────────────────────────────────────
        ...prayers.map((prayer) {
          final apiTime =
              state.todayTimes?.timeFor(prayer) ?? '--:--';
          final adj = s.adjustmentFor(prayer);
          final effectiveTime =
              state.effectiveTimeFor(prayer) ?? apiTime;
          final notifType = s.notifTypeFor(prayer);
          final isOn = notifType != 'silent';

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _PrayerAlarmCard(
              icon: icons[prayer]!,
              prayer: prayer,
              apiTime: apiTime,
              effectiveTime: effectiveTime,
              adjustment: adj,
              notifType: notifType,
              isOn: isOn,
              accent: _a,
              onTimeTap: () =>
                  _showAdjustmentSheet(prayer, apiTime, adj),
              onNotifTypeTap: () =>
                  _showNotifTypePicker(prayer, notifType),
            ),
          );
        }),

        const SizedBox(height: 4),
        _buildSoundSection(s),
        const SizedBox(height: 14),
        _buildActivate(hasLoc, state.todayTimes != null, enabledCount),
      ],
    );
  }

  // ══════════════════════════════════════════════════════
  //  SOUND SETTINGS (collapsible inside alarm section)
  // ══════════════════════════════════════════════════════

  Widget _buildSoundSection(PrayerReminderSettings s) {
    final customFileName = s.customSoundPath.isNotEmpty
        ? s.customSoundPath.split('/').last
        : null;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _showSoundSettings = !_showSoundSettings);
      },
      child: _Surface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.volume_up_rounded,
                    size: 13,
                    color: _a.withValues(alpha: 0.35)),
                const SizedBox(width: 6),
                Text(
                  'SOUND',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: _a.withValues(alpha: 0.35),
                  ),
                ),
                const Spacer(),
                Text(
                  _soundLabel(s.soundType),
                  style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withValues(alpha: 0.3)),
                ),
                const SizedBox(width: 4),
                AnimatedRotation(
                  turns: _showSoundSettings ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: Colors.white.withValues(alpha: 0.15)),
                ),
              ],
            ),
            if (_showSoundSettings) ...[
              const SizedBox(height: 12),
              _SoundOption(
                label: 'Namaz Reminder',
                selected: s.soundType == 'namaz_reminder',
                accent: _a,
                onTap: () {
                  HapticFeedback.lightImpact();
                  ref
                      .read(prayerAlarmProvider.notifier)
                      .updateSoundSettings(
                          soundType: 'namaz_reminder');
                },
                onPreview: () => _previewSound('namaz_reminder'),
                isPreviewing: _previewingSound == 'namaz_reminder',
              ),
              const SizedBox(height: 6),
              _SoundOption(
                label: 'Vibration Only',
                selected: s.soundType == 'vibrate_only',
                accent: _a,
                onTap: () {
                  HapticFeedback.lightImpact();
                  ref
                      .read(prayerAlarmProvider.notifier)
                      .updateSoundSettings(
                          soundType: 'vibrate_only');
                },
              ),
              const SizedBox(height: 6),
              _SoundOption(
                label: 'Custom Audio',
                selected: s.soundType == 'custom',
                accent: _a,
                onTap: _pickCustomAudio,
                onPreview: s.customSoundPath.isNotEmpty
                    ? () => _previewSound('custom')
                    : null,
                isPreviewing: _previewingSound == 'custom',
              ),
              if (s.soundType == 'custom') ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _a.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: _a.withValues(alpha: 0.15),
                        width: 0.5),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.audio_file_rounded,
                          size: 14,
                          color: _a.withValues(alpha: 0.6)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          customFileName ?? 'No file selected',
                          style: TextStyle(
                            fontSize: 11,
                            color: customFileName != null
                                ? Colors.white
                                    .withValues(alpha: 0.7)
                                : Colors.white
                                    .withValues(alpha: 0.3),
                            overflow: TextOverflow.ellipsis,
                          ),
                          maxLines: 1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _pickCustomAudio,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _a.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Browse',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _a,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(Icons.snooze_rounded,
                      size: 13,
                      color: Colors.white
                          .withValues(alpha: 0.2)),
                  const SizedBox(width: 6),
                  Text('Snooze',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(
                              alpha: 0.35))),
                  const Spacer(),
                  DropdownButton<int>(
                    value: s.snoozeDurationMinutes,
                    underline: const SizedBox(),
                    isDense: true,
                    dropdownColor:
                        const Color(0xFF141418),
                    style: TextStyle(
                        fontSize: 12, color: _a),
                    items: [5, 10, 15, 20, 30]
                        .map((m) => DropdownMenuItem(
                            value: m,
                            child: Text('${m}m')))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        ref
                            .read(prayerAlarmProvider
                                .notifier)
                            .updateSoundSettings(
                                snoozeDurationMinutes:
                                    v);
                      }
                    },
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _soundLabel(String type) {
    switch (type) {
      case 'namaz_reminder':
        return 'Namaz Reminder';
      case 'vibrate_only':
        return 'Vibration Only';
      case 'custom':
        return 'Custom Audio';
      default:
        return 'Default';
    }
  }

  // ══════════════════════════════════════════════════════
  //  HOME WIDGET TOGGLES
  // ══════════════════════════════════════════════════════

  Widget _buildWidgetToggles() {
    final display = ref.watch(displaySettingsProvider);
    final widgetOn =
        display.showPrayerWidget || display.showFastingWidget || display.showDuaWidget;

    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.widgets_rounded,
                  size: 13,
                  color: _a.withValues(alpha: 0.35)),
              const SizedBox(width: 6),
              Text(
                'HOME SCREEN WIDGET',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: _a.withValues(alpha: 0.35),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              final newValue = !widgetOn;
              ref
                  .read(displaySettingsProvider.notifier)
                  .setShowPrayerWidget(newValue);
              ref
                  .read(displaySettingsProvider.notifier)
                  .setShowFastingWidget(newValue);
              ref
                  .read(displaySettingsProvider.notifier)
                  .setShowDuaWidget(newValue);
              if (newValue) {
                ref.read(fastingProvider.notifier).fetch();
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: widgetOn
                    ? _a.withValues(alpha: 0.08)
                    : Colors.white.withValues(alpha: 0.02),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: widgetOn
                      ? _a.withValues(alpha: 0.28)
                      : Colors.white.withValues(alpha: 0.06),
                ),
              ),
              child: Row(
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: widgetOn
                              ? _a.withValues(alpha: 0.15)
                              : Colors.white
                                  .withValues(alpha: 0.04),
                        ),
                        child: Icon(
                          Icons.mosque_rounded,
                          size: 16,
                          color: widgetOn
                              ? _a
                              : Colors.white
                                  .withValues(alpha: 0.25),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: widgetOn
                                ? _a.withValues(alpha: 0.9)
                                : Colors.white
                                    .withValues(alpha: 0.06),
                            border: Border.all(
                              color: const Color(0xFF0D1117),
                              width: 1.5,
                            ),
                          ),
                          child: Icon(
                            Icons.nightlight_round,
                            size: 7,
                            color: widgetOn
                                ? Colors.white
                                : Colors.white
                                    .withValues(alpha: 0.2),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Prayer + Fasting Widget',
                          style: TextStyle(
                            color: widgetOn
                                ? Colors.white
                                    .withValues(alpha: 0.9)
                                : Colors.white
                                    .withValues(alpha: 0.35),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widgetOn
                              ? 'Showing on home screen'
                              : 'Hidden from home screen',
                          style: TextStyle(
                            color: widgetOn
                                ? _a.withValues(alpha: 0.6)
                                : Colors.white
                                    .withValues(alpha: 0.2),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _TogglePill(value: widgetOn, accent: _a),
                ],
              ),
            ),
          ),
          if (widgetOn) ...[
            const SizedBox(height: 10),
            _MiniToggle(
              icon: Icons.mosque_rounded,
              label: 'Prayer times row',
              value: display.showPrayerWidget,
              accent: _a,
              onChanged: (v) {
                HapticFeedback.selectionClick();
                ref
                    .read(displaySettingsProvider.notifier)
                    .setShowPrayerWidget(v);
              },
            ),
            const SizedBox(height: 8),
            _MiniToggle(
              icon: Icons.nightlight_round,
              label: 'Suhoor / Iftar row',
              value: display.showFastingWidget,
              accent: _a,
              onChanged: (v) {
                HapticFeedback.selectionClick();
                ref
                    .read(displaySettingsProvider.notifier)
                    .setShowFastingWidget(v);
                if (v) ref.read(fastingProvider.notifier).fetch();
              },
            ),
            const SizedBox(height: 12),
            _buildRamadanDayOffset(display),
          ],
        ],
      ),
    );
  }

  Widget _buildRamadanDayOffset(dynamic display) {
    final offset = display.ramadanDayOffset as int;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Icon(Icons.wb_twilight_rounded,
              size: 13,
              color: _a.withValues(alpha: 0.45)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ramadan day offset',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color:
                        Colors.white.withValues(alpha: 0.55),
                  ),
                ),
                Text(
                  'Adjust for moon sighting in your region',
                  style: TextStyle(
                    fontSize: 10,
                    color:
                        Colors.white.withValues(alpha: 0.22),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [-2, -1, 0, 1, 2].map((val) {
              final isActive = offset == val;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  ref
                      .read(displaySettingsProvider.notifier)
                      .setRamadanDayOffset(val);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 28,
                  height: 26,
                  margin: const EdgeInsets.only(left: 4),
                  decoration: BoxDecoration(
                    color: isActive
                        ? _a.withValues(alpha: 0.20)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isActive
                          ? _a.withValues(alpha: 0.55)
                          : Colors.white
                              .withValues(alpha: 0.10),
                      width: isActive ? 1.2 : 0.8,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      val == 0
                          ? '0'
                          : (val > 0 ? '+$val' : '$val'),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isActive
                            ? FontWeight.w700
                            : FontWeight.w400,
                        color: isActive
                            ? _a
                            : Colors.white
                                .withValues(alpha: 0.30),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  //  ACTIVATE BUTTON
  // ══════════════════════════════════════════════════════

  Widget _buildActivate(bool hasLoc, bool hasTimes, int count) {
    final canSave = hasLoc && hasTimes && count > 0;

    return GestureDetector(
      onTap: canSave && !_isSaving
          ? _saveAndActivateAlarms
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: canSave
              ? LinearGradient(colors: [
                  _a.withValues(alpha: 0.25),
                  _a.withValues(alpha: 0.10),
                ])
              : null,
          color: canSave
              ? null
              : Colors.white.withValues(alpha: 0.02),
          border: Border.all(
            color: canSave
                ? _a.withValues(alpha: 0.35)
                : Colors.white.withValues(alpha: 0.04),
          ),
        ),
        child: _isSaving
            ? Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: _a),
                ),
              )
            : Center(
                child: Text(
                  canSave
                      ? 'ACTIVATE $count ALARM${count != 1 ? 'S' : ''}'
                      : hasLoc
                          ? 'SELECT PRAYERS ABOVE'
                          : 'SET LOCATION FIRST',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: canSave
                        ? Colors.white.withValues(alpha: 0.93)
                        : Colors.white.withValues(alpha: 0.15),
                  ),
                ),
              ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  //  ADJUSTMENT SHEET (free-input slider + text field)
  // ══════════════════════════════════════════════════════

  void _showAdjustmentSheet(String prayer, String apiTime, int currentAdj) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AdjustmentSheet(
        prayer: prayer,
        apiTime: apiTime,
        currentAdjustment: currentAdj,
        accent: _a,
        onSave: (int minutes) async {
          HapticFeedback.mediumImpact();
          await ref
              .read(prayerAlarmProvider.notifier)
              .setPrayerAdjustment(prayer, minutes);
        },
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  //  NOTIFICATION TYPE PICKER (per-prayer bottom sheet)
  // ══════════════════════════════════════════════════════

  void _showNotifTypePicker(String prayer, String currentType) {
    const types = [
      {
        'value': 'silent',
        'label': 'Silent',
        'desc': 'No reminder — completely off',
        'icon': Icons.notifications_off_rounded,
      },
      {
        'value': 'notification',
        'label': 'Notification',
        'desc': 'Banner + sound in notification shade',
        'icon': Icons.notifications_active_rounded,
      },
      {
        'value': 'athan',
        'label': 'Alarm',
        'desc': 'Wakes screen • Full-page reminder • Athan sound',
        'icon': Icons.mosque_rounded,
      },
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0C0C10),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 3,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                '$prayer Reminder',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Choose how you want to be reminded',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.3),
                ),
              ),
              const SizedBox(height: 20),
              ...types.map((t) {
                final isSelected = currentType == t['value'];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GestureDetector(
                    onTap: () async {
                      HapticFeedback.lightImpact();
                      Navigator.pop(ctx);
                      final success = await ref
                          .read(prayerAlarmProvider.notifier)
                          .setPrayerNotifType(
                              prayer, t['value'] as String);
                      if (!success && mounted) {
                        // Permission missing — show permission screen
                        _saveAndActivateAlarms();
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: isSelected
                            ? _a.withValues(alpha: 0.08)
                            : Colors.white.withValues(alpha: 0.02),
                        border: Border.all(
                          color: isSelected
                              ? _a.withValues(alpha: 0.3)
                              : Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: isSelected
                                  ? _a.withValues(alpha: 0.12)
                                  : Colors.white.withValues(alpha: 0.03),
                            ),
                            child: Icon(
                              t['icon'] as IconData,
                              size: 18,
                              color: isSelected
                                  ? _a.withValues(alpha: 0.8)
                                  : Colors.white.withValues(alpha: 0.3),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t['label'] as String,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected
                                        ? Colors.white.withValues(alpha: 0.9)
                                        : Colors.white.withValues(alpha: 0.5),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  t['desc'] as String,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white.withValues(alpha: 0.25),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            Icon(Icons.check_circle_rounded,
                                size: 20,
                                color: _a.withValues(alpha: 0.7)),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════
  //  ACTIONS
  // ══════════════════════════════════════════════════════

  Future<void> _saveAndActivateAlarms() async {
    setState(() => _isSaving = true);
    try {
      if (!mounted) return;
      final result = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => PermissionSetupScreen(
            onAllGranted: () async {
              await ref
                  .read(prayerAlarmProvider.notifier)
                  .rescheduleAllAlarms();
              if (!mounted) return;
              Navigator.of(context).pop(true);
            },
            onSkipped: () =>
                Navigator.of(context).pop(false),
          ),
          fullscreenDialog: true,
        ),
      );
      setState(() => _isSaving = false);
      if (result == true && mounted) _showSuccess();
      // Re-check permissions after returning from permission screen
      _checkPermissions();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to activate: $e'),
          backgroundColor: Colors.red.shade800,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showSuccess() {
    final state = ref.read(prayerAlarmProvider);
    final count =
        state.enabledMap.values.where((v) => v).length;
    final next = _getNextPrayerText(state);

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF0C0C10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
              color: Colors.white.withValues(alpha: 0.04)),
        ),
        child: Padding(
          padding:
              const EdgeInsets.fromLTRB(28, 32, 28, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      Colors.green.withValues(alpha: 0.08),
                  border: Border.all(
                      color: Colors.green
                          .withValues(alpha: 0.15)),
                ),
                child: Icon(Icons.check_rounded,
                    size: 28,
                    color: Colors.green
                        .withValues(alpha: 0.8)),
              ),
              const SizedBox(height: 20),
              Text(
                '$count Alarm${count != 1 ? 's' : ''} Active',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white
                      .withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You will be reminded at each salah time.\nMay Allah accept your prayers.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white
                      .withValues(alpha: 0.35),
                  height: 1.5,
                ),
              ),
              if (next != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: _a.withValues(alpha: 0.06),
                    border: Border.all(
                        color: _a.withValues(alpha: 0.1)),
                  ),
                  child: Text(
                    'Next: $next',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _a.withValues(alpha: 0.75),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () {
                  Navigator.pop(ctx);
                  // Stay on Salah Wake page — don't pop the settings screen
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      vertical: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: _a.withValues(alpha: 0.08),
                    border: Border.all(
                        color: _a.withValues(alpha: 0.12)),
                  ),
                  child: Center(
                    child: Text(
                      'Done',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white
                            .withValues(alpha: 0.85),
                      ),
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

  Future<void> _scheduleFastingAlarm(
      String label, String timeStr) async {
    try {
      DateTime? parsed;
      final str = timeStr.trim();
      final parts24 = str.split(':');
      if (parts24.length == 2 && !str.contains(' ')) {
        parsed = DateTime(0, 1, 1, int.parse(parts24[0]),
            int.parse(parts24[1]));
      } else {
        parsed = DateFormat('h:mm a').parse(str);
      }

      final now = DateTime.now();
      var target = DateTime(now.year, now.month, now.day,
          parsed.hour, parsed.minute);
      if (target.isBefore(now)) {
        target = target.add(const Duration(days: 1));
      }

      final displayTime = DateFormat('h:mm a').format(target);
      final alarmId = label == 'Suhoor' ? 1010 : 1011;

      await PrayerAlarmService.storeFastingAlarm(
          alarmId, label, target);
      await PrayerAlarmService.scheduleFastingAlarm(
        label: label,
        alarmTime: target,
        alarmId: alarmId,
      );

      if (mounted) {
        HapticFeedback.heavyImpact();
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (sheetCtx) => Container(
            margin:
                const EdgeInsets.fromLTRB(16, 0, 16, 24),
            padding: const EdgeInsets.symmetric(
                horizontal: 24, vertical: 28),
            decoration: BoxDecoration(
              color: const Color(0xFF141414),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                  color: _a.withValues(alpha: 0.18)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _a.withValues(alpha: 0.1),
                    border: Border.all(
                        color:
                            _a.withValues(alpha: 0.3),
                        width: 1.5),
                  ),
                  child: Icon(Icons.alarm_on_rounded,
                      color: _a, size: 26),
                ),
                const SizedBox(height: 16),
                Text(
                  '$label Alarm Set',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white
                        .withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  displayTime,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w300,
                    color: _a.withValues(alpha: 0.85),
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  target.day == DateTime.now().day
                      ? 'Alarm scheduled for today'
                      : 'Alarm scheduled for tomorrow',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white
                        .withValues(alpha: 0.35),
                  ),
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () =>
                      Navigator.pop(sheetCtx),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        vertical: 14),
                    decoration: BoxDecoration(
                      borderRadius:
                          BorderRadius.circular(14),
                      color:
                          _a.withValues(alpha: 0.1),
                      border: Border.all(
                          color: _a.withValues(
                              alpha: 0.2)),
                    ),
                    child: Text(
                      'Done',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _a.withValues(
                            alpha: 0.8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not set alarm: $e'),
            backgroundColor: Colors.red.shade900,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ══════════════════════════════════════════════════════
  //  HELPERS (delegates to shared prayer_time_utils)
  // ══════════════════════════════════════════════════════

  String _fmt12h(String s) => fmt12h(s);

  String _todayKey() => todayDateKey();

  String? _findNextPrayer(PrayerAlarmState state) {
    if (state.todayTimes == null) return null;
    final now = DateTime.now();
    for (final p
        in ['Fajr', 'Sunrise', 'Dhuhr', 'Asr', 'Maghrib', 'Isha']) {
      final t = state.todayTimes!.timeFor(p);
      if (t.isEmpty) continue; // Sunrise might be empty on old cached data
      final parts = t.split(':');
      if (parts.length != 2) continue;
      final h = int.tryParse(parts[0]) ?? 0;
      final m = int.tryParse(parts[1]) ?? 0;
      if (DateTime(now.year, now.month, now.day, h, m)
          .isAfter(now)) {
        return p;
      }
    }
    return null;
  }

  String? _getNextPrayerText(PrayerAlarmState state) {
    final now = DateTime.now();
    final times = state.effectiveTimesMap;
    final enabled = state.enabledMap;
    for (final p
        in ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha']) {
      if (!(enabled[p] ?? false)) continue;
      final t = times[p];
      if (t == null) continue;
      final parts = t.split(':');
      if (parts.length != 2) continue;
      final h = int.tryParse(parts[0]) ?? 0;
      final m = int.tryParse(parts[1]) ?? 0;
      if (DateTime(now.year, now.month, now.day, h, m)
          .isAfter(now)) {
        final period = h >= 12 ? 'PM' : 'AM';
        final h12 = h > 12 ? h - 12 : (h == 0 ? 12 : h);
        return '$p at $h12:${m.toString().padLeft(2, '0')} $period';
      }
    }
    return null;
  }

  Future<void> _detectLocation() async {
    // Check current permission status
    var locationStatus = await Permission.location.status;

    if (locationStatus.isPermanentlyDenied) {
      // Permanently denied — must go to app settings
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Location permission is permanently denied. Enable it in Settings.'),
        backgroundColor: Colors.red.shade800,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'OPEN SETTINGS',
          textColor: Colors.white,
          onPressed: () => openAppSettings(),
        ),
      ));
      return;
    }

    if (locationStatus.isDenied) {
      // Request permission directly — shows the OS prompt immediately
      locationStatus = await Permission.location.request();
      if (!locationStatus.isGranted) return;
    }

    // Open the location panel so the user sees the result appear
    setState(() {
      _isLocating = true;
      _showLocationSearch = true;
      _showCalcMethod = false;
      _showAsrSchool = false;
      _autoDetectedCity = null;
    });
    try {
      await PrayerAlarmService.requestNotificationPermission();
      final coords =
          await LocationService.getCurrentLocation();
      final lat = coords['lat']!;
      final lng = coords['lng']!;
      final cityName =
          await LocationService.getCityName(lat, lng);
      if (!mounted) return;
      _cityController.text = cityName;
      setState(() {
        _searchResults = [];
        _isLocating = false;
        _autoDetectedCity = cityName; // show auto-location chip
      });
      ref.read(prayerAlarmProvider.notifier).updateConfig(
            latitude: lat,
            longitude: lng,
            timezone: DateTime.now().timeZoneName,
            locationLabel: cityName,
          );
    } on LocationException catch (e) {
      if (!mounted) return;
      setState(() { _isLocating = false; _autoDetectedCity = null; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.message),
        backgroundColor: Colors.red.shade800,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
            label: 'SETTINGS',
            textColor: Colors.white,
            onPressed: () => openAppSettings()),
      ));
    } catch (_) {
      if (!mounted) return;
      setState(() { _isLocating = false; _autoDetectedCity = null; });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(
        content: Text('Could not detect location.'),
        backgroundColor: Colors.black54,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _onCitySearch(String query) async {
    if (query.trim().length < 2) {
      setState(() => _searchResults = []);
      return;
    }
    _lastSearchTime = DateTime.now();
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    if (DateTime.now()
            .difference(_lastSearchTime!)
            .inMilliseconds <
        450) {
      return;
    }
    setState(() => _isSearching = true);
    try {
      final results =
          await LocationService.searchCity(query);
      if (!mounted) return;
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSearching = false);
    }
  }

  void _selectSearchResult(
      Map<String, dynamic> result) async {
    final lat = result['lat'] as double;
    final lng = result['lng'] as double;
    final name = result['name'] as String;
    _cityController.text = name;
    setState(() => _searchResults = []);
    FocusScope.of(context).unfocus();
    await PrayerAlarmService
        .requestNotificationPermission();
    ref.read(prayerAlarmProvider.notifier).updateConfig(
          latitude: lat,
          longitude: lng,
          timezone: DateTime.now().timeZoneName,
          locationLabel: name,
        );
  }

  void _previewSound(String type) async {
    if (_previewingSound == type) {
      await _audioPreview?.stop();
      if (mounted) setState(() => _previewingSound = null);
      return;
    }
    if (mounted) setState(() => _previewingSound = type);
    try {
      await _audioPreview?.stop();
      if (type == 'custom') {
        final s =
            ref.read(prayerAlarmProvider).reminderSettings;
        if (s.customSoundPath.isNotEmpty) {
          await _audioPreview?.play(
              DeviceFileSource(s.customSoundPath));
        }
      } else {
        await _audioPreview?.play(
            AssetSource('sounds/namaz_reminder.mp3'));
      }
      Future.delayed(const Duration(seconds: 20),
          () async {
        if (mounted && _previewingSound == type) {
          for (int i = 10; i >= 0; i--) {
            if (!mounted || _previewingSound != type) {
              break;
            }
            await _audioPreview?.setVolume(i / 10.0);
            await Future.delayed(
                const Duration(seconds: 1));
          }
          if (mounted && _previewingSound == type) {
            await _audioPreview?.stop();
            await _audioPreview?.setVolume(1.0);
            setState(() => _previewingSound = null);
          }
        }
      });
    } catch (_) {
      setState(() => _previewingSound = null);
    }
  }

  Future<void> _pickCustomAudio() async {
    HapticFeedback.lightImpact();
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: false,
    );
    if (result != null &&
        result.files.single.path != null) {
      final path = result.files.single.path!;
      await ref
          .read(prayerAlarmProvider.notifier)
          .updateSoundSettings(
            soundType: 'custom',
            customSoundPath: path,
          );
    }
  }
}

// ═══════════════════════════════════════════════════════
//  COMPONENTS
// ═══════════════════════════════════════════════════════

// ──────────────────────────────────────────────────────────────────────────
//  Nav Arrow button for date navigation
// ──────────────────────────────────────────────────────────────────────────

// ──────────────────────────────────────────────────────────────────────────
//  Settings bar pill — one tappable item in the top bar
// ──────────────────────────────────────────────────────────────────────────

class _SettingsPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accent;
  final bool active;
  final Color? iconColor;
  final Widget? trailing;
  final VoidCallback onTap;

  const _SettingsPill({
    required this.icon,
    required this.label,
    required this.accent,
    required this.active,
    required this.onTap,
    this.iconColor,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final col = iconColor ?? (active ? accent : Colors.white.withValues(alpha: 0.3));
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: active
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.transparent,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: col),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight:
                      active ? FontWeight.w600 : FontWeight.w400,
                  color: active
                      ? Colors.white.withValues(alpha: 0.8)
                      : Colors.white.withValues(alpha: 0.35),
                ),
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 4),
              trailing!,
            ],
            const SizedBox(width: 2),
            Icon(
              active
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              size: 12,
              color: Colors.white.withValues(alpha: 0.18),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────
//  Vertical divider between settings pills
// ──────────────────────────────────────────────────────────────────────────

class _SettingsDivider extends StatelessWidget {
  const _SettingsDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 20,
      color: Colors.white.withValues(alpha: 0.06),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────
//  Asr school option chip
// ──────────────────────────────────────────────────────────────────────────

class _AsrOption extends StatelessWidget {
  final String label;
  final String sublabel;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const _AsrOption({
    required this.label,
    required this.sublabel,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: selected
                ? accent.withValues(alpha: 0.08)
                : Colors.white.withValues(alpha: 0.02),
            border: Border.all(
              color: selected
                  ? accent.withValues(alpha: 0.25)
                  : Colors.white.withValues(alpha: 0.05),
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 14,
                color: selected
                    ? accent
                    : Colors.white.withValues(alpha: 0.25),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? Colors.white.withValues(alpha: 0.85)
                          : Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                  Text(
                    sublabel,
                    style: TextStyle(
                      fontSize: 9,
                      color: selected
                          ? accent.withValues(alpha: 0.6)
                          : Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────

class _NavArrow extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  const _NavArrow({
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.04),
          border:
              Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Icon(icon, size: 20, color: accent.withValues(alpha: 0.7)),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────

class _Surface extends StatelessWidget {
  final Widget child;
  const _Surface({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: child,
    );
  }
}

/// Per-prayer alarm toggle row
/// ── PRAYER ALARM CARD ─────────────────────────────────────────────────────
/// Full-width card for one prayer. Surfaces three things prominently:
///   1. Prayer name + time (large, always readable)
///   2. Inline ±minute adjuster — the main control (no hidden sheet needed)
///   3. Alarm-type pill (Notification / Alarm / Off)
class _PrayerAlarmCard extends StatelessWidget {
  final IconData icon;
  final String prayer;
  final String apiTime;
  final String effectiveTime;
  final int adjustment;
  final String notifType;
  final bool isOn;
  final Color accent;
  final VoidCallback onTimeTap;
  final VoidCallback onNotifTypeTap;

  const _PrayerAlarmCard({
    required this.icon,
    required this.prayer,
    required this.apiTime,
    required this.effectiveTime,
    required this.adjustment,
    required this.notifType,
    required this.isOn,
    required this.accent,
    required this.onTimeTap,
    required this.onNotifTypeTap,
  });

  String _fmt12h(String t) {
    final parts = t.split(':');
    if (parts.length != 2) return t;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    final period = h < 12 ? 'AM' : 'PM';
    final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '${h12.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} $period';
  }

  IconData get _typeIcon {
    switch (notifType) {
      case 'athan':
        return Icons.mosque_rounded;
      case 'silent':
        return Icons.notifications_off_rounded;
      default:
        return Icons.notifications_active_rounded;
    }
  }

  String get _typeLabel {
    switch (notifType) {
      case 'athan':
        return 'Alarm';
      case 'silent':
        return 'Off';
      default:
        return 'Notify';
    }
  }

  @override
  Widget build(BuildContext context) {
    final dimmed = !isOn;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: dimmed ? 0.45 : 1.0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isOn
              ? accent.withValues(alpha: 0.04)
              : Colors.white.withValues(alpha: 0.015),
          border: Border.all(
            color: isOn
                ? accent.withValues(alpha: 0.14)
                : Colors.white.withValues(alpha: 0.05),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Row 1: name + time + alarm-type pill ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Icon
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: isOn
                        ? accent.withValues(alpha: 0.10)
                        : Colors.white.withValues(alpha: 0.03),
                  ),
                  child: Icon(icon,
                      size: 16,
                      color: isOn
                          ? accent.withValues(alpha: 0.8)
                          : Colors.white.withValues(alpha: 0.15)),
                ),
                const SizedBox(width: 10),
                // Prayer name
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      prayer,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isOn
                            ? Colors.white.withValues(alpha: 0.88)
                            : Colors.white.withValues(alpha: 0.3),
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 1),
                    // Effective alarm time — prominent
                    Text(
                      _fmt12h(effectiveTime),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: adjustment != 0
                            ? accent.withValues(alpha: 0.75)
                            : Colors.white.withValues(alpha: 0.38),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                // Alarm-type pill — tappable
                GestureDetector(
                  onTap: onNotifTypeTap,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: notifType == 'athan'
                          ? accent.withValues(alpha: 0.13)
                          : notifType == 'silent'
                              ? Colors.white.withValues(alpha: 0.03)
                              : Colors.white.withValues(alpha: 0.06),
                      border: Border.all(
                        color: notifType == 'athan'
                            ? accent.withValues(alpha: 0.28)
                            : notifType == 'silent'
                                ? Colors.white.withValues(alpha: 0.07)
                                : Colors.white.withValues(alpha: 0.10),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_typeIcon,
                            size: 13,
                            color: notifType == 'athan'
                                ? accent
                                : notifType == 'silent'
                                    ? Colors.white.withValues(alpha: 0.2)
                                    : Colors.white.withValues(alpha: 0.5)),
                        const SizedBox(width: 5),
                        Text(
                          _typeLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: notifType == 'athan'
                                ? accent
                                : notifType == 'silent'
                                    ? Colors.white.withValues(alpha: 0.22)
                                    : Colors.white.withValues(alpha: 0.55),
                          ),
                        ),
                        const SizedBox(width: 3),
                        Icon(Icons.keyboard_arrow_down_rounded,
                            size: 13,
                            color: Colors.white.withValues(alpha: 0.18)),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // ── Divider ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Container(
                height: 1,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),

            // ── Row 2: Adjustment chip (tap to open sheet) ───────────────
            GestureDetector(
              onTap: onTimeTap,
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  // Left: label + description
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ADJUST TIME',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: Colors.white.withValues(alpha: 0.25),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        adjustment == 0
                            ? 'Alarm at exact prayer time'
                            : adjustment > 0
                                ? '+$adjustment min after ${_fmt12h(apiTime)}'
                                : '${adjustment.abs()} min before ${_fmt12h(apiTime)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: adjustment != 0
                              ? accent.withValues(alpha: 0.7)
                              : Colors.white.withValues(alpha: 0.22),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Right: value badge + edit icon
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: adjustment != 0
                          ? accent.withValues(alpha: 0.10)
                          : Colors.white.withValues(alpha: 0.04),
                      border: Border.all(
                        color: adjustment != 0
                            ? accent.withValues(alpha: 0.25)
                            : Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          adjustment == 0
                              ? '0 min'
                              : adjustment > 0
                                  ? '+$adjustment min'
                                  : '$adjustment min',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            fontFeatures: const [
                              FontFeature.tabularFigures()
                            ],
                            color: adjustment != 0
                                ? accent
                                : Colors.white.withValues(alpha: 0.35),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.edit_rounded,
                            size: 11,
                            color: Colors.white.withValues(alpha: 0.2)),
                      ],
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

// ═══════════════════════════════════════════════════════════════════
//  ADJUSTMENT SHEET — free-input minute offset for a single prayer
// ═══════════════════════════════════════════════════════════════════

class _AdjustmentSheet extends StatefulWidget {
  final String prayer;
  final String apiTime;
  final int currentAdjustment;
  final Color accent;
  final ValueChanged<int> onSave;

  const _AdjustmentSheet({
    required this.prayer,
    required this.apiTime,
    required this.currentAdjustment,
    required this.accent,
    required this.onSave,
  });

  @override
  State<_AdjustmentSheet> createState() => _AdjustmentSheetState();
}

class _AdjustmentSheetState extends State<_AdjustmentSheet> {
  late int _minutes;
  late TextEditingController _ctrl;
  final _focusNode = FocusNode();

  static const int _min = -60;
  static const int _max = 60;

  @override
  void initState() {
    super.initState();
    _minutes = widget.currentAdjustment.clamp(_min, _max);
    _ctrl = TextEditingController(text: _minutes == 0 ? '' : '$_minutes');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // Compute the preview alarm time from the API time + offset
  String _previewTime() {
    final parts = widget.apiTime.split(':');
    if (parts.length != 2) return widget.apiTime;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    var total = h * 60 + m + _minutes;
    if (total < 0) total += 24 * 60;
    total = total % (24 * 60);
    final rh = total ~/ 60;
    final rm = total % 60;
    final period = rh < 12 ? 'AM' : 'PM';
    final h12 = rh == 0 ? 12 : (rh > 12 ? rh - 12 : rh);
    return '${h12.toString().padLeft(2, '0')}:${rm.toString().padLeft(2, '0')} $period';
  }

  void _update(int val) {
    final clamped = val.clamp(_min, _max);
    setState(() {
      _minutes = clamped;
      // Keep text field in sync only when slider drags
      _ctrl.text = clamped == 0 ? '' : '$clamped';
      if (_ctrl.text.isNotEmpty) {
        _ctrl.selection = TextSelection.collapsed(offset: _ctrl.text.length);
      }
    });
  }

  void _onTextChanged(String raw) {
    // Allow minus sign alone while typing
    if (raw == '' || raw == '-') {
      setState(() => _minutes = 0);
      return;
    }
    final parsed = int.tryParse(raw);
    if (parsed == null) return;
    setState(() => _minutes = parsed.clamp(_min, _max));
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;
    final hasOffset = _minutes != 0;
    final kb = MediaQuery.of(context).viewInsets.bottom;

    return GestureDetector(
      onTap: () => _focusNode.unfocus(),
      child: Container(
        margin: EdgeInsets.only(bottom: kb),
        decoration: const BoxDecoration(
          color: Color(0xFF0D0D12),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            const SizedBox(height: 20),

            // Title row
            Row(
              children: [
                Text(
                  widget.prayer,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Adjustment',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
                ),
                const Spacer(),
                // Reset chip
                if (hasOffset)
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _focusNode.unfocus();
                      _update(0);
                      _ctrl.clear();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.white.withValues(alpha: 0.04),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: Text(
                        'Reset',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Preview card ────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: hasOffset
                    ? accent.withValues(alpha: 0.06)
                    : Colors.white.withValues(alpha: 0.02),
                border: Border.all(
                  color: hasOffset
                      ? accent.withValues(alpha: 0.18)
                      : Colors.white.withValues(alpha: 0.06),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CALCULATED TIME',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                          color: Colors.white.withValues(alpha: 0.25),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _previewApiTime(),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w300,
                          color: Colors.white.withValues(alpha: 0.35),
                        ),
                      ),
                    ],
                  ),
                  if (hasOffset)
                    Icon(Icons.arrow_forward_rounded,
                        size: 16,
                        color: accent.withValues(alpha: 0.5)),
                  if (hasOffset)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'ALARM FIRES AT',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                            color: accent.withValues(alpha: 0.5),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _previewTime(),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: accent,
                          ),
                        ),
                      ],
                    ),
                  if (!hasOffset)
                    Text(
                      'No offset',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // ── Slider ──────────────────────────────────────────────────
            Row(
              children: [
                Text(
                  '−60',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withValues(alpha: 0.25),
                  ),
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: hasOffset
                          ? accent.withValues(alpha: 0.7)
                          : Colors.white.withValues(alpha: 0.15),
                      inactiveTrackColor:
                          Colors.white.withValues(alpha: 0.06),
                      thumbColor: hasOffset ? accent : Colors.white,
                      overlayColor: accent.withValues(alpha: 0.12),
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 10),
                    ),
                    child: Slider(
                      value: _minutes.toDouble(),
                      min: _min.toDouble(),
                      max: _max.toDouble(),
                      divisions: _max - _min,
                      onChanged: (v) {
                        HapticFeedback.selectionClick();
                        _update(v.round());
                        _focusNode.unfocus();
                      },
                    ),
                  ),
                ),
                Text(
                  '+60',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withValues(alpha: 0.25),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Text input ──────────────────────────────────────────────
            Row(
              children: [
                // Minus quick buttons
                _AdjBtn(
                  label: '−5',
                  accent: accent,
                  onTap: () => _update(_minutes - 5),
                ),
                const SizedBox(width: 6),
                _AdjBtn(
                  label: '−1',
                  accent: accent,
                  onTap: () => _update(_minutes - 1),
                ),
                const SizedBox(width: 10),

                // Free-type field
                Expanded(
                  child: Container(
                    height: 46,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.white.withValues(alpha: 0.04),
                      border: Border.all(
                        color: _focusNode.hasFocus
                            ? accent.withValues(alpha: 0.4)
                            : Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Center(
                      child: TextField(
                        controller: _ctrl,
                        focusNode: _focusNode,
                        keyboardType: const TextInputType.numberWithOptions(
                            signed: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^-?\d{0,3}')),
                        ],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: hasOffset
                              ? accent
                              : Colors.white.withValues(alpha: 0.6),
                          fontFeatures: const [
                            FontFeature.tabularFigures()
                          ],
                        ),
                        decoration: InputDecoration(
                          hintText: '0',
                          hintStyle: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w300,
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                          suffix: Text(
                            ' min',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.25),
                            ),
                          ),
                        ),
                        onChanged: _onTextChanged,
                        onSubmitted: (_) => _focusNode.unfocus(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Plus quick buttons
                _AdjBtn(
                  label: '+1',
                  accent: accent,
                  onTap: () => _update(_minutes + 1),
                ),
                const SizedBox(width: 6),
                _AdjBtn(
                  label: '+5',
                  accent: accent,
                  onTap: () => _update(_minutes + 5),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Range hint
            Center(
              child: Text(
                'Range −60 to +60 minutes',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white.withValues(alpha: 0.18),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── Save button ─────────────────────────────────────────────
            GestureDetector(
              onTap: () {
                _focusNode.unfocus();
                widget.onSave(_minutes);
                Navigator.pop(context);
              },
              child: Container(
                width: double.infinity,
                height: 50,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: accent.withValues(alpha: 0.15),
                  border: Border.all(
                      color: accent.withValues(alpha: 0.3)),
                ),
                child: Center(
                  child: Text(
                    _minutes == 0
                        ? 'Keep at exact time'
                        : _minutes > 0
                            ? 'Set +$_minutes min after prayer'
                            : 'Set ${_minutes.abs()} min before prayer',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: accent,
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

  String _previewApiTime() {
    final parts = widget.apiTime.split(':');
    if (parts.length != 2) return widget.apiTime;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    final period = h < 12 ? 'AM' : 'PM';
    final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '${h12.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} $period';
  }
}

/// Small quick-adjust button inside _AdjustmentSheet
class _AdjBtn extends StatelessWidget {
  final String label;
  final Color accent;
  final VoidCallback onTap;

  const _AdjBtn({
    required this.label,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        width: 40,
        height: 46,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: Colors.white.withValues(alpha: 0.04),
          border: Border.all(
              color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.55),
            ),
          ),
        ),
      ),
    );
  }
}

/// Fasting time chip with alarm action
class _FastingTimeChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String time;
  final Color accent;
  final VoidCallback onSetAlarm;

  const _FastingTimeChip({
    required this.icon,
    required this.label,
    required this.time,
    required this.accent,
    required this.onSetAlarm,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: accent.withValues(alpha: 0.04),
        border: Border.all(
            color: accent.withValues(alpha: 0.10)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(
              icon,
              size: 16,
              color: accent.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: Colors.white
                        .withValues(alpha: 0.3),
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  time,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: accent.withValues(
                        alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              onSetAlarm();
            },
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    accent.withValues(alpha: 0.08),
              ),
              child: Icon(Icons.alarm_add_rounded,
                  size: 14,
                  color: accent.withValues(
                      alpha: 0.6)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SoundOption extends StatelessWidget {
  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;
  final VoidCallback? onPreview;
  final bool isPreviewing;

  const _SoundOption({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
    this.onPreview,
    this.isPreviewing = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: selected
              ? accent.withValues(alpha: 0.05)
              : Colors.transparent,
          border: Border.all(
            color: selected
                ? accent.withValues(alpha: 0.12)
                : Colors.white
                    .withValues(alpha: 0.03),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? accent
                      : Colors.white
                          .withValues(alpha: 0.12),
                  width: 2,
                ),
                color: selected
                    ? accent.withValues(alpha: 0.15)
                    : Colors.transparent,
              ),
              child: selected
                  ? Center(
                      child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: accent)))
                  : null,
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(
                    alpha: selected ? 0.8 : 0.35),
              ),
            ),
            const Spacer(),
            if (onPreview != null)
              GestureDetector(
                onTap: onPreview,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white
                        .withValues(alpha: 0.03),
                  ),
                  child: Icon(
                    isPreviewing
                        ? Icons.stop_rounded
                        : Icons.play_arrow_rounded,
                    size: 13,
                    color: Colors.white
                        .withValues(alpha: 0.3),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MiniToggle extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final Color accent;
  final ValueChanged<bool> onChanged;

  const _MiniToggle({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onChanged(!value);
      },
      child: Row(
        children: [
          Icon(icon,
              size: 13,
              color: Colors.white
                  .withValues(alpha: 0.2)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.white
                        .withValues(alpha: 0.35))),
          ),
          Container(
            width: 30,
            height: 16,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: value
                  ? accent.withValues(alpha: 0.2)
                  : Colors.white
                      .withValues(alpha: 0.04),
            ),
            child: AnimatedAlign(
              duration:
                  const Duration(milliseconds: 180),
              alignment: value
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: Container(
                width: 12,
                height: 12,
                margin: const EdgeInsets.symmetric(
                    horizontal: 2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: value
                      ? accent
                      : Colors.white
                          .withValues(alpha: 0.2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TogglePill extends StatelessWidget {
  final bool value;
  final Color accent;

  const _TogglePill(
      {required this.value, required this.accent});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: 44,
      height: 26,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13),
        color: value
            ? accent.withValues(alpha: 0.85)
            : Colors.white.withValues(alpha: 0.08),
      ),
      child: Stack(
        children: [
          AnimatedPositioned(
            duration:
                const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            left: value ? 20 : 3,
            top: 3,
            child: Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
