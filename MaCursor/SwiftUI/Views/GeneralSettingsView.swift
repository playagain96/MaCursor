import SwiftUI
import Sparkle

struct GeneralSettingsView: View {
    var updater: SPUUpdater?

    @Environment(AppearanceManager.self) private var appearanceManager
    @Environment(LanguageManager.self) private var languageManager
    @Environment(LibraryViewModel.self) private var library

    @State private var cursorScaleValue: Double = GeneralSettingsView.initialScale()
    @State private var scaleText: String = GeneralSettingsView.formatScaleStatic(GeneralSettingsView.initialScale())
    @FocusState private var scaleFieldFocused: Bool


    @State private var hideTahoeCursors: Bool = MACPreferences.hideTahoeCursors
    @State private var isLeftHanded: Bool = MACPreferences.isLeftHanded
    @State private var showResetConfirmation = false
    @State private var showRestartAlert = false

    var body: some View {
        @Bindable var manager = appearanceManager
        @Bindable var langManager = languageManager

        Form {
            Section("Theme") {
                Picker("Appearance", selection: $manager.currentMode) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Label(mode.label, systemImage: mode.icon)
                            .tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Language") {
                Picker("Language", selection: $langManager.currentLanguage) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayName)
                            .tag(language)
                    }
                }
            }

            Section("Cursor") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Cursor Scale")
                        Spacer()
                        TextField("", text: $scaleText)
                            .textFieldStyle(.roundedBorder)
                            .multilineTextAlignment(.trailing)
                            .monospacedDigit()
                            .frame(width: 64)
                            .focused($scaleFieldFocused)
                            .onChange(of: scaleText) { _, newValue in
                                let sanitized = sanitizeScaleInput(newValue)
                                if sanitized != newValue {
                                    scaleText = sanitized
                                }
                            }
                            .onSubmit {
                                commitScaleText()
                            }
                            .onChange(of: scaleFieldFocused) { _, focused in
                                if !focused {
                                    commitScaleText()
                                }
                            }
                            .accessibilityLabel("Cursor Scale")
                        Text("×")
                            .foregroundStyle(.secondary)
                    }

                    Slider(value: sliderBinding, in: 0.5...4.0) { editing in
                        if !editing {
                            reapplyForCursorScale()
                        }
                    }
                        .onChange(of: cursorScaleValue) { _, newValue in
                            MACPreferences.set(NSNumber(value: newValue), forKey: MACPreferences.cursorScaleKey)
                            CursorService.setScale(Float(max(1.0, newValue)))
                            let formatted = formatScale(newValue)
                            if scaleFieldFocused {
                                DispatchQueue.main.async {
                                    scaleText = formatted
                                }
                            } else {
                                scaleText = formatted
                            }
                        }
                        .accessibilityValue(String(format: "%.2f×", cursorScaleValue))
                }
                .onAppear {
                    scaleText = formatScale(cursorScaleValue)
                }

                Toggle("Hide Tahoe cursors", isOn: $hideTahoeCursors)
                    .onChange(of: hideTahoeCursors) { _, newValue in
                        MACPreferences.setFlag(newValue, forKey: MACPreferences.hideTahoeCursorsKey)
                        NotificationCenter.default.post(name: .hideTahoeCursorsChanged, object: nil)
                    }

                Text("When enabled, Tahoe-specific cursor variants (ArrowS, IBeamS) are hidden. Removing a cursor will also remove its Tahoe counterpart.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                Picker("Mouse Hand", selection: $isLeftHanded) {
                    Text("Left Hand").tag(true)
                    Text("Right Hand").tag(false)
                }
                .pickerStyle(.radioGroup)
                .onChange(of: isLeftHanded) { _, newValue in
                    MACPreferences.setFlag(newValue, forKey: MACPreferences.handednessKey)
                    reapplyActiveThemeIfNeeded()
                }
            }


            Section("Helper Tool") {
                HelperToolStatusView()
            }

            if let updater = updater {
                Section("Software Updates") {
                    Toggle("Automatically check for updates", isOn: Binding(
                        get: { updater.automaticallyChecksForUpdates },
                        set: { updater.automaticallyChecksForUpdates = $0 }
                    ))
                }
            }

            Section("Reset Settings") {
                HStack {
                    Text("Reset all settings to default values (cannot be undone)")
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button {
                        showResetConfirmation = true
                    } label: {
                        Text("Reset")
                            .font(.callout.weight(.medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(.red, in: RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("General")
        .alert("Reset All Settings?", isPresented: $showResetConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                performFullReset()
            }
        } message: {
            Text("This will remove all cursor themes, restore system cursors, and reset every preference to its default value. This action cannot be undone.")
        }
        .alert("Restart Required", isPresented: $showRestartAlert) {
            Button("Restart Now") {
                languageManager.restartApp()
            }
            Button("Later", role: .cancel) { }
        } message: {
            Text("The language change will take effect after restarting MaCursor.")
        }
        .onChange(of: languageManager.needsRestart) { _, needsRestart in
            if needsRestart {
                showRestartAlert = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .cursorSettingsDidReset)) { _ in
            let stored = (MACPreferences.value(forKey: MACPreferences.cursorScaleKey) as? NSNumber)?.doubleValue ?? 1.0
            cursorScaleValue = max(0.5, min(4.0, stored))
            scaleText = formatScale(cursorScaleValue)
            isLeftHanded = MACPreferences.isLeftHanded
        }
    }


    private func performFullReset() {
        library.removeAllThemes()

        CursorService.setScale(CursorService.defaultScale())

        let allKeys: [String] = [
            MACPreferences.appliedCursorKey,
            MACPreferences.clickActionKey,
            MACPreferences.cursorScaleKey,

            MACPreferences.handednessKey,
            MACPreferences.suppressDeleteLibraryKey,
            MACPreferences.suppressDeleteCursorKey,
            MACPreferences.favoriteCursorsKey,
            MACPreferences.appearanceModeKey,
            MACPreferences.languageKey,
            MACPreferences.hideTahoeCursorsKey
        ]
        for key in allKeys {
            MACPreferences.set(nil, forKey: key)
        }

        appearanceManager.currentMode = .system
        languageManager.currentLanguage = .system
        UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        UserDefaults.standard.synchronize()

        UserDefaults.standard.removeObject(forKey: "SUEnableAutomaticChecks")

        cursorScaleValue = 1.0
        scaleText = formatScale(1.0)
        MACPreferences.set(NSNumber(value: 1.0), forKey: MACPreferences.cursorScaleKey)
        CursorService.setScale(1.0)
        hideTahoeCursors = true
        isLeftHanded = false

        reapplyForCursorScale()

        let helperManager = HelperToolManager.shared
        if helperManager.isInstalled {
            Task {
                try? await helperManager.uninstall()
            }
        }
    }

    private func reapplyActiveThemeIfNeeded() {
        if let appliedTheme = library.cursorThemes.first(where: { $0.isApplied }) {
            library.apply(appliedTheme)
        }
    }

    private func reapplyForCursorScale() {
        if let appliedTheme = library.cursorThemes.first(where: { $0.isApplied }) {
            library.apply(appliedTheme)
        } else {
            CursorService.restoreAll()
        }
    }

    private var sliderBinding: Binding<Double> {
        Binding(
            get: { cursorScaleValue },
            set: { newValue in
                let tenth = (newValue / 0.1).rounded() / 10.0
                cursorScaleValue = GeneralSettingsView.clampScale(tenth)
            }
        )
    }

    private static func clampScale(_ value: Double) -> Double {
        let snapped = (value * 100).rounded() / 100
        return Swift.max(0.5, Swift.min(4.0, snapped))
    }

    private static func initialScale() -> Double {
        let stored = (MACPreferences.value(forKey: MACPreferences.cursorScaleKey) as? NSNumber)?.doubleValue ?? 1.0
        return clampScale(stored)
    }

    private static func formatScaleStatic(_ value: Double) -> String {
        return value.formatted(.number.precision(.fractionLength(2)).grouping(.never))
    }

    private func formatScale(_ value: Double) -> String {
        return GeneralSettingsView.formatScaleStatic(value)
    }

    private func parseScale(_ text: String) -> Double? {
        let normalized = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        return Double(normalized)
    }

    private func sanitizeScaleInput(_ input: String) -> String {
        var result = ""
        var separatorSeen = false
        var fractionDigits = 0
        for character in input {
            if character.isASCII && character.isNumber {
                if separatorSeen {
                    if fractionDigits < 2 {
                        result.append(character)
                        fractionDigits += 1
                    }
                } else {
                    result.append(character)
                }
            } else if (character == "." || character == ",") && !separatorSeen {
                separatorSeen = true
                result.append(character)
            }
        }
        return result
    }

    private func commitScaleText() {
        guard let parsed = parseScale(scaleText) else {
            scaleText = formatScale(cursorScaleValue)
            return
        }
        let clamped = GeneralSettingsView.clampScale(parsed)
        scaleText = formatScale(clamped)
        guard abs(clamped - cursorScaleValue) > 0.0001 else { return }
        cursorScaleValue = clamped
        MACPreferences.set(NSNumber(value: clamped), forKey: MACPreferences.cursorScaleKey)
        CursorService.setScale(Float(max(1.0, clamped)))
        reapplyForCursorScale()
    }
}
