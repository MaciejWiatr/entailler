# 02 — Volume and brightness Flash Activities

**What to build:** When I change the volume or display brightness, the macOS pop-ups no longer appear in the middle of the screen. A Flash Activity at the Notch shows the new level instead. Muting shows as the muted state of the volume Flash Activity. The Flash Activity disappears about 1.5 s after my last change, and whatever Ongoing Activity was showing comes back. Parent spec: `.scratch/entailler-v1/spec.md`. The pop-up suppression uses private APIs behind their own adapter, per ADR 0001.

**Blocked by:** 01 — Skeleton: Notch opens on hover, with the Activity slot

**Status:** ready-for-agent

- [ ] A volume/brightness adapter delivers change events (level and muted state) to the core and suppresses the system volume and brightness pop-ups while Entailler runs
- [ ] The system pop-ups return after quitting Entailler
- [ ] Changing the volume shows a volume Flash Activity with the level. Muting shows it in the muted state
- [ ] Changing display brightness shows a brightness Flash Activity with the level
- [ ] Repeated changes keep the Flash Activity visible. It hides about 1.5 s after the last change
- [ ] Flash Activities appear in fullscreen apps
- [ ] If the private adapter stops working after a macOS update, only this feature degrades and the rest of the app keeps working
- [ ] Core tests with a fake adapter and fake clock cover display, extension on repeated changes, expiry, the muted state, and the return of a lower-priority Activity
