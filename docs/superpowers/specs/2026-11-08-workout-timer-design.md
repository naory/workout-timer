# Workout Timer — Design

## Intent
The user's current interval-timer app (iPhone + Mac) crashes when editing a timer and can't express the
workouts they actually do. Goal: a reliable, structured interval timer. Mac first; iPhone (with a lock-screen
Live Activity offering pause/resume) later, so the code should be shareable.

Success = build a structured workout quickly, edit it without ever losing data or crashing, and run it with
clear on-screen status and audio cues.

## Goals
1. **Workout structure** (user-defined):
   - **Round** = one exercise name. Gets its work/rest time from its set.
   - **Set** = an ordered list of rounds + a **repeat count** + a **work time** and **rest time** that apply to
     every round in the set.
   - **Workout** = ordered list of sets. Each set has its own times, so later sets can be harder
     (e.g. Set 1 30s/30s, Set 2 40s/20s, Set 3 45s/15s).
2. **Editor**: create, rename, duplicate, delete workouts; add/remove/reorder sets and rounds; edit names,
   times, repeat counts. Shows computed total workout duration.
3. **Timer screen** (user-specified) shows prominently: current **set number**, current **round number**,
   **exercise name**, and the **countdown seconds**. Countdown digits are **red during work** and **green
   during rest**. (Builder's call: get-ready digits amber; neutral dark background; small secondary line with
   set repetition, next exercise and total remaining.)
4. **Sounds**:
   - "Get ready" cue 10 seconds before every work period.
   - 3 short beeps at 3, 2, 1 seconds before every work period starts.
   - 1 long beep when a work period ends (start of rest).

## Non-goals (for now)
- iPhone app, Live Activity, sync, accounts, cloud, workout history/stats, music integration.

## Anti-goals
- Crashing or losing edits. Invalid input must be impossible or clamped, never fatal.
- Timer drift: time must come from a clock (elapsed since start minus paused time), not from counting ticks.

## Decided (by the user)
- Native app, Swift/SwiftUI, Mac first, iPhone later.
- Times are per set, not per round.
- Screen stays on during a workout.

## Builder's calls (Claude's, open to override)
- **Build**: Swift Package, buildable from the command line (Swift 6.4; user is installing Xcode, which can open
  `Package.swift` directly). A script bundles the executable into `WorkoutTimer.app`. For iPhone later, an
  Xcode multiplatform app target will depend on the local `WorkoutCore` package. Code split into a pure `WorkoutCore` library (model, timeline, engine,
  cue scheduling — fully unit-tested, platform-agnostic for later iOS reuse) and a SwiftUI `WorkoutTimerApp`.
- **Timeline model**: a workout is flattened into a list of segments
  `[getReady 10s, work, rest, work, rest, …, work]`. The engine maps elapsed time → current segment + remaining.
  Order: for each set, for each repetition, for each round: work then rest. Rest after the very last work
  period of the workout is skipped. No extra rest between sets (the round's rest covers it).
- **Lead-in**: workouts start with a 10s GET READY phase, so the first work period gets the same cues.
- **Get-ready cue** = a distinct two-tone chime, plus spoken "Get ready — <exercise>" (macOS speech,
  toggle in settings, on by default). If rest is shorter than 10s, the cue plays at the start of the rest.
  Beeps are generated tones (no audio files); short beep ~880 Hz 0.15s, long beep ~660 Hz 0.8s.
- **Controls**: Start, Pause/Resume (Space), Skip forward/back a segment (→ / ←), Stop (Esc, with confirm).
  Skipping doesn't replay cues already passed.
- **Editing while running**: the run uses a snapshot of the workout; editing is allowed but affects the next run.
- **Limits/validation**: times 1s–60min via steppers + text field (clamped); repeat count 1–99; empty
  exercise names shown as "Exercise N". A set needs ≥1 round, a workout ≥1 set (enforced by UI).
- **Storage**: JSON file in `~/Library/Application Support/WorkoutTimer/workouts.json`, saved on every change
  (debounced), written atomically. A sample workout is created on first launch.
- **Keep awake**: `ProcessInfo` activity / IOPM assertion to prevent display sleep while running.
- **Layout**: two-pane window — workout list sidebar, editor on the right; "Start" opens the timer view
  (full-window, large type, dark background; countdown digits red for work, green for rest, amber get-ready).

## Left to the builder
Visual styling details, exact tones, file/module organisation within the above split.
