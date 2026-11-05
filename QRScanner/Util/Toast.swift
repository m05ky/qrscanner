import SwiftUI

/// Short messages shown at the bottom of the screen.
final class ToastCenter: ObservableObject {
    static let shared = ToastCenter()

    @Published var text: String?
    private var generation = 0

    func show(_ message: String) {
        DispatchQueue.main.async {
            self.generation += 1
            let current = self.generation
            self.text = message
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                if self.generation == current { self.text = nil }
            }
        }
    }
}

struct ToastOverlay: View {
    @ObservedObject private var center = ToastCenter.shared

    var body: some View {
        VStack {
            Spacer()
            if let text = center.text {
                Text(text)
                    .font(Typo.font(14, .medium))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(Color.black.opacity(0.82))
                    .clipShape(Capsule())
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: center.text)
        .allowsHitTesting(false)
    }
}
