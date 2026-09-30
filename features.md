# NotchNook — Feature Set

NotchNook, made by lo.cafe (lead developer and designer Igor Marcossi), is a macOS app that turns the MacBook notch into a "Dynamic Island" style panel. When you hover over the notch or swipe down, it expands into a panel called the **Nook** with two parts: **widgets** and a **files Tray**. While the notch is closed, it shows **live activities** around it.

*Researched 2026-09-30. Latest version: 1.6.2 (June 2026).*

---

## Core interaction
- **Hover to peek:** moving the pointer over the notch makes it bulge slightly, with a drop shadow.
- **Click or two-finger swipe down** opens the full Nook. Moving the pointer away closes it.
- **Gestures:** swipe to open or close the notch, swipe sideways on the media widget to change tracks, and swipe up to hide the notch. Each gesture has its own toggle ("Allow gestures", notch open/close, media control).
- **Scrolling:** the Nook grows to fit however many widgets you add (auto-width, since v1.2), and you scroll sideways to reach the rest.
- **Animations:** spring and bounce transitions, and a "squeeze" effect when it closes.
- **Window focus restoring:** focus goes back to the previous app after you use the notch.
- **Fullscreen:** the notch still appears on hover and works when it is hidden in fullscreen apps.

## Widgets (inside the Nook)
| Widget | What it does |
|---|---|
| **Media Player** | Album art, track info, play/pause/skip, and a swipe to change tracks. It can control media from any app ("universal media", e.g. YouTube, VLC, SoundCloud, Spotify), or be limited to Music and Spotify only. |
| **Calendar** | Timeline of upcoming events; swipe to change the day. Options: pick which calendars to show (with select-all and clear buttons), hide all-day and multi-day events. Clicking an event or the month name opens Calendar.app. |
| **Shortcuts** | Runs Apple Shortcuts from the notch, for example a ChatGPT shortcut. |
| **Mirror** | One-click preview of the webcam (FaceTime camera), like Hand Mirror. It supports several camera sources and shows a mirrored image. |
| **Notes** | Quick notes typed right in the notch (v1.4). Esc key support was added in v1.5.5. |
| **Timer / To-do** | Reportedly added in 1.6.0–1.6.1 (2026). The only source for this is a third-party download site. |
| *Quick Apps* | App launcher. It was shown as "coming soon" for a long time. |

Widget layout options: turn each widget on or off, reorder, resize, add or remove dividers, change padding, and choose rounded or square buttons.

## Live activities (while the notch is closed)
- **Now playing:** small album art on one side and an animated audio waveform on the other. Click to play or pause without opening the Nook. There is also a "quick peek" when the song changes.
- **Calendar:** shows upcoming events and clears itself after an event ends.
- **HUD replacement:** the built-in volume and brightness pop-ups are replaced by slim indicators next to the notch. You can choose to show them on all screens.
- **Lock indicator.**
- Live activities also work on notchless screens and in transparent-handler mode, and their bar height can be adjusted.

## Files Tray (file shelf)
- **Drag any file onto the notch** and it opens two drop zones: **Files Tray** and **AirDrop**.
- **Tray:** a temporary holding area. Files stay there until you drag them out to another app, Space, or Finder window.
  - Keyboard: Delete removes a file, Space opens Quick Look, Cmd+C copies, Return renames, arrow keys move between files, Shift or Shift+arrows select several, Cmd+A selects all.
  - Right-click menu: rename, remove, send through AirDrop.
  - Default tray width matches the Nook so the panel doesn't close by accident.
