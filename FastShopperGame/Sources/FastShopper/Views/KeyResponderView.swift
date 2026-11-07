import SwiftUI
import AppKit

public struct KeyResponderView: NSViewRepresentable {
    public class FocusView: NSView {
        public override var acceptsFirstResponder: Bool { true }
        public override func becomeFirstResponder() -> Bool { true }
        public override var canBecomeKeyView: Bool { true }
        
        public override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            DispatchQueue.main.async { [weak self] in
                self?.window?.makeFirstResponder(self)
            }
        }
        
        public override func mouseDown(with event: NSEvent) {
            super.mouseDown(with: event)
            self.window?.makeFirstResponder(self)
        }
        
        public override func keyDown(with event: NSEvent) {
            InputManager.shared.handleKeyDown(event: event)
        }
        
        public override func keyUp(with event: NSEvent) {
            InputManager.shared.handleKeyUp(event: event)
        }
    }
    
    public func makeNSView(context: Context) -> FocusView {
        let view = FocusView(frame: .zero)
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }
        return view
    }
    
    public func updateNSView(_ nsView: FocusView, context: Context) {
        if nsView.window?.firstResponder !== nsView {
            nsView.window?.makeFirstResponder(nsView)
        }
    }
}
