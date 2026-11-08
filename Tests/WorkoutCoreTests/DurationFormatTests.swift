import Testing
@testable import WorkoutCore

@Suite struct DurationFormatTests {
    @Test func formats() {
        #expect(DurationFormat.format(5) == "0:05")
        #expect(DurationFormat.format(90) == "1:30")
        #expect(DurationFormat.format(3600) == "60:00")
    }

    @Test func countdownShowsSecondsBelowAMinute() {
        #expect(DurationFormat.countdown(59.2) == "60")   // ceil, 60 shown as seconds
        #expect(DurationFormat.countdown(45.0) == "45")
        #expect(DurationFormat.countdown(60.5) == "1:01")
        #expect(DurationFormat.countdown(0) == "0")
    }

    @Test func parses() {
        #expect(DurationFormat.parse("45") == 45)
        #expect(DurationFormat.parse(" 1:30 ") == 90)
        #expect(DurationFormat.parse("0:05") == 5)
        #expect(DurationFormat.parse("abc") == nil)
        #expect(DurationFormat.parse("") == nil)
        #expect(DurationFormat.parse("1:75") == nil)
        #expect(DurationFormat.parse("-3") == nil)
    }

    @Test func parseClamps() {
        #expect(DurationFormat.parse("0") == 1)
        #expect(DurationFormat.parse("99:00") == 3600)
    }
}
