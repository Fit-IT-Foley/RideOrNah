import SwiftUI

extension View {
    /// Places the view on the app's standard surface, which is Liquid Glass. This is the one
    /// place surfaces get their material; extend it here rather than styling surfaces elsewhere.
    func adaptiveSurface(in shape: some Shape) -> some View {
        modifier(AdaptiveSurface(shape: shape))
    }
}

private struct AdaptiveSurface<S: Shape>: ViewModifier {
    let shape: S

    func body(content: Content) -> some View {
        content.glassEffect(.regular, in: shape)
    }
}

#Preview("Adaptive surface") {
    Text("Ride")
        .font(.title.bold())
        .padding(32)
        .adaptiveSurface(in: .rect(cornerRadius: 24))
        .padding()
        .background(.orange.gradient)
}
