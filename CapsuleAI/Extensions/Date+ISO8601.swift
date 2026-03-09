//
//  Date+ISO8601.swift
//  CapsuleAI
//

import Foundation

enum ISO8601Parser {
    static func parse(_ str: String?) -> Date? {
        guard let str else { return nil }
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = fmt.date(from: str) { return d }
        fmt.formatOptions = [.withInternetDateTime]
        return fmt.date(from: str)
    }

    static func parseFromTimestamp(_ ts: Double?) -> Date? {
        guard let ts else { return nil }
        return Date(timeIntervalSince1970: ts > 1e12 ? ts / 1000 : ts) // ms ou s
    }
}
