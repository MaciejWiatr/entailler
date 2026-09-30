# 03 — Media: Widget and now-playing Activity

**What to build:** When media plays in any app, including YouTube in a browser, the Notch shows a now-playing Ongoing Activity: artwork on one side and an animated waveform on the other. The Activity hides 5 s after playback pauses. The Media Widget on Home shows artwork, title, and artist, with previous, play/pause, and next buttons and a progress bar I can drag to seek. The Widget keeps showing the paused track and has an empty state when nothing has played. Parent spec: `.scratch/entailler-v1/spec.md`. Now playing and control use MediaRemote through an entitled helper process, behind their own adapter, per ADR 0001.

**Blocked by:** 01 — Skeleton: Notch opens on hover, with the Activity slot

**Status:** ready-for-agent

- [ ] A now-playing adapter reports artwork, title, artist, position, duration, and playing/paused state for whichever app is the system's now-playing source, using MediaRemote through the entitled helper
- [ ] A media-controller adapter carries previous, play/pause, next, and seek commands from the core to the system
- [ ] If the helper is unavailable, the adapter reports no media rather than crashing, and the Media Widget shows its empty state
- [ ] The Media Widget on Home shows artwork, title, and artist, with working transport buttons and a progress bar you can drag to seek
- [ ] While media plays, a now-playing Ongoing Activity shows artwork and a waveform beside the Notch
- [ ] The now-playing Ongoing Activity hides 5 s after pausing, and the Media Widget still shows the paused track
- [ ] The now-playing Ongoing Activity is hidden in fullscreen, gives way to Flash Activities and upcoming-event Ongoing Activities, and returns after them
- [ ] Core tests with fake adapters and a fake clock cover Widget contents, the empty state, media commands, the 5 s pause hide, and the fullscreen and priority behaviour
