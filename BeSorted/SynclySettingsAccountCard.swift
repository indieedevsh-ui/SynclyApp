//
//  SynclySettingsAccountCard.swift
//  BeSorted
//
//  Kafelek konta w Ustawieniach + Sign in with Apple.
//

import AuthenticationServices
import SwiftUI

struct SynclySettingsAccountCard: View {
    @Environment(AppAppearance.self) private var appearance
    @State private var account = SynclyCloudAccount.shared
    @State private var authError: String?
    @State private var showSignOutConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Konto Apple".l10n)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(appearance.primaryText)
                    .besortedNeoCarvedTextFrame(appearance)

                if account.isSignedIn {
                    Text(signedInSubtitle)
                        .font(.caption)
                        .foregroundStyle(appearance.tertiaryText)
                        .lineLimit(1)
                        .besortedNeoCarvedTextFrame(appearance)
                    Text(account.iCloudStatusLabel)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(syncStatusColor)
                        .fixedSize(horizontal: false, vertical: true)
                        .besortedNeoCarvedTextFrame(appearance)
                }
            }

            Spacer(minLength: 0)

            profileAvatar
        }

            if account.isSignedIn {
                Button {
                    showSignOutConfirm = true
                } label: {
                    Text("Wyloguj się".l10n)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color(red: 0.95, green: 0.28, blue: 0.28))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .besortedGlass(
                            appearance,
                            interactive: true,
                            tint: appearance.tileTint.opacity(0.85),
                            in: .rect(cornerRadius: 14),
                            role: .content
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(BeSortedPlainButtonStyle())
            } else {
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName]
                } onCompletion: { result in
                    handleSettingsSignIn(result)
                }
                .signInWithAppleButtonStyle(
                    appearance.theme.usesLightContent ? .black : .white
                )
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(appearance.fieldStroke, lineWidth: 1)
                }

                if let authError {
                    Text(authError)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color(red: 1.0, green: 0.35, blue: 0.35))
                }
            }
        }
        .padding(14)
        .besortedGlass(
            appearance,
            interactive: false,
            tint: appearance.tileTint.opacity(0.85),
            in: .rect(cornerRadius: 16),
            role: .content
        )
        .confirmationDialog(
            "Wylogować się?".l10n,
            isPresented: $showSignOutConfirm,
            titleVisibility: .visible
        ) {
            Button("Wyloguj się".l10n, role: .destructive) {
                account.signOut()
            }
            Button("Anuluj".l10n, role: .cancel) {}
        } message: {
            Text(
                "Po wylogowaniu wrócisz do ekranu logowania. Synchronizacja iCloud będzie niedostępna do ponownego zalogowania.".l10n
            )
        }
        .task {
            await account.refreshICloudStatus()
        }
    }

    private var signedInSubtitle: String {
        if let name = account.displayName, !name.isEmpty {
            return name
        }
        return "Zalogowano".l10n
    }

    /// Zielony, gdy CloudKit naprawdę syncuje; bursztynowy przy fallbacku / braku statusu.
    private var syncStatusColor: Color {
        if account.isCloudSyncActive {
            return Color(red: 0.22, green: 0.55, blue: 0.30)
        }
        return Color(red: 0.92, green: 0.50, blue: 0.22)
    }

    private var profileAvatar: some View {
        ZStack {
            if !appearance.isNeomorphic {
                Circle()
                    .fill(appearance.selectedTabTint.opacity(account.isSignedIn ? 0.85 : 0.35))
            }

            if account.isSignedIn, let initials = profileInitials {
                Text(initials)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(appearance.selectedTabForeground)
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(
                        account.isSignedIn
                            ? appearance.selectedTabForeground
                            : appearance.primaryText.opacity(0.55)
                    )
            }
        }
        .frame(width: 28, height: 28)
        .background {
            if appearance.isNeomorphic {
                // Wypukły avatar w kolorze tła (ten sam rozmiar) — cienie jak reszta elementów.
                BeSortedNeoRaised(shape: Circle(), appearance: appearance)
            }
        }
        .overlay {
            if !appearance.isNeomorphic {
                Circle()
                    .stroke(appearance.fieldStroke, lineWidth: 1)
            }
        }
        .accessibilityLabel(
            account.displayName
                ?? account.appleUserID
                ?? "Nie zalogowano".l10n
        )
    }

    private var profileInitials: String? {
        let source = (account.displayName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !source.isEmpty else { return nil }
        let parts = source.split(whereSeparator: { $0.isWhitespace }).prefix(2)
        let letters = parts.compactMap { $0.first.map(String.init) }
        let joined = letters.joined().uppercased()
        return joined.isEmpty ? nil : joined
    }

    private func handleSettingsSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                authError = "Nie udało się odczytać danych konta Apple.".l10n
                return
            }
            account.completeSignIn(
                userID: credential.user,
                fullName: credential.fullName
            )
            authError = nil
            Task { await account.refreshICloudStatus() }

        case .failure(let error):
            let ns = error as NSError
            if ns.domain == ASAuthorizationError.errorDomain,
               ns.code == ASAuthorizationError.canceled.rawValue {
                return
            }
            authError = error.localizedDescription
        }
    }
}
