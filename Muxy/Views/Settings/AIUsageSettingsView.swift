import SwiftUI

struct AIUsageSettingsView: View {
    @State private var usageService = AIUsageService.shared
    @State private var usageDisplayMode = AIUsageSettingsStore.usageDisplayMode()
    @State private var autoRefreshInterval = AIUsageSettingsStore.autoRefreshInterval()

    private var providers: [AIUsageProviderCatalogEntry] {
        AIUsageProviderCatalog.providers
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text("Show")
                    .font(.system(size: 12, weight: .medium))

                Spacer()

                Picker("Show", selection: $usageDisplayMode) {
                    ForEach(AIUsageDisplayMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 6)

            Divider().padding(.horizontal, 12)

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
            .onChange(of: usageDisplayMode) { _, newValue in
                AIUsageSettingsStore.setUsageDisplayMode(newValue)
            }
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

            if provider.hasNotificationIntegration {
                Text("Integrated")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
            }

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
                AIUsageProviderTrackingStore.isTracked(providerID: provider.id)
            },
            set: { isOn in
                AIUsageProviderTrackingStore.setTracked(isOn, providerID: provider.id)
                usageService.recomposeSnapshots()
            }
        )
    }

    private func refreshUsage() {
        Task {
            await usageService.refresh(force: true)
        }
    }
}
