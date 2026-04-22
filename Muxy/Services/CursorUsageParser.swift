import Foundation

enum CursorUsageParserError: Error {
    case invalidPayload
    case noActiveSubscription
    case missingUsageData
}

enum CursorUsageParser {
    static func parseMetricRows(usageData: Data, planData: Data?) throws -> [AIUsageMetricRow] {
        guard let usagePayload = try JSONSerialization.jsonObject(with: usageData) as? [String: Any] else {
            throw CursorUsageParserError.invalidPayload
        }

        if let enabled = usagePayload["enabled"] as? Bool, enabled == false {
            throw CursorUsageParserError.noActiveSubscription
        }

        guard let planUsage = usagePayload["planUsage"] as? [String: Any] else {
            throw CursorUsageParserError.noActiveSubscription
        }

        let planName = extractPlanName(from: planData)
        let spendLimit = usagePayload["spendLimitUsage"] as? [String: Any]
        let isTeamPlan = isTeam(planName: planName, spendLimit: spendLimit)

        let resetDate = AIUsageParserSupport.date(in: usagePayload, keys: ["billingCycleEnd"])

        var rows: [AIUsageMetricRow] = []

        if isTeamPlan,
           let totalSpend = AIUsageParserSupport.number(in: planUsage, keys: ["totalSpend"]),
           let limit = AIUsageParserSupport.number(in: planUsage, keys: ["limit"]),
           limit > 0
        {
            let usedDollars = totalSpend / 100
            let limitDollars = limit / 100
            rows.append(
                AIUsageMetricRow(
                    label: "Total usage",
                    percent: AIUsageParserSupport.utilizationPercent(used: usedDollars, limit: limitDollars),
                    resetDate: resetDate,
                    detail: "\(AIUsageParserSupport.formatNumber(usedDollars))/\(AIUsageParserSupport.formatNumber(limitDollars))"
                )
            )
        } else {
            let totalPercent = AIUsageParserSupport.number(in: planUsage, keys: ["totalPercentUsed"])
                ?? computedPercent(from: planUsage)

            if let totalPercent {
                rows.append(
                    AIUsageMetricRow(
                        label: "Total usage",
                        percent: max(0, min(100, totalPercent)),
                        resetDate: resetDate,
                        detail: "\(AIUsageParserSupport.formatNumber(max(0, min(100, totalPercent))))/100"
                    )
                )
            }
        }

        if let autoPercent = AIUsageParserSupport.number(in: planUsage, keys: ["autoPercentUsed"]) {
            rows.append(
                AIUsageMetricRow(
                    label: "Auto usage",
                    percent: max(0, min(100, autoPercent)),
                    resetDate: resetDate,
                    detail: "\(AIUsageParserSupport.formatNumber(max(0, min(100, autoPercent))))/100"
                )
            )
        }

        if let apiPercent = AIUsageParserSupport.number(in: planUsage, keys: ["apiPercentUsed"]) {
            rows.append(
                AIUsageMetricRow(
                    label: "API usage",
                    percent: max(0, min(100, apiPercent)),
                    resetDate: resetDate,
                    detail: "\(AIUsageParserSupport.formatNumber(max(0, min(100, apiPercent))))/100"
                )
            )
        }

        if let bonusSpend = AIUsageParserSupport.number(in: planUsage, keys: ["bonusSpend"]), bonusSpend > 0 {
            rows.append(
                AIUsageMetricRow(
                    label: "Bonus spend",
                    percent: nil,
                    resetDate: resetDate,
                    detail: AIUsageParserSupport.currencyDetail(amount: bonusSpend / 100)
                )
            )
        }

        if let spendLimit {
            let limit = AIUsageParserSupport.number(in: spendLimit, keys: ["individualLimit", "pooledLimit"])
            let remaining = AIUsageParserSupport.number(in: spendLimit, keys: ["individualRemaining", "pooledRemaining"])
            if let limit, limit > 0 {
                let used = max(0, limit - (remaining ?? 0))
                rows.append(
                    AIUsageMetricRow(
                        label: "On-demand",
                        percent: AIUsageParserSupport.utilizationPercent(used: used / 100, limit: limit / 100),
                        resetDate: resetDate,
                        detail: "\(AIUsageParserSupport.formatNumber(used / 100))/\(AIUsageParserSupport.formatNumber(limit / 100))"
                    )
                )
            }
        }

        if rows.isEmpty {
            throw CursorUsageParserError.missingUsageData
        }

        return rows
    }

    private static func extractPlanName(from planData: Data?) -> String? {
        guard let planData,
              let payload = try? JSONSerialization.jsonObject(with: planData) as? [String: Any],
              let planInfo = payload["planInfo"] as? [String: Any]
        else {
            return nil
        }

        return AIUsageParserSupport.string(in: planInfo, keys: ["planName", "plan_name"])
    }

    private static func isTeam(planName: String?, spendLimit: [String: Any]?) -> Bool {
        if planName?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "team" {
            return true
        }
        if let spendLimit {
            if AIUsageParserSupport.string(in: spendLimit, keys: ["limitType", "limit_type"])?.lowercased() == "team" {
                return true
            }
            if AIUsageParserSupport.number(in: spendLimit, keys: ["pooledLimit", "pooled_limit"]) != nil {
                return true
            }
        }
        return false
    }

    private static func computedPercent(from planUsage: [String: Any]) -> Double? {
        let limit = AIUsageParserSupport.number(in: planUsage, keys: ["limit"])
        let remaining = AIUsageParserSupport.number(in: planUsage, keys: ["remaining"])
        guard let limit, limit > 0, let remaining else { return nil }
        let used = max(0, limit - remaining)
        return max(0, min(100, (used / limit) * 100))
    }
}
