# 01 — Skeleton: Notch opens on hover, with the Activity slot

**What to build:** Running the app puts a Notch on the built-in notched display. It is a menu bar app with no Dock icon, and its menu has only Launch at login and Quit. Resting the pointer on the Notch for about 150 ms opens the Nook on an empty Home view. You can switch to an empty Files view, and the Nook closes as soon as the pointer leaves. This ticket also creates the pure Notch core, its test target, the injectable clock, and the core's single Activity slot. The slot is exercised by tests using fake Activities, so every feature ticket after this one only has to plug in an adapter. Parent spec: `.scratch/entailler-v1/spec.md`.

**Blocked by:** None — can start immediately

**Status:** ready-for-agent

- [x] The Xcode project is generated from an XcodeGen spec, targets macOS 26+, and builds a menu-bar-only app with no Dock icon
- [x] The menu bar menu offers Launch at login (via the system login-item service) and Quit
- [x] The Notch core has no dependency on AppKit, SwiftUI, or any adapter's framework. It takes inputs and publishes one display state
- [x] A display-locator adapter reports whether the built-in notched display is present and the Notch's size and position. When it isn't present the Notch is absent, and it reappears when it returns
- [x] A borderless, non-activating floating window sits over the notch, above the menu bar and fullscreen apps, and never takes focus
- [x] Hovering for about 150 ms opens the Nook on Home. A shorter pass does not open it. The pointer leaving closes it
- [x] Inside the open Nook you can switch between Home and Files
- [x] The Activity slot shows at most one Activity, in priority order: Flash Activity, then upcoming-event Ongoing Activity, then now-playing Ongoing Activity. A lower Activity returns when a higher one ends
- [x] While the front app is fullscreen, only Flash Activities are shown. Hovering still opens the Nook
- [x] Core tests use a fake clock and fake adapters and cover the hover delay, closing, view switching, display presence, Activity priority, and the fullscreen rule

## Comments

**2026-09-30 — implemented.** The Notch core lives in the `Packages/NotchCore` Swift package, with 26 Swift Testing tests at the core seam. The shell and adapters are in `Entailler/`. `project.yml` generates `Entailler.xcodeproj`, and `xcodegen generate` needs XcodeGen (`brew install xcodegen`). Checked on this MacBook: the window sits over the notch, hovering opens Home, you can switch to Files, and leaving closes the Nook. Not checked yet, so these need a manual pass: fullscreen detection with a real fullscreen app, the Notch disappearing and returning on lid close/open, and Launch at login (the build is ad-hoc signed, so `SMAppService` may refuse to register).

Left as-is from review: `activityStarted`/`activityEnded` are generic slot inputs. Tickets 02–04 should add domain inputs (volume, now playing, calendar) that drive the slot inside the core, so timing rules stay in the core. The Activity wings drawn in `NotchView.swift` are placeholders for those tickets to replace.
