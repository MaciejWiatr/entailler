# 01 — Skeleton: Notch opens on hover, with the Activity slot

**What to build:** Running the app puts a Notch on the built-in notched display. It is a menu bar app with no Dock icon, and its menu has only Launch at login and Quit. Resting the pointer on the Notch for about 150 ms opens the Nook on an empty Home view. You can switch to an empty Files view, and the Nook closes as soon as the pointer leaves. This ticket also creates the pure Notch core, its test target, the injectable clock, and the core's single Activity slot. The slot is exercised by tests using fake Activities, so every feature ticket after this one only has to plug in an adapter. Parent spec: `.scratch/entailler-v1/spec.md`.

**Blocked by:** None — can start immediately

**Status:** ready-for-agent

- [ ] The Xcode project is generated from an XcodeGen spec, targets macOS 26+, and builds a menu-bar-only app with no Dock icon
- [ ] The menu bar menu offers Launch at login (via the system login-item service) and Quit
- [ ] The Notch core has no dependency on AppKit, SwiftUI, or any adapter's framework. It takes inputs and publishes one display state
- [ ] A display-locator adapter reports whether the built-in notched display is present and the Notch's size and position. When it isn't present the Notch is absent, and it reappears when it returns
- [ ] A borderless, non-activating floating window sits over the notch, above the menu bar and fullscreen apps, and never takes focus
- [ ] Hovering for about 150 ms opens the Nook on Home. A shorter pass does not open it. The pointer leaving closes it
- [ ] Inside the open Nook you can switch between Home and Files
- [ ] The Activity slot shows at most one Activity, in priority order: Flash Activity, then upcoming-event Ongoing Activity, then now-playing Ongoing Activity. A lower Activity returns when a higher one ends
- [ ] While the front app is fullscreen, only Flash Activities are shown. Hovering still opens the Nook
- [ ] Core tests use a fake clock and fake adapters and cover the hover delay, closing, view switching, display presence, Activity priority, and the fullscreen rule
