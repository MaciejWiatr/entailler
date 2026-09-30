# 05 — Files: Tray and AirDrop Drop Zone

**What to build:** Dragging a file over the Notch opens the Nook on Files, which has two Drop Zones: the Tray and AirDrop.
- **Dropping into the Tray** parks references to the original files. Nothing is copied, and a file already in the Tray isn't added twice. Items show an icon or thumbnail with the name, survive quitting and restarting, and disappear if their original file is gone.
- **Managing items:** Cmd-click and Shift-click select several items. The × button or the Delete key removes them.
- **Dragging out:** I can drag one or several items to Finder or any app. The Nook closes as soon as the pointer leaves it while the drag carries on. When the destination accepts the drop, the items leave the Tray. A cancelled or rejected drag keeps them.
- **AirDrop:** dropping files onto the AirDrop Drop Zone opens the AirDrop share sheet with them. It accepts files only.

Parent spec: `.scratch/entailler-v1/spec.md`.

**Blocked by:** 01 — Skeleton: Notch opens on hover, with the Activity slot

**Status:** ready-for-agent

- [ ] A drag entering the Notch opens the Nook on Files, whatever view was last shown
- [ ] Dropping files into the Tray adds references to the originals. A file already in the Tray is not duplicated
- [ ] A Tray store adapter persists the references so the Tray survives quitting Entailler and restarting the Mac
- [ ] Tray items whose original file has been deleted or can't be found are pruned
- [ ] Tray items show an icon or thumbnail and a name
- [ ] Cmd-click and Shift-click build a multi-selection. The × button or the Delete key removes the selected items
- [ ] One or several selected items can be dragged out to Finder or any app
- [ ] During a drag-out, the Nook closes when the pointer leaves it and the drag continues
- [ ] Any accepted drop, including an upload or a copy, removes the dragged items from the Tray. A cancelled or rejected drop keeps them
- [ ] Dropping one or more files onto the AirDrop Drop Zone opens the AirDrop share sheet with those files. Non-file drags are not accepted
- [ ] Core tests with a fake Tray store and fake AirDrop sharer cover opening on Files when a drag enters, adding, de-duplication, persistence round-trip, pruning, multi-select removal, accepted versus cancelled drag-out, and handing files to AirDrop
