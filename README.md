# Workout Timer

A Mac interval timer for structured workouts: sets of named rounds, per-set work/rest times and
repeat counts, a big colour-coded countdown (red = work, green = rest) and audio cues
(get-ready chime + spoken exercise 10 s before work, 3 countdown beeps, long beep when work ends).

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
