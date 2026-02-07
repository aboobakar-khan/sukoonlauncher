# 🍅⚙️ Pomodoro Customization & Navigation Improvements

## Overview

This update adds two major improvements to the minimalist app:

1. **Customizable Pomodoro Durations** - Adjust work and break session lengths to match your workflow
2. **Right Edge Swipe** - Navigate from Quran/Hadith/Dua to Dashboard with an edge swipe gesture

---

## 1. Customizable Pomodoro Timer ⏱️

### What's New

You can now customize both work and break durations for your Pomodoro sessions. No longer limited to the default 25/5 minute split!

### Features

#### Settings Screen
- **Work Duration** - Adjust from 1 to 120 minutes (default: 25 min)
- **Break Duration** - Adjust from 1 to 120 minutes (default: 10 min)
- **Visual Slider** - Smooth slider with live preview
- **Quick Adjustments** - ±1 and ±5 minute buttons
- **Large Display** - See your current duration in ultra-large numbers

#### Preset Configurations
- **Classic** - 25 min work / 5 min break (original Pomodoro)
- **Extended** - 50 min work / 10 min break (deep work)
- **Short** - 15 min work / 3 min break (quick sprints)
- **Deep Work** - 90 min work / 20 min break (maximum focus)

### How to Access

1. **From Full-Screen Timer**:
   - Start or expand the Pomodoro timer to full-screen
   - Tap the **settings icon** (⚙️) in the top-right corner

2. **Quick Access**:
   - Tap on the Pomodoro widget in the dashboard
   - Expand to full-screen
   - Tap settings icon

### Usage

#### Custom Duration Setup

1. Open Pomodoro Settings
2. Scroll to the duration you want to change
3. Use the slider or quick adjust buttons
4. See the large number update in real-time
5. Changes apply immediately to the timer

#### Apply a Preset

1. Open Pomodoro Settings
2. Scroll to the "PRESETS" section
3. Tap any preset button
4. A confirmation message will appear
5. Return to the timer - new durations are active

### Visual Design

```
┌─────────────────────────────────┐
│ ← Pomodoro Settings             │
│                                 │
│  ┌───────────────────────────┐  │
│  │ 🎯 Work Duration          │  │
│  │ Focus session length      │  │
│  │                           │  │
│  │          25               │  │  ← Large display
│  │        MINUTES            │  │
│  │                           │  │
│  │  ━━━━━━●━━━━━━━━━━━━━    │  │  ← Slider
│  │                           │  │
│  │  [-5] [-1]  [+1] [+5]     │  │  ← Quick adjust
│  └───────────────────────────┘  │
│                                 │
│  ┌───────────────────────────┐  │
│  │ ☕ Break Duration         │  │
│  │ Rest session length       │  │
│  │          10               │  │
│  │        MINUTES            │  │
│  │  ━━━━━━━━━━●━━━━━━━━━    │  │
│  │  [-5] [-1]  [+1] [+5]     │  │
│  └───────────────────────────┘  │
│                                 │
│  PRESETS                        │
│  ┌─────────┐ ┌─────────┐       │
│  │ Classic │ │Extended │       │
│  │ 25m/5m  │ │ 50m/10m │       │
│  └─────────┘ └─────────┘       │
│  ┌─────────┐ ┌─────────┐       │
│  │ Short   │ │Deep Work│       │
│  │ 15m/3m  │ │ 90m/20m │       │
│  └─────────┘ └─────────┘       │
│                                 │
│  ℹ️ Pomodoro Technique          │
│  Work in focused intervals...   │
└─────────────────────────────────┘
```

### Technical Details

**File**: `lib/screens/pomodoro_settings_screen.dart`

**Features**:
- Ultra-light minimalist design
- Color-coded cards (red for work, green for break)
- Smooth slider with 1-minute precision
- Haptic feedback on all interactions
- Real-time duration updates
- Preset quick-apply system

