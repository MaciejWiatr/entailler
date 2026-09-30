# Private macOS APIs, each isolated behind an adapter

Entailler is a personal tool that will never ship through the Mac App Store, so it uses private or undocumented macOS APIs where public ones can't do the job: MediaRemote for now-playing and control of media from any app (reached through an entitled helper process since macOS 15.4 restricted direct access), and suppression of the system volume/brightness HUD. Each private API sits behind its own adapter so a macOS update that breaks one degrades only that feature rather than the whole app.

## Considered Options

- **Public APIs only** — rejected: media would be limited to Music and Spotify via AppleScript, and the system HUD could not be replaced.
