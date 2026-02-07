# 🍅 Pomodoro Timer - Visual Guide

## Home Screen - Mini Indicator

```
┌─────────────────────────────────┐
│                                 │
│           14:23                 │  ← Clock
│        Wednesday                │
│                                 │
│     ┌─────────────┐             │
│     │  ◯  24:30   │             │  ← Mini Pomodoro Indicator
│     │  🔴 FOCUS • │             │     (appears when running)
│     └─────────────┘             │
│                                 │
│                                 │
│                                 │
│                                 │
│     FAVORITES                   │
│     Calendar                    │
│     Notes                       │
│     Email                       │
│                                 │
└─────────────────────────────────┘
```

### Mini Indicator Features:
- **Circular progress ring** (32px) - fills as time progresses
- **Live countdown** - updates every second
- **Session label** - "FOCUS" (red) or "BREAK" (green)
- **Running dot** (•) - appears when actively counting
- **Glowing border** - red/green based on session type
- **Tap to expand** - opens full-screen view

---

## Full-Screen Pomodoro View

```
┌─────────────────────────────────┐
│ ✕                          ⏱   │  ← Close & Timer icon
│                                 │
│                                 │
│       FOCUS TIME                │  ← Session type
│                                 │
│                                 │
│          ◯◯◯◯◯                  │
│        ◯       ◯                │
│       ◯         ◯               │
│      ◯           ◯              │  ← Large circular
│      ◯   24:30   ◯              │     progress timer
│      ◯           ◯              │     (280px diameter)
│       ◯         ◯               │
│        ◯       ◯                │
│          ◯◯◯◯◯                  │
│      IN PROGRESS                │
│                                 │
│                                 │
│    ⟲        ▶️        ⏭       │  ← Controls
│  Reset   Play/Pause   Skip     │
│                                 │
│                                 │
│  Stay focused.                  │  ← Motivational tip
│  Eliminate distractions.        │
│                                 │
└─────────────────────────────────┘
```

### Full-Screen Features:
- **Immersive black background** - pure focus
- **Pulsing ambient glow** - subtle breathing effect
- **72pt time display** - ultra-readable
- **Circular progress ring** - visual countdown
- **Session colors**:
  - 🔴 Red for work sessions
  - 🟢 Green for break sessions
- **Three control buttons**:
  - Reset (⟲) - start over
  - Play/Pause (▶️/⏸) - main control
  - Skip (⏭) - jump to next session

---

## Completion Celebration

```
┌─────────────────────────────────┐
│                                 │
│                                 │
│                                 │
│                                 │
│                                 │
│           ✨                    │  ← Animated icon
│          ✨✨                   │     (elastic bounce)
│         ✨  ✨                  │
│          ✨✨                   │
│           ✨                    │
│                                 │
│                                 │
│     🎉 Work Complete!           │  ← Message
│     You earned a break          │
│                                 │
│                                 │
│                                 │
│     (Auto-dismisses in 2s)      │
│                                 │
│                                 │
└─────────────────────────────────┘
```

### Celebration Features:
- **Full-screen overlay** - dark translucent
- **Animated icon** - scales from 0 to 1 with elastic curve
- **Session-specific icons**:
  - ✨ Self-improvement icon (work complete)
  - 🎉 Trophy icon (break complete)
- **Motivational messages**:
  - Work: "✨ Work Complete! You earned a break"
  - Break: "🎉 Break Complete! Time to focus again"
- **Sound plays** - gentle bell/chime (if file added)
- **Double haptic** - vibration feedback
- **Auto-dismiss** - fades out after 2 seconds

---

## Widget Dashboard - Pomodoro Widget

```
┌─────────────────────────────────┐
│  ⏱ POMODORO         WORK  🖵    │  ← Header with expand icon
│                                 │
│           ◯                     │
│          ◯ ◯                    │  ← Mini circular
│         ◯ ⏱ ◯                   │     progress (100px)
│          ◯ ◯                    │
│           ◯                     │
│                                 │
│          24:30                  │  ← Large time display
│     TAP FOR FULL SCREEN         │  ← Hint
│                                 │
│    ⟲       ▶️       ⏭          │  ← Controls
│                                 │
└─────────────────────────────────┘
```

### Widget Features:
- **Shows mini progress** - 100px circular indicator when running
- **Large time** - 48pt display
- **Tap hint** - "TAP FOR FULL SCREEN" or "TAP TO START"
- **Animated border** - glows when running (red/green)
- **Session badge** - "WORK" or "BREAK" in header
- **Expand icon** - indicates tap-to-fullscreen

---

## Session Flow Diagram

