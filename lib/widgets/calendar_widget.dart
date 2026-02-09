import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:hijri/hijri_calendar.dart';
import '../providers/prayer_provider.dart';
import '../models/prayer_record.dart';

// ─── Design tokens (Camel brand — disciplined palette) ─────────────────────
const Color _sandGold = Color(0xFFC2A366);
const Color _oasisGreen = Color(0xFF7BAE6E);

/// ─── Islamic Occasions ───────────────────────────────────────────────────────
const Map<String, Map<String, String>> _islamicOccasions = {
  '1-1': {'name': 'Islamic New Year', 'emoji': '🌙'},
  '1-10': {'name': 'Day of Ashura', 'emoji': '🤲'},
  '3-12': {'name': 'Mawlid al-Nabi ﷺ', 'emoji': '🕌'},
  '7-27': {'name': 'Isra & Mi\'raj', 'emoji': '✨'},
  '8-15': {'name': 'Shab-e-Barat', 'emoji': '🌕'},
  '9-1': {'name': 'Ramadan Begins', 'emoji': '🌙'},
  '9-27': {'name': 'Laylat al-Qadr', 'emoji': '⭐'},
  '10-1': {'name': 'Eid al-Fitr', 'emoji': '🎉'},
  '12-8': {'name': 'Day of Tarwiyah', 'emoji': '🕋'},
  '12-9': {'name': 'Day of Arafah', 'emoji': '🤲'},
  '12-10': {'name': 'Eid al-Adha', 'emoji': '🐪'},
};

/// Sunnah fasting days
bool _isSunnahFastDay(HijriCalendar hijri, DateTime gregorian) {
  if (gregorian.weekday == DateTime.monday ||
      gregorian.weekday == DateTime.thursday) return true;
  if (hijri.hDay == 13 || hijri.hDay == 14 || hijri.hDay == 15) return true;
  if (hijri.hMonth == 12 && hijri.hDay == 9) return true;
  if (hijri.hMonth == 1 && (hijri.hDay == 9 || hijri.hDay == 10)) return true;
  return false;
}

/// Calendar widget for dashboard — Minimalist, meaningful, Islamic
class CalendarWidget extends ConsumerStatefulWidget {
  final VoidCallback? onExpand;
  const CalendarWidget({super.key, this.onExpand});

  @override
  ConsumerState<CalendarWidget> createState() => _CalendarWidgetState();
}

