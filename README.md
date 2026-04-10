# Pomodoro Timer — DankMaterialShell Widget

A study-focused Pomodoro timer widget for [DankMaterialShell](https://github.com/anametologin/DankMaterialShell) on Niri/Wayland.

## Features

- Circular arc that **fills clockwise** during work, **empties counter-clockwise** during break (breathing rhythm)
- Themed icon when idle — uses the DMS accent color
- Session dot tracker showing progress through the current cycle
- Notifications at session end (via `notify-send`)
- Optional sound playback (off by default)
- Auto-start break optional (off by default — leaves time for notes)
- Configurable durations, all with sensible defaults so it works out of the box

## Installation

```bash
git clone <this-repo> ~/Documents/projects/pomodoro
cd ~/Documents/projects/pomodoro
chmod +x install.sh
./install.sh
```

Then restart DankMaterialShell (`Super+Shift+R` or re-login).

The widget appears at the **start of the center bar**.

## Manual Installation

If you prefer to install manually:

1. Copy `PomodoroWidget/` to `~/.config/DankMaterialShell/plugins/`
2. In `~/.config/DankMaterialShell/settings.json`, add `"pomodoroWidget"` to the start of `centerWidgets`
3. In `~/.config/DankMaterialShell/plugin_settings.json`, add the defaults block below
4. Restart DMS

## Usage

| Action | Result |
|---|---|
| Click widget (bar) | Toggle popup open/close |
| **▶** (play) | Start a work session (or resume if paused) |
| **⏸** (pause) | Pause/resume the current session |
| **↺** (reset) | Reset the current timer, return to idle |
| **⏭** (skip) | Skip to end of current session |
| **Reset Session** | Clear pomodoro count, return to idle |

When a work session ends: notification fires. Break starts manually (or automatically if configured). When a break ends: notification fires, returns to idle.

## Configuration

Edit `~/.config/DankMaterialShell/plugin_settings.json`, or use the DMS settings panel (Plugins → Pomodoro Timer).

```json
{
  "pomodoroWidget": {
    "enabled": true,

    "workDuration": 25,               // Work session length in minutes
    "shortBreakDuration": 5,          // Short break length in minutes
    "longBreakDuration": 15,          // Long break length in minutes
    "pomodorosUntilLongBreak": 4,     // Sessions per cycle before long break

    "autoStartBreak": false,          // Set true to start breaks automatically
    "enableSound": false,             // Set true to play a sound at session end
    "soundFile": ""                   // Absolute path to audio file (used by paplay)
  }
}
```

### Sound example

```json
"enableSound": true,
"soundFile": "/home/yourname/sounds/bell.ogg"
```

Requires `paplay` (part of `pulseaudio-utils` / `pipewire-pulse`).

## Popup Window on Wayland

The popup uses Qt's `Qt.Popup` window type, which maps to `xdg-popup` on Wayland. On Niri this should appear just below the bar, centered on the widget. If positioning is off, you can adjust the `x`/`y` values in `PomodoroWidget.qml` (search for `popupWin`).

## Arc Behaviour

- **Work session**: arc fills clockwise from 12 o'clock (0% → 100%)
- **Break**: arc empties — the leading edge retreats counter-clockwise (100% → 0%)
- **Paused**: arc pulses (opacity animation) to indicate frozen state

The dot row in the popup shows your position within the current cycle. After 4 (configurable) sessions, a long break is triggered and the dot row resets.
