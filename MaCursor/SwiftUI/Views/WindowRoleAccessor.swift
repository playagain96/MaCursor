import SwiftUI
import AppKit

struct WindowRoleAccessor: NSViewRepresentable {
    let role: ModalWindowRole

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            register(view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        register(nsView.window)
    }

    private func register(_ window: NSWindow?) {
        guard let window else { return }
        ModalWindowCoordinator.shared.register(window, as: role)
    }
}
