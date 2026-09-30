# Entailler v1

Status: ready-for-agent

## Problem Statement

My MacBook Pro's camera notch is dead space: the menu bar wraps around it and nothing uses it. Meanwhile the things I glance at all day are scattered — now-playing lives in Control Center, the macOS volume/brightness pop-ups land in the middle of the screen over whatever I'm watching, my next meeting is buried in Calendar, and moving files between apps or Spaces means juggling Finder windows or the Desktop. NotchNook solved this nicely, but it has been abandoned (site down, license server gone), so I want my own notch app that I control.

## Solution

Entailler is a personal macOS app that turns the Notch into an interactive surface. While collapsed, the Notch shows Activities beside the camera cutout: a Flash Activity when I change volume or brightness (replacing the system pop-ups), and Ongoing Activities for now playing or an event about to start. Hovering over the Notch opens the Nook, which has two views: Home, with a Media Widget and a Calendar Widget, and Files, with the Tray (a temporary holding area for files) and an AirDrop Drop Zone. Dragging a file onto the Notch opens Files directly. It runs only on the built-in notched display, lives in the menu bar with no Dock icon, and has no settings beyond launch-at-login and quit.

## User Stories

### Notch and Nook

1. As a user, I want the Notch to blend with the physical camera cutout when nothing is happening, so that it's invisible until it has something to say.
2. As a user, I want the Nook to open when I rest the pointer over the Notch for about 150 ms, so that I can reach my Widgets without clicking.
3. As a user, I want brief pointer passes over the Notch (under the hover delay) not to open the Nook, so that reaching for menu bar items doesn't trigger it.
4. As a user, I want the Nook to close as soon as the pointer leaves it, so that it gets out of the way instantly.
5. As a user, I want the Nook to always open on Home when opened by hover, so that I know what I'll see.
6. As a user, I want the Nook to open directly on Files when I drag a file over the Notch, so that I can drop it without extra steps.
7. As a user, I want to switch between Home and Files inside the open Nook, so that I can reach the Tray even when I didn't arrive by dragging.
8. As a user, I want the Notch and Nook to animate smoothly between states, so that the app feels native.
9. As a user, I want Entailler to appear only on the built-in notched display, so that it never draws a fake notch elsewhere.
10. As a user, I want Entailler to be absent when the lid is closed or the built-in display is unavailable, and to reappear when it returns, so that it never ends up in the wrong place.
11. As a user, I want the Nook to keep working in fullscreen apps when I hover the Notch, so that I can still control media during a fullscreen video.

### Activities

12. As a user, I want a Flash Activity at the Notch when I change the volume, so that I see the level without the system pop-up covering my content.
13. As a user, I want a Flash Activity at the Notch when I change display brightness, so that I see the level in the same place.
14. As a user, I want the system volume and brightness pop-ups suppressed while Entailler runs, so that I don't see both.
15. As a user, I want muting to show as the muted state of the volume Flash Activity, so that mute is clearly visible.
16. As a user, I want a Flash Activity to last about 1.5 s after my last change, so that repeated key presses keep it up and it then disappears.
17. As a user, I want an Ongoing Activity showing artwork on one side of the Notch and an animated waveform on the other while media plays, so that I know what's playing at a glance.
18. As a user, I want the now-playing Ongoing Activity to cover media from any app, including a browser playing YouTube, so that it isn't limited to music apps.
19. As a user, I want the now-playing Ongoing Activity to hide 5 s after playback pauses, so that the Notch goes quiet when I'm not listening.
20. As a user, I want an Ongoing Activity for an upcoming event from 5 minutes before it starts until it starts, so that I don't miss meetings.
21. As a user, I want all-day events never to produce an Activity, so that holidays and out-of-office days don't nag me.
22. As a user, I want only one Activity visible at a time, chosen by priority (Flash Activity, then upcoming event, then now playing), so that the Notch stays readable.
23. As a user, I want a lower-priority Activity to come back once a higher-priority one ends, so that a volume change doesn't hide now playing for good.
24. As a user, I want only Flash Activities in fullscreen, so that now playing and event Activities don't sit on top of a fullscreen video.

### Media Widget

25. As a user, I want the Media Widget on Home to show artwork, title, and artist of the current media, so that I know what's playing.
26. As a user, I want previous, play/pause, and next controls in the Media Widget, so that I can control playback without switching apps.
27. As a user, I want a progress bar I can drag to seek, so that I can jump within a track or video.
28. As a user, I want the Media Widget to keep showing the paused track after the Ongoing Activity hides, so that I can resume from Home.
29. As a user, I want the Media Widget to show an empty state when nothing has played, so that it doesn't look broken.
30. As a user, I want the Media Widget to follow whichever app is currently the system's now-playing source, so that it tracks what I'm actually listening to.