class _CalendarWidgetState extends ConsumerState<CalendarWidget> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  bool _isWeekView = true;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final prayerRecordsMap = ref.watch(prayerRecordsMapProvider);

    final hijriSelected = HijriCalendar.fromDate(_selectedDay ?? DateTime.now());
    final hijriFocused = HijriCalendar.fromDate(_focusedDay);

    final occasionKey = '${hijriSelected.hMonth}-${hijriSelected.hDay}';
    final occasion = _islamicOccasions[occasionKey];

    final selectedDateKey = _selectedDay != null
        ? '${_selectedDay!.year}-${_selectedDay!.month.toString().padLeft(2, '0')}-${_selectedDay!.day.toString().padLeft(2, '0')}'
        : '';
    final prayerRecord = prayerRecordsMap[selectedDateKey];
    final prayerCount = prayerRecord?.completedCount ?? 0;

    final isJummah = (_selectedDay ?? DateTime.now()).weekday == DateTime.friday;
    final isSunnahFast =
        _isSunnahFastDay(hijriSelected, _selectedDay ?? DateTime.now());

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(hijriFocused),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TableCalendar(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: (selectedDay, focusedDay) {
                HapticFeedback.selectionClick();
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              },
              onPageChanged: (focusedDay) {
                setState(() => _focusedDay = focusedDay);
              },
              calendarFormat: _isWeekView ? CalendarFormat.week : CalendarFormat.month,
              availableCalendarFormats: const {
                CalendarFormat.month: 'Month',
                CalendarFormat.week: 'Week',
              },
              startingDayOfWeek: StartingDayOfWeek.monday,
              headerVisible: false,
              daysOfWeekHeight: 28,
              daysOfWeekStyle: DaysOfWeekStyle(
                dowTextFormatter: (date, locale) =>
                    DateFormat.E(locale).format(date)[0],
                weekdayStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.35),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
                weekendStyle: TextStyle(
                  color: _sandGold.withValues(alpha: 0.4),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              rowHeight: 44,
              calendarStyle: const CalendarStyle(outsideDaysVisible: false),
              calendarBuilders: CalendarBuilders(
                defaultBuilder: (ctx, day, focusedDay) =>
                    _buildDayCell(day, false, false, prayerRecordsMap),
                todayBuilder: (ctx, day, focusedDay) =>
                    _buildDayCell(day, true, false, prayerRecordsMap),
                selectedBuilder: (ctx, day, focusedDay) =>
                    _buildDayCell(day, isSameDay(day, DateTime.now()), true,
                        prayerRecordsMap),
              ),
            ),
          ),
          const SizedBox(height: 4),
          _buildSelectedDayPanel(
            hijriSelected, prayerCount, isJummah, isSunnahFast,
            occasion,
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  // ─── Custom Header ────────────────────────────────────────────────────────
  Widget _buildHeader(HijriCalendar hijri) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 10, 2),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat.yMMMM().format(_focusedDay),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  '${hijri.longMonthName} ${hijri.hYear}',
                  style: TextStyle(
                    color: _sandGold.withValues(alpha: 0.5),
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          // Today button
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() {
                _focusedDay = DateTime.now();
                _selectedDay = DateTime.now();
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                'Today',
                style: TextStyle(
                  color: _sandGold.withValues(alpha: 0.6),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          // Toggle week/month
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _isWeekView = !_isWeekView);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Icon(
                _isWeekView ? Icons.calendar_month_rounded : Icons.view_week_rounded,
                color: Colors.white.withValues(alpha: 0.3),
                size: 16,
              ),
            ),
          ),
          const SizedBox(width: 6),
          _buildNavBtn(Icons.chevron_left, () {
            setState(() {
              _focusedDay = _isWeekView
                  ? _focusedDay.subtract(const Duration(days: 7))
                  : DateTime(_focusedDay.year, _focusedDay.month - 1, 1);
            });
          }),
          const SizedBox(width: 2),
          _buildNavBtn(Icons.chevron_right, () {
            setState(() {
              _focusedDay = _isWeekView
                  ? _focusedDay.add(const Duration(days: 7))
                  : DateTime(_focusedDay.year, _focusedDay.month + 1, 1);
            });
          }),
        ],
      ),
    );
  }

  Widget _buildNavBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, color: Colors.white.withValues(alpha: 0.4), size: 18),
      ),
    );
  }

  // ─── Custom Day Cell (prayer activity ring + occasion dot) ────────────────
  Widget _buildDayCell(
    DateTime day,
    bool isToday,
    bool isSelected,
    Map<String, PrayerRecord> prayerRecordsMap,
  ) {
    final dateKey =
        '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    final record = prayerRecordsMap[dateKey];
    final prayerCount = record?.completedCount ?? 0;
    final isFriday = day.weekday == DateTime.friday;

    final hijri = HijriCalendar.fromDate(day);
    final oKey = '${hijri.hMonth}-${hijri.hDay}';
    final hasOccasion = _islamicOccasions.containsKey(oKey);

    // Prayer text color based on completion
    Color prayerTextColor;
    if (prayerCount == 5) {
      prayerTextColor = _oasisGreen;
    } else if (prayerCount >= 3) {
      prayerTextColor = _sandGold;
    } else if (prayerCount >= 1) {
      prayerTextColor = _sandGold.withValues(alpha: 0.7);
    } else {
      prayerTextColor = Colors.white;
    }

    return Container(
      margin: const EdgeInsets.all(2),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Day circle background
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected
                  ? _sandGold.withValues(alpha: 0.25)
                  : isToday
                      ? _sandGold.withValues(alpha: 0.1)
                      : hasOccasion
                          ? _sandGold.withValues(alpha: 0.08)
                          : Colors.transparent,
              border: isToday && !isSelected
                  ? Border.all(color: _sandGold.withValues(alpha: 0.5), width: 1.5)
                  : null,
            ),
          ),
          // Day number
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${day.day}',
                style: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : isToday
                          ? _sandGold
                          : hasOccasion
                              ? _sandGold.withValues(alpha: 0.9)
                              : isFriday
                                  ? _sandGold.withValues(alpha: 0.7)
                                  : Colors.white.withValues(alpha: 0.65),
                  fontSize: 12.5,
                  fontWeight:
                      isToday || isSelected || hasOccasion ? FontWeight.w600 : FontWeight.w400,
                  height: 1.1,
                ),
              ),
              // Prayer count text (e.g. "2/5", "5/5")
              if (prayerCount > 0)
                Text(
                  '$prayerCount/5',
                  style: TextStyle(
                    color: prayerTextColor.withValues(alpha: 0.85),
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                    height: 1.0,
                  ),
                ),
            ],
          ),
          // Islamic occasion marker (top-right corner)
          if (hasOccasion)
            Positioned(
              top: 1,
              right: 2,
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: _sandGold.withValues(alpha: 0.7),
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─── Selected Day Info Panel ──────────────────────────────────────────────
  Widget _buildSelectedDayPanel(
    HijriCalendar hijri,
    int prayerCount,
    bool isJummah,
    bool isSunnahFast,
    Map<String, String>? occasion,
  ) {
    final isToday = isSameDay(_selectedDay, DateTime.now());
    final isPast = _selectedDay != null &&
        _selectedDay!.isBefore(
            DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: occasion != null
                ? _sandGold.withValues(alpha: 0.15)
                : Colors.white.withValues(alpha: 0.04),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date row
            Row(
              children: [
                Expanded(
                  child: Text(
                    _selectedDay != null
                        ? (isToday ? 'Today' : DateFormat('EEE, d MMM').format(_selectedDay!))
                        : 'Today',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                // Hijri
                Text(
                  '${hijri.hDay} ${hijri.shortMonthName} ${hijri.hYear}',
                  style: TextStyle(
                    color: _sandGold.withValues(alpha: 0.55),
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Activity chips row
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (prayerCount > 0 || isToday || isPast)
                  _buildChip(
                    Icons.mosque_rounded,
                    '$prayerCount/5',
                    prayerCount == 5
                        ? _oasisGreen
                        : _sandGold,
                    filled: prayerCount == 5,
                  ),
                if (isJummah)
                  _buildChip(Icons.auto_awesome, 'Jummah', _sandGold),
                if (isSunnahFast)
                  _buildChip(Icons.restaurant_rounded, 'Sunnah Fast', _sandGold),
              ],
            ),

            // Islamic occasion banner
            if (occasion != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    _sandGold.withValues(alpha: 0.12),
                    _sandGold.withValues(alpha: 0.06),
                  ]),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _sandGold.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Text(occasion['emoji'] ?? '🌙', style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            occasion['name'] ?? '',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Islamic Occasion',
                            style: TextStyle(
                              color: _sandGold.withValues(alpha: 0.6),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

          ],
        ),
      ),
    );
  }

  Widget _buildChip(IconData icon, String label, Color color, {bool filled = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: filled ? 0.2 : 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: filled ? 0.4 : 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color.withValues(alpha: 0.8), size: 12),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color.withValues(alpha: 0.9),
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
