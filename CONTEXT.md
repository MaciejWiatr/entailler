# Entailler

A personal macOS app that turns the MacBook's camera notch into an interactive surface for glanceable status, media, calendar, and short-lived file handling.

## Language

### Surfaces

**Notch**:
The collapsed surface drawn around the physical camera cutout at the top of the built-in display.
_Avoid_: Island, Dynamic Island, pill

**Nook**:
The expanded panel that grows out of the Notch and hosts Widgets and the Tray.
_Avoid_: Panel, popover, drawer

**Home**:
The Nook view that holds the Widgets.
_Avoid_: Main tab, dashboard

**Files**:
The Nook view that holds the Tray and the AirDrop Drop Zone.
_Avoid_: Tray tab, shelf tab

### Content

**Activity**:
Glanceable status shown beside the collapsed Notch, such as now playing or a volume change.
_Avoid_: Live Activity, indicator, badge

**Flash Activity**:
An Activity shown briefly in response to an event, such as a volume or brightness change.
_Avoid_: Transient activity, HUD, OSD

**Ongoing Activity**:
An Activity that stays for as long as its source is active, such as now playing or an upcoming event.
_Avoid_: Persistent activity, live activity

**Widget**:
A self-contained module displayed inside the Nook, such as media or calendar.
_Avoid_: Card, tile, module

### Files

**Tray**:
A holding area in the Nook where files are parked temporarily and dragged back out later.
_Avoid_: Shelf, files tray, stash

**Drop Zone**:
A target inside the Nook that accepts dropped files, such as the Tray or AirDrop.
_Avoid_: Drop target, dropper
