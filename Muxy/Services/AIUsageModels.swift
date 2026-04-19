import Foundation

struct AIUsageMetricRow: Identifiable, Equatable, Sendable {
    let id: String
    let label: String
    let percent: Double?
    let resetDate: Date?
    let detail: String?

    init(label: String, percent: Double?, resetDate: Date?, detail: String?) {
        id = label
        self.label = label
        self.percent = percent
        self.resetDate = resetDate
        self.detail = detail
    }
}

enum AIProviderUsageState: Equatable, Sendable {
    case available
    case unavailable(message: String)
    case error(message: String)
}

struct AIProviderUsageSnapshot: Identifiable, Equatable, Sendable {
    let id: String
    let providerID: String
    let providerName: String
    let providerIconName: String
    let fetchedAt: Date
    let state: AIProviderUsageState
    let rows: [AIUsageMetricRow]

    init(
        providerID: String,
        providerName: String,
        providerIconName: String,
        fetchedAt: Date = Date(),
        state: AIProviderUsageState,
        rows: [AIUsageMetricRow]
    ) {
        id = providerID
        self.providerID = providerID
        self.providerName = providerName
        self.providerIconName = providerIconName
        self.fetchedAt = fetchedAt
        self.state = state
        self.rows = rows
    }
}
