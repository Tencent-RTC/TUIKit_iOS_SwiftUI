
public class DateHelper {
    public static func convertDateToHMStr(_ date: Date?) -> String? {
        guard let date = date else {
            return nil
        }
        if date == Date.distantPast {
            return ""
        }
        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "HH:mm"
        let str = dateFmt.string(from: date)
        return str
    }
    
    public static func convertDateToYMDStr(_ date: Date) -> String {
        if date == Date.distantPast {
            return ""
        }
        
        let dateFmt: DateFormatter = {
            let formatter = DateFormatter()
            formatter.locale = nil
            return formatter
        }()
        
        let calendar = Calendar.current
        var customCalendar = calendar
        customCalendar.firstWeekday = 7
        
        let now = Date()
        let nowComponent = customCalendar.dateComponents([.day, .month, .year, .weekOfMonth], from: now)
        let dateComponent = customCalendar.dateComponents([.day, .month, .year, .weekOfMonth], from: date)
        
        if nowComponent.year == dateComponent.year {
            if nowComponent.month == dateComponent.month {
                if nowComponent.weekOfMonth == dateComponent.weekOfMonth {
                    if nowComponent.day == dateComponent.day {
                        dateFmt.dateFormat = "HH:mm"
                    } else {
                        dateFmt.dateFormat = "EEEE"
                        let identifier = LanguageHelper.getCurrentLanguage()
                        dateFmt.locale = Locale(identifier: identifier)
                    }
                } else {
                    dateFmt.dateFormat = "MM/dd"
                }
            } else {
                dateFmt.dateFormat = "MM/dd"
            }
        } else {
            dateFmt.dateFormat = "yyyy/MM/dd"
        }
        return dateFmt.string(from: date)
    }
}
