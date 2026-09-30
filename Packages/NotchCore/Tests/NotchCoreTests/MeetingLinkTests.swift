import Foundation
import NotchCore
import Testing

struct MeetingLinkTests {
    @Test(arguments: [
        "https://us02web.zoom.us/j/81234567890?pwd=abc123",
        "https://zoom.us/wc/join/81234567890",
        "https://meet.google.com/abc-defg-hij",
        "https://teams.microsoft.com/l/meetup-join/19%3ameeting_abc%40thread.v2/0?context=%7b%7d",
        "https://teams.live.com/meet/9876543210",
        "https://gov.teams.microsoft.us/l/meetup-join/19%3ameeting_abc%40thread.v2/0",
        "https://facetime.apple.com/join#v=1&p=AbCdEf&k=GhIjKl",
    ])
    func aLinkFromEachProviderIsFoundInTheNotes(link: String) {
        let event = CalendarEvent.with(notes: "Agenda: roadmap.\nJoin here: \(link)\nThanks!")

        #expect(event.joinLink == URL(string: link))
    }

    @Test func aMeetingLinkIsFoundInTheURL() {
        let event = CalendarEvent.with(url: URL(string: "https://meet.google.com/abc-defg-hij"))

        #expect(event.joinLink == URL(string: "https://meet.google.com/abc-defg-hij"))
    }

    @Test func aMeetingLinkIsFoundInTheLocation() {
        let event = CalendarEvent.with(location: "Room 4 / https://zoom.us/j/81234567890")

        #expect(event.joinLink == URL(string: "https://zoom.us/j/81234567890"))
    }

    @Test func aLinkWrittenWithoutItsSchemeIsFound() {
        let event = CalendarEvent.with(location: "meet.google.com/abc-defg-hij")

        #expect(event.joinLink == URL(string: "https://meet.google.com/abc-defg-hij"))
    }

    @Test func theURLIsCheckedBeforeTheLocationAndTheNotes() {
        let event = CalendarEvent.with(
            url: URL(string: "https://zoom.us/j/111"),
            location: "https://meet.google.com/abc-defg-hij",
            notes: "https://teams.live.com/meet/222"
        )

        #expect(event.joinLink == URL(string: "https://zoom.us/j/111"))
    }

    @Test func theLocationIsCheckedBeforeTheNotes() {
        let event = CalendarEvent.with(
            location: "https://meet.google.com/abc-defg-hij",
            notes: "https://zoom.us/j/111"
        )

        #expect(event.joinLink == URL(string: "https://meet.google.com/abc-defg-hij"))
    }

    @Test func aURLThatIsNotAMeetingLinkDoesNotStopTheSearch() {
        let event = CalendarEvent.with(
            url: URL(string: "https://example.com/agenda"),
            notes: "https://zoom.us/j/111"
        )

        #expect(event.joinLink == URL(string: "https://zoom.us/j/111"))
    }

    @Test func theFirstMeetingLinkInAFieldWins() {
        let event = CalendarEvent.with(
            notes: "See https://example.com first. Join: https://zoom.us/j/111 or https://meet.google.com/abc-defg-hij"
        )

        #expect(event.joinLink == URL(string: "https://zoom.us/j/111"))
    }

    @Test(arguments: [
        "Room 4",
        "https://example.com/j/123",
        "https://zoom.us/download",
        "https://meet.google.com/",
        "https://meet.google.com/new",
        "https://meet.google.com/landing",
        "https://teams.microsoft.com/meetingOptions/?organizerId=abc",
        "https://support.google.com/a/users/answer/9282720",
    ])
    func anEventWithoutAMeetingLinkHasNoJoinLink(text: String) {
        let event = CalendarEvent.with(location: text, notes: text)

        #expect(event.joinLink == nil)
    }
}

extension CalendarEvent {
    static func with(url: URL? = nil, location: String? = nil, notes: String? = nil) -> CalendarEvent {
        CalendarEvent(
            id: "call",
            title: "Call",
            start: .today(at: 10),
            end: .today(at: 11),
            url: url,
            location: location,
            notes: notes
        )
    }
}
