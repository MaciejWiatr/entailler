# 07 — To-Dos: a Nook view synced with Apple Reminders

**What to build:** A To-Dos view in the Nook, beside Home, Calendar and Files, listing the user's to-dos from Apple Reminders. Ticking one off, or adding one, changes Reminders; changes made in Reminders, or on another device, show in the Nook. Parent spec: `.scratch/entailler-v1/spec.md`.

**Blocked by:** 01 — Skeleton: Notch opens on hover, with the Activity slot

**Status:** done

- [x] The adapter reads the to-dos not yet done from every Reminders list through EventKit, asking for Reminders access at launch the first time, and reads again whenever Reminders changes
- [x] To-dos with a due date come first, soonest first, then the rest, oldest first; each shows its due day or time, in red once overdue, and its list when they come from more than one
- [x] Ticking a to-do's circle marks it done in Reminders; it stays in the list, ticked, until the Nook closes, so unticking it undoes the mistake
- [x] A field under the list adds a to-do to the default Reminders list on Return; blank titles add nothing
- [x] Quick-add due: a date written in the new to-do, such as "Buy milk tomorrow 5pm" or "Pay rent on friday", is taken out of the title and becomes its due date, with a reminder at the time if one was written; the field previews the due date as it's typed
- [x] The Notch window takes the keyboard only while To-Dos is open, without activating Entailler, and hands it back when the Nook closes or switches view
- [x] Without Reminders access the view says so and links to Privacy Settings
- [x] Core tests with a fake adapter cover ordering, ticking, unticking, closing the Nook, adding and no access
