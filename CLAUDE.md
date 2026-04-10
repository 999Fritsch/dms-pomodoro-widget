# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this project is

A [DankMaterialShell](https://github.com/anametologin/DankMaterialShell) (DMS) widget plugin written in QML/Quickshell. It adds a Pomodoro timer to the Niri/Wayland bar. There is no build step — the plugin is pure QML loaded at runtime by the DMS shell.

## Installing / reloading

```bash
./install.sh          # copies PomodoroWidget/ to ~/.config/DankMaterialShell/plugins/
                      # and patches settings.json + plugin_settings.json
```

After install, restart DMS with `Super+Shift+R` (or re-login) to pick up changes. The deployed copy lives at `~/.config/DankMaterialShell/plugins/PomodoroWidget/` — edits there take effect on the next DMS reload without re-running `install.sh`.

## Architecture

The entire plugin is two QML files:

- **`PomodoroWidget/PomodoroWidget.qml`** — the main `PluginComponent`. Owns all timer state (`mode`, `running`, `paused`, `remainingSecs`, `pomodorosDone`, `_breakPending`), the countdown `Timer`, two `Process` children (notify-send, paplay), and both bar pill components (`horizontalBarPill`, `verticalBarPill`). Also contains the popup `Window`.
- **`PomodoroWidget/PomodoroSettings.qml`** — a `PluginSettings` component that renders the DMS settings panel using `SliderSetting`, `ToggleSetting`, and `TextSetting` from `qs.Widgets`.

Configuration comes from `pluginData` (DMS-injected from `~/.config/DankMaterialShell/plugin_settings.json` under key `"pomodoroWidget"`).

### Timer state machine

`mode` drives everything:
- `0` = idle
- `1` = work (arc fills CW)
- `2` = short break (arc retreats CCW)
- `3` = long break (arc retreats CCW)

`_breakPending` is the flag set when `autoStartBreak` is false and a work session ends — the bar stays idle but the play button starts a break instead of a new work session.

### Bar pill

- **Idle**: single `DankIcon` with `name: "timer"` in `Theme.primary`
- **Running / paused / break**: `Canvas` arc + pomodoro count text
- Paused state is indicated by a pulsing opacity `SequentialAnimation` on the arc

### Popup

A `Window` child with `flags: Qt.Popup | Qt.FramelessWindowHint`, toggled via `pillClickAction`. Position is set by `popupTargetX` (passed from the pill click coordinates). Closes automatically when it loses focus (`onActiveChanged`).

## Known caveats

- **Popup positioning on Wayland** is compositor-dependent. On Niri the `x`/`y` set on the `Window` (`popupWin`) may be ignored. If the popup appears in the wrong place, the fix is to replace the `Window` with a `PanelWindow + WlrLayerShell` (requires `import Quickshell.Wayland`).
- **`SliderSetting` / `TextSetting`** in `PomodoroSettings.qml` are assumed to exist in `qs.Widgets` — if they are missing from the DMS version in use, the settings panel won't render (the widget itself still works via `plugin_settings.json`).
- **Material Icons font**: `DankIcon` is assumed to resolve `"timer"`, `"play_arrow"`, `"pause"`, `"replay"`, `"skip_next"` from the font DMS ships. If icons render as squares, the font family name used internally by DMS may differ.

## DMS imports used

```qml
import Quickshell
import Quickshell.Io     // Process
import qs.Common         // Theme
import qs.Widgets        // DankIcon, StyledText, SliderSetting, ToggleSetting, TextSetting
import qs.Modules.Plugins // PluginComponent, PluginSettings
```

## QML gotchas

- Use `var` (not `const`/`let`) in QML signal handlers and `onPaint` — the QML engine version bundled with DMS may not support ES6 variable declarations.
- Avoid identifiers that are QML reserved words (e.g. don't name a property `long`).
- `readonly property` computed from other properties updates reactively; mutable timer state must be plain `property`.
