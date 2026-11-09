# Workout Timer

I was looking for a simple subscription-free timer app for my workout routines and since I couldn't find one I decided to build one ;)

A Mac interval timer for structured workouts: sets of named rounds, per-set work/rest times and
repeat counts, a big colour-coded countdown (red = work, green = rest) and audio cues.

## Features

**Build your workouts**
- Workouts are made of **sets**; each set is a list of **rounds**, one named exercise per round
- Each set has its own **work time**, **rest time** and **repeat count**, so later sets can get harder
  (e.g. 30s/30s → 40s/20s → 45s/15s)
- Add, delete, reorder and duplicate workouts, sets and exercises
- Times accept `45` or `1:30`; invalid input is reverted, out-of-range values are clamped
- Total workout duration is calculated as you edit
- Auto-saves every change; a damaged save file is set aside, never overwritten

**Run them**
- Big countdown: **red** digits while working, **green** while resting, amber for the 10 s lead-in
- Shows the current **set**, **round** and **exercise**, plus the next exercise, repetition and time left
- Audio cues:
  - a chime and spoken "Get ready – *exercise*" 10 s before each work period
  - 3 beeps in the last 3 seconds before work starts
  - a long beep when work ends and rest begins
- Pause/resume, skip forward/back, stop, with keyboard shortcuts
- Keeps the display awake while a workout runs
- Accurate timing: driven by the clock, not by counting ticks, so it never drifts

**No strings attached**
- No subscription, no account, no ads, no tracking: your workouts stay on your Mac

## Build & run

```sh
scripts/build-app.sh          # builds build/WorkoutTimer.app
open build/WorkoutTimer.app   # or drag it into /Applications
swift run WorkoutTimer        # quick debug run
swift test                    # core logic tests
```

You can also open `Package.swift` in Xcode.

## Keys while the timer runs
Space pause/resume · ← previous · → next · Esc stop

## Data
Workouts are saved to `~/Library/Application Support/WorkoutTimer/workouts.json`.
If that file is ever unreadable it is renamed to `workouts.corrupt-<time>.json` rather than overwritten.

## Layout
- `Sources/WorkoutCore` — model, timeline, timer engine, cue schedule, persistence (no UI; reusable on iPhone)
- `Sources/WorkoutTimer` — SwiftUI Mac app
- `Tests/WorkoutCoreTests` — Swift Testing suite
