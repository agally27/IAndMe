import Foundation

enum DateFormatting {
    static let calendar = Calendar.current

    /// "Today", "Yesterday", "Tuesday", "12 March" or "12 March 2025".
    static func dayLabel(for date: Date, relativeTo now: Date = .now) -> String {
        if calendar.isDate(date, inSameDayAs: now) { return "Today" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(date, inSameDayAs: yesterday) {
            return "Yesterday"
        }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now)).day ?? 0
        if days > 0 && days < 7 {
            return date.formatted(.dateTime.weekday(.wide))
        }
        if calendar.isDate(date, equalTo: now, toGranularity: .year) {
            return date.formatted(.dateTime.day().month(.wide))
        }
        return date.formatted(.dateTime.day().month(.wide).year())
    }

    /// Lowercase relative phrase for prose: "this morning", "yesterday", "on Tuesday", "on 12 March".
    static func prosePhrase(for date: Date, relativeTo now: Date = .now) -> String {
        if calendar.isDate(date, inSameDayAs: now) {
            let hour = calendar.component(.hour, from: date)
            switch hour {
            case 0..<12: return "this morning"
            case 12..<17: return "this afternoon"
            case 17..<21: return "this evening"
            default: return "tonight"
            }
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(date, inSameDayAs: yesterday) {
            return "yesterday"
        }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now)).day ?? 0
        if days > 0 && days < 7 {
            return "on " + date.formatted(.dateTime.weekday(.wide))
        }
        if days < 14 { return "last week" }
        if calendar.isDate(date, equalTo: now, toGranularity: .year) {
            return "on " + date.formatted(.dateTime.day().month(.wide))
        }
        return "on " + date.formatted(.dateTime.day().month(.wide).year())
    }

    static func timeLabel(for date: Date) -> String {
        date.formatted(.dateTime.hour().minute())
    }

    static func monthLabel(for date: Date, relativeTo now: Date = .now) -> String {
        if calendar.isDate(date, equalTo: now, toGranularity: .year) {
            return date.formatted(.dateTime.month(.wide))
        }
        return date.formatted(.dateTime.month(.wide).year())
    }

    /// "March – June 2026" style range.
    static func periodLabel(from start: Date?, to end: Date?) -> String? {
        guard let start, let end else { return nil }
        let sameYear = calendar.isDate(start, equalTo: end, toGranularity: .year)
        let sameMonth = calendar.isDate(start, equalTo: end, toGranularity: .month)
        if sameMonth {
            return start.formatted(.dateTime.month(.wide).year())
        }
        if sameYear {
            return "\(start.formatted(.dateTime.month(.wide))) – \(end.formatted(.dateTime.month(.wide).year()))"
        }
        return "\(start.formatted(.dateTime.month(.wide).year())) – \(end.formatted(.dateTime.month(.wide).year()))"
    }

    static func greeting(for date: Date = .now) -> String {
        let hour = calendar.component(.hour, from: date)
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default: return "Still up"
        }
    }

    static func daysBetween(_ a: Date, _ b: Date) -> Int {
        abs(calendar.dateComponents([.day], from: calendar.startOfDay(for: a), to: calendar.startOfDay(for: b)).day ?? 0)
    }
}

extension Date {
    var startOfDay: Date { Calendar.current.startOfDay(for: self) }

    func adding(days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: self) ?? self
    }

    func adding(hours: Int) -> Date {
        Calendar.current.date(byAdding: .hour, value: hours, to: self) ?? self
    }

    func at(hour: Int, minute: Int = 0) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: self) ?? self
    }

    var isWeekend: Bool { Calendar.current.isDateInWeekend(self) }

    var hour: Int { Calendar.current.component(.hour, from: self) }

    var weekday: Int { Calendar.current.component(.weekday, from: self) }
}
