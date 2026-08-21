import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var settings = model.settings

        Form {
            Toggle("Launch at login", isOn: $settings.launchAtLogin)
            Toggle("Show working indicator", isOn: $settings.workingIndicatorEnabled)
            Toggle("Enable sound", isOn: $settings.soundEnabled)

            Slider(value: $settings.notificationDuration, in: 1...8, step: 0.5) {
                Text("Notification duration")
            } minimumValueLabel: {
                Text("1s")
            } maximumValueLabel: {
                Text("8s")
            }
            Text("\(settings.notificationDuration, format: .number.precision(.fractionLength(1))) seconds")
                .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .padding(8)
        .onChange(of: settings.workingIndicatorEnabled) { _, enabled in
            model.applyWorkingIndicatorSetting(enabled)
        }
    }
}
