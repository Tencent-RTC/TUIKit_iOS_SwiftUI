import Foundation

class DateHelper {
    private static let sundayFirstWeekday = 1

    private static let mondayFirstWeekday = 2

    private static let mondayBasedWeekdayShift = 5

    private static let daysPerWeek = 7

    private static let secondsPerMinute = 60

    private static let secondsPerHour = 3600

    private static var isChineseLanguage: Bool {
        LanguageHelper.getCurrentLanguage().hasPrefix("zh")
    }

    private static var shortDatePattern: String {
        isChineseLanguage ? "M月d日" : "M/d/yy"
    }

    private static var fullDatePattern: String {
        isChineseLanguage ? "yyyy年M月d日" : "M/d/yy"
    }

    private static let formatterLock = NSLock()
    private static var formatterCache: [String: DateFormatter] = [:]

    private static func formatString(_ date: Date, format: String, localeIdentifier: String?) -> String {
        let key = "\(format)|\(localeIdentifier ?? "system")"
        formatterLock.lock()
        defer { formatterLock.unlock() }
        let formatter: DateFormatter
        if let cached = formatterCache[key] {
            formatter = cached
        } else {
            let created = DateFormatter()
            created.dateFormat = format
            if let localeIdentifier = localeIdentifier {
                created.locale = Locale(identifier: localeIdentifier)
            }
            formatterCache[key] = created
            formatter = created
        }
        return formatter.string(from: date)
    }

    static func convertDateToHMStr(_ date: Date?) -> String? {
        guard let date = date else {
            return nil
        }
        if date == Date.distantPast {
            return ""
        }
        return formatString(date, format: "HH:mm", localeIdentifier: nil)
    }

    static func convertDateToMessageTimeStr(_ date: Date) -> String {
        if date == Date.distantPast {
            return ""
        }
        let calendar = Calendar.current
        let timeString = formatString(date, format: "HH:mm", localeIdentifier: "en_US_POSIX")

        if calendar.isDateInToday(date) {
            return timeString
        }
        if calendar.isDateInYesterday(date) {
            return "\(LocalizedChatString("Yesterday")) \(timeString)"
        }

        let now = Date()
        let nowComponents = calendar.dateComponents([.year], from: now)
        let dateComponents = calendar.dateComponents([.year], from: date)
        let isSameYear = nowComponents.year == dateComponents.year
        let isSameWeek = startOfWeekMonday(now) == startOfWeekMonday(date)

        if isSameYear && isSameWeek {
            let weekday = formatString(date, format: "EEEE", localeIdentifier: LanguageHelper.getCurrentLanguage())
            return "\(weekday) \(timeString)"
        }

        let day = formatString(date, format: isSameYear ? Self.shortDatePattern : Self.fullDatePattern, localeIdentifier: "en_US_POSIX")
        return "\(day) \(timeString)"
    }

    static func convertDateToYMDStr(_ date: Date) -> String {
        if date == Date.distantPast {
            return ""
        }

        let calendar = Calendar.current
        var customCalendar = calendar
        customCalendar.firstWeekday = sundayFirstWeekday

        let now = Date()
        let nowComponent = customCalendar.dateComponents([.day, .month, .year, .weekOfMonth], from: now)
        let dateComponent = customCalendar.dateComponents([.day, .month, .year, .weekOfMonth], from: date)

        if nowComponent.year == dateComponent.year {
            if nowComponent.month == dateComponent.month {
                if nowComponent.weekOfMonth == dateComponent.weekOfMonth {
                    if nowComponent.day == dateComponent.day {
                        return formatString(date, format: "HH:mm", localeIdentifier: "en_US_POSIX")
                    } else {
                        return formatString(date, format: "EEEE", localeIdentifier: LanguageHelper.getCurrentLanguage())
                    }
                }
            }
            return formatString(date, format: Self.shortDatePattern, localeIdentifier: "en_US_POSIX")
        }
        return formatString(date, format: Self.fullDatePattern, localeIdentifier: "en_US_POSIX")
    }

    static func formatDurationSeconds(_ totalSeconds: Int) -> String {
        if totalSeconds <= 0 {
            return "00:00"
        }
        let hours = totalSeconds / secondsPerHour
        let minutes = totalSeconds % secondsPerHour / secondsPerMinute
        let seconds = totalSeconds % secondsPerMinute
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    static func formatDurationMillis(_ milliseconds: Int) -> String {
        return formatDurationSeconds(milliseconds / 1000)
    }

    static func formatCallDuration(_ totalSeconds: Int) -> String {
        let safeSeconds = max(totalSeconds, 0)
        return String(format: "%02d:%02d", safeSeconds / secondsPerMinute, safeSeconds % secondsPerMinute)
    }

    private static func startOfWeekMonday(_ date: Date) -> Date {
        var calendar = Calendar.current
        calendar.firstWeekday = mondayFirstWeekday
        let startOfDay = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: startOfDay)
        let mondayBasedIndex = (weekday + mondayBasedWeekdayShift) % daysPerWeek
        return calendar.date(byAdding: .day, value: -mondayBasedIndex, to: startOfDay) ?? startOfDay
    }
}