**State Management**:
- Uses existing `pomodoroProvider`
- Calls `setWorkDuration(minutes)` and `setBreakDuration(minutes)`
- Changes persist across app sessions
- Timer resets to new duration when not running

---

## 2. Right Edge Swipe Navigation 👉

### What's New

You can now swipe from the right edge of the screen to navigate from Quran, Hadith, or Dua pages directly to the Widget Dashboard!

### The Problem (Before)

❌ When viewing Quran/Hadith/Dua, you could only:
- Swipe left from the home screen to access Islamic Hub
- Had to navigate back to home, then swipe right to reach dashboard
- No quick way to access widgets while studying

### The Solution (Now)

✅ **Right Edge Swipe Gesture**:
- Swipe left from the **right edge** of the screen
- Instantly navigate from Islamic Hub → Widget Dashboard
- Works on all three tabs: Quran, Hadith, Dua
- Consistent with the app's existing swipe navigation

### How It Works

```
┌─────────────────────────────────┐
│  QURAN                          │ ← Islamic Hub (Index 0)
│                                 │
│  [Surah list content]           │
│                                 │
│                              👆 │ ← Swipe left from here
│                              │  │
│                          50px   │ ← Detection zone
│                         zone    │
└─────────────────────────────────┘

       ⬇️ Swipe detected! ⬇️

┌─────────────────────────────────┐
│  ⏱️ POMODORO                    │ ← Widget Dashboard (Index 1)
│  [Timer widget]                 │
│                                 │
│  📋 TODO LIST                   │
│  [Task list]                    │
└─────────────────────────────────┘
```

### Usage

1. Open any Islamic content (Quran, Hadith, or Dua)
2. Place your finger on the **right edge** of the screen
3. Swipe **left** quickly (velocity > 300px/s)
4. You'll navigate instantly to the Dashboard

### Visual Feedback

- **Haptic feedback** - Light vibration when swipe is detected
- **Smooth animation** - Eased curve transition (450ms)
- **Transparent zone** - 50px wide detection area on right edge

### Navigation Flow

```
App Pages Layout:
[Islamic Hub] ← [Dashboard] ← [HOME] → [App List]
     0              1            2          3

Right Edge Swipe:
Islamic Hub (0) --swipe-left--> Dashboard (1)
```

### Technical Implementation

**Wrapper Component**: `lib/widgets/edge_swipe_wrapper.dart`

```dart
EdgeSwipeWrapper(
  onSwipeRight: () => navigateToDashboard(),
  child: SurahListScreen(),
)
```

