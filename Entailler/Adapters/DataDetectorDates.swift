import Foundation
import NotchCore

/// Finds dates written in text with Foundation's data detector, which reads the user's language.
///
/// Whether a time of day was written comes from the result's undocumented `timeIsSignificant`,
/// since the public API can't tell "tomorrow" from "tomorrow 12pm". If a macOS update takes it
/// away, a time of day counts as written unless it's noon, the time the detector gives a day.
@MainActor
final class DataDetectorDates: DateDetector {
    private static let timeIsSignificant = "timeIsSignificant"

    private let detector = try! NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)

    func lastDate(in text: String) -> WrittenDate? {
        guard let result = detector.matches(in: text, range: NSRange(text.startIndex..., in: text)).last,
              let date = result.date,
              let range = Range(result.range, in: text)
        else { return nil }
        return WrittenDate(range: range, date: date, hasTime: hasTime(result, date))
    }

    private func hasTime(_ result: NSTextCheckingResult, _ date: Date) -> Bool {
        if result.responds(to: Selector((Self.timeIsSignificant))),
           let significant = result.value(forKey: Self.timeIsSignificant) as? Bool {
            return significant
        }
        let time = Calendar.current.dateComponents([.hour, .minute], from: date)
        return time.hour != 12 || time.minute != 0
    }
}