### Calendar Widget

31. As a user, I want the Calendar Widget on Home to list today's remaining events, so that I see the rest of my day.
32. As a user, I want the first event of tomorrow shown after today's, so that I know how tomorrow starts.
33. As a user, I want all-day events shown as a single line at the top of the Calendar Widget, so that they're visible but compact.
34. As a user, I want events from all my calendars, so that nothing is hidden without settings.
35. As a user, I want clicking an event to open it in Calendar, so that I can see details or edit it.
36. As a user, I want a Join button on events that have a Zoom, Google Meet, Microsoft Teams, or FaceTime link, so that I can join a call in one click.
37. As a user, I want the meeting link found in the event's URL, location, or notes, taking the first match, so that it works however the invite was written.
38. As a user, I want the Calendar Widget to update when events change or the day rolls over, so that it's never stale.
39. As a user, I want to be asked for calendar access the first time it's needed, so that I understand why.
40. As a user, I want the Calendar Widget to say so when calendar access is denied, so that I know why it's empty.

### Tray

41. As a user, I want to drop files onto the Tray in Files, so that I can park them while I switch apps or Spaces.
42. As a user, I want the Tray to hold references to the original files rather than copies, so that it doesn't quietly fill my disk.
43. As a user, I want Tray contents to survive quitting Entailler and restarting my Mac, so that parked files don't vanish.
44. As a user, I want a Tray item to disappear if its original file is deleted or no longer found, so that the Tray never shows dead items.
45. As a user, I want Tray items shown with their icon or thumbnail and name, so that I can tell them apart.
46. As a user, I want to drag an item out of the Tray into Finder or any app, so that I can deliver it where it's needed.
47. As a user, I want an item removed from the Tray when any destination accepts the drop, including an upload or a copy, so that the Tray only holds what I haven't delivered yet.
48. As a user, I want an item to stay in the Tray when the drag is cancelled or the destination rejects it, so that I don't lose track of it.
49. As a user, I want to select several Tray items with Cmd-click and Shift-click, so that I can work in batches.
50. As a user, I want to drag several selected items out together, so that I can move a batch of screenshots in one go.
51. As a user, I want to remove Tray items with an × button or the Delete key, including a multi-selection, so that I can tidy up quickly.
52. As a user, I want the Nook to close when the pointer leaves it during a drag-out while the drag carries on, so that the Nook doesn't cover the drop target.
53. As a user, I want dropping a file already in the Tray not to create a duplicate, so that the Tray stays clean.

### AirDrop Drop Zone

54. As a user, I want to drop files onto the AirDrop Drop Zone to open the AirDrop share sheet with them, so that I can send them without digging through menus.
55. As a user, I want the AirDrop Drop Zone to accept several files at once, so that I can send a batch.
56. As a user, I want the AirDrop Drop Zone to accept only files, so that its behavior is predictable.

### App shell

57. As a user, I want Entailler to run as a menu bar app with no Dock icon, so that it stays out of the way.
58. As a user, I want a Launch at login toggle in the menu bar menu, so that it's always there after a restart.
59. As a user, I want a Quit item in the menu bar menu, so that I can stop it and get the system pop-ups back.
60. As a user, I want a macOS update that breaks one private API to disable only that feature, so that the rest of Entailler keeps working.

## Implementation Decisions

- **Platform:** native Swift, with SwiftUI for rendering and AppKit for window management. Targets macOS 26 and later only. The Xcode project is generated from an XcodeGen spec and the generated project is not the source of truth.
- **Private APIs (ADR 0001):** private or undocumented macOS APIs are allowed where public ones can't do the job. Each one lives behind its own adapter, so a macOS update breaks only that adapter's feature. The two known cases:
  - Now playing and media control from any app, via MediaRemote. Since macOS 15.4 this has to go through a helper process that is still entitled to call it.
  - Suppressing the system volume and brightness pop-ups.
- **Architecture:** one pure Notch core plus thin adapters and a thin UI shell.
  - The **Notch core** holds all behavior and has no dependencies on AppKit, SwiftUI or the frameworks the adapters wrap. It receives inputs and publishes a single display state.
  - **Adapters** convert system services into core inputs and carry core commands back to the system.
  - The **shell** owns the floating window above the menu bar, the pointer and drag tracking, the SwiftUI views that draw the display state, and the menu bar item.
- **Notch core inputs:**
  - The pointer entering or leaving the Notch or Nook
  - A drag entering the Notch, a drop onto a Drop Zone, and a drag-out finishing as accepted or cancelled
  - Switching views in the Nook, Tray selection and removal commands, and media commands
  - Now-playing updates: artwork, title, artist, position, duration, and playing or paused
  - Volume and brightness change events, with the muted state
  - Calendar events: title, times, all-day flag, URL, location, notes, and an identifier
  - Whether the front app is fullscreen
  - Whether the built-in display is available
  - A clock, injected so tests control time