**Features**:
- 50px wide detection zone on right edge
- Minimum velocity: 300px/s (fast swipe required)
- Transparent overlay (no visual interference)
- HitTestBehavior.translucent (doesn't block scrolling)
- Callback-based navigation (flexible integration)

**Modified Files**:
1. `lib/screens/launcher_shell.dart` - Added EdgeSwipeWrapper to each tab
2. `lib/widgets/edge_swipe_wrapper.dart` - New gesture detection component

---

## Combined Use Cases

### Scenario 1: Study + Focus Timer

1. Start Pomodoro timer (custom 50-minute session)
2. Swipe left to Islamic Hub
3. Open Quran and start reading
4. Check timer via mini indicator on home screen
5. Swipe right (edge) to dashboard when timer expires

### Scenario 2: Quick Adjustments

1. Open Pomodoro full-screen
2. Tap settings icon
3. Apply "Deep Work" preset (90 min)
4. Close settings
5. Start timer for extended focus session

### Scenario 3: Seamless Navigation

1. Reading hadith in Islamic Hub
2. Need to check tasks
3. Edge swipe right → Dashboard
4. View todo list
5. Swipe left to return to hadiths

---

## Files Created/Modified

### New Files ✨

1. **`lib/screens/pomodoro_settings_screen.dart`** (420 lines)
   - Complete settings interface
   - Sliders, presets, quick adjust buttons
   - Color-coded duration cards

2. **`lib/widgets/edge_swipe_wrapper.dart`** (48 lines)
   - Reusable gesture detection wrapper
   - Right edge swipe handler
   - Transparent overlay component

### Modified Files 🔧

1. **`lib/screens/pomodoro_full_screen.dart`**
   - Added settings button import
   - Updated header with settings icon
   - Navigation to settings screen

2. **`lib/screens/launcher_shell.dart`**
   - Added EdgeSwipeWrapper import
   - Pass PageController to IslamicHubScreen
   - Wrapped each tab content with EdgeSwipeWrapper
   - Implemented navigateToDashboard callback

---

## Design Principles

### Minimalist Aesthetic
- **Black backgrounds** - Pure focus, no distractions
- **Ultra-light typography** - Weight 200-300 for elegance
- **Color coding** - Red (work), Green (break), Blue (info)
- **Generous spacing** - Breathing room between elements

### User Experience
- **Immediate feedback** - Haptic responses on all interactions
- **Large touch targets** - 50px edge zone, 40px+ buttons
- **Visual hierarchy** - 64pt numbers, 16pt titles, 11pt labels
- **Smooth animations** - 450ms eased curves

### Accessibility
- **High contrast** - White text on black backgrounds
- **Tabular figures** - Monospaced numbers for alignment
- **Clear labels** - Descriptive text for all actions
- **Haptic feedback** - Non-visual interaction confirmation

---

## Tips & Best Practices

### Pomodoro Customization

1. **Start with Presets** - Try the built-in presets before creating custom durations
2. **Match Your Workflow** - Short sprints for emails, deep work for coding/studying
3. **Gradual Adjustments** - Use ±1 buttons for fine-tuning
4. **Reset Carefully** - Changing duration while timer is running resets progress

### Edge Swipe Navigation

1. **Fast Swipes Work Best** - Quick flick from right edge
2. **Edge Only** - Must start from the rightmost 50px
3. **Vertical Scrolling** - Normal scrolling still works, swipe is separate
4. **Consistent Direction** - Always swipe LEFT from right edge (→ ←)

### Combined Features

1. **Custom Study Sessions** - Set 45-minute work sessions for Quran study
2. **Quick Checks** - Edge swipe to dashboard to view timer progress
3. **Preset Switching** - Change between Classic and Deep Work throughout the day
4. **Workflow Integration** - Combine with app filtering and focus mode

---

## Troubleshooting

### Pomodoro Settings

**Q: Changes don't apply to running timer**
- A: Stop the timer, adjust settings, then start fresh

**Q: Can't find settings icon**
- A: Must open full-screen timer first (tap widget or mini indicator)

**Q: Slider too sensitive**
- A: Use quick adjust buttons (±1, ±5) for precise control

### Edge Swipe

**Q: Swipe not working**
- A: Ensure you're starting from the rightmost 50px and swiping LEFT quickly

**Q: Accidentally triggering while scrolling**
- A: Swipe requires 300px/s velocity - normal scrolling won't trigger it

**Q: Works on Quran but not Hadith**
- A: Should work on all three tabs equally - check finger position

---

## Future Enhancements

### Pomodoro Settings (Potential)

- [ ] Long break duration (after 4 work sessions)
- [ ] Auto-start next session option
- [ ] Session counter and daily statistics
- [ ] Custom sound selection for completion
- [ ] Notification customization

### Navigation (Potential)

- [ ] Left edge swipe from Dashboard → Islamic Hub
- [ ] Gesture hints/tutorial on first use
- [ ] Visual swipe progress indicator
- [ ] Customizable swipe sensitivity

---

## Summary

✅ **Pomodoro Customization Complete**
- Fully functional settings screen
- 4 built-in presets
- 1-120 minute range for both sessions
- Persistent state across app sessions

✅ **Edge Swipe Navigation Complete**
- Works on Quran, Hadith, and Dua screens
- Smooth 450ms animation
- 50px detection zone
- Haptic feedback confirmation

Both features integrate seamlessly with the existing minimalist design and enhance productivity without adding visual clutter! 🎉
