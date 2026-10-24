# 06 — Claude Code: waiting-session Activity

**What to build:** When a Claude Code session finishes responding, or asks for permission or an answer, the Notch shows an Ongoing Activity: the Claude Code bot dancing on the left, and a button named after the session's project on the right. Clicking the button brings the terminal or app the session runs in to the front, with its tab or window where possible. Parent spec: `.scratch/entailler-v1/spec.md`.

**Blocked by:** 01 — Skeleton: Notch opens on hover, with the Activity slot

**Status:** done

- [x] Claude Code hooks (`UserPromptSubmit`, `Stop`, `Notification` for permission and elicitation, `SessionEnd`) send their input to Entailler over a Unix socket, using `nc`, and do nothing while Entailler isn't running
- [x] A menu bar toggle adds the hooks to `~/.claude/settings.json`, or takes them out, leaving the rest of the settings alone
- [x] The adapter finds the app the session runs in from the hook's parent processes, falling back on the app the hook was started from; and finds its terminal device
- [x] A session that begins waiting shows the Activity, unless its app is already in front
- [x] The Activity ends when the user clicks it, switches to the session's app, sends the session a prompt, or the session ends or its process goes away
- [x] With several sessions waiting, the latest shows, with how many are waiting; opening it shows the one before
- [x] Clicking selects the session's tab in Terminal and iTerm2, and raises the window named after the project in other apps
- [x] It ranks below Flash Activities and the upcoming-event Activity and above now playing, and is hidden in fullscreen
- [x] Core tests with fake adapters cover showing, ending, ordering, priority and fullscreen
