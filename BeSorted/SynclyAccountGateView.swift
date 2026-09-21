//
//  SynclyAccountGateView.swift
//  BeSorted
//
//  Pierwsze uruchomienie: wyśrodkowane okienko Sign in with Apple + status iCloud/CloudKit.
//

import AuthenticationServices
import SwiftUI

struct SynclyAccountGateView: View {
    /// `true` = zalogowano; `false` = pominięto.
    var onFinished: (_ signedIn: Bool) -> Void

    @Environment(AppAppearance.self) private var appearance
    @State private var account = SynclyCloudAccount.shared
    @State private var authError: String?
    @State private var isCompleting = false
    @State private var showSkipWarning = false
    @State private var cardAppeared = false
    @State private var backdropAppeared = false

    var body: some View {
        ZStack {
            appearance.screenBackgroundGradient
                .opacity(backdropAppeared ? 1 : 0)
                .ignoresSafeArea()
                .overlay {
                    Color.black.opacity(
                        backdropAppeared
                            ? (appearance.theme.usesLightContent ? 0.18 : 0.45)
                            : 0
                    )
                    .ignoresSafeArea()
                }

            VStack(spacing: 0) {
                Spacer(minLength: 24)

                gateCard
                    .padding(.horizontal, 22)
                    .scaleEffect(cardAppeared ? 1 : 0.88)
                    .opacity(cardAppeared ? 1 : 0)
                    .offset(y: cardAppeared ? 0 : 36)
                    .blur(radius: cardAppeared ? 0 : 6)

                Spacer(minLength: 24)
            }

            if showSkipWarning {
                skipWarningOverlay
                    .transition(
                        .opacity.combined(with: .scale(scale: 0.96))
                    )
                    .zIndex(10)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.28)) {
                backdropAppeared = true
            }
            withAnimation(.spring(response: 0.52, dampingFraction: 0.82, blendDuration: 0.15)) {
                cardAppeared = true
            }
        }
        .task {
            await account.refreshICloudStatus()
            await account.validateExistingCredential()
            if account.isSignedIn, account.isICloudAvailable {
                onFinished(true)
            }
        }
    }

    private var gateCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                Image("SynclyLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Syncly")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(appearance.primaryText)
                    Text("Zaloguj się kontem Apple".l10n)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Self.signInTitleColor)
                }
                Spacer(minLength: 0)
            }

            Text(
                "Po zalogowaniu projekty i dane synchronizują się przez iCloud. Na nowym urządzeniu wystarczy to samo konto Apple.".l10n
            )
            .font(.footnote)
            .foregroundStyle(appearance.tertiaryText)
            .fixedSize(horizontal: false, vertical: true)

            iCloudStatusCard

            if let authError {
                Text(authError)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(red: 1.0, green: 0.35, blue: 0.35))
                    .fixedSize(horizontal: false, vertical: true)
            }

            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.fullName]
            } onCompletion: { result in
                handleSignIn(result)
            }
            .signInWithAppleButtonStyle(
                appearance.theme.usesLightContent ? .black : .white
            )
            .frame(maxWidth: .infinity)
            .frame(height: Self.gateButtonHeight)
            .clipShape(RoundedRectangle(cornerRadius: Self.gateButtonCorner, style: .continuous))
            .overlay {
                gateButtonBorder
            }
            .disabled(isCompleting || showSkipWarning)

            Button {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                    showSkipWarning = true
                }
            } label: {
                Text("Pomiń".l10n)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(appearance.primaryText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .buttonStyle(BeSortedPlainButtonStyle())
            .gateActionChrome(appearance)
            .disabled(isCompleting || showSkipWarning)

            if account.isICloudAvailable == false {
                Button {
                    account.openSystemSettingsForICloud()
                } label: {
                    Text("Otwórz Ustawienia iCloud".l10n)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(appearance.primaryText)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .buttonStyle(BeSortedPlainButtonStyle())
                .gateActionChrome(appearance)
                .disabled(showSkipWarning)

                Button {
                    Task { await account.refreshICloudStatus() }
                } label: {
                    HStack(spacing: 8) {
                        if account.isRefreshing {
                            ProgressView()
                                .tint(appearance.primaryText)
                        }
                        Text("Sprawdź ponownie iCloud".l10n)
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(appearance.primaryText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .buttonStyle(BeSortedPlainButtonStyle())
                .gateActionChrome(appearance)
                .disabled(showSkipWarning)
            }
        }
        .padding(22)
        .frame(maxWidth: 420)
        .besortedGlass(
            appearance,
            interactive: false,
            tint: appearance.tileTint.opacity(0.92),
            in: .rect(cornerRadius: 24),
            role: .content
        )
    }

    private var skipWarningOverlay: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.smooth(duration: 0.28)) {
                        showSkipWarning = false
                    }
                }

            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Color(red: 1.0, green: 0.72, blue: 0.28))
                    Text("Uwaga".l10n)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(appearance.primaryText)
                    Spacer(minLength: 0)
                }

                Text(
                    "Bez zalogowania się nie będziesz mógł kupić Smart Assistant oraz dane będą zapisywane jedynie lokalnie.".l10n
                )
                .font(.subheadline)
                .foregroundStyle(appearance.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    Button {
                        withAnimation(.smooth(duration: 0.28)) {
                            showSkipWarning = false
                        }
                    } label: {
                        Text("Anuluj".l10n)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(appearance.primaryText)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .buttonStyle(BeSortedPlainButtonStyle())
                    .gateActionChrome(appearance)

                    Button {
                        account.skipSignIn()
                        dismissGate(signedIn: false)
                    } label: {
                        Text("Kontynuuj".l10n)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(appearance.selectedTabForeground)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .buttonStyle(BeSortedPlainButtonStyle())
                    .frame(maxWidth: .infinity)
                    .frame(height: Self.gateButtonHeight)
                    .background {
                        RoundedRectangle(cornerRadius: Self.gateButtonCorner, style: .continuous)
                            .fill(appearance.selectedTabTint)
                    }
                    .overlay {
                        gateButtonBorder
                    }
                    .clipShape(RoundedRectangle(cornerRadius: Self.gateButtonCorner, style: .continuous))
                }
            }
            .padding(20)
            .frame(maxWidth: 360)
            .besortedGlass(
                appearance,
                interactive: false,
                tint: appearance.tileTint.opacity(0.96),
                in: .rect(cornerRadius: 22),
                role: .content
            )
            .padding(.horizontal, 28)
        }
    }

    private var iCloudStatusCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: account.isICloudAvailable ? "checkmark.icloud.fill" : "exclamationmark.icloud.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(
                    account.isICloudAvailable
                        ? Color(red: 0.35, green: 0.82, blue: 0.55)
                        : Self.signInTitleColor
                )

            Text(account.iCloudStatusLabel)
                .font(.caption.weight(.medium))
                .foregroundStyle(appearance.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(appearance.fieldFill)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(appearance.fieldStroke, lineWidth: 1)
        }
    }

    private static let signInTitleColor = Color(red: 0.72, green: 0.12, blue: 0.18)
    private static let gateButtonHeight: CGFloat = 52
    private static let gateButtonCorner: CGFloat = 14

    private var gateButtonBorder: some View {
        RoundedRectangle(cornerRadius: Self.gateButtonCorner, style: .continuous)
            .stroke(appearance.fieldStroke, lineWidth: 1)
    }

    private func dismissGate(signedIn: Bool) {
        withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
            cardAppeared = false
            backdropAppeared = false
            showSkipWarning = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            onFinished(signedIn)
        }
    }

    private func handleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                authError = "Nie udało się odczytać danych konta Apple.".l10n
                return
            }

            isCompleting = true
            account.completeSignIn(
                userID: credential.user,
                fullName: credential.fullName
            )

            Task {
                await account.refreshICloudStatus()
                await MainActor.run {
                    isCompleting = false
                    authError = nil
                    // Po SIWA wchodzimy do app — CloudKit gdy dostępny, inaczej lokalny fallback w kontenerze.
                    dismissGate(signedIn: true)
                }
            }

        case .failure(let error):
            let ns = error as NSError
            if ns.domain == ASAuthorizationError.errorDomain,
               ns.code == ASAuthorizationError.canceled.rawValue {
                authError = nil
                return
            }
            authError = error.localizedDescription
        }
    }
}

private extension View {
    func gateActionChrome(_ appearance: AppAppearance) -> some View {
        self
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(appearance.fieldFill)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(appearance.fieldStroke, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
