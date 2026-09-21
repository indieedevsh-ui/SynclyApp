//
//  SynclySplashView.swift
//  BeSorted
//

import SwiftUI

/// Ekran startowy Syncly: logo (jak App Icon) + nazwa, potem płynne zniknięcie.
struct SynclySplashView: View {
    var onFinished: () -> Void

    @State private var contentOpacity: Double = 0
    @State private var contentScale: CGFloat = 0.92
    @State private var splashOpacity: Double = 1

    /// Kolor tła z `synlcyIconNew.icon` (display-p3 ≈ sRGB).
    private let iconFill = Color(red: 0.182, green: 0.211, blue: 0.268)

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 18) {
                ZStack {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    iconFill.opacity(1.12),
                                    iconFill,
                                    iconFill.opacity(0.88)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Image("SynclyLogo")
                        .resizable()
                        .scaledToFit()
                        // Jak warstwa w Icon Composer (scale ≈ 0.4).
                        .frame(width: 128 * 0.42, height: 128 * 0.42)
                }
                .frame(width: 128, height: 128)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .shadow(color: .white.opacity(0.12), radius: 20, y: 4)

                Text("Syncly")
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .tracking(0.6)
            }
            .scaleEffect(contentScale)
            .opacity(contentOpacity)
            .allowsHitTesting(false)
        }
        .opacity(splashOpacity)
        .preferredColorScheme(.dark)
        .onAppear {
            Task { @MainActor in
                await runSplashSequence()
            }
        }
    }

    @MainActor
    private func runSplashSequence() async {
        withAnimation(.smooth(duration: 0.75)) {
            contentOpacity = 1
            contentScale = 1
        }
        try? await Task.sleep(nanoseconds: 1_350_000_000)

        withAnimation(.smooth(duration: 0.55)) {
            splashOpacity = 0
            contentOpacity = 0
            contentScale = 1.04
        }
        try? await Task.sleep(nanoseconds: 520_000_000)
        onFinished()
    }
}
