# 04 — Calendar: Widget, Join button and upcoming-event Activity

**What to build:** The Calendar Widget on Home shows events from all my calendars: the all-day events for today on one line at the top, then today's remaining events, then tomorrow's first event. Clicking an event opens it in Calendar. Events with a Zoom, Google Meet, Microsoft Teams, or FaceTime link get a Join button. The link is found in the event's URL, then its location, then its notes, and the first match wins. From 5 minutes before an event starts until it starts, the Notch shows an upcoming-event Ongoing Activity. All-day events never create one. Calendar access is requested on first use, and if it's denied the Widget says so. Parent spec: `.scratch/entailler-v1/spec.md`.

**Blocked by:** 01 — Skeleton: Notch opens on hover, with the Activity slot

**Status:** done

- [x] A calendar adapter reads events from all calendars via EventKit, requests access on first use, and notifies the core when events change
- [x] When calendar access is denied, the Calendar Widget shows a message explaining why it's empty
- [x] The Calendar Widget shows the all-day line at the top, then today's remaining events, then tomorrow's first event
- [x] The Widget updates when events change and when the day rolls over
- [x] Clicking an event opens it in Calendar
- [x] Meeting-link detection finds Zoom, Google Meet, Microsoft Teams, and FaceTime links, checking URL, then location, then notes, and the first match wins. Matching events get a Join button that opens the link
- [x] An upcoming-event Ongoing Activity shows from 5 minutes before an event starts until it starts. All-day events never create one
- [x] The upcoming-event Ongoing Activity ranks below Flash Activities and above now playing, and is hidden in fullscreen
- [x] Core tests with a fake calendar adapter and fake clock cover Widget contents, day rollover, the access-denied state, meeting-link detection (each provider, field order, first match, no match), and the upcoming-event Ongoing Activity window including the all-day exclusion

## Comments

Built on 2026-09-30. Choices made while building it:

- Access is asked for at launch, the first time Entailler runs, since the upcoming-event Activity needs events before Home is ever opened.
- Today's remaining events include one already underway, until it ends. Tomorrow's first event is its first event that isn't all-day.
- The upcoming-event Activity shows a calendar icon on one side of the Notch and the minutes left on the other. When two events are about to start, the sooner one shows.
- Besides event changes, the Widget is read again when the day changes, the clock or time zone changes, and after the Mac wakes.
- Clicking an event opens it through Calendar's `ical://ekevent/…` link. That scheme isn't documented, and every occurrence of a repeating event shares one identifier, so check it on the MacBook.
- The access-denied message has a button that opens the Calendars privacy settings.

Changed afterwards, as asked:

- The Calendar Widget is a row of days that scrolls sideways without end, rather than a list with only tomorrow's first event. It starts with a week and reads a week further each time the last days come into view, then goes back to a week when the Nook closes. Every day after today lists all its events and its own all-day line.
- A third Nook view, Calendar, sits between Home and Files. It shows a month grid with today marked and a dot on days with events. Beside the grid are the selected day's events, and today is selected at first. A sideways trackpad swipe or the chevrons move between months, and closing the Nook goes back to this month. The Nook is taller in this view.
- Where the days run off the right edge, they fade out.
- A hairline separates the Media and Calendar Widgets on Home.
- While a call is coming up (an upcoming event with a meeting link), the Activity's wings widen. The left wing shows a video icon and the countdown, and the right wing shows a Join button you can click on the collapsed Notch. Resting on the Join button doesn't open the Nook, and the rest of the collapsed Notch still lets clicks through to the menu bar.
- Joining a Google Meet call first opens Google's account chooser (`accounts.google.com/AccountChooser?continue=…`), so you pick which Google account joins. Other providers open their link directly.