- **AirDrop drop zone:** dropping a file here opens the AirDrop share sheet right away. Since v1.5.1 it also accepts **text and URLs**.
- **Pipelines** (announced as the app's biggest planned feature): user-made "drop actions" that run shell commands on dropped files, such as zip/unzip, resize images, or get a public link, and can be shared with others. The app bundle already declares a "NotchNook Pipeline Installer" file type. I found no evidence it was ever publicly released.

## Appearance and customization
- Transparency, notch height with fine-tuning, padding, dividers, button shape.
- **Custom GIFs** shown in the notch (v1.4.4): use your own or choose from built-in ones.
- Separate height setting for the live-activities bar on notchless displays.
- Translated into about 29 languages through Crowdin.

## Display support
- **Notched MacBooks** (MacBook Pro 2021+, MacBook Air M2+): the panel sits against the real notch.
- **Notchless or external displays:** a smaller "handler" at the top center of the screen with the same features. A transparent handler mode is also available.
- **Multiple monitors** supported.

## Platform, permissions, and distribution
- Requires macOS 14.6 or later. Native on both Apple Silicon and Intel. Built with Swift and SwiftUI. Runs without a Dock icon (LSUIElement).
- Permissions it asks for: Accessibility, Screen Recording, Camera (Mirror), Calendar, Apple Events/Automation (media and Shortcuts).
- **Not on the Mac App Store** because it uses private macOS APIs for system-wide media control. Available from lo.cafe, Setapp (stuck at 1.5.5), and Homebrew (`notchnook`). Updates through Sparkle.
- Private APIs have broken with macOS updates before. In macOS 15.4, media control was temporarily limited to Spotify and Apple Music.

## Pricing (at the time it was sold)
- **$25 one-time** (5 devices) or **$3/month** (2 devices). Short free trial, 15-day refund window.
- Also included in Setapp.

## ⚠️ Current status (September 2026)
- The lo.cafe/notchnook page now returns 404. The Wayback Machine recorded a 402 error on 2026-09-09.
- Homebrew **disabled** the cask on **2026-09-19** because the download is unreachable.
- A MacUpdate review from Sept 2026 says the license server is down and the developers aren't responding. MacUpdate labels the app "no longer supported by its developer."

## Version highlights
- **1.0** (Jun 2024): Nook widgets (Media, Shortcuts, Mirror, Calendar), Tray, AirDrop.
- **1.2** (Aug 2024): auto-width Nook, volume/brightness HUD replacement, lock indicator, global media control, focus restoring, localization.
- **1.2.5**: Tray rework (keyboard shortcuts, Quick Look, rename, multi-select).
- **1.3**: Tray right-click menu, multiple Mirror camera sources, live-activity height setting for notchless screens.
- **1.4**: Notes widget, rounded-button option, height fine-tuning. **1.4.3**: calendar picker, HUD-on-all-screens setting. **1.4.4**: custom GIFs, notch works in fullscreen.
- **1.5.1**: universal media is back, AirDrop for text and URLs, calendar improvements.
- **1.5.5** (Jan 2026): fullscreen live-activity fixes, tray width, Esc in Notes.
- **1.6.0–1.6.1** (Mar–Jun 2026): Timer and To-do widgets (reported). **1.6.2** (Jun 2026): gesture toggles enabled by default again.

---

## Sources
- [lo.cafe/notchnook (cached)](https://lo.cafe/notchnook)
- [MacUpdater version history](https://macupdater.net/app_updates/appinfo/lo.cafe.NotchNook/index.html)
- [MacUpdate listing](https://notchnook.macupdate.com/)
- [Setapp listing](https://setapp.com/apps/notchnook)
- [Homebrew cask](https://formulae.brew.sh/cask/notchnook)
- [MacStories review](https://www.macstories.net/reviews/notchnook-and-mediamate-two-apps-to-add-a-dynamic-island-to-the-mac/)
- [Macworld review](https://www.macworld.com/article/2406934/notfhnook-macbook-dynamic-island-widgets-files-tray.html)
- [Digital Trends](https://www.digitaltrends.com/computing/macbook-notch-redeemed/)
- [iMore (v1.2 + Pipelines)](https://www.imore.com/apps/mac-apps/notchnook-app-that-turns-macbook-notch-into-a-dynamic-island-is-now-better-than-ever)
- [TorrentMac 1.6.2 notes](https://www.torrentmac.net/notchnook-1-6-2/) (only source for the 1.6.0/1.6.1 details)
