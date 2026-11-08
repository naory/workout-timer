import SwiftUI

struct SettingsView: View {
    @AppStorage(SoundPlayer.speakKey) private var speakGetReady = true

    var body: some View {
        Form {
            Toggle("Speak “Get ready” with the exercise name", isOn: $speakGetReady)
        }
        .padding(20)
        .frame(width: 380)
    }
}
