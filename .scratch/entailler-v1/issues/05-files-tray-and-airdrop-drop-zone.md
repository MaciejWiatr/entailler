# 05 — Files: Tray and AirDrop Drop Zone

**What to build:** Dragging a file over the Notch opens the Nook on Files, which has two Drop Zones: the Tray and AirDrop.
- **Dropping into the Tray** parks references to the original files. Nothing is copied, and a file already in the Tray isn't added twice. Items show an icon or thumbnail with the name, survive quitting and restarting, and disappear if their original file is gone.
- **Managing items:** Cmd-click and Shift-click select several items. The × button or the Delete key removes them.
- **Dragging out:** I can drag one or several items to Finder or any app. The Nook closes as soon as the pointer leaves it while the drag carries on. When the destination accepts the drop, the items leave the Tray. A cancelled or rejected drag keeps them.
- **AirDrop:** dropping files onto the AirDrop Drop Zone opens the AirDrop share sheet with them. It accepts files only.

Parent spec: `.scratch/entailler-v1/spec.md`.

**Blocked by:** 01 — Skeleton: Notch opens on hover, with the Activity slot

**Status:** ready-for-human

- [x] A drag entering the Notch opens the Nook on Files, whatever view was last shown
- [x] Dropping files into the Tray adds references to the originals. A file already in the Tray is not duplicated
- [x] A Tray store adapter persists the references so the Tray survives quitting Entailler and restarting the Mac
- [x] Tray items whose original file has been deleted or can't be found are pruned
- [x] Tray items show an icon or thumbnail and a name
- [x] Cmd-click and Shift-click build a multi-selection. The × button or the Delete key removes the selected items
- [x] One or several selected items can be dragged out to Finder or any app
- [x] During a drag-out, the Nook closes when the pointer leaves it and the drag continues
- [x] Any accepted drop, including an upload or a copy, removes the dragged items from the Tray. A cancelled or rejected drop keeps them
- [x] Dropping one or more files onto the AirDrop Drop Zone opens the AirDrop share sheet with those files. Non-file drags are not accepted
- [x] Core tests with a fake Tray store and fake AirDrop sharer cover opening on Files when a drag enters, adding, de-duplication, persistence round-trip, pruning, multi-select removal, accepted versus cancelled drag-out, and handing files to AirDrop

## Comments

Built. Core rules are covered by `TrayTests` (25 tests). Checked in the running app: the Files view, thumbnails, persistence across a relaunch, pruning a deleted file, and following a renamed one (the Tray store keeps bookmarks, so moved or renamed files stay; files in the Trash count as gone).

Still to check by hand, since drags can't be scripted: a Finder drag opening the Nook on Files, dropping into the Tray and onto AirDrop, dragging items out (single and multi-select), and the Nook closing mid-drag while the drag carries on.

Decisions made while building:
- The × button on a selected item removes the whole selection; on an unselected one, only that item.
- Clicking a Tray item takes the keyboard, so Delete works on a Nook opened by hover.
- Dragging Tray items back onto the Tray is turned down, so they stay. Dropping them on the AirDrop Drop Zone counts as delivered and removes them.
- Drags out of the Tray allow move, so Finder moves the file within a disk, as a Finder drag would; ⌥ copies.

Fixed after the first hand check, where the AirDrop Drop Zone ignored drags: SwiftUI hit-tests drops through the Nook's clip as the collapsed Notch, so nothing right of the collapsed Notch's edge saw a drag. The window's content view now takes file drags in AppKit and hands each one to the Drop Zone under the pointer (`FileDrops.swift`). The same view turns down the Tray's own files dragged back onto it; before, that drop counted as accepted and removed them. Scripted drags confirmed the AirDrop Drop Zone lights up, a drop opens the AirDrop sheet, and a drop back onto the Tray keeps the item.
