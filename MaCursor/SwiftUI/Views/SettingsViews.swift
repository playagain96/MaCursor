import AppKit
import Sparkle
import SwiftUI

private class SettingsPanel: NSWindow {
    override func cancelOperation(_ sender: Any?) {
        close()
    }
}

enum SettingsTab: String, CaseIterable, Identifiable {
    case general  = "General"
    case shortcut = "Shortcut"
    case about    = "About"

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .general:  return String(localized: "General")
        case .shortcut: return String(localized: "Shortcut")
        case .about:    return String(localized: "About")
        }
    }

    var icon: String {
        switch self {
        case .general:  return "gear"
        case .shortcut: return "star"
        case .about:    return "info.circle"
        }
    }
}

struct SettingsSidebarView: View {
    @Binding var selectedTab: SettingsTab

    var body: some View {
        List(SettingsTab.allCases, selection: $selectedTab) { tab in
            Label(tab.localizedName, systemImage: tab.icon)
                .tag(tab)
        }
        .listStyle(.sidebar)
        .contentMargins(.top, 12, for: .scrollContent)
    }
}

final class SettingsWindowController: NSWindowController, NSToolbarDelegate {
    static let shared = SettingsWindowController()

    private let splitVC = NSSplitViewController()
    private static let sidebarTrackingID = NSToolbarItem.Identifier("sidebarTracking")

    private var library: LibraryViewModel?
    private var appearanceManager: AppearanceManager?
    private var languageManager: LanguageManager?
    private var updater: SPUUpdater?

    private var selectedTab: SettingsTab = .general {
        didSet {
            updateDetailView()
        }
    }

    private init() {
        let window = SettingsPanel(
            contentRect: NSRect(x: 0, y: 0, width: 750, height: 475),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered, defer: false
        )

        window.titleVisibility = .hidden
        window.title = String(localized: "Settings")
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false

        let toolbar = NSToolbar(identifier: "SettingsSplitToolbar")
        toolbar.showsBaselineSeparator = false
        toolbar.displayMode = .iconOnly
        toolbar.allowsDisplayModeCustomization = false
        window.toolbar = toolbar
        window.toolbarStyle = .unified

        super.init(window: window)

        toolbar.delegate = self

        let sidebarVC = NSHostingController(rootView: AnyView(EmptyView()))
        let detailVC = NSHostingController(rootView: AnyView(EmptyView()))

        let sidebarItem = NSSplitViewItem(sidebarWithViewController: sidebarVC)
        sidebarItem.canCollapse = false
        sidebarItem.minimumThickness = 160
        sidebarItem.maximumThickness = 160
        sidebarItem.allowsFullHeightLayout = true

        let detailItem = NSSplitViewItem(viewController: detailVC)

        splitVC.splitViewItems = [sidebarItem, detailItem]
        splitVC.splitView.dividerStyle = .thin

        window.contentViewController = splitVC

        let windowSize = NSSize(width: 750, height: 475)
        window.setContentSize(windowSize)
        window.minSize = windowSize
        window.maxSize = windowSize

        updateSidebarView()
        updateDetailView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(library: LibraryViewModel, appearanceManager: AppearanceManager, languageManager: LanguageManager, updater: SPUUpdater? = nil) {
        self.library = library
        self.appearanceManager = appearanceManager
        self.languageManager = languageManager
        self.updater = updater
        updateDetailView()
    }

    override func showWindow(_ sender: Any?) {
        let wasAlreadyVisible = window?.isVisible ?? false
        super.showWindow(sender)

        if let window {
            ModalWindowCoordinator.shared.register(window, as: .modal)
        }

        if !wasAlreadyVisible {
            centerOnMainWindow()
        }
    }

    private func centerOnMainWindow() {
        guard let settingsWindow = window else { return }

        guard let mainWindow = ModalWindowCoordinator.shared.resolvedMainWindow,
              mainWindow !== settingsWindow else {
            settingsWindow.center()
            return
        }

        let mainFrame = mainWindow.frame
        guard let visibleFrame = mainWindow.screen?.visibleFrame
                ?? NSScreen.screens.first(where: { $0.frame.intersects(mainFrame) })?.visibleFrame
                ?? NSScreen.main?.visibleFrame else {
            settingsWindow.center()
            return
        }

        settingsWindow.setFrameOrigin(ModalWindowPlacement.centeredOrigin(
            size: settingsWindow.frame.size,
            over: mainFrame,
            constrainedTo: visibleFrame
        ))
    }


    private func updateSidebarView() {
        let sidebarView = SettingsSidebarView(selectedTab: Binding(
            get: { self.selectedTab },
            set: { self.selectedTab = $0 }
        ))

        if let vc = splitVC.splitViewItems[0].viewController as? NSHostingController<AnyView> {
            vc.rootView = AnyView(sidebarView)
        }
    }

    private func updateDetailView() {
        guard let library = library, let appearanceManager = appearanceManager, let languageManager = languageManager else { return }

        var detailView: AnyView
        switch selectedTab {
        case .general:
            detailView = AnyView(GeneralSettingsView(updater: updater))
        case .shortcut:
            detailView = AnyView(ShortcutSettingsView())
        case .about:
            detailView = AnyView(AboutSettingsView())
        }

        let injectedView = AnyView(
            detailView
                .environment(library)
                .environment(appearanceManager)
                .environment(languageManager)
                .frame(minWidth: 265, maxWidth: .infinity, minHeight: 350, maxHeight: .infinity)
        )

        if let vc = splitVC.splitViewItems[1].viewController as? NSHostingController<AnyView> {
            vc.rootView = injectedView
        }
    }


    func toolbar(_ toolbar: NSToolbar,
                 itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
                 willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        if itemIdentifier == Self.sidebarTrackingID {
            return NSTrackingSeparatorToolbarItem(
                identifier: itemIdentifier,
                splitView: splitVC.splitView,
                dividerIndex: 0
            )
        }
        return nil
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [Self.sidebarTrackingID]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarDefaultItemIdentifiers(toolbar)
    }
}

struct GeneralSettingsView: View {
    var updater: SPUUpdater?

