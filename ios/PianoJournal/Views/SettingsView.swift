import SwiftUI
import StoreKit

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SubscriptionManager.self) private var store

    @AppStorage("dailyGoalMinutes") private var dailyGoal = 15
    @AppStorage("reminderEnabled") private var reminderEnabled = false
    @AppStorage("reminderMinutes") private var reminderMinutes = 18 * 60

    @State private var showPaywall = false
    @State private var showManage = false
    @State private var notificationsDenied = false

    private var reminderTime: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(bySettingHour: reminderMinutes / 60, minute: reminderMinutes % 60, second: 0, of: Date()) ?? Date()
            },
            set: { newValue in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                reminderMinutes = (parts.hour ?? 18) * 60 + (parts.minute ?? 0)
                if reminderEnabled { Task { _ = await Reminders.schedule(minutesAfterMidnight: reminderMinutes) } }
            }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if store.isPro {
                        Label("Piano Journal Pro actif", systemImage: "checkmark.seal.fill").foregroundStyle(.green)
                        Button("Gérer mon abonnement") { showManage = true }
                    } else {
                        Button { showPaywall = true } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Passer à Piano Journal Pro").font(.headline)
                                Text("Partitions illimitées — \(store.displayPrice) par mois").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Button("Restaurer mes achats") { Task { await store.restore() } }
                    }
                } header: {
                    Text("Abonnement")
                } footer: {
                    if !store.isPro {
                        Text("Version gratuite : jusqu'à \(Config.freeScoreLimit) partitions ou recueils.")
                    }
                }

                Section("Objectif") {
                    Stepper(value: $dailyGoal, in: 5...180, step: 5) {
                        HStack {
                            Text("Objectif quotidien")
                            Spacer()
                            Text(verbatim: "\(dailyGoal) min").foregroundStyle(.secondary).monospacedDigit()
                        }
                    }
                }

                Section {
                    Toggle("Rappel quotidien", isOn: $reminderEnabled)
                    if reminderEnabled {
                        DatePicker("Heure", selection: reminderTime, displayedComponents: .hourAndMinute)
                    }
                } header: {
                    Text("Rappel")
                } footer: {
                    if notificationsDenied {
                        Text("Les notifications sont désactivées pour Piano Journal. Activez-les dans Réglages > Notifications.")
                    }
                }

                Section("À propos") {
                    Link("Politique de confidentialité", destination: Config.privacyURL)
                    Link("Conditions d'utilisation", destination: Config.termsURL)
                    Link("Aide et contact", destination: Config.supportURL)
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Réglages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("OK") { dismiss() } }
            }
            .onChange(of: reminderEnabled) { _, enabled in
                if enabled {
                    Task {
                        let granted = await Reminders.schedule(minutesAfterMidnight: reminderMinutes)
                        if !granted {
                            notificationsDenied = true
                            reminderEnabled = false
                        }
                    }
                } else {
                    Reminders.cancel()
                }
            }
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .manageSubscriptionsSheet(isPresented: $showManage)
            .alert("Abonnement", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(store.errorMessage ?? "")
            }
        }
    }
}

// MARK: - Écran d'abonnement

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SubscriptionManager.self) private var store

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    Image(systemName: "pianokeys")
                        .font(.system(size: 44))
                        .foregroundStyle(.white)
                        .frame(width: 92, height: 92)
                        .background(Color.accentColor.gradient, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .padding(.top, 12)

                    VStack(spacing: 6) {
                        Text("Piano Journal Pro").font(.title.weight(.bold))
                        Text("Tout votre répertoire, suivi pièce par pièce.")
                            .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        feature("books.vertical.fill", "Partitions et recueils illimités", "La version gratuite est limitée à \(Config.freeScoreLimit) partitions.")
                        if OnlineCatalog.isAIAvailable {
                            feature("sparkles", "Recherche IA", "Retrouvez n'importe quel recueil et son contenu détaillé.")
                        }
                        feature("checklist", "Suivi complet", "Cochez, notez et chronométrez chaque pièce de vos recueils.")
                        feature("chart.bar.fill", "Statistiques et historique", "Séries, temps par partition, journal de toutes vos séances.")
                    }
                    .padding(.horizontal, 4)

                    VStack(spacing: 10) {
                        Button {
                            Task { if await store.purchase() { dismiss() } }
                        } label: {
                            VStack(spacing: 2) {
                                if let trial = store.trialDescription {
                                    Text("Essayer gratuitement").font(.headline)
                                    Text("\(trial), puis \(store.displayPrice) par mois").font(.caption).opacity(0.9)
                                } else {
                                    Text("S'abonner — \(store.displayPrice) par mois").font(.headline)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.roundedRectangle(radius: 16))
                        .disabled(store.isPurchasing)
                        .overlay { if store.isPurchasing { ProgressView() } }

                        Button("Restaurer mes achats") {
                            Task {
                                await store.restore()
                                if store.isPro { dismiss() }
                            }
                        }
                        .font(.subheadline)
                    }

                    VStack(spacing: 8) {
                        Text("Abonnement mensuel à renouvellement automatique. Le paiement est débité sur votre compte Apple. Résiliable à tout moment dans les réglages de votre compte, au moins 24 h avant la fin de la période en cours.")
                            .font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        HStack(spacing: 16) {
                            Link("Conditions d'utilisation", destination: Config.termsURL)
                            Link("Politique de confidentialité", destination: Config.privacyURL)
                        }
                        .font(.caption2)
                    }
                }
                .padding(20)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .accessibilityLabel(Text("Fermer"))
                }
            }
            .alert("Abonnement", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(store.errorMessage ?? "")
            }
        }
    }

    private func feature(_ icon: String, _ title: LocalizedStringKey, _ detail: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
