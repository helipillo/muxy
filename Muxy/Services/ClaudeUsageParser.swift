import Foundation

enum ClaudeUsageParserError: Error {
    case invalidPayload
}

enum ClaudeUsageParser {
    private static let windowDefinitions: [(key: String, label: String)] = [
        ("five_hour", "5h"),
        ("seven_day", "7d"),
        ("seven_day_opus", "7d Opus"),
        ("seven_day_omelette", "7d Omelette"),
    ]

    static func parseMetricRows(from data: Data) throws -> [AIUsageMetricRow] {
        guard let payload = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ClaudeUsageParserError.invalidPayload
        }

        var rows: [AIUsageMetricRow] = []
        rows.reserveCapacity(windowDefinitions.count)

        for definition in windowDefinitions {
            guard let window = payload[definition.key] as? [String: Any] else { continue }

            let used = number(in: window, keys: ["used", "usage", "consumed", "current"])
            let limit = number(in: window, keys: ["limit", "max", "quota", "total"])
            let percent = utilizationPercent(used: used, limit: limit)
            let resetDate = date(in: window, keys: ["reset_at", "resets_at", "resetAt", "reset", "window_end"])
            let detail = usageDetail(used: used, limit: limit)

            guard percent != nil || resetDate != nil || detail != nil else { continue }

            rows.append(
                AIUsageMetricRow(
                    label: definition.label,
                    percent: percent,
                    resetDate: resetDate,
                    detail: detail
                )
            )
        }

        return rows
    }

    private static func number(in dictionary: [String: Any], keys: [String]) -> Double? {
        for key in keys {
            guard let value = dictionary[key] else { continue }
            switch value {
            case let number as NSNumber:
                return number.doubleValue
            case let string as String:
                if let parsed = Double(string) {
                    return parsed
                }
            default:
                continue
            }
        }
        return nil
    }

    private static func date(in dictionary: [String: Any], keys: [String]) -> Date? {
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let withoutFraction = ISO8601DateFormatter()
        withoutFraction.formatOptions = [.withInternetDateTime]

        for key in keys {
            guard let value = dictionary[key] else { continue }
            if let number = value as? NSNumber {
                return unixDate(from: number.doubleValue)
            }
            if let string = value as? String {
                if let seconds = Double(string) {
                    return unixDate(from: seconds)
                }
                if let date = withFraction.date(from: string) ?? withoutFraction.date(from: string) {
                    return date
                }
            }
        }
        return nil
    }

    private static func unixDate(from value: Double) -> Date {
        value > 10_000_000_000 ? Date(timeIntervalSince1970: value / 1000) : Date(timeIntervalSince1970: value)
    }

    private static func utilizationPercent(used: Double?, limit: Double?) -> Double? {
        guard let used, let limit, limit > 0 else { return nil }
        let ratio = used / limit
        return min(max(ratio * 100, 0), 100)
    }

    private static func usageDetail(used: Double?, limit: Double?) -> String? {
        guard let used, let limit else { return nil }
        return "\(formatNumber(used))/\(formatNumber(limit))"
    }

    private static func formatNumber(_ value: Double) -> String {
        if value >= 100 {
            return String(Int(value.rounded()))
        }
        return String(format: "%.1f", value)
    }
}
