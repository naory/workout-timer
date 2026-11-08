# Workout Timer (Mac) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A native macOS SwiftUI interval timer with structured workouts (sets of named rounds, per-set work/rest
times and repeat counts), a clock-accurate timer screen, and audio cues.

**Architecture:** A Swift package with a pure, platform-agnostic `WorkoutCore` library (model, timeline,
engine, cue scheduling, JSON persistence) and a `WorkoutTimer` SwiftUI executable that wraps it. A shell
script bundles the executable into `WorkoutTimer.app`. Core is verified by a `WorkoutCoreChecks` executable
because XCTest / Swift Testing are unavailable without full Xcode (verified: both fail with Command Line Tools).

**Tech Stack:** Swift 6.4, SwiftPM, SwiftUI (macOS 14+), AVFoundation (AVAudioEngine tones, AVSpeechSynthesizer), IOKit/ProcessInfo.

**Spec:** `docs/superpowers/specs/2026-11-08-workout-timer-design.md`

## Global Constraints
- Platform: `.macOS(.v14)`; `WorkoutCore` must not import AppKit/SwiftUI (reused on iOS later).
- Times are per set: `workSeconds`, `restSeconds` clamped to 1…3600; `repeats` clamped to 1…99.
- Lead-in GET READY phase: 10 s. Get-ready cue 10 s before every work period; beeps at 3, 2, 1 s before; long beep at end of every work period.
- No rest after the final work period; no extra rest between sets.
- Timing is derived from a clock (`Date`), never from counting ticks.
- Storage: `~/Library/Application Support/WorkoutTimer/workouts.json`, atomic writes, sample workout on first launch.
- Empty exercise name displays as `"Exercise N"` (1-based position in its set).
- Never crash on bad input or bad file; never silently destroy the user's data.

## Review Focus
1. **Corrupt or unreadable `workouts.json`** → app launches with the sample, and the bad file is preserved as `workouts.corrupt-<timestamp>.json`, never overwritten. (Task 4 check `corruptFileIsBackedUp`.)
2. **Deleting or reordering rounds/sets while a row editor is open** (the crash the user hit in their old app) → bindings are by `id`, never by captured array index; a missing id yields no-op. (Task 5 rule + Task 1 check `updateMissingIdIsNoOp`.)
3. **Rest shorter than 10 s or ≤ 4 s** → get-ready cue moves to rest start + 1 s; dropped if that lands at or after the first countdown beep; beeps never fire before the rest started. (Task 3 checks.)
4. **Pause, then resume (or Mac sleeps while paused)** → no cue fires twice, no cue between old and new position is skipped incorrectly, remaining time unchanged across pause. (Task 3 check `pauseFreezesTimeAndCues`.)
5. **Skip back from first segment / skip forward from last** → clamps to start / finishes cleanly with `isFinished == true`, no index error. (Task 3 check `skipClamps`.)

---

### Task 1: Package scaffold, model, check runner

**Files:**
- Create: `Package.swift`, `.gitignore` (`.build/`, `build/`)
- Create: `Sources/WorkoutCore/Model.swift`
- Create: `Sources/WorkoutCoreChecks/main.swift`, `Sources/WorkoutCoreChecks/Check.swift`, `Sources/WorkoutCoreChecks/ModelChecks.swift`
- Create: `Sources/WorkoutTimer/WorkoutTimerApp.swift` (placeholder window "Workout Timer")

**Interfaces:**
- Produces:
  - `public struct Exercise: Identifiable, Codable, Hashable { public var id: UUID; public var name: String }`
  - `public struct WorkoutSet: Identifiable, Codable, Hashable { id: UUID; name: String; exercises: [Exercise]; repeats: Int; workSeconds: Int; restSeconds: Int }` — all `public var`; `didSet`-free; clamping via `normalized()`.
  - `public struct Workout: Identifiable, Codable, Hashable { id: UUID; name: String; sets: [WorkoutSet] }`
  - `public enum Limits { static let seconds = 1...3600; static let repeats = 1...99; static func clamp(_ v: Int, _ r: ClosedRange<Int>) -> Int }`
  - `WorkoutSet.normalized() -> WorkoutSet` (clamps fields; if `exercises` empty, inserts one `Exercise(name: "")`)
  - `Workout.normalized() -> Workout` (normalizes sets; if `sets` empty, inserts one default set)
  - `WorkoutSet.displayName(ofExerciseAt index: Int) -> String` (trimmed name, or `"Exercise \(index+1)"`)
  - `Workout.sample -> Workout`: "Sample HIIT", Set 1 ["Squats","Push-ups","Plank"] ×2 @ 30/30, Set 2 same exercises ×2 @ 40/20.
  - `extension Array where Element: Identifiable { mutating func update(id: Element.ID, _ body: (inout Element) -> Void) }` — no-op if id missing.
  - Check helpers: `func check(_ cond: @autoclosure () -> Bool, _ name: String, file: StaticString = #fileID, line: UInt = #line)`, `func checkEqual<T: Equatable>(_ a: T, _ b: T, _ name: String, …)`; global counters; `main.swift` runs all `run*Checks()` then prints `"<n> checks passed"` and `exit(0)`, or lists failures and `exit(1)`.

