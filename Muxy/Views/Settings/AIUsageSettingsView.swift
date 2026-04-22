import SwiftUI

struct AIUsageSettingsView: View {
    @State private var usageService = AIUsageService.shared
    @AppStorage(AIUsageSettingsStore.usageEnabledKey) private var usageEnabled = false
    @State private var usageDisplayMode = AIUsageSettingsStore.usageDisplayMode()
    @State private var autoRefreshInterval = AIUsageSettingsStore.autoRefreshInterval()

    private var providers: [AIUsageProviderCatalogEntry] {
        AIUsageProviderCatalog.providers
    }

    private let gridColumns: [GridItem] = [
        GridItem(.flexible(minimum: 140), spacing: 12),
        GridItem(.flexible(minimum: 140), spacing: 12),
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text("AI Usage")
                    .font(.system(size: 12, weight: .medium))

                Spacer()

                Toggle("", isOn: $usageEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .scaleEffect(0.9)
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 6)

            Divider().padding(.horizontal, 12)

            if usageEnabled {
                enabledSettings
            } else {
                disabledSettings
            }

            Spacer(minLength: 0)
        }
        .onChange(of: usageEnabled) { _, enabled in
            AIUsageSettingsStore.setUsageEnabled(enabled)
            if enabled {
                refreshUsage()
            }
        }
        .onChange(of: usageDisplayMode) { _, newValue in
            AIUsageSettingsStore.setUsageDisplayMode(newValue)
        }
        .onChange(of: autoRefreshInterval) { _, newValue in
            AIUsageSettingsStore.setAutoRefreshInterval(newValue)
        }
    }

    private var disabledSettings: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Enable AI Usage to show the usage board in the sidebar.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
        }
    }

    private var enabledSettings: some View {
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

            Divider().padding(.horizontal, 12)

            ScrollView {
                LazyVGrid(columns: gridColumns, spacing: 8) {
                    ForEach(providers) { provider in
                        providerCell(provider)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
        }
    }

    private func providerCell(_ provider: AIUsageProviderCatalogEntry) -> some View {
        HStack(spacing: 8) {
            Image(systemName: provider.iconName)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(provider.displayName)
                    .font(.system(size: 12))
                    .lineLimit(1)

                if provider.hasNotificationIntegration {
                    Text("Integrated")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)

            Toggle("", isOn: providerToggleBinding(for: provider))
                .labelsHidden()
                .toggleStyle(.switch)
                .scaleEffect(0.9)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
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
