# 03 — Media: Widget and now-playing Activity

**What to build:** When media plays in any app, including YouTube in a browser, the Notch shows a now-playing Ongoing Activity: artwork on one side and an animated waveform on the other. The Activity hides 5 s after playback pauses. The Media Widget on Home shows artwork, title, and artist, with previous, play/pause, and next buttons and a progress bar I can drag to seek. The Widget keeps showing the paused track and has an empty state when nothing has played. Parent spec: `.scratch/entailler-v1/spec.md`. Now playing and control use MediaRemote through an entitled helper process, behind their own adapter, per ADR 0001.

**Blocked by:** 01 — Skeleton: Notch opens on hover, with the Activity slot

**Status:** done

- [x] A now-playing adapter reports artwork, title, artist, position, duration, and playing/paused state for whichever app is the system's now-playing source, using MediaRemote through the entitled helper
- [x] A media-controller adapter carries previous, play/pause, next, and seek commands from the core to the system
- [x] If the helper is unavailable, the adapter reports no media rather than crashing, and the Media Widget shows its empty state
- [x] The Media Widget on Home shows artwork, title, and artist, with working transport buttons and a progress bar you can drag to seek
- [x] While media plays, a now-playing Ongoing Activity shows artwork and a waveform beside the Notch
- [x] The now-playing Ongoing Activity hides 5 s after pausing, and the Media Widget still shows the paused track
- [x] The now-playing Ongoing Activity is hidden in fullscreen, gives way to Flash Activities and upcoming-event Ongoing Activities, and returns after them
- [x] Core tests with fake adapters and a fake clock cover Widget contents, the empty state, media commands, the 5 s pause hide, and the fullscreen and priority behaviour

## Comments

Built on 2026-09-30. Asked for while it was being built:

- The artwork shows as a minimal turntable: the cover is the label of a record that spins at 33⅓ rpm while playing, and a tonearm swings on when playback starts and off when it pauses. Clicking the artwork switches to a plain rounded cover, and back, with a morph between them. The choice is remembered, and the now-playing Activity beside the Notch follows it.
- Artwork comes from the system only, with no Spotify AppleScript fallback. Media without artwork keeps the artwork its app last published until another app becomes the source. This covers Spotify, which also publishes its tracks with no artwork and its window title in place of the title.
- Hovering the progress bar shows a marker and the time a click would seek to.
- The title-and-controls column is as tall as the artwork, and the Nook's height fits its content.