- [ ] **Step 1:** `git init`; write `Package.swift` (targets `WorkoutCore` library, `WorkoutCoreChecks` executable depending on it, `WorkoutTimer` executable depending on it), `.gitignore`, placeholder app.
- [ ] **Step 2: Write failing checks** in `ModelChecks.swift` (`runModelChecks()`):
  - `clampWork`: `WorkoutSet(… workSeconds: 0, restSeconds: 99999, repeats: 0).normalized()` → work 1, rest 3600, repeats 1.
  - `emptySetGetsExercise`: set with `exercises: []` normalized has 1 exercise.
  - `emptyWorkoutGetsSet`: `Workout(name:"x", sets: []).normalized().sets.count == 1`.
  - `displayNameFallback`: exercise `"  "` at index 1 → `"Exercise 2"`; `" Squats "` → `"Squats"`.
  - `codableRoundTrip`: encode/decode `Workout.sample` equals original.
  - `updateMissingIdIsNoOp`: `update(id: UUID())` on sample's sets leaves array equal.
- [ ] **Step 3:** `swift run WorkoutCoreChecks` → fails to compile (types missing).
- [ ] **Step 4:** Implement `Model.swift` per Interfaces.
- [ ] **Step 5:** `swift run WorkoutCoreChecks` → `6 checks passed`; `swift build` succeeds for all targets.
- [ ] **Step 6:** Commit `feat: package scaffold and workout model`.

### Task 2: Timeline

**Files:**
- Create: `Sources/WorkoutCore/Timeline.swift`, `Sources/WorkoutCoreChecks/TimelineChecks.swift`

**Interfaces:**
- Consumes: Task 1 model.
- Produces:
  - `public enum Phase: Equatable, Sendable { case getReady, work, rest }`
  - `public struct Segment: Equatable, Sendable { phase: Phase; start: Int; duration: Int; exerciseName: String; nextExerciseName: String?; setIndex: Int; setCount: Int; setName: String; repetition: Int; repeatCount: Int; roundIndex: Int; roundCount: Int }` — indices 0-based; `var end: Int { start + duration }`.
  - `public enum Timeline { static let leadIn = 10; static func build(_ w: Workout) -> [Segment] }` — operates on `w.normalized()`.
  - `extension Array where Element == Segment { var totalDuration: Int }`