- **Notch core display state:**
  - Visibility: absent, or present on the built-in display
  - The single Activity currently shown, if any, and whether it is a Flash Activity or an Ongoing Activity
  - The Nook: closed, or open on Home or Files
  - The Media Widget contents
  - The Calendar Widget contents: all-day line, today's remaining events, tomorrow's first event, and a Join link per event
  - Tray items with the current selection
- **Rules owned by the core:**
  - About 150 ms of hover opens the Nook on Home. The pointer leaving closes it.
  - A drag entering the Notch opens the Nook on Files.
  - Activity priority is Flash Activity, then upcoming event, then now playing.
  - A Flash Activity lasts about 1.5 s after the last change.
  - The upcoming-event Activity runs from 5 minutes before an event until it starts. All-day events never create one.
  - The now-playing Activity hides 5 s after playback pauses.
  - In fullscreen, only Flash Activities show.
  - Tray items are removed when a drag-out is accepted and kept when it is cancelled or rejected.
  - Dropping a file that is already in the Tray does not add it again.
  - Tray items whose original file is gone are pruned.
- **Detecting meeting links:** a pure function in the core. It scans the event's URL, then location, then notes for Zoom, Google Meet, Microsoft Teams or FaceTime links, and the first match wins.
- **Adapters (each a protocol with one real and one fake implementation):**
  - Now-playing source and media controller: MediaRemote via the entitled helper.
  - Volume and brightness events plus pop-up suppression: private.
  - Calendar source: EventKit, reading all calendars and requesting access on first use.
  - AirDrop sharer: the system AirDrop sharing service.
  - Tray store: persists file references across restarts and reports whether each original still exists.
  - Display locator: whether the built-in notched display is present, and the Notch's size and position.
  - Fullscreen detector.
  - Clock.
- **Tray persistence:** stores references to the original files, not copies. Entailler is not sandboxed, so plain file references or bookmarks are enough.
- **Shell:** a borderless, non-activating floating window placed over the notch area of the built-in display. It must stay above the menu bar and fullscreen apps without taking focus.
- **Menu bar menu:** only Launch at login (using the system login-item service) and Quit. There is no Settings window, no Dock icon, and every tunable value is hard-coded.

## Testing Decisions

- **One seam:** the Notch core. Tests feed it inputs through fake adapters and a controllable clock, then assert on the display state. They don't check internal fields, private helpers, or the order of calls.
- **What makes a good test:** it describes a behavior in `CONTEXT.md` terms and survives refactoring the core's internals. Examples:
  - "A volume Flash Activity replaces now playing for 1.5 s, then now playing returns."
  - "An accepted drag-out removes every selected Tray item; a cancelled one keeps them."
  - "An all-day event appears on the all-day line and never creates an Activity."
  - "In fullscreen, a playing track shows no Activity but a volume change does."
  - "Hover shorter than the delay doesn't open the Nook."
- **Covered by tests:** all the core rules listed under Implementation Decisions, including the timing rules (driven by the fake clock), Activity priority, Tray membership and pruning, Calendar Widget contents, and meeting-link detection.
- **Not unit-tested:** SwiftUI views, the floating window, pointer and drag tracking in the shell, and the real adapters. These are checked by running the app on the MacBook. Real adapters should stay thin enough that running the app is enough to trust them.
- **Prior art:** none, because the project has no code yet. Tests use the standard Swift testing tooling included with Xcode.

## Out of Scope

- Handles or floating pills on external or notchless displays, and working with the lid closed
- Drop actions (NotchNook's "Pipelines"): scripts that run on dropped files, such as zip or resize. This is the first candidate for v2.
- A webcam mirror, Shortcuts launcher, notes, to-do or timer Widgets
- Custom GIFs and appearance options
- Replacing the keyboard backlight pop-up, or a mute pop-up separate from volume
- AirDrop for text and URLs
- A settings window, choosing which calendars to show, and excluding media sources
- Support for macOS older than 26, Mac App Store distribution, sandboxing, licensing, and auto-update

## Further Notes

- Vocabulary follows `CONTEXT.md`: Notch, Nook, Home, Files, Activity, Flash Activity, Ongoing Activity, Widget, Tray, Drop Zone.
- `features.md` is the NotchNook research this scope was taken from.
- Hover-to-open was chosen over click-to-open, even though accidental opens are a risk. If they turn out to be a problem in daily use, adjust the hover delay before changing how the Nook opens.
- When the helper process for MediaRemote can't be used, the now-playing adapter should report "no media" rather than crash, so the Media Widget shows its empty state.
