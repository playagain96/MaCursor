import SwiftUI
import Sparkle

struct GeneralSettingsView: View {
    var updater: SPUUpdater?
    
    @Environment(AppearanceManager.self) private var appearanceManager
    @Environment(LanguageManager.self) private var languageManager
    @Environment(LibraryViewModel.self) private var library
    
    @State private var cursorScaleValue: Double = {
        (MACPreferences.value(forKey: MACPreferences.cursorScaleKey) as? NSNumber)?.doubleValue ?? 1.0
    }()
    
    
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
                        Text("\(cursorScaleValue, specifier: "%.2f")×")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    
                    Slider(value: $cursorScaleValue, in: 1.0...4.0, step: 0.25)
                        .onChange(of: cursorScaleValue) { _, newValue in
                            MACPreferences.set(NSNumber(value: newValue), forKey: MACPreferences.cursorScaleKey)
                            CursorService.setScale(Float(newValue))
                        }
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
        hideTahoeCursors = true
        isLeftHanded = false
        
        reapplyActiveThemeIfNeeded()
        
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
}
