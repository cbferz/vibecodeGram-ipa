import SwiftUI

struct GlassSurface<Content: View>: View {
    private let cornerRadius: CGFloat
    private let content: Content

    init(
        cornerRadius: CGFloat = 24,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            content
                .padding(16)
                .glassEffect(.regular, in: shape)
        } else {
            materialSurface(in: shape)
        }
        #else
        materialSurface(in: shape)
        #endif
    }

    private func materialSurface<ShapeType: Shape>(in shape: ShapeType) -> some View {
        content
            .padding(16)
            .background(.ultraThinMaterial, in: shape)
            .overlay {
                shape.stroke(Color.primary.opacity(0.08), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.06), radius: 18, y: 8)
    }
}
