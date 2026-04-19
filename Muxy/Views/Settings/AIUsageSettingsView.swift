import SwiftUI

struct AIUsageSettingsView: View {
    @State private var usageService = AIUsageService.shared
    @State private var autoRefreshInterval = AIUsageSettingsStore.autoRefreshInterval()

    private var providers: [AIUsageProviderCatalogEntry] {
        AIUsageProviderCatalog.providers
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text("Auto Refresh")
                    .font(.system(size: 12, weight: .medium))

                Spacer()

                Picker("Auto Refresh", selection: $autoRefreshInterval) {
                    ForEach(AIUsageAutoRefreshInterval.allCases) { interval in
                        Text(interval.label).tag(interval)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(width: 100)
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 6)

            Divider().padding(.horizontal, 12)

            HStack(spacing: 8) {
                Text("Choose which providers appear on the usage board.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    refreshUsage()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 10, weight: .semibold))
                        Text("Refresh")
                            .font(.system(size: 11, weight: .medium))
                    }
                }
                .buttonStyle(.borderless)
                .disabled(usageService.isRefreshing)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .onChange(of: autoRefreshInterval) { _, newValue in
                AIUsageSettingsStore.setAutoRefreshInterval(newValue)
            }

            Divider().padding(.horizontal, 12)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(providers) { provider in
                        providerRow(provider)
                        Divider().padding(.leading, 12)
                    }
                }
            }

            Spacer(minLength: 0)
        }
    }

    private func providerRow(_ provider: AIUsageProviderCatalogEntry) -> some View {
        HStack(spacing: 8) {
            Image(systemName: provider.iconName)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .frame(width: 16)

            Text(provider.displayName)
                .font(.system(size: 12))

            Text(provider.isNative ? "Native" : "Bridge")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.quaternary, in: Capsule())

            Spacer()

            Toggle("", isOn: providerToggleBinding(for: provider))
                .labelsHidden()
                .toggleStyle(.switch)
                .scaleEffect(0.9)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private func providerToggleBinding(for provider: AIUsageProviderCatalogEntry) -> Binding<Bool> {
        Binding(
            get: {
                isProviderToggleOn(provider)
            },
            set: { isOn in
                let nativeProvider = provider.isNative ? AIUsageProviderCatalog.nativeProvider(providerID: provider.id) : nil
                let wasEnabled = nativeProvider?.isEnabled ?? AIUsageProviderEnabledStore.isEnabled(providerID: provider.id)

                AIUsageProviderTrackingStore.setTracked(isOn, providerID: provider.id)

                if provider.isNative {
                    if wasEnabled != isOn {
                        nativeProvider?.isEnabled = isOn
                        AIProviderRegistry.shared.installAll()
                    }
                } else {
                    if wasEnabled != isOn {
                        AIUsageProviderEnabledStore.setEnabled(isOn, providerID: provider.id)
                    }
                }
            }
        )
    }

    private func isProviderToggleOn(_ provider: AIUsageProviderCatalogEntry) -> Bool {
        let tracked = AIUsageProviderTrackingStore.isTracked(providerID: provider.id)
        let enabled: Bool

        if provider.isNative {
            enabled = AIUsageProviderCatalog.nativeProvider(providerID: provider.id)?.isEnabled ?? false
        } else {
            enabled = AIUsageProviderEnabledStore.isEnabled(providerID: provider.id)
        }

        return tracked && enabled
    }

    private func refreshUsage() {
        Task {
            await usageService.refresh(force: true)
        }
    }
}
