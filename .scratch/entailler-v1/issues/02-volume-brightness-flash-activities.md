# 02 — Volume and brightness Flash Activities

**What to build:** When I change the volume or display brightness, the macOS pop-ups no longer appear in the middle of the screen. A Flash Activity at the Notch shows the new level instead. Muting shows as the muted state of the volume Flash Activity. The Flash Activity disappears about 1.5 s after my last change, and whatever Ongoing Activity was showing comes back. Parent spec: `.scratch/entailler-v1/spec.md`. The pop-up suppression uses private APIs behind their own adapter, per ADR 0001.

**Blocked by:** 01 — Skeleton: Notch opens on hover, with the Activity slot

**Status:** done

- [x] A volume/brightness adapter delivers change events (level and muted state) to the core and suppresses the system volume and brightness pop-ups while Entailler runs
- [x] The system pop-ups return after quitting Entailler
- [x] Changing the volume shows a volume Flash Activity with the level. Muting shows it in the muted state
- [x] Changing display brightness shows a brightness Flash Activity with the level
- [x] Repeated changes keep the Flash Activity visible. It hides about 1.5 s after the last change
- [x] Flash Activities appear in fullscreen apps
- [x] If the private adapter stops working after a macOS update, only this feature degrades and the rest of the app keeps working
- [x] Core tests with a fake adapter and fake clock cover display, extension on repeated changes, expiry, the muted state, and the return of a lower-priority Activity

## Comments

**2026-09-30 — implemented.**
- **Core:** Flash Activities come from the new `LevelChangeSource` adapter input, and the core owns the 1.5 s expiry. `Activity` is now an enum, `.flash(LevelChange)` / `.upcomingEvent` / `.nowPlaying`. There are 32 core tests, and `FlashActivityTests` covers this ticket.
- **Adapter:** `MediaKeyLevelSource` swallows the volume and brightness keys with an active event tap, applies each change itself, and reports it. Volume goes through CoreAudio (`SystemVolume`), and brightness through the private DisplayServices framework loaded at runtime (`DisplayBrightness`, ADR 0001). Steps are 1/16, or 1/64 with Shift-Option, as in macOS.
- **Accessibility:** the event tap needs Accessibility permission. Until it's granted, the keys pass through and the macOS pop-ups show as before. The adapter asks once, then retries every 2 s.
- **Signing:** `project.yml` now signs with the Apple Development identity (team ZT5YR566L2), so the Accessibility grant survives rebuilds. Ad-hoc signatures changed with every build.

**Checked on this MacBook**, with synthetic media-key events:
- Volume up, mute and brightness up each show the Flash Activity with no macOS pop-up.
- It collapses after about 1.5 s.
- Quitting Entailler brings the macOS pop-up back.
- The grant survives a rebuild.

**Not checked by hand:**
- Fullscreen apps. A core test covers this, and the window already joins fullscreen spaces.
- The degraded paths: no Accessibility, DisplayServices missing, an output without volume control. By design, each of these passes the key to macOS.
- Real-keyboard key repeat.

**Known gaps, left as-is from review:**
- Only the keys produce a Flash Activity. Volume changes from Control Center or AirPods don't.
- Swallowing the brightness keys also stops them adjusting an external Apple display.
- `activityStarted(.flash(...))` would bypass the 1.5 s expiry. It's a generic slot input with no callers, and tickets 03–04 should replace it.
- Two Entailler builds with the same bundle ID (e.g. from separate worktrees) fight over one Accessibility grant. Launch and quit them by path or PID, not by bundle ID.