Order: lead-in `getReady` (exercise = first work's exercise), then for set → repetition → round: `work`, then `rest` unless it is the final work of the workout. A rest segment's `exerciseName` is the **next** exercise (what you're about to do); `nextExerciseName` on work = following work's exercise or `nil` at end.

- [ ] **Step 1: Write failing checks** (`runTimelineChecks()`), using a workout of Set A ["A1","A2"] ×2 @ 20/10 and Set B ["B1"] ×1 @ 30/5:
  - `segmentCount`: 1 getReady + 5 work + 4 rest = 10 segments.
  - `phasesOrder`: `[.getReady, .work, .rest, .work, .rest, .work, .rest, .work, .rest, .work]`.
  - `noTrailingRest`: last segment is `.work`, exercise "B1".
  - `perSetTimes`: work durations `[20,20,20,20,30]`, rest durations `[10,10,10,10]` (rest after A's last round uses set A's rest).
  - `startsContiguous`: each `segments[i].start == segments[i-1].end`; first start 0, lead-in 10.
  - `totalDuration`: `10 + 80 + 30 + 40 == 160`.
  - `counters`: 4th segment (index 3, work) has `setIndex 0, repetition 0, roundIndex 1, roundCount 2`; index 5 has `repetition 1, roundIndex 0, repeatCount 2`.
  - `restShowsUpcoming`: segment index 2 (rest) `exerciseName == "A2"`.
- [ ] **Step 2:** Run → fails to compile.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run → all checks pass.
- [ ] **Step 5:** Commit `feat: flatten workouts into a timeline`.

### Task 3: Engine and cues

**Files:**
- Create: `Sources/WorkoutCore/Cues.swift`, `Sources/WorkoutCore/Engine.swift`, `Sources/WorkoutCoreChecks/EngineChecks.swift`

**Interfaces:**
- Consumes: `Segment`, `Timeline.build`.
- Produces:
  - `public enum CueKind: Equatable, Sendable { case getReady(exercise: String), beep, longBeep }`
  - `public struct Cue: Equatable, Sendable { time: Double; kind: CueKind }`
  - `public enum Cues { static func schedule(_ segments: [Segment]) -> [Cue] }` sorted by time.
  - `public struct TimerEngine` (value type, all time passed in explicitly — no `Date()` inside):
    - `init(segments: [Segment])`
    - `mutating func start(at now: Date)`, `pause(at:)`, `resume(at:)`, `skipForward(at:)`, `skipBackward(at:)`
    - `func elapsed(at now: Date) -> Double`
    - `func status(at now: Date) -> Status` where `public struct Status: Equatable { segmentIndex: Int; remainingInSegment: Double; totalRemaining: Double; isFinished: Bool; isPaused: Bool }`
    - `mutating func dueCues(at now: Date) -> [Cue]` — returns cues with `lastCueTime < time <= elapsed`, then advances `lastCueTime`. `start` sets `lastCueTime = -1` so time-0 cues fire.

Cue rules per work segment `w` with previous segment `p` (always exists — the lead-in):
- `beep` at `w.start-3, w.start-2, w.start-1`, each only if `>= p.start`.
- `getReady(w.exerciseName)` at `t = max(w.start-10, p.start + (p.phase == .rest ? 1 : 0))`, dropped if `t >= w.start-3`. (The +1 keeps it off the long beep at rest start.)
- `longBeep` at `w.end`.

Skip semantics: `skipForward` → elapsed = next segment start (or total → finished); `skipBackward` → if more than 2 s into the current segment, go to its start, else previous segment's start (clamped to 0). After a skip `lastCueTime = newElapsed` (cues at the new position are not fired, passed cues are not replayed). Elapsed clamps to `[0, total]`; `isFinished` when elapsed ≥ total.

- [ ] **Step 1: Write failing checks** (`runEngineChecks()`), `t0 = Date(timeIntervalSince1970: 0)`:
  - `cuesBasic` (Set ["X"] ×2 @ 20/15; work 10–30, rest 30–45, work 45–65): get-ready "X" at 0, beeps 7,8,9, longBeep 30, get-ready at 35, beeps 42,43,44, longBeep 65.
  - `cuesShortRest` (rest 6, work 20): second work starts 36 → get-ready at max(26, 31) = 31, beeps 33,34,35.
  - `cuesTinyRest` (rest 4): second work at 34, rest starts 30 → get-ready at 31 ≥ 31 → dropped; beeps 31,32,33.
  - `cuesTwoSecondRest` (rest 2; second work at 32): no get-ready; beeps at 30, 31 only (29 < rest start 30, dropped).
  - `statusAtTime` (cuesBasic workout): after `start(t0)`, `status(at: t0+12)` → segmentIndex 1, remaining 18.
  - `pauseFreezesTimeAndCues` (cuesBasic workout): `start(t0)`; `dueCues(at: t0)` == `[getReady "X"]`; `pause(at: t0+5)`; `dueCues(at: t0+50)` == `[]`; `resume(at: t0+100)`; `status(at: t0+102)` → segment 0, remaining 3; `dueCues(at: t0+103.5)` == `[beep@7, beep@8]`; calling again at same time == `[]`.
  - `skipClamps`: `skipBackward` at +1 → elapsed 0; repeated `skipForward` past end → `isFinished`, no crash; `dueCues` after skip returns `[]` for the skipped range.
  - `finishedAtEnd`: `status(at: t0 + total + 50).isFinished == true`, `totalRemaining == 0`.
- [ ] **Step 2:** Run → fails to compile.
- [ ] **Step 3:** Implement `Cues.swift`, `Engine.swift`.
- [ ] **Step 4:** Run → all checks pass.
- [ ] **Step 5:** Commit `feat: clock-based timer engine and audio cue schedule`.

### Task 4: Persistence

**Files:**
- Create: `Sources/WorkoutCore/WorkoutFile.swift`, `Sources/WorkoutCoreChecks/PersistenceChecks.swift`

**Interfaces:**
- Produces:
  - `public struct WorkoutFile { init(url: URL); static var defaultURL: URL` (Application Support/WorkoutTimer/workouts.json) `; func load() -> [Workout]; func save(_ workouts: [Workout]) throws }`
  - File format: `{"version": 1, "workouts": [...]}`, pretty-printed, sorted keys.
  - `load()`: missing file → `[Workout.sample]`; undecodable → move file to `workouts.corrupt-<unix seconds>.json` in the same dir, return `[Workout.sample]`; decoded → each `normalized()`; decoded but empty list → `[]` (user deleted all — respected).
  - `save`: create directory if needed, `Data.write(options: .atomic)`.

- [ ] **Step 1: Write failing checks** (temp dir via `FileManager.default.temporaryDirectory`):
  - `missingFileGivesSample`, `roundTrip` (save 2 workouts, load equal), `corruptFileIsBackedUp` (write `"{nope"`, load → sample; a `workouts.corrupt-*.json` exists containing `{nope`; original path no longer holds `{nope`), `loadNormalizes` (file with `workSeconds: 0` → loads as 1), `emptyListRespected`.
- [ ] **Step 2:** Run → fails. **Step 3:** Implement. **Step 4:** Run → pass.
- [ ] **Step 5:** Commit `feat: JSON workout persistence with corrupt-file backup`.

### Task 5: Library and editor UI

**Files:**
- Create: `Sources/WorkoutTimer/WorkoutStore.swift`, `Sources/WorkoutTimer/ContentView.swift`, `Sources/WorkoutTimer/WorkoutEditorView.swift`, `Sources/WorkoutTimer/SetEditorView.swift`, `Sources/WorkoutTimer/DurationField.swift`
- Modify: `Sources/WorkoutTimer/WorkoutTimerApp.swift`

**Interfaces:**
- Consumes: model, `Array.update(id:)`, `WorkoutFile`, `Timeline.build(...).totalDuration`.
- Produces: `@MainActor @Observable final class WorkoutStore { var workouts: [Workout]; init(file: WorkoutFile = .init(url: WorkoutFile.defaultURL)); func add() -> Workout.ID; func duplicate(_ id:); func delete(_ id:); func binding(for id: Workout.ID) -> Binding<Workout>? }` — saves 0.5 s after the last change (debounced `Task`) and on `NSApplication.willTerminateNotification`; save errors shown as a non-fatal banner.
- `ContentView` exposes `onStart: (Workout) -> Void` used by Task 6.

Rules:
- `NavigationSplitView`: sidebar list of workouts (name + total duration `m:ss`), toolbar Add / Duplicate / Delete (delete asks to confirm). Detail = `WorkoutEditorView`.
- Editor: workout name field, total duration, list of sets; each set in a `GroupBox`: name, repeats `Stepper`, work and rest `DurationField`s, ordered exercise rows (text field, move up/down, delete), "Add exercise"; set-level move up/down, duplicate, delete; "Add set" (copies the previous set's times). Delete of the last remaining set/exercise is disabled.
- **All `ForEach` use ids; row bindings are built from the id via lookup** (`Binding(get: { set.exercises.first{$0.id==id} ?? placeholder }, set: { new in set.exercises.update(id: id){ $0 = new } })`), never `$array[index]`.
- `DurationField`: shows `m:ss`, accepts `"45"`, `"1:30"`; invalid text reverts on commit; ±5 s stepper; clamps to `Limits.seconds`.
- "Start" button (⌘↩) → `onStart(workout)`.

- [ ] **Step 1:** Implement the views/store.
- [ ] **Step 2:** `swift build` → succeeds with no warnings in `WorkoutTimer`.
- [ ] **Step 3:** Launch (`swift run WorkoutTimer`), manually: sample appears; add/rename workout; add set; delete an exercise while its text field is focused; reorder sets; type `"abc"` and `"0"` into a duration (reverts / clamps to 0:01); quit and relaunch → edits persisted. Then `swift run WorkoutCoreChecks` still passes.
- [ ] **Step 4:** Commit `feat: workout library and editor`.

### Task 6: Timer screen, sounds, keep-awake

**Files:**
- Create: `Sources/WorkoutTimer/RunController.swift`, `Sources/WorkoutTimer/TimerView.swift`, `Sources/WorkoutTimer/SoundPlayer.swift`, `Sources/WorkoutTimer/KeepAwake.swift`, `Sources/WorkoutTimer/SettingsView.swift`
- Modify: `Sources/WorkoutTimer/ContentView.swift` (present `TimerView` in place of the split view while running)

**Interfaces:**
- Consumes: `TimerEngine`, `Cues`, `Timeline`, `Segment`, `CueKind`.
- Produces: `@MainActor @Observable final class RunController { init(workout: Workout, sound: SoundPlayer); var status: TimerEngine.Status; var segment: Segment; func start(); togglePause(); skipForward(); skipBackward(); stop() }` — 20 Hz `Timer` calls `engine.status(at: Date())` and plays `engine.dueCues(at: Date())`. The workout is a snapshot taken at `init`.
- `final class SoundPlayer { func play(_ kind: CueKind) }`: `AVAudioEngine` + `AVAudioPlayerNode`, pre-rendered sine buffers with 10 ms fade in/out: beep 880 Hz 0.15 s; longBeep 660 Hz 0.8 s; getReady chime 523 Hz 0.15 s then 784 Hz 0.25 s; plus `AVSpeechSynthesizer` "Get ready — <exercise>" when `@AppStorage("speakGetReady")` (default true).
- `KeepAwake`: `ProcessInfo.processInfo.beginActivity(options: [.idleDisplaySleepDisabled, .userInitiated], reason:)` while running and not paused; `endActivity` on pause/stop/finish.

TimerView layout (user-specified primary elements): dark neutral background; large `SET 1/3` and `ROUND 2/4` (round = position of the exercise within its set); exercise name large; huge monospaced countdown (seconds, `m:ss` when ≥ 60; ceil of remaining) with digits **red (`.red`) during work, green (`.green`) during rest**, amber during get-ready; small phase label (WORK / REST / GET READY). Secondary, small and dimmed: `Rep 2/2 · Next: …`, progress bar for whole workout + total remaining. Finished state: "Done!" with total time and Close button. Keys: Space pause/resume, → skip forward, ← skip back, Esc stop (confirm dialog unless finished). On-screen buttons for each.

- [ ] **Step 1:** Implement.
- [ ] **Step 2:** `swift build` passes; `swift run WorkoutCoreChecks` passes.
- [ ] **Step 3:** Manual run with a test workout (Set ["A","B"] ×1 @ 5/12): hear chime + "Get ready — A" at 0, beeps at 7,8,9, long beep at 15, chime at 18, beeps 24–26; Space pauses (countdown frozen, no sound), resumes correctly; ←/→ skip; Esc confirms; display does not sleep (`pmset -g assertions` shows the app's PreventUserIdleDisplaySleep while running).
- [ ] **Step 4:** Commit `feat: timer screen with audio cues and keep-awake`.

### Task 7: App bundle

**Files:**
- Create: `scripts/build-app.sh`, `Resources/Info.plist`, `README.md`

**Interfaces:**
- `scripts/build-app.sh` → `swift build -c release`, assembles `build/WorkoutTimer.app/Contents/{MacOS/WorkoutTimer, Info.plist}`, ad-hoc signs (`codesign --force --sign - build/WorkoutTimer.app`).
- `Info.plist`: `CFBundleIdentifier` `com.naoryuval.WorkoutTimer`, `CFBundleName` `Workout Timer`, `LSMinimumSystemVersion` `14.0`, `NSHighResolutionCapable` true, `CFBundlePackageType` `APPL`.
- README: how to build, run checks, open in Xcode, where data lives.

- [ ] **Step 1:** Write script, plist, README.
- [ ] **Step 2:** `scripts/build-app.sh && open build/WorkoutTimer.app` → app launches as a normal app (Dock icon, menu bar "Workout Timer"), workouts from Task 5 present.
- [ ] **Step 3:** Commit `build: bundle WorkoutTimer.app`.
