import SwiftUI
import WorkoutCore

struct TimerView: View {
    let run: RunController
    let onClose: () -> Void

    @State private var confirmStop = false

    var body: some View {
        ZStack {
            Color(white: 0.07).ignoresSafeArea()
            if run.status.isFinished {
                finished
            } else {
                running
            }
        }
        .environment(\.colorScheme, .dark)
        .onDisappear { run.stop() }
        .confirmationDialog("End this workout?", isPresented: $confirmStop) {
            Button("End Workout", role: .destructive) { close() }
            Button("Keep Going", role: .cancel) {}
        }
    }

    // MARK: - Running

    private var running: some View {
        let seg = run.segment
        return VStack(spacing: 0) {
            HStack(alignment: .top) {
                counter("SET", seg.setIndex + 1, seg.setCount)
                Spacer()
                counter("ROUND", seg.roundIndex + 1, seg.roundCount)
            }

            Spacer(minLength: 12)

            Text(phaseLabel(seg.phase))
                .font(.system(size: 22, weight: .heavy))
                .tracking(4)
                .foregroundStyle(color(for: seg.phase))
            Text(seg.exerciseName)
                .font(.system(size: 54, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .padding(.top, 4)

            Text(DurationFormat.countdown(run.status.remainingInSegment))
                .font(.system(size: 240, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(color(for: seg.phase))
                .lineLimit(1)
                .minimumScaleFactor(0.3)
                .contentTransition(.identity)

            Text(secondaryLine(seg))
                .font(.title3)
                .foregroundStyle(.white.opacity(0.45))

            Spacer(minLength: 12)

            VStack(spacing: 6) {
                ProgressView(value: run.progress)
                    .tint(.white.opacity(0.6))
                HStack {
                    Text(run.workout.name)
                    Spacer()
                    Text("\(DurationFormat.format(Int(run.status.totalRemaining.rounded(.up)))) left")
                        .monospacedDigit()
                }
                .font(.callout)
                .foregroundStyle(.white.opacity(0.45))
            }
            .padding(.bottom, 16)

            controls
        }
        .padding(28)
    }

    private func counter(_ title: String, _ value: Int, _ total: Int) -> some View {
        VStack(alignment: title == "SET" ? .leading : .trailing, spacing: 0) {
            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .tracking(3)
                .foregroundStyle(.white.opacity(0.55))
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(value)").font(.system(size: 64, weight: .bold, design: .rounded))
                Text("/ \(total)").font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .monospacedDigit()
            .foregroundStyle(.white)
        }
    }

    private var controls: some View {
        HStack(spacing: 28) {
            Button(action: run.skipBackward) { Image(systemName: "backward.end.fill") }
                .keyboardShortcut(.leftArrow, modifiers: [])
                .help("Previous (←)")
            Button(action: run.togglePause) {
                Image(systemName: run.status.isPaused ? "play.fill" : "pause.fill")
                    .frame(width: 44)
            }
            .keyboardShortcut(.space, modifiers: [])
            .help("Pause / Resume (Space)")
            Button(action: run.skipForward) { Image(systemName: "forward.end.fill") }
                .keyboardShortcut(.rightArrow, modifiers: [])
                .help("Next (→)")
            Button { confirmStop = true } label: { Image(systemName: "stop.fill") }
                .keyboardShortcut(.cancelAction)
                .help("Stop (Esc)")
        }
        .font(.system(size: 30))
        .buttonStyle(.borderless)
        .foregroundStyle(.white.opacity(0.85))
    }

    // MARK: - Finished

    private var finished: some View {
        VStack(spacing: 16) {
            Text("Done!")
                .font(.system(size: 96, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("\(run.workout.name) · \(DurationFormat.format(Int(run.totalDuration)))")
                .font(.title2)
                .foregroundStyle(.white.opacity(0.6))
            Button("Close", action: close)
                .keyboardShortcut(.defaultAction)
                .controlSize(.large)
                .padding(.top, 12)
        }
    }

    // MARK: - Helpers

    private func close() {
        run.stop()
        onClose()
    }

    private func phaseLabel(_ phase: Phase) -> String {
        switch phase {
        case .work: "WORK"
        case .rest: "REST · UP NEXT"
        case .getReady: "GET READY"
        }
    }

    private func color(for phase: Phase) -> Color {
        switch phase {
        case .work: .red
        case .rest: .green
        case .getReady: .orange
        }
    }

    private func secondaryLine(_ seg: Segment) -> String {
        var parts = ["Rep \(seg.repetition + 1)/\(seg.repeatCount)"]
        if seg.phase == .work, let next = seg.nextExerciseName { parts.append("Next: \(next)") }
        if run.status.isPaused { parts.insert("PAUSED", at: 0) }
        return parts.joined(separator: "  ·  ")
    }
}