```
  START
    │
    ▼
┌─────────┐
│  WORK   │  25 minutes
│ (Focus) │  Red theme
│    🎯   │  "Stay focused"
└─────────┘
    │
    ▼ (Complete!)
   🔔🎉
    │
    ▼
┌─────────┐
│  BREAK  │  10 minutes  
│ (Rest)  │  Green theme
│    🌿   │  "Relax your mind"
└─────────┘
    │
    ▼ (Complete!)
   🔔🎉
    │
    ▼
(Cycle repeats)
```

---

## Color System

### Work Session (Focus)
- **Primary**: `#FF0000` (Red)
- **Border**: Red with 40% opacity
- **Background glow**: Red with 10% opacity
- **Message**: "FOCUS TIME"
- **Icon**: 🎯
- **Tip**: "Stay focused. Eliminate distractions."

### Break Session (Rest)
- **Primary**: `#00FF00` (Green)
- **Border**: Green with 40% opacity
- **Background glow**: Green with 10% opacity
- **Message**: "BREAK TIME"
- **Icon**: 🌿
- **Tip**: "Take a break. Relax your mind."

### Neutral Elements
- **Background**: `#000000` (Black)
- **Time text**: White with 95% opacity
- **Labels**: White with 40% opacity
- **Controls**: White with 30% opacity (inactive)

---

## Animations

### 1. Pulse Animation (Background)
```
Duration: 1500ms
Repeat: Infinite
Effect: Breathing glow
Range: 0.0 → 1.0 → 0.0
```

### 2. Progress Animation (Ring)
```
Duration: 300ms
Curve: Linear
Effect: Smooth fill
Updates: Every second
```

### 3. Celebration Animation (Icon)
```
Duration: 800ms
Curve: Elastic out
Effect: Bounce scale
Range: 0.0 → 1.0
```

### 4. Opacity Animation (Overlay)
```
Duration: 500ms
Curve: Ease in/out
Effect: Fade in/out
Range: 0.0 ↔ 1.0
```

---

## Sound & Haptics

### Completion Sound
```
Format: MP3/OGG
Duration: 2-5 seconds
Type: Meditation bell / Zen chime
Volume: Soft and calming
Path: assets/sounds/pomodoro_complete.mp3
```

### Haptic Feedback
```
On Start:    Medium Impact
On Pause:    Medium Impact  
On Reset:    Medium Impact
On Skip:     Medium Impact
On Complete: Heavy Impact × 2 (100ms apart)
On Tap:      Light Impact
```

---

## Screen Positions

### Home Screen Layout
```
Top to Bottom:
- 20px: Top padding
- 50px: Offline indicator
- 80px: Clock display
- 180px: 👉 Mini Pomodoro indicator
- Center: (Empty space)
- Bottom-90px: Favorite apps list
- Bottom-16px: Quick action buttons
```

### Z-Index Layers
```
1. Background (wallpaper)
2. Main content (clock, favorites)
3. Mini indicator (floating)
4. Quick actions (phone, camera)
```

---

## Responsive Behavior

### When Timer is Inactive
- Mini indicator: Hidden ❌
- Widget border: Normal white
- Widget text: "TAP TO START"

### When Timer is Running
- Mini indicator: Visible ✅
- Widget border: Glowing (red/green)
- Widget text: "TAP FOR FULL SCREEN"
- Progress ring: Animating
- Running dot: Visible

### When Timer is Paused
- Mini indicator: Visible ✅
- Widget border: Dimmed
- Widget text: "PAUSED"
- Progress ring: Static
- Running dot: Hidden

---

## User Interactions

### Tap Gestures
- **Mini indicator**: Opens full-screen
- **Widget**: Opens full-screen
- **Play button**: Starts/pauses timer
- **Reset button**: Resets to start
- **Skip button**: Jumps to next session
- **Close button**: Exits full-screen

### Haptic Responses
- **Light**: Tap, Close
- **Medium**: Start, Pause, Reset, Skip
- **Heavy**: Completion (×2)

---

## Typography Scale

```
Time Display:
- Full-screen: 72pt (ultra-large)
- Widget:      48pt (large)
- Mini:        16pt (compact)

Labels:
- Headers:     14pt (caps, wide spacing)
- Session:     12pt (caps, wide spacing)
- Tips:        13pt (regular)
- Hints:       10pt (caps, wide spacing)

Weight: 200 (ultra-light)
Spacing: 2-4px letter spacing
Feature: Tabular figures (monospace numbers)
```

---

This visual guide shows exactly how the Pomodoro timer looks and behaves in your minimalist app! 🍅✨