    @Environment(AppearanceManager.self) private var appearanceManager
    @Environment(LanguageManager.self) private var languageManager
    @Environment(LibraryViewModel.self) private var library

    @State private var cursorScaleValue: Double = GeneralSettingsView.initialScale()
    @State private var scaleText: String = CursorScaleInput.format(GeneralSettingsView.initialScale())
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
                                let sanitized = CursorScaleInput.sanitize(newValue)
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
                        Text(verbatim: "×")
                            .foregroundStyle(.secondary)
                    }

                    Slider(value: sliderBinding, in: CursorScaleInput.range) { editing in
                        if !editing {
                            reapplyForCursorScale()
                        }
                    }
                        .onChange(of: cursorScaleValue) { _, newValue in
                            MACPreferences.set(NSNumber(value: newValue), forKey: MACPreferences.cursorScaleKey)
                            CursorService.setScale(Float(max(1.0, newValue)))
                            let formatted = CursorScaleInput.format(newValue)
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
                    scaleText = CursorScaleInput.format(cursorScaleValue)
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
            cursorScaleValue = GeneralSettingsView.initialScale()
            scaleText = CursorScaleInput.format(cursorScaleValue)
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
        scaleText = CursorScaleInput.format(1.0)
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
                cursorScaleValue = CursorScaleInput.snapToStep(newValue)
            }
        )
    }

    private static func initialScale() -> Double {
        let stored = (MACPreferences.value(forKey: MACPreferences.cursorScaleKey) as? NSNumber)?.doubleValue ?? 1.0
        return CursorScaleInput.clamp(stored)
    }

    private func commitScaleText() {
        guard let parsed = CursorScaleInput.parse(scaleText) else {
            scaleText = CursorScaleInput.format(cursorScaleValue)
            return
        }
        let clamped = CursorScaleInput.clamp(parsed)
        scaleText = CursorScaleInput.format(clamped)
        guard abs(clamped - cursorScaleValue) > CursorScaleInput.commitEpsilon else { return }
        cursorScaleValue = clamped
        MACPreferences.set(NSNumber(value: clamped), forKey: MACPreferences.cursorScaleKey)
        CursorService.setScale(Float(max(1.0, clamped)))
        reapplyForCursorScale()
    }
}

struct HelperToolStatusView: View {
    @State private var helperManager = HelperToolManager.shared
    @State private var errorMessage: String?
    @State private var isProcessing: Bool = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(helperManager.isInstalled ? .green : .secondary)
                        .frame(width: 8, height: 8)

                    Text(helperManager.statusDescription)
                        .font(.callout)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Spacer()

            Button(helperManager.isInstalled ? "Uninstall" : "Install") {
                Task {
                    isProcessing = true
                    defer { isProcessing = false }
                    do {
                        try await helperManager.toggle()
                        errorMessage = nil
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            }
            .controlSize(.small)
            .disabled(isProcessing)
        }
        .onAppear {
            helperManager.refreshStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            helperManager.refreshStatus()
        }
    }
}

@MainActor
final class CheckForUpdatesViewModel: ObservableObject {
    @Published var canCheckForUpdates = false

    init(updater: SPUUpdater) {
        updater.publisher(for: \.canCheckForUpdates)
            .receive(on: DispatchQueue.main)
            .assign(to: &$canCheckForUpdates)
    }
}

struct CheckForUpdatesView: View {
    @ObservedObject private var checkForUpdatesViewModel: CheckForUpdatesViewModel
    private let updater: SPUUpdater

    init(updater: SPUUpdater) {
        self.updater = updater
        self.checkForUpdatesViewModel = CheckForUpdatesViewModel(updater: updater)
    }

    var body: some View {
        Button("Check for Updates…", action: updater.checkForUpdates)
            .disabled(!checkForUpdatesViewModel.canCheckForUpdates)
    }
}
