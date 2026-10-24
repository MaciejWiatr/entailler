# 08 — Keyboard control of the Notch

**What to build:** The whole Notch works from the keyboard. A global shortcut opens the Nook with the keyboard, and each view has keys for what it does. Parent spec: `.scratch/entailler-v1/spec.md`.

**Blocked by:** 07 — To-Dos: a Nook view synced with Apple Reminders

**Status:** done

- [x] ⌥⌘N, from any app, opens the Nook on Home with the keyboard; on a Nook opened by hovering it takes the keyboard; on one that has it, it closes the Nook
- [x] The Nook takes the keyboard without activating Entailler, keeps it until it closes, then hands it back to the app in front
- [x] Opening To-Dos takes the keyboard and focuses the new to-do field
- [x] Escape closes the Nook; ⌘1–⌘4 switch views; ⌘[ and ⌘] switch to the view before or after, wrapping around
- [x] Home: Space plays or pauses; ← and → skip to the previous or next track
- [x] Calendar: ← and → move the selected day by a day, ↑ and ↓ by a week, into the next or previous month if need be; [ and ] move a month; T goes to today
- [x] To-Dos: ↑ and ↓ highlight a to-do while the field keeps the keyboard; Return with nothing typed ticks the highlighted to-do off, or unticks it
- [x] Core tests cover the shortcut, keeping the keyboard, view switching and moving the selected day
